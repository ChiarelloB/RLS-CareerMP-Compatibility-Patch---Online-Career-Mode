--CareerMP (CLIENT) by Dudekahedron, 2026

local M = {}

--Setup

local nickname = MPConfig.getNickname()

local blockedInputActions = {}

local clientConfig

local function getClientConfig()
	return clientConfig
end

local careerMPActive = false
local syncRequested = false
local trafficRuntimeTimer = 0
local remoteGhostRefreshTimer = 0

local originalMPOnUpdate
local originalGetDriverData

local inComputerMenus = false

local function countTableEntries(t)
	if type(t) ~= "table" then return 0 end
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

local function diag(message)
	log('W', 'CareerMP-DIAG', tostring(message))
end

--Settings

local userTrafficSettings = {}
local careerMPTrafficSettings = {}

local userGameplaySettings = {}
local careerMPGameplaySettings = {}

local function getUserTrafficSettings()
	userTrafficSettings.trafficSmartSelections = settings.getValue('trafficSmartSelections')
	userTrafficSettings.trafficSimpleVehicles = settings.getValue('trafficSimpleVehicles')
	userTrafficSettings.trafficAllowMods = settings.getValue('trafficAllowMods')
	userTrafficSettings.trafficAmount = settings.getValue('trafficAmount')
	userTrafficSettings.trafficParkedAmount = settings.getValue('trafficParkedAmount')
	userTrafficSettings.trafficParkedVehicles = settings.getValue('trafficParkedVehicles')
end

local function setTrafficSettings(trafficSettings)
	for setting, value in pairs(trafficSettings) do
		settings.setValue(setting, value)
	end
end

local function applyTrafficRuntimeState()
	if not clientConfig then return end

	local roadTrafficEnabled = clientConfig.roadTrafficEnabled == true
	local parkedTrafficEnabled = clientConfig.parkedTrafficEnabled == true
	local roadTrafficAmount = clientConfig.roadTrafficAmount or 0
	local parkedTrafficAmount = clientConfig.parkedTrafficAmount or 0

	if freeroam_freeroam and freeroam_freeroam.spawningOptionsHelper then
		freeroam_freeroam.spawningOptionsHelper.trafficMode = roadTrafficEnabled and "enabled" or "disabled"
		freeroam_freeroam.spawningOptionsHelper.trafficAmount = roadTrafficAmount
		freeroam_freeroam.spawningOptionsHelper.trafficPolice = "disabled"
		freeroam_freeroam.spawningOptionsHelper.trafficPoliceRatio = 0
		freeroam_freeroam.spawningOptionsHelper.trafficParked = parkedTrafficEnabled and "enabled" or "disabled"
		freeroam_freeroam.spawningOptionsHelper.trafficParkedAmount = parkedTrafficAmount
	end

	if not roadTrafficEnabled and gameplay_traffic then
		if gameplay_traffic.deactivate then gameplay_traffic.deactivate(true) end
		if gameplay_traffic.deleteVehicles then gameplay_traffic.deleteVehicles() end
	end

	if not parkedTrafficEnabled and gameplay_parking then
		if gameplay_parking.deactivate then gameplay_parking.deactivate() end
		if gameplay_parking.deleteVehicles then gameplay_parking.deleteVehicles() end
	end
end

local function getUserGameplaySettings()
	userGameplaySettings.simplifyRemoteVehicles = settings.getValue("simplifyRemoteVehicles")
	userGameplaySettings.spawnVehicleIgnitionLevel = settings.getValue("spawnVehicleIgnitionLevel")
	userGameplaySettings.skipOtherPlayersVehicles = settings.getValue("skipOtherPlayersVehicles")
end

local function setGameplaySettings(gameplaySettings)
	for setting, value in pairs(gameplaySettings) do
		settings.setValue(setting, value)
	end
end

local function safeIsOwn(gameVehicleID)
	return gameVehicleID and MPVehicleGE and MPVehicleGE.isOwn and MPVehicleGE.isOwn(gameVehicleID)
end

local function safeGetServerVehicleID(gameVehicleID)
	if not (gameVehicleID and MPVehicleGE and MPVehicleGE.getServerVehicleID) then
		return nil
	end
	return MPVehicleGE.getServerVehicleID(gameVehicleID)
end

local function syncVehicleActiveState(gameVehicleID, active)
	if not safeIsOwn(gameVehicleID) then
		return
	end

	local serverVehicleID = safeGetServerVehicleID(gameVehicleID)
	if not serverVehicleID then
		return
	end

	local data = {}
	data.active = active
	data.serverVehicleID = serverVehicleID
	diag('tx vehicle active state serverVehicleID=' .. tostring(serverVehicleID) .. ' gameVehicleID=' .. tostring(gameVehicleID) .. ' active=' .. tostring(active))
	TriggerServerEvent("careerVehicleActiveHandler", jsonEncode(data))
end

local function getVehicleLicenseText(veh)
	if not veh then
		return "Illegible"
	end
	return veh:getDynDataFieldbyName("licenseText", 0) or "Illegible"
end

local function getVehicleModelName(veh)
	if not veh then
		return "Unknown"
	end

	if core_vehicles and core_vehicles.getModel and veh.JBeam then
		local ok, modelData = pcall(core_vehicles.getModel, veh.JBeam)
		if ok and modelData and modelData.model and modelData.model.Name then
			return modelData.model.Name
		end
	end

	return veh.JBeam or "Unknown"
end

local function applyRemoteGhostState(veh)
	if not (veh and clientConfig) then
		return
	end

	if veh.JBeam == "unicycle" then
		-- Remote walking players should stay visible. Ghosting unicycles can
		-- make BeamMP render them as grey placeholder orbs for late joiners.
		veh:queueLuaCommand('careerMPEnabler.setUnicycleGhost(false)')
		return
	end

	veh:queueLuaCommand('careerMPEnabler.setAllGhost(' .. tostring(clientConfig.allGhost == true) .. ')')
end

--Hidden Nametags by Vehicle Model

local hiddens = {
	anticut = "anticut",
	ball = "ball",
	barrels = "barrels",
	barrier = "barrier",
	barrier_plastic = "barrier_plastic",
	blockwall = "blockwall",
	bollard = "bollard",
	boxutility = "boxutility",
	boxutility_large = "boxutility_large",
	cannon = "cannon",
	caravan = "caravan",
	cardboard_box = "cardboard_box",
	cargotrailer = "cargotrailer",
	chair = "chair",
	christmas_tree = "christmas_tree",
	cones = "cones",
	containerTrailer = "containerTrailer",
	couch = "couch",
	crowdbarrier = "crowdbarrier",
	delineator = "delineator",
	dolly = "dolly",
	dryvan = "dryvan",
	engine_props = "engine_props",
	flail = "flail",
	flatbed = "flatbed",
	flipramp = "flipramp",
	frameless_dump = "frameless_dump",
	fridge = "fridge",
	gate = "gate",
	haybale = "haybale",
	inflated_mat = "inflated_mat",
	kickplate = "kickplate",
	large_angletester = "large_angletester",
	large_bridge = "large_bridge",
	large_cannon = "large_cannon",
	large_crusher = "large_crusher",
	large_hamster_wheel = "large_hamster_wheel",
	large_roller = "large_roller",
	large_spinner = "large_spinner",
	large_tilt = "large_tilt",
	large_tire = "large_tire",
	log_trailer = "log_trailer",
	logs = "logs",
	mattress = "mattress",
	metal_box = "metal_box",
	metal_ramp = "metal_ramp",
	piano = "piano",
	porta_potty = "porta_potty",
	pressure_ball = "pressure_ball",
	rallyflags = "rallyflags",
	rallysigns = "rallysigns",
	rallytape = "rallytape",
	roadsigns = "roadsigns",
	rocks = "rocks",
	rollover = "rollover",
	roof_crush_tester = "roof_crush_tester",
	sawhorse = "sawhorse",
	shipping_container = "shipping_container",
	simple_traffic = "simple_traffic",
	spikestrip = "spikestrip",
	steel_coil = "steel_coil",
	streetlight = "streetlight",
	suspensionbridge = "suspensionbridge",
	tanker = "tanker",
	testroller = "testroller",
	tiltdeck = "tiltdeck",
	tirestacks = "tirestacks",
	tirewall = "tirewall",
	trafficbarrel = "trafficbarrel",
	trampoline = "trampoline",
	trashbin = "trashbin",
	tsfb = "tsfb",
	tub = "tub",
	tube = "tube",
	tv = "tv",
	wall = "wall",
	weightpad = "weightpad",
	woodcrate = "woodcrate",
	woodplanks = "woodplanks",
}

--Vehicles and part paints

local function rxCareerVehSync(data)
	if data ~= "null" then
		local vehicleStates = jsonDecode(data)
		diag('rx vehicle sync states=' .. tostring(countTableEntries(vehicleStates)))
		local vehicles = MPVehicleGE.getVehicles()
		for serverVehicleID, state in pairs(vehicleStates) do
			if vehicles[serverVehicleID] then
				local gameVehicleID = vehicles[serverVehicleID].gameVehicleID
				if gameVehicleID ~= -1 then
					if not safeIsOwn(gameVehicleID) then
						local veh = be:getObjectByID(gameVehicleID)
						if veh then
							if not state.active then
								veh:setActive(0)
								vehicles[serverVehicleID].hideNametag = true
							else
								veh:setActive(1)
								if hiddens[vehicles[serverVehicleID].jbeam] then
									vehicles[serverVehicleID].hideNametag = true
								else
									vehicles[serverVehicleID].hideNametag = false
								end
							end
						end
					end
				end
			end
		end
	end
end

local function onVehicleActiveChanged(gameVehicleID, active)
	if gameVehicleID then
		diag('vehicle active changed gameVehicleID=' .. tostring(gameVehicleID) .. ' own=' .. tostring(safeIsOwn(gameVehicleID)) .. ' active=' .. tostring(active))
		if safeIsOwn(gameVehicleID) then
			syncVehicleActiveState(gameVehicleID, active)
		else
			TriggerServerEvent("careerVehSyncRequested", "")
		end
	end
end

local function onVehicleSpawned(gameVehicleID)
	if gameVehicleID then
		diag('vehicle spawned gameVehicleID=' .. tostring(gameVehicleID) .. ' own=' .. tostring(safeIsOwn(gameVehicleID)))
		local veh = be:getObjectByID(gameVehicleID)
		if veh then
			veh:queueLuaCommand('careerMPEnabler.onVehicleReady()')
		end
		if not safeIsOwn(gameVehicleID) then
			TriggerServerEvent("careerVehSyncRequested", "")
		end
	end
end

local function onVehicleReady(gameVehicleID)
	local serverVehicleID = safeGetServerVehicleID(gameVehicleID)
	if serverVehicleID then
		local veh = be:getObjectByID(gameVehicleID)
		if veh then
			diag('vehicle ready serverVehicleID=' .. tostring(serverVehicleID) .. ' gameVehicleID=' .. tostring(gameVehicleID) .. ' jbeam=' .. tostring(veh.JBeam) .. ' own=' .. tostring(safeIsOwn(gameVehicleID)))
			if not safeIsOwn(gameVehicleID) then
				local vehicles = MPVehicleGE.getVehicles()
				applyRemoteGhostState(veh)
				if hiddens[veh.JBeam] then
					vehicles[serverVehicleID].hideNametag = true
				else
					vehicles[serverVehicleID].hideNametag = false
				end
			end
			veh:setField('renderDistance', '', 1610)
		end
	end
end

local function onVehicleSwitched(oldGameVehicleID, newGameVehicleID)
	diag('vehicle switched old=' .. tostring(oldGameVehicleID) .. ' new=' .. tostring(newGameVehicleID))
	local newVeh = be:getObjectByID(newGameVehicleID)
	local oldVeh = be:getObjectByID(oldGameVehicleID)
	if oldVeh and oldVeh.JBeam == "unicycle" then
		syncVehicleActiveState(oldGameVehicleID, false)
	end
	if newVeh then
		if hiddens[newVeh.JBeam] then
			if not safeIsOwn(newGameVehicleID) then
				be:enterNextVehicle(0, 1)
			end
		end
		if newVeh.JBeam == "unicycle" then
			if inComputerMenus then
				gameplay_walk.setWalkingMode(false)
				be:enterVehicle(0, oldVeh)
			end
		end
	end
end

--Traffic Signals and Cameras

local function onSpeedTrapTriggered(speedTrapData, playerSpeed, overSpeed)
	if speedTrapData and safeIsOwn(speedTrapData.subjectID) then
		local veh = be:getObjectByID(speedTrapData.subjectID)
		speedTrapData.licensePlate = getVehicleLicenseText(veh)
		speedTrapData.vehicleModel = getVehicleModelName(veh)
		speedTrapData.playerSpeed = playerSpeed
		speedTrapData.overSpeed = overSpeed
		TriggerServerEvent("speedTrap", jsonEncode( speedTrapData ) )
	end
end

local function onRedLightCamTriggered(redLightData, playerSpeed)
	if redLightData and safeIsOwn(redLightData.subjectID) then
		local veh = be:getObjectByID(redLightData.subjectID)
		redLightData.licensePlate = getVehicleLicenseText(veh)
		redLightData.vehicleModel = getVehicleModelName(veh)
		redLightData.playerSpeed = playerSpeed
		TriggerServerEvent("redLight", jsonEncode( redLightData ) )
	end
end

local function rxTrafficSignalTimer(data)
	if core_trafficSignals and core_trafficSignals.setTimer and tonumber(data) then
		core_trafficSignals.setTimer(tonumber(data))
	end
end

--Garage / Office Computer Handling

local function computerMenuHandler(targetVehicleID)
	if targetVehicleID then
		local veh = be:getObjectByID(targetVehicleID)
		if veh then
			if veh.JBeam ~= "unicycle" then
				if gameplay_walk.isWalking() then
					gameplay_walk.getInVehicle(veh)
				else
					be:enterVehicle(0, veh)
				end
				inComputerMenus = true
			end
		end
	end
end

local function onComputerOpened()
	if inComputerMenus then
		inComputerMenus = false
	end
end

--Patch BeamMP behavior and topBar

local function patchTopBar()
	if not (ui_topBar and ui_topBar.getEntries and ui_topBar.removeEntry and ui_topBar.updateEntries and ui_topBar.updateVisibleItems) then
		return
	end
	local entries = ui_topBar.getEntries()
	ui_topBar.removeEntry("environment")
	ui_topBar.removeEntry("mods")
	ui_topBar.removeEntry("vehicleconfig")
	ui_topBar.removeEntry("vehicles")
	entries = ui_topBar.getEntries()
	ui_topBar.updateEntries(entries)
	ui_topBar.updateVisibleItems()
end

local function modifiedGetDriverData(veh)
	if not veh then return nil end
	local caller = debug.getinfo(2).name
	if caller and caller == "getDoorsidePosRot" and veh.mpVehicleType and veh.mpVehicleType == 'R' then
		local id, right = core_camera.getDriverDataById(veh and veh:getID())
		return id, not right
	end
	return core_camera.getDriverDataById(veh and veh:getID())
end

local function modifiedOnUpdate(dt)
	if MPCoreNetwork and MPCoreNetwork.isMPSession() then
		if core_camera.getDriverData ~= modifiedGetDriverData then
			log('W', 'onUpdate', 'Setting modifiedGetDriverData')
			originalGetDriverData = core_camera.getDriverData
			core_camera.getDriverData = modifiedGetDriverData
		end
		if worldReadyState == 0 then
			serverConnection.onCameraHandlerSetInitial()
			extensions.hook('onCameraHandlerSet')
		end
	end
end

local function patchBeamMP()
	if multiplayer_multiplayer then
		if multiplayer_multiplayer.onUpdate ~= modifiedOnUpdate then
			originalMPOnUpdate = multiplayer_multiplayer.onUpdate
			multiplayer_multiplayer.onUpdate = modifiedOnUpdate
		end
	end
end

local function unPatchBeamMP()
	multiplayer_multiplayer.onUpdate = originalMPOnUpdate
	core_camera.getDriverData = originalGetDriverData
end

--Initial Syncs and Updates

local function actionsCheck()
	if not clientConfig.consoleEnabled then
		table.insert(blockedInputActions, "toggleConsoleNG")
		extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
		extensions.core_input_actionFilter.addAction(0, 'careerMP', true)
	elseif clientConfig.consoleEnabled then
		extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
		extensions.core_input_actionFilter.addAction(0, 'careerMP', false)
	end
	if not clientConfig.worldEditorEnabled then
		table.insert(blockedInputActions, "editorToggle")
		table.insert(blockedInputActions, "editorSafeModeToggle")
		table.insert(blockedInputActions, "objectEditorToggle")
		extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
		extensions.core_input_actionFilter.addAction(0, 'careerMP', true)
	elseif clientConfig.worldEditorEnabled then
		extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
		extensions.core_input_actionFilter.addAction(0, 'careerMP', false)
	end
end

local function settingsCheck()
	careerMPTrafficSettings.trafficAllowMods = clientConfig.trafficAllowMods
	careerMPTrafficSettings.trafficSimpleVehicles = clientConfig.trafficSimpleVehicles
	careerMPTrafficSettings.trafficSmartSelections = clientConfig.trafficSmartSelections
	careerMPTrafficSettings.trafficAmount = clientConfig.roadTrafficEnabled and clientConfig.roadTrafficAmount or 0
	careerMPTrafficSettings.trafficParkedAmount = clientConfig.parkedTrafficEnabled and clientConfig.parkedTrafficAmount or 0
	careerMPTrafficSettings.trafficParkedVehicles = clientConfig.parkedTrafficEnabled == true
	setTrafficSettings(careerMPTrafficSettings)
	applyTrafficRuntimeState()
	-- Simple remote vehicles can appear as grey placeholder orbs for players,
	-- walking unicycles, and parked cars when BeamMP streams them late.
	careerMPGameplaySettings.simplifyRemoteVehicles = false
	careerMPGameplaySettings.spawnVehicleIgnitionLevel = clientConfig.spawnVehicleIgnitionLevel
	careerMPGameplaySettings.skipOtherPlayersVehicles = clientConfig.skipOtherPlayersVehicles
	setGameplaySettings(careerMPGameplaySettings)
	diag('settings applied roadTrafficEnabled=' .. tostring(clientConfig.roadTrafficEnabled) .. ' roadTrafficAmount=' .. tostring(clientConfig.roadTrafficAmount) .. ' parkedTrafficEnabled=' .. tostring(clientConfig.parkedTrafficEnabled) .. ' parkedTrafficAmount=' .. tostring(clientConfig.parkedTrafficAmount) .. ' simplifyRemoteVehicles=false skipOtherPlayersVehicles=' .. tostring(clientConfig.skipOtherPlayersVehicles))
end

local function rxCareerSync(data)
	clientConfig = jsonDecode(data)
	diag('rx career sync payload=' .. tostring(data))
	nickname = MPConfig.getNickname()
	blockedInputActions = {}
	settingsCheck()
	actionsCheck()
	if not careerMPActive then
		if clientConfig.serverSaveNameEnabled then
			nickname = clientConfig.serverSaveName
		end
		local currentLevel = getCurrentLevelIdentifier and getCurrentLevelIdentifier() or nil
		career_career.createOrLoadCareerAndStart(nickname .. clientConfig.serverSaveSuffix, false, false, nil, nil, nil, currentLevel)
		careerMPActive = true
	end
end

local function rxClientConfigUpdate(data)
	clientConfig = jsonDecode(data)
	diag('rx config update payload=' .. tostring(data))
	blockedInputActions = {}
	settingsCheck()
	actionsCheck()
end

local function onCareerActive(active)
	if active and careerMPActive then
		local vehicles = MPVehicleGE.getVehicles()
		for _, vehicle in pairs(vehicles) do
			if vehicle.isLocal then
				if vehicle.jbeam ~= "unicycle" then
					be:getObjectByID(vehicle.gameVehicleID):delete()
				end
			end
		end
	end
end

local function onWorldReadyState(state)
	if state == 2 then
		if not syncRequested then
			diag('world ready: requesting prefab/career sync')
			TriggerServerEvent("prefabSyncRequested", "")
			TriggerServerEvent("careerSyncRequested", "")
			syncRequested = true
		end
	end
end

local function onClientPostStartMission(levelPath)
	patchTopBar()
end

local function onUpdate(dtReal, dtSim, dtRaw)
	patchBeamMP()
	if clientConfig then
		trafficRuntimeTimer = trafficRuntimeTimer + (dtReal or 0)
		if trafficRuntimeTimer > 2 then
			applyTrafficRuntimeState()
			trafficRuntimeTimer = 0
		end
	end
	if worldReadyState == 2 then
		if clientConfig then
			remoteGhostRefreshTimer = remoteGhostRefreshTimer + (dtReal or 0)
			if remoteGhostRefreshTimer <= 2 then
				return
			end
			remoteGhostRefreshTimer = 0
			local vehicles = MPVehicleGE.getVehicles()
			for serverVehicleID in pairs(vehicles) do
				local veh = be:getObjectByID(vehicles[serverVehicleID].gameVehicleID)
				if veh then
					if not safeIsOwn(vehicles[serverVehicleID].gameVehicleID) then
						applyRemoteGhostState(veh)
					end
				end
			end
		end
	end
end

--Loading / Unloading

local function onExtensionLoaded()
	getUserTrafficSettings()
	getUserGameplaySettings()
	AddEventHandler("rxCareerSync", rxCareerSync)
	AddEventHandler("rxClientConfigUpdate", rxClientConfigUpdate)
	AddEventHandler("rxCareerVehSync", rxCareerVehSync)
	AddEventHandler("rxTrafficSignalTimer", rxTrafficSignalTimer)
	career_career = extensions.career_careerMP
	if extensions.disableSerialization then
		extensions.disableSerialization("career_career")
	end
	log('W', 'careerMP', 'CareerMP Enabler LOADED!')
end

local function onExtensionUnloaded()
	log('W', 'careerMP', 'CareerMP Enabler UNLOADED!')
end

local function onServerLeave()
	diag('server leave: restoring local settings and BeamMP hooks')
	unPatchBeamMP()
	blockedInputActions = {}
	extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
	extensions.core_input_actionFilter.addAction(0, 'careerMP', false)
	setTrafficSettings(userTrafficSettings)
	setGameplaySettings(userGameplaySettings)
end

--Access

M.getClientConfig = getClientConfig

M.onCareerActive = onCareerActive

M.onVehicleActiveChanged = onVehicleActiveChanged
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleReady = onVehicleReady
M.onVehicleSwitched = onVehicleSwitched

M.onSpeedTrapTriggered = onSpeedTrapTriggered
M.onRedLightCamTriggered = onRedLightCamTriggered

M.onComputerOpened = onComputerOpened
M.onComputerMenuOpened = onComputerOpened

M.onCareerTuningStarted = computerMenuHandler
M.onPartShoppingStarted = computerMenuHandler
M.onPerformanceTestStarted = computerMenuHandler
M.onVehiclePaintingUiOpened = computerMenuHandler

M.onClientPostStartMission = onClientPostStartMission

M.onWorldReadyState = onWorldReadyState
M.onUpdate = onUpdate

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

M.onServerLeave = onServerLeave

M.onInit = function() setExtensionUnloadMode(M, 'manual') end

return M
