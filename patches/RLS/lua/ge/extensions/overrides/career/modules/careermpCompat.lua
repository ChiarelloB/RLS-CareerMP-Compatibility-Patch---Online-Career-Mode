local M = {}

local function safeGetObject(vehId)
  if not vehId then
    return nil
  end
  return getObjectByID(vehId)
end

local function syncPlayerVehicleTraffic(vehId)
  if not (vehId and gameplay_traffic) then
    return
  end

  pcall(function()
    gameplay_traffic.removeTraffic(vehId)
  end)

  if core_jobsystem and gameplay_traffic.insertTraffic then
    core_jobsystem.create(function(job)
      job.sleep(0.05)

      if be:getPlayerVehicleID(0) ~= vehId or not safeGetObject(vehId) then
        return
      end

      gameplay_traffic.insertTraffic(vehId, true, true)

      if career_modules_playerDriving and career_modules_playerDriving.resetPlayerState then
        career_modules_playerDriving.resetPlayerState()
      end
    end)
  end
end

function M.install()
  if not career_modules_inventory or career_modules_inventory._careermpCompatInstalled then
    return career_modules_inventory ~= nil
  end

  local inventory = career_modules_inventory
  inventory._careermpCompatInstalled = true

  local rawGetVehicleIdFromInventoryId = inventory.getVehicleIdFromInventoryId
  local rawGetInventoryIdFromVehicleId = inventory.getInventoryIdFromVehicleId
  local rawSpawnVehicle = inventory.spawnVehicle

  inventory.getVehicleIdFromInventoryId = function(inventoryId)
    local vehId = rawGetVehicleIdFromInventoryId(inventoryId)
    if not safeGetObject(vehId) then
      return nil
    end
    return vehId
  end

  inventory.getInventoryIdFromVehicleId = function(vehId)
    if not safeGetObject(vehId) then
      return nil
    end
    return rawGetInventoryIdFromVehicleId(vehId)
  end

  inventory.spawnVehicle = function(inventoryId, replaceOption, callback)
    local currentInventoryId = inventory.getCurrentVehicle and inventory.getCurrentVehicle() or nil
    local isCurrentVehicleRespawn = currentInventoryId ~= nil and currentInventoryId == inventoryId
    local previousVehId = rawGetVehicleIdFromInventoryId(inventoryId)

    if previousVehId and (replaceOption == 1 or isCurrentVehicleRespawn) and gameplay_traffic then
      pcall(function()
        gameplay_traffic.removeTraffic(previousVehId)
      end)
    end

    local vehObj = rawSpawnVehicle(inventoryId, replaceOption, callback)
    if vehObj and (replaceOption == 1 or isCurrentVehicleRespawn) then
      syncPlayerVehicleTraffic(vehObj:getID())
    end

    return vehObj
  end

  log("I", "careermpCompat", "Installed RLS/CareerMP inventory compatibility guards")
  return true
end

return M
