-- Multiplayer-safe RLS speed/red-light camera handling.
-- RLS expects the player's vehicle to always be registered as traffic. In
-- CareerMP, traffic can be disabled and remote/late-join vehicles can be nil,
-- so every external lookup must be guarded before issuing fines.

local M = {}

local leaderboardFolder = "/career/speedTrapLeaderboards/"
local core_vehicles = require('core/vehicles')

M.dependencies = {'career_career', 'gameplay_speedTraps', 'gameplay_traffic'}

local fines = {
  {overSpeed = 6.7056, fine = {money = {amount = 750, canBeNegative = true}}},
  {overSpeed = 11.176, fine = {money = {amount = 2000, canBeNegative = true}}},
}
local maxFine = {money = {amount = 2000, canBeNegative = true}}
local playerPursuiting = false

local function isHardcoreMode()
  if career_modules_difficultyMode and career_modules_difficultyMode.isHardcoreMode then
    return career_modules_difficultyMode.isHardcoreMode() == true
  end
  return career_career and career_career.hardcoreMode == true
end

local function isInAmbulance()
  return gameplay_ambulance and gameplay_ambulance.isInAmbulance and gameplay_ambulance.isInAmbulance() or false
end

local function getFineFromSpeed(overSpeed)
  for _, fineInfo in ipairs(fines) do
    if overSpeed <= fineInfo.overSpeed then
      return deepcopy(fineInfo.fine)
    end
  end
  return deepcopy(maxFine)
end

local function hasLicensePlate(inventoryId)
  if not inventoryId then
    return false
  end
  if not (career_modules_partInventory and career_modules_partInventory.getInventory) then
    -- If part inventory is not ready in multiplayer yet, prefer issuing the
    -- standard fine instead of silently exempting the vehicle.
    return true
  end
  for _, part in pairs(career_modules_partInventory.getInventory()) do
    if part.location == inventoryId and part.name and string.find(part.name, "licenseplate") then
      return true
    end
  end
  return false
end

local function getPlayerRole()
  if not (gameplay_traffic and gameplay_traffic.getTrafficData and be) then
    return nil
  end
  local playerVehicleId = be:getPlayerVehicleID(0)
  local trafficData = gameplay_traffic.getTrafficData()
  local playerTraffic = trafficData and trafficData[playerVehicleId] or nil
  return playerTraffic and playerTraffic.role and playerTraffic.role.name or nil
end

local function getLicenseText(veh)
  if core_vehicles and core_vehicles.getVehicleLicenseText and veh then
    local ok, text = pcall(core_vehicles.getVehicleLicenseText, veh)
    if ok and text then
      return text
    end
  end
  return "Illegible"
end

local function safePay(reward, label)
  if career_modules_payment and career_modules_payment.pay then
    career_modules_payment.pay(reward, {label = label, tags = {"fine"}})
  end
end

local function safeAddTicket(inventoryId)
  if inventoryId and career_modules_inventory and career_modules_inventory.addTicket then
    career_modules_inventory.addTicket(inventoryId)
  end
end

local function safeAddSpeedRecord(speedTrapData, playerSpeed, overSpeed, veh)
  if not (gameplay_speedTrapLeaderboards and gameplay_speedTrapLeaderboards.addRecord and veh) then
    return
  end

  local ok, highscore, leaderboard = pcall(gameplay_speedTrapLeaderboards.addRecord, speedTrapData, playerSpeed, overSpeed, veh)
  if not ok or not leaderboard then
    log("W", "speedTraps", "Could not update speed trap leaderboard: " .. tostring(highscore))
    return
  end

  local message
  if highscore then
    if leaderboard[2] then
      message = {txt = "ui.freeroam.speedTrap.newRecord", context = {recordedSpeed = playerSpeed, previousSpeed = leaderboard[2].speed}}
    else
      message = {txt = "ui.freeroam.speedTrap.newRecordNoOld", context = {recordedSpeed = playerSpeed}}
    end
  elseif leaderboard[1] then
    message = {txt = "ui.freeroam.speedTrap.noNewRecord", context = {recordedSpeed = playerSpeed, recordSpeed = leaderboard[1].speed}}
  end

  if message then
    ui_message(message, 10, 'speedTrapRecord')
  end
end

local function canHandlePlayerCameraEvent(data)
  if gameplay_cab and gameplay_cab.inCab and gameplay_cab.inCab() then
    return false
  end
  if isInAmbulance() then
    return false
  end
  if not (data and data.subjectID and be) then
    return false
  end
  return data.subjectID == be:getPlayerVehicleID(0)
end

local function onSpeedTrapTriggered(speedTrapData, playerSpeed, overSpeed)
  if not canHandlePlayerCameraEvent(speedTrapData) then
    return
  end
  if not speedTrapData.speedLimit then
    return
  end

  local playerRole = getPlayerRole()
  if playerPursuiting and playerRole == "police" then
    return
  end

  local vehId = speedTrapData.subjectID
  local veh = getPlayerVehicle(0) or scenetree.findObjectById(vehId)
  if not veh then
    return
  end

  local inventoryId = career_modules_inventory and career_modules_inventory.getInventoryIdFromVehicleId and career_modules_inventory.getInventoryIdFromVehicleId(vehId) or nil
  local vehInfo = inventoryId and career_modules_inventory and career_modules_inventory.getVehicles and career_modules_inventory.getVehicles()[inventoryId] or nil

  local penaltyType
  if not inventoryId then
    penaltyType = "default"
  elseif hasLicensePlate(inventoryId) then
    if vehInfo and vehInfo.owned then
      penaltyType = "default"
    elseif vehInfo and vehInfo.loanType == "work" then
      penaltyType = "workVehicle"
    else
      penaltyType = "default"
    end
  else
    penaltyType = "noLicensePlate"
  end

  if penaltyType == "default" then
    local fine = getFineFromSpeed(overSpeed or 0)
    fine.money.amount = fine.money.amount * (isHardcoreMode() and 10 or 1)
    local globalIndex = career_modules_globalEconomy and career_modules_globalEconomy.getGlobalIndex and career_modules_globalEconomy.getGlobalIndex() or 1.0
    fine.money.amount = math.floor(fine.money.amount * globalIndex)

    local speedStr = string.format("%.0f km/h (%.0f mph)", (playerSpeed or 0) * 3.6, (playerSpeed or 0) * 2.23694)
    local limitStr = string.format("%.0f km/h (%.0f mph)", speedTrapData.speedLimit * 3.6, speedTrapData.speedLimit * 2.23694)
    local plate = getLicenseText(veh)
    local message
    if playerRole == "police" then
      message = string.format("Traffic Violation (Officer Misconduct): \n - %q | Fine %d$\n - %s | (Limit: %s)\n - Abuse of power is not permitted", plate, fine.money.amount, speedStr, limitStr)
    else
      message = string.format("Traffic Violation (Speeding): \n - %q | Fine %d$\n - %s | (Limit: %s)", plate, fine.money.amount, speedStr, limitStr)
    end

    safePay(fine, "Fine for speeding")
    ui_message(message, 10, "speedTrap")
    Engine.Audio.playOnce('AudioGui', 'event:>UI>Career>Speedcam_Snapshot')
    safeAddTicket(inventoryId)
  elseif penaltyType == "noLicensePlate" then
    ui_message({txt = "ui.career.speedTrap.noLicensePlateMessage", context = {recordedSpeed = playerSpeed, speedLimit = speedTrapData.speedLimit}}, 10, 'speedTrap')
    Engine.Audio.playOnce('AudioGui', 'event:>UI>Career>Speedcam_Snapshot')
  elseif penaltyType == "workVehicle" and vehInfo and vehInfo.owningOrganization then
    local fine = {}
    fine[vehInfo.owningOrganization .. "Reputation"] = {amount = 10, canBeNegative = true}
    safePay(fine, "Reputation cost for speeding")
    ui_message(string.format("Traffic Violation (Speeding): \n - %q | Reputation Loss: 10 (%s)", getLicenseText(veh), vehInfo.owningOrganization), 10, "speedTrap")
  end

  safeAddSpeedRecord(speedTrapData, playerSpeed or 0, overSpeed or 0, veh)
end

local function onRedLightCamTriggered(speedTrapData, playerSpeed)
  if not canHandlePlayerCameraEvent(speedTrapData) then
    return
  end

  local playerRole = getPlayerRole()
  if playerPursuiting and playerRole == "police" then
    return
  end

  local vehId = speedTrapData.subjectID
  local veh = getPlayerVehicle(0) or scenetree.findObjectById(vehId)
  if not veh then
    return
  end

  local inventoryId = career_modules_inventory and career_modules_inventory.getInventoryIdFromVehicleId and career_modules_inventory.getInventoryIdFromVehicleId(vehId) or nil
  if not inventoryId or hasLicensePlate(inventoryId) then
    local redLightGlobalIndex = career_modules_globalEconomy and career_modules_globalEconomy.getGlobalIndex and career_modules_globalEconomy.getGlobalIndex() or 1.0
    local fine = {money = {amount = math.floor(500 * (isHardcoreMode() and 2 or 1) * redLightGlobalIndex), canBeNegative = true}}
    local message
    if playerRole == "police" then
      message = string.format("Traffic Violation (Officer Misconduct): \n - %q | Fine %d$\n - Abuse of power is not permitted", getLicenseText(veh), fine.money.amount)
    else
      message = string.format("Traffic Violation (Failure to stop at Red Light): \n - %q | Fine %d$", getLicenseText(veh), fine.money.amount)
    end

    safePay(fine, "Fine for driving over a red light")
    Engine.Audio.playOnce('AudioGui', 'event:>UI>Career>Speedcam_Snapshot')
    ui_message(message, 10, "speedTrap")
  else
    ui_message("Traffic Violation (Failure to stop at Red Light): \n - No license plate detected | Fine could not be issued", 10, "speedTrap")
  end
end

local function onExtensionLoaded()
  if not (career_career and career_career.isActive and career_career.isActive()) then
    return false
  end
  if career_saveSystem and career_saveSystem.getCurrentSaveSlot and gameplay_speedTrapLeaderboards and gameplay_speedTrapLeaderboards.loadLeaderboards then
    local _, savePath = career_saveSystem.getCurrentSaveSlot()
    if savePath then
      gameplay_speedTrapLeaderboards.loadLeaderboards(savePath .. leaderboardFolder)
    end
  end
end

local function onSaveCurrentSaveSlot(currentSavePath)
  if currentSavePath and gameplay_speedTrapLeaderboards and gameplay_speedTrapLeaderboards.saveLeaderboards then
    gameplay_speedTrapLeaderboards.saveLeaderboards(currentSavePath .. leaderboardFolder, true)
  end
end

local function onPursuitAction(id, pursuitData)
  local playerVehicleId = be and be:getPlayerVehicleID(0) or nil
  if id ~= playerVehicleId and pursuitData then
    if pursuitData.type == "start" then
      playerPursuiting = true
    elseif pursuitData.type == "evade" or pursuitData.type == "reset" or pursuitData.type == "arrest" then
      playerPursuiting = false
    end
  end
end

M.onSpeedTrapTriggered = onSpeedTrapTriggered
M.onRedLightCamTriggered = onRedLightCamTriggered
M.onExtensionLoaded = onExtensionLoaded
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onPursuitAction = onPursuitAction

return M
