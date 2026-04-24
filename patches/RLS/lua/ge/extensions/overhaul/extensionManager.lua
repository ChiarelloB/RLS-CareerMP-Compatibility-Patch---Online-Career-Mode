local M = {}

local ourModName = "rls_career_overhaul"
local ourModId = "RLSCO24"

local commandCallback = nil
local devKey = "dc124d6fb1a6261f"


local function checkVersion()
    local fileData = jsonReadFile("integrity.json")
    if fileData.version then
        local version = fileData.version
        local versionParts = string.split(version, ".")
        if versionParts[4] ~= "8" then
            guihooks.trigger("toastrMsg", {type="error", title="Update required", msg="RLS Career Overhaul is outdated. Please update to the latest version either from Patreon or Github."})
            return false
        end
    end
    return true
end

-- local function deactivateBeamMP()
--     local beammp = core_modmanager.getMods()["multiplayerbeammp"]
--     if beammp then
--         core_modmanager.deactivateMod("multiplayerbeammp")
--     end
-- end

-- Configures unload behavior for overhaul runtime: sets several gameplay, career and editor extensions to manual unload and unloads extensions that must remain disabled while the overhaul is active.
-- CareerMP needs the drag practice race extension alive because RLS drag strip lights,
-- freeroam drag events and tuning shop drag jobs use that runtime path.
local function loadExtensions()

    extensions.unload("freeroam_freeroam")
    extensions.unload("core_recoveryPrompt")

    setExtensionUnloadMode("gameplay_drag_dragTypes_dragPracticeRace", "manual")
    setExtensionUnloadMode("gameplay_events_freeroamEvents", "manual")
    setExtensionUnloadMode("gameplay_phone", "manual")
    setExtensionUnloadMode("gameplay_repo", "manual")
    setExtensionUnloadMode("gameplay_taxi", "manual")
    setExtensionUnloadMode("gameplay_cab", "manual")
    setExtensionUnloadMode("gameplay_cardGames", "manual")
    setExtensionUnloadMode("gameplay_loading", "manual")
    setExtensionUnloadMode("gameplay_ambulance", "manual")
    setExtensionUnloadMode("gameplay_bus", "manual")
    setExtensionUnloadMode("gameplay_beamEats", "manual")
    setExtensionUnloadMode("gameplay_phoneCamera", "manual")
    setExtensionUnloadMode("gameplay_facilityWork", "manual")
    setExtensionUnloadMode("career_challengeModes", "manual")
    setExtensionUnloadMode("career_economyAdjuster", "manual")
    setExtensionUnloadMode("career_challengeSeedEncoder", "manual")
    setExtensionUnloadMode("editor_freeroamEventEditor", "manual")

    setExtensionUnloadMode("dynamicRoutes", "manual")
    setExtensionUnloadMode("editor_dynamicRoutesEditor", "manual")

    extensions.unload("career_career")
    extensions.unload("career_saveSystem")
end

local function loadExtensionIfNeeded(extensionName)
    if not extensionName or not extensions or not extensions.load then
        return
    end

    setExtensionUnloadMode(extensionName, "manual")
    if extensions.isExtensionLoaded and extensions.isExtensionLoaded(extensionName) then
        return
    end

    pcall(extensions.load, extensionName)
end

local function ensureDragRuntimeExtensions()
    -- The drag practice stack drives staging AI, tree lights, timeslips and
    -- RLS drag payouts. Keeping it warm avoids BeamMP/CareerMP load-order
    -- races where the opponent spawns but never receives staging commands.
    local dragExtensions = {
        "gameplay_drag_general",
        "gameplay_drag_utils",
        "gameplay_drag_times",
        "gameplay_drag_display",
        "gameplay_drag_dragTypes_dragPracticeRace",
    }

    for _, extensionName in ipairs(dragExtensions) do
        loadExtensionIfNeeded(extensionName)
    end
end

-- Unloads all career, gameplay, freeroam, and overhaul-related extensions used by the mod.
-- 
-- This forces removal of core game context, freeroam/events, gameplay modules (phone, repo, taxi, cab, ambulance, bus, beamEats),
-- career subsystems (career, save system, challenge modes, economy adjuster, challenge seed encoder), and overhaul modules
-- (settings, maps, clear levels, add map changes). No value is returned.
-- Remove the openPhone binding from saved bindings so the vanilla
-- bindingsLegend doesn't crash after the mod is deactivated.
local function removePhoneBinding()
    pcall(function()
        if not core_input_bindings or not core_input_bindings.bindings then return end
        for _, device in ipairs(core_input_bindings.bindings) do
            if device.contents and device.contents.bindings then
                local bindings = device.contents.bindings
                for i = #bindings, 1, -1 do
                    if bindings[i].action == "openPhone" then
                        table.remove(bindings, i)
                    end
                end
                pcall(function()
                    core_input_bindings.saveBindingsToDisk(device.contents)
                end)
            end
        end
        -- Reload actions so the engine drops the now-unmounted phone.json
        if core_input_actions then
            extensions.reload("core_input_actions")
        end
    end)
end

local function unloadAllExtensions()
    removePhoneBinding()
    extensions.unload("core_gameContext")
    extensions.unload("gameplay_events_freeroamEvents")
    extensions.unload("career_career")
    extensions.unload("career_saveSystem")
    extensions.unload("gameplay_phone")
    extensions.unload("freeroam_facilities")
    extensions.unload("gameplay_repo")
    extensions.unload("gameplay_taxi")
    extensions.unload("gameplay_cab")
    extensions.unload("gameplay_ambulance")
    extensions.unload("gameplay_bus")
    extensions.unload("gameplay_beamEats")
    extensions.unload("gameplay_phoneCamera")
    extensions.unload("gameplay_facilityWork")
    extensions.unload("overhaul_settings")
    extensions.unload("overhaul_maps")
    extensions.unload("overhaul_clearLevels")
    extensions.unload("overhaul_addMapChanges")
    extensions.unload("career_challengeModes")
    extensions.unload("career_economyAdjuster")
    extensions.unload("career_challengeSeedEncoder")
    extensions.unload("dynamicRoutes")
    extensions.unload("editor_dynamicRoutesEditor")
end

local function startup()
    -- deactivateBeamMP()

    setExtensionUnloadMode("overhaul_overrideManager", "manual")
    extensions.load("overhaul_overrideManager")

    setExtensionUnloadMode("overhaul_settings", "manual")
    setExtensionUnloadMode("overhaul_maps", "manual")
    setExtensionUnloadMode("overhaul_clearLevels", "manual")
    setExtensionUnloadMode("overhaul_addMapChanges", "manual")

    if not core_gamestate.state or core_gamestate.state.state ~= "career" then
        loadExtensions()
    end

    core_jobsystem.create(function(job)
        job.sleep(5)
        if not checkVersion() then
            print("Deactivating RLS Career Overhaul")
            core_modmanager.deactivateModId("RLSCO24")
        end
    end)

    loadManualUnloadExtensions()
    ensureDragRuntimeExtensions()
end

local function onModActivated(modData)
    if ourModName or ourModId then
        return
    end

    if not modData or not modData.modname then
        return
    end

    if modData.modname and (modData.modname:find("BatchActivation_") or modData.modname:find("BatchDeactivation_")) then
        return
    end

    if not ourModName then
        ourModName = modData.modname
        if modData.modData and modData.modData.tagid then
            ourModId = modData.modData.tagid
        end
        return true
    end
end

local function onModDeactivated(modData)
    if not modData or not modData.modname then
        return
    end

    if modData.modname and (modData.modname:find("BatchActivation_") or modData.modname:find("BatchDeactivation_")) then
        return
    end

    if (ourModName and modData.modname == ourModName) or
       (ourModId and modData.modData and modData.modData.tagid == ourModId) then
        unloadAllExtensions()
        loadManualUnloadExtensions()
    end
end

local function getVehicleId(veh)
    if not veh then return nil end

    local ok, id = pcall(function()
        if veh.getID then return veh:getID() end
        if veh.getId then return veh:getId() end
        if veh.id then return veh.id end
        return nil
    end)

    if ok then
        return id
    end
    return nil
end

local function isDragRacerVehicle(vehId)
    if not vehId or not gameplay_drag_general or not gameplay_drag_general.getData then
        return false
    end

    local ok, dragData = pcall(gameplay_drag_general.getData)
    if not ok or not dragData or not dragData.racers then
        return false
    end

    return dragData.racers[vehId] ~= nil
end

local function installVehicleAiOverride(veh, vehId)
    if not veh then return end

    -- Drag NPCs must stay on the vanilla drag AI controller. RLS overrideAI is
    -- useful elsewhere, but on staged opponents it can swallow the drag strip's
    -- ai.setTarget/ai.setSpeed flow and leave the car sitting at the line.
    if isDragRacerVehicle(vehId) then
        return
    end

    pcall(function()
        veh:queueLuaCommand([[
            extensions.load('overrideAI')
            ai = overrideAI
        ]])
    end)
end

local function onVehicleSpawned(_, veh)
    if not veh then return end

    veh:queueLuaCommand("extensions.load('fuelMultiplier')")

    local vehId = getVehicleId(veh)
    if core_jobsystem and core_jobsystem.create then
        core_jobsystem.create(function(job)
            job.sleep(0.5)
            installVehicleAiOverride(veh, vehId)
        end)
    else
        installVehicleAiOverride(veh, vehId)
    end
end

local function updateEditorBlocking()
    local blockedActions = {"editorToggle", "editorSafeModeToggle", "vehicleEditorToggle"}
    core_input_actionFilter.setGroup("RLS_DEACTIVATION", blockedActions)
    local cheatsEnabled = career_modules_cheats and career_modules_cheats.isCheatsMode()
    if not M.isDevKeyValid() and career_career.isActive() and not cheatsEnabled then
        core_input_actionFilter.addAction(0, "RLS_DEACTIVATION", true)
    else
        core_input_actionFilter.addAction(0, "RLS_DEACTIVATION", false)
    end
end

M.onWorldReadyState = function(state)
    if state == 2 then
        ensureDragRuntimeExtensions()
        updateEditorBlocking()
    end
end

M.onCheatsModeChanged = function(enabled)
    updateEditorBlocking()
end
  
M.onVehicleSpawned = onVehicleSpawned
M.onExtensionLoaded = startup
M.onModActivated = onModActivated
M.onModDeactivated = onModDeactivated

M.isDevKeyValid = function()
    return devKey == FS:hashFile("devkey.txt")
end

M.getModData = function()
    return {
        name = ourModName,
        id = ourModId
    }
end

return M
