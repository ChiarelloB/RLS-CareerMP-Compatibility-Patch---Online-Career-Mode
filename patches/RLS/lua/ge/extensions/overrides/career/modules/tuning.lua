-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {"career_career"}

local inventoryId
local vehicleVarsBefore
local changedVars
local shoppingCart
local tuningSessionActive
local rollbackOnUiCloseInProgress
local controlledUiCloseInProgress

local originComputerId

local tether

local prices = {
  Suspension = {
    Front = {
      price = 100
    },
    Rear = {
      price = 100
    }
  },

  Wheels = {
    Front = {
      price = 100
    },
    Rear = {
      price = 100
    }
  },

  Transmission = {
    price = 500,
    default = {
      default = true,
      variables = {
        ["$gear_1"] = {price = 100},
        ["$gear_2"] = {price = 100},
        ["$gear_3"] = {price = 100},
        ["$gear_4"] = {price = 100},
        ["$gear_5"] = {price = 100},
        ["$gear_6"] = {price = 100},
        ["$gear_R"] = {price = 100},
      }
    }
  },

  ["Wheel Alignment"] = {
    Front = {
      price = 100
    },
    Rear = {
      price = 100
    }
  },

  Chassis = {
    price = 100
  },

  default = {
    default = true,
    price = 200
  }
}

local shoppingCartBlackList = {
  {name = "$$ffbstrength", category = "Chassis"},
  {name = "$tirepressure_F", category = "Wheels", subCategory = "Front"},
  {name = "$tirepressure_R", category = "Wheels", subCategory = "Rear"},
}

local function isOnBlackList(varData)
  for _, blackListItem in ipairs(shoppingCartBlackList) do
    if blackListItem.name ~= varData.name then goto continue end
    if blackListItem.category ~= varData.category then goto continue end
    if blackListItem.subCategory ~= varData.subCategory then goto continue end
    do return true end
    ::continue::
  end
  return false
end

local function getPrice(category, subCategory, varName)
  if prices[category] then
    if prices[category][subCategory] then
      if prices[category][subCategory].variables and prices[category][subCategory].variables[varName] then
        return prices[category][subCategory].variables[varName].price or 0
      end
    elseif prices[category].default then
      if prices[category].default.variables and prices[category].default.variables[varName] then
        return prices[category].default.variables[varName].price or 0
      end
    end
  elseif prices.default then
    if prices.default.variables and prices.default.variables[varName] then
      return prices.default.variables[varName].price or 0
    end
  end
  return 0
end

local function getPriceCategory(category)
  if prices[category] then
    return prices[category].price or 0
  end
  return prices.default.price
end

local function getPriceSubCategory(category, subCategory)
  if prices[category] then
    if prices[category][subCategory] then
      return prices[category][subCategory].price or 0
    end
    return prices[category].default and prices[category].default.price or 0
  end
  return 0
end

local function getPlayerVehicleObj()
  if not getPlayerVehicle then
    return nil
  end
  local veh = getPlayerVehicle(0)
  if not veh or not veh.getID then
    return nil
  end
  return veh
end

local function getFallbackTransform()
  local playerVeh = getPlayerVehicleObj()
  if not playerVeh then
    return nil
  end

  return {
    pos = playerVeh:getPosition(),
    rot = quat(0, 0, 1, 0) * quat(playerVeh:getRefNodeRotation())
  }
end

local function resolveInventoryVehicle(allowRespawn)
  if not inventoryId then
    return nil, nil
  end

  local vehId = career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
  local veh = vehId and getObjectByID(vehId) or nil
  if veh then
    return vehId, veh
  end

  local map = career_modules_inventory.getMapInventoryIdToVehId and career_modules_inventory.getMapInventoryIdToVehId() or nil
  vehId = map and map[inventoryId] or nil
  veh = vehId and getObjectByID(vehId) or nil
  if veh then
    return vehId, veh
  end

  local playerVeh = getPlayerVehicleObj()
  if playerVeh then
    local playerVehId = playerVeh:getID()
    local playerInventoryId = career_modules_inventory.getInventoryIdFromVehicleId and career_modules_inventory.getInventoryIdFromVehicleId(playerVehId) or nil
    if playerInventoryId == inventoryId then
      return playerVehId, playerVeh
    end
  end

  if allowRespawn and career_modules_inventory.spawnVehicle then
    veh = career_modules_inventory.spawnVehicle(inventoryId, 2)
    if veh then
      return veh:getID(), veh
    end

    map = career_modules_inventory.getMapInventoryIdToVehId and career_modules_inventory.getMapInventoryIdToVehId() or nil
    vehId = map and map[inventoryId] or nil
    veh = vehId and getObjectByID(vehId) or nil
    if veh then
      return vehId, veh
    end
  end

  return nil, nil
end

local function setFreezeOnCurrentVehicle(shouldFreeze)
  local _, veh = resolveInventoryVehicle(shouldFreeze)
  if veh then
    core_vehicleBridge.executeAction(veh, "setFreeze", shouldFreeze)
  end
end

local function clearTether()
  if tether then
    tether.remove = true
    tether = nil
  end
end

local function markControlledUiClose()
  controlledUiCloseInProgress = true
  if core_jobsystem and core_jobsystem.create then
    core_jobsystem.create(function(job)
      job.sleep(0.1)
      controlledUiCloseInProgress = false
    end)
  else
    controlledUiCloseInProgress = false
  end
end

local function setupTether()
  local _, veh = resolveInventoryVehicle(false)
  if not veh then
    return
  end

  local oobb = veh:getSpawnWorldOOBB()
  local vehCenter = oobb:getCenter()
  local vehRadius = (oobb:getPoint(0) - oobb:getPoint(6)):length()
  local computer = freeroam_facilities.getFacility("computer", originComputerId)
  local computerPos = computer and freeroam_facilities.getAverageDoorPositionForFacility(computer) or nil
  if not computerPos then
    return
  end

  local distBetweenVehicleAndComputer = (computerPos - vehCenter):length()
  local radiusMultipler = ((clamp(distBetweenVehicleAndComputer, 4, 12) - 4) / 16 + 1)
  tether = career_modules_tether.startCapsuleTetherBetweenStatics(
    computerPos,
    10 * radiusMultipler,
    vehCenter,
    vehRadius + (9 * radiusMultipler),
    M.cancelShopping
  )
end

local closeMenuAfterSaving

local function applyShopping()
  if not shoppingCart or not shoppingCart.items or next(shoppingCart.items) == nil then
    return
  end

  career_modules_vehiclePerformance.invalidateCertification(inventoryId)
  career_modules_inventory.setVehicleDirty(inventoryId)
  career_modules_playerAttributes.addAttributes({money = -shoppingCart.total}, {tags = {"tuning", "buying"}, label = "Tuned vehicle"})

  Engine.Audio.playOnce("AudioGui", "event:>UI>Career>Buy_01")
  if career_career.isAutosaveEnabled() then
    closeMenuAfterSaving = true
    career_saveSystem.saveCurrent({inventoryId})
  else
    M.close()
  end
end

local function onVehicleSaveFinished()
  if closeMenuAfterSaving then
    closeMenuAfterSaving = nil
    M.close()
  end
end

local function getTuningData()
  local _, veh = resolveInventoryVehicle(false)
  if not veh then
    return nil
  end

  local vehData = core_vehicle_manager.getVehicleData(veh:getID())
  return vehData and vehData.vdata and deepcopy(vehData.vdata.variables) or nil
end

local function sendShoppingCartToUI(shoppingCartUI)
  local shoppingData = {shoppingCart = shoppingCartUI}
  shoppingData.playerMoney = career_modules_playerAttributes.getAttributeValue("money")
  guihooks.trigger("sendTuningShoppingData", shoppingData)
end

local function createShoppingCart()
  local tuningData = getTuningData()
  shoppingCart = {items = {}}

  if not tuningData then
    shoppingCart.taxes = 0
    shoppingCart.total = 0
    sendShoppingCartToUI({items = {}, taxes = 0, total = 0})
    return
  end

  local total = 0
  for varName, value in pairs(changedVars) do
    local varData = tuningData[varName]
    if not varData then
      goto continue
    end

    local varPrice
    if isOnBlackList(varData) then
      shoppingCart.items[varName] = {name = varName, title = string.format("%s %s %s", varData.category, varData.subCategory, varData.title)}
      varPrice = 0
    elseif varData.category then
      if not shoppingCart.items[varData.category] then
        local price = getPriceCategory(varData.category)
        total = total + price
        shoppingCart.items[varData.category] = {type = "category", items = {}, price = price, title = varData.category}
      end

      if varData.subCategory and not shoppingCart.items[varData.category].items[varData.subCategory] then
        local price = getPriceSubCategory(varData.category, varData.subCategory)
        total = total + price
        shoppingCart.items[varData.category].items[varData.subCategory] = {type = "subCategory", items = {}, price = price, title = varData.subCategory}
      end

      if varData.subCategory then
        varPrice = getPrice(varData.category, varData.subCategory, varName)
        shoppingCart.items[varData.category].items[varData.subCategory].items[varName] = {name = varName, title = varData.title, price = varPrice}
      else
        varPrice = getPrice(varData.category, varData.subCategory, varName)
        shoppingCart.items[varData.category].items[varName] = {name = varName, title = varData.title, price = varPrice}
      end
    else
      varPrice = getPrice(varData.category, varData.subCategory, varName)
      shoppingCart.items[varName] = {name = varName, title = varData.title, price = varPrice}
    end

    total = total + varPrice
    ::continue::
  end

  local shoppingCartUI = {items = {}}
  for _, info in pairs(shoppingCart.items) do
    table.insert(shoppingCartUI.items, {varName = info.name, level = 1, title = info.title, price = info.price, type = info.type})
    for _, infoLevel2 in pairs(info.items or {}) do
      table.insert(shoppingCartUI.items, {varName = infoLevel2.name, level = 2, title = infoLevel2.title, price = infoLevel2.price, type = infoLevel2.type})
      for _, infoLevel3 in pairs(infoLevel2.items or {}) do
        table.insert(shoppingCartUI.items, {varName = infoLevel3.name, level = 3, title = infoLevel3.title, price = infoLevel3.price, type = infoLevel3.type})
      end
    end
  end

  shoppingCart.taxes = total * 0.07
  shoppingCart.total = total + shoppingCart.taxes
  shoppingCartUI.taxes = shoppingCart.taxes
  shoppingCartUI.total = shoppingCart.total
  sendShoppingCartToUI(shoppingCartUI)
end

local function getChangedVars(vars1, vars2)
  local res = {}
  for varName1, value1 in pairs(vars1) do
    if vars2[varName1] ~= value1 then
      res[varName1] = value1
    end
  end
  return res
end

local function startActual(_originComputerId)
  originComputerId = _originComputerId
  shoppingCart = {}
  changedVars = {}
  tuningSessionActive = true
  rollbackOnUiCloseInProgress = false
  closeMenuAfterSaving = nil
  if originComputerId then
    guihooks.trigger("ChangeState", {state = "tuning", params = {}})
    local vehId = career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
    if vehId then
      extensions.hook("onCareerTuningStarted", vehId)
    end
    createShoppingCart()
    setFreezeOnCurrentVehicle(true)
    setupTether()
  end
end

local function start(_inventoryId, _originComputerId)
  inventoryId = _inventoryId or career_modules_inventory.getInventoryIdsInClosestGarage(true)
  if not inventoryId or not career_modules_inventory.getVehicles()[inventoryId] then
    return
  end

  local tuningData = getTuningData()
  if not tuningData then
    local _, spawnedVeh = resolveInventoryVehicle(true)
    if not spawnedVeh then
      return
    end
    tuningData = getTuningData()
    if not tuningData then
      return
    end
  end

  vehicleVarsBefore = deepcopy(career_modules_inventory.getVehicles()[inventoryId].config.vars or {})
  for varName, varTuningData in pairs(tuningData) do
    if not vehicleVarsBefore[varName] then
      vehicleVarsBefore[varName] = varTuningData.val
    end
  end

  local numberOfBrokenParts = career_modules_valueCalculator.getNumberOfBrokenParts(career_modules_inventory.getVehicles()[inventoryId].partConditions)
  if numberOfBrokenParts > 0 and numberOfBrokenParts < career_modules_valueCalculator.getBrokenPartsThreshold() then
    career_modules_insurance_insurance.startRepair(inventoryId, nil, function()
      startActual(_originComputerId)
    end)
  else
    startActual(_originComputerId)
  end
end

local function apply(tuningValues, callback)
  local _, oldVeh = resolveInventoryVehicle(false)
  local vehicleTransform = oldVeh and {pos = oldVeh:getPosition(), rot = quat(0, 0, 1, 0) * quat(oldVeh:getRefNodeRotation())} or getFallbackTransform()

  local vehicleVarsCurrent = career_modules_inventory.getVehicles()[inventoryId].config.vars or {}
  career_modules_inventory.getVehicles()[inventoryId].config.vars = tableMerge(vehicleVarsCurrent, tuningValues)

  career_modules_inventory.spawnVehicle(inventoryId, 2, function(...)
    local newVehId, newVeh = resolveInventoryVehicle(false)
    if not newVeh then
      newVehId, newVeh = resolveInventoryVehicle(true)
    end

    if newVeh then
      if vehicleTransform then
        spawn.safeTeleport(newVeh, vehicleTransform.pos, vehicleTransform.rot, nil, nil, nil, nil, false)
      end
      core_vehicleBridge.executeAction(newVeh, "setFreeze", true)
      if be:getPlayerVehicleID(0) ~= newVehId then
        gameplay_walk.setWalkingMode(false, nil, nil, true)
        be:enterVehicle(0, newVeh)
      end
    end

    extensions.hook("onCareerTuningApplied")

    tableMerge(changedVars, tuningValues)
    changedVars = getChangedVars(changedVars, vehicleVarsBefore)
    createShoppingCart()

    if callback then
      callback(...)
    end
  end)
end

local function removeVarFromShoppingCart(varName)
  local tuningData = getTuningData()
  if not tuningData then
    return
  end

  local varTuningData = deepcopy(tuningData[varName])
  if not varTuningData then
    return
  end

  local vars = {}
  vars[varName] = vehicleVarsBefore[varName]
  apply(vars)

  varTuningData.val = vars[varName]
  guihooks.trigger("updateTuningVariable", varTuningData)
end

local function cancelShopping()
  apply(vehicleVarsBefore, M.close)
end

local function close()
  local currentOriginComputerId = originComputerId
  markControlledUiClose()
  tuningSessionActive = false
  rollbackOnUiCloseInProgress = false
  changedVars = {}
  shoppingCart = {items = {}, taxes = 0, total = 0}

  if currentOriginComputerId then
    local computer = freeroam_facilities.getFacility("computer", currentOriginComputerId)
    career_modules_computer.openMenu(computer)
  else
    career_career.closeAllMenus()
  end

  setFreezeOnCurrentVehicle(false)
  clearTether()
  closeMenuAfterSaving = nil
  vehicleVarsBefore = nil
  inventoryId = nil
  originComputerId = nil
end

local function onUiChangedState(toState, fromState)
  if rollbackOnUiCloseInProgress or controlledUiCloseInProgress or not tuningSessionActive then
    return
  end

  if fromState ~= "tuning" or toState == "tuning" then
    return
  end

  rollbackOnUiCloseInProgress = true

  local hasPendingChanges = next(changedVars or {}) ~= nil
  if hasPendingChanges then
    apply(vehicleVarsBefore, function()
      rollbackOnUiCloseInProgress = false
      M.close()
    end)
  else
    rollbackOnUiCloseInProgress = false
    M.close()
  end
end

local function onComputerAddFunctions(menuData, computerFunctions)
  if not menuData.computerFacility.functions["tuning"] then
    return
  end

  for _, vehicleData in ipairs(menuData.vehiclesInGarage) do
    local computerFunctionData = {
      id = "tuning",
      label = "Tuning",
      callback = function()
        start(vehicleData.inventoryId, menuData.computerFacility.id)
      end,
      disabled = buttonDisabled,
      order = 10
    }

    if vehicleData.needsRepair then
      computerFunctionData.disabled = true
      computerFunctionData.reason = career_modules_computer.reasons.needsRepair
    end

    if menuData.tutorialPartShoppingActive or menuData.tutorialTuningActive then
      computerFunctionData.disabled = true
      computerFunctionData.reason = career_modules_computer.reasons.tutorialActive
    end

    local inventoryId = vehicleData.inventoryId
    local reason = career_modules_permissions.getStatusForTag({"tuning", "vehicleModification"}, {inventoryId = inventoryId})
    if not reason.allow then
      computerFunctionData.disabled = true
    end
    if reason.permission ~= "allowed" then
      computerFunctionData.reason = reason
    end

    computerFunctions.vehicleSpecific[inventoryId][computerFunctionData.id] = computerFunctionData
  end
end

M.start = start
M.apply = apply
M.getTuningData = getTuningData
M.close = close
M.applyShopping = applyShopping
M.cancelShopping = cancelShopping
M.removeVarFromShoppingCart = removeVarFromShoppingCart

M.onComputerAddFunctions = onComputerAddFunctions
M.onVehicleSaveFinished = onVehicleSaveFinished
M.onUiChangedState = onUiChangedState

return M
