-- propCargo.lua
-- Physical prop-based parcel delivery for RLS Career Overhaul.

local M = {}

local dParcelManager, dGenerator, dProgress, dGeneral

M.onCareerActivated = function()
  dParcelManager = career_modules_delivery_parcelManager
  dGenerator = career_modules_delivery_generator
  dProgress = career_modules_delivery_progress
  dGeneral = career_modules_delivery_general
end

local PROP_RIGHT_OFFSET = 3.0
local BOX_GRID_SPACING = 0.55
local BOX_LAYER_HEIGHT = 0.40
local BOX_SPAWN_LIFT = 0.30
local CRATE_SPAWN_LIFT = 0.30
local DELIVERY_RADIUS = 5.0
local PLAYER_EXIT_RADIUS = 6.0
local UPDATE_INTERVAL = 0.5
local HEAVY_THRESHOLD_KG = 30.0

local LABEL_COLOR = ColorF(1, 1, 1, 1)
local LABEL_BG = ColorI(0, 0, 0, 180)
local LABEL_BG_BLUE = ColorI(0, 60, 180, 210)
local LABEL_BG_GREEN = ColorI(0, 150, 50, 210)
local LABEL_MAX_DIST = 12.0
local LABEL_FOV_COS = 0.985
local LABEL_Z_OFFSET = 0.2

local trackedProps = {}
local deliveryQueue = {}
local updateTimer = 0

local function getParkingSpotPos(location)
  if location and location.type == "facilityParkingspot" then
    local ps = dGenerator.getParkingSpotByPath(location.psPath)
    if ps then
      return vec3(ps.pos)
    end
  end
  return nil
end

local function getObjectPos(id)
  local obj = scenetree.findObjectById(id)
  if obj then
    return vec3(obj:getPosition())
  end
  return nil
end

local function deleteProp(id)
  local obj = scenetree.findObjectById(id)
  if obj then
    obj:delete()
  end
end

local function applyPropModifiers(cargoId)
  local cargo = dParcelManager.getCargoById(cargoId)
  if not cargo then
    return
  end

  if cargo.rewards and cargo.rewards.money then
    cargo.rewards.money = cargo.rewards.money * 2
  end

  if cargo.modifiers then
    for _, mod in ipairs(cargo.modifiers) do
      if mod.type == "timed" then
        if mod.timeUntilDelayed then
          mod.timeUntilDelayed = mod.timeUntilDelayed * 3
        end
        if mod.timeUntilLate then
          mod.timeUntilLate = mod.timeUntilLate * 3
        end
      end
    end
  end
end

local function destKey(dest)
  return (dest.facId or "") .. "|" .. (dest.psPath or "")
end

local function boxSlotPos(groupCentre, index)
  local layer = math.floor(index / 4)
  local slot = index % 4
  local col = slot % 2
  local row = math.floor(slot / 2)
  local dx = (col - 0.5) * BOX_GRID_SPACING
  local dy = (row - 0.5) * BOX_GRID_SPACING
  local dz = BOX_SPAWN_LIFT + layer * BOX_LAYER_HEIGHT
  return groupCentre + vec3(dx, dy, dz)
end

M.spawnPropsForCargo = function(batch, facId, psPath)
  if not batch or #batch == 0 then
    return
  end

  local ps = dGenerator.getParkingSpotByPath(psPath)
  if not ps then
    log("W", "propCargo", "Cannot find parking spot: " .. tostring(psPath))
    return
  end

  if not dGeneral.isDeliveryModeActive() then
    dGeneral.startDeliveryMode()
  end

  local basePos = vec3(ps.pos)
  local baseRot = quat(ps.rot) or quatFromDir(vec3(0, 1, 0))
  local boxGroupCentre = basePos + (baseRot * vec3(1, 0, 0)) * PROP_RIGHT_OFFSET

  local crateIdx = 0
  local lightItems = {}
  local heavyByDest = {}
  local heavyDestOrder = {}

  for _, cargo in ipairs(batch) do
    if (cargo.weight or 0) >= HEAVY_THRESHOLD_KG then
      local key = destKey(cargo.destination)
      if not heavyByDest[key] then
        heavyByDest[key] = {
          cargoIds = {},
          destination = cargo.destination,
          name = cargo.name
        }
        table.insert(heavyDestOrder, key)
      end
      table.insert(heavyByDest[key].cargoIds, cargo.id)
    else
      table.insert(lightItems, cargo)
    end
  end

  local function spawnOne(model, config, spawnPos, cargoIds, destination, label)
    local obj = core_vehicles.spawnNewVehicle(model, {
      pos = spawnPos,
      rot = quatFromDir(vec3(0, 1, 0)),
      config = config,
      autoEnterVehicle = false,
    })

    if not obj then
      log("W", "propCargo", string.format("Failed to spawn %s for dest %s/%s", model, destination.facId, destination.psPath))
      return
    end

    obj.playerUsable = false

    for _, cargoId in ipairs(cargoIds) do
      dParcelManager.changeCargoLocation(cargoId, {
        type = "vehicle",
        vehId = -1,
        containerId = 0,
      })
      applyPropModifiers(cargoId)
    end

    table.insert(trackedProps, {
      propId = obj:getID(),
      cargoIds = cargoIds,
      destination = destination,
      destinationPos = getParkingSpotPos(destination),
      label = label,
    })

    log("I", "propCargo", string.format("Spawned %s (id=%d, %d cargo) -> %s/%s", model, obj:getID(), #cargoIds, destination.facId, destination.psPath))
  end

  for index, cargo in ipairs(lightItems) do
    local spawnPos = boxSlotPos(boxGroupCentre, index - 1)
    local destShort = dParcelManager.getLocationLabelShort(cargo.destination)
    local label = cargo.name .. "\n-> " .. destShort
    spawnOne("cardboard_box", "small", spawnPos, {cargo.id}, cargo.destination, label)
  end

  local crateLineStart = boxGroupCentre + (baseRot * vec3(1, 0, 0)) * 1.5
  for _, key in ipairs(heavyDestOrder) do
    local group = heavyByDest[key]
    crateIdx = crateIdx + 1
    local spawnPos = crateLineStart
      + (baseRot * vec3(1, 0, 0)) * (crateIdx - 1) * 1.8
      + vec3(0, 0, CRATE_SPAWN_LIFT)
    local destShort = dParcelManager.getLocationLabelShort(group.destination)
    local label = group.name .. " (" .. #group.cargoIds .. "x)\n-> " .. destShort
    spawnOne("woodcrate", nil, spawnPos, group.cargoIds, group.destination, label)
  end

  if career_modules_delivery_cargoScreen and career_modules_delivery_cargoScreen.setBestRoute then
    career_modules_delivery_cargoScreen.setBestRoute()
  end
end

M.onPreRender = function()
  if #trackedProps == 0 then
    return
  end
  if not gameplay_walk or not gameplay_walk.isWalking or not gameplay_walk.isWalking() then
    return
  end

  local camPos = core_camera.getPosition()
  local camQuat = core_camera.getQuat()
  if not camPos or not camQuat then
    return
  end
  local camForward = camQuat * vec3(0, 1, 0)

  local playerVeh = be:getPlayerVehicleID(0) and scenetree.findObjectById(be:getPlayerVehicleID(0))
  local playerPos = playerVeh and vec3(playerVeh:getPosition()) or camPos
  local closestDest = nil
  local closestDist = math.huge

  for _, entry in ipairs(trackedProps) do
    if entry.destinationPos then
      local dist = (entry.destinationPos - playerPos):length()
      if dist < closestDist then
        closestDist = dist
        closestDest = destKey(entry.destination)
      end
    end
  end

  for _, entry in ipairs(trackedProps) do
    local propPos = getObjectPos(entry.propId)
    if propPos and entry.label then
      local toVec = propPos - camPos
      local dist = toVec:length()
      if dist > 0 and dist <= LABEL_MAX_DIST then
        local dot = toVec:normalized():dot(camForward)
        if dot >= LABEL_FOV_COS then
          local bg = LABEL_BG
          if entry.destinationPos then
            local distToDest = (propPos - entry.destinationPos):length()
            if distToDest <= DELIVERY_RADIUS then
              bg = LABEL_BG_GREEN
            elseif destKey(entry.destination) == closestDest then
              bg = LABEL_BG_BLUE
            end
          end

          debugDrawer:drawTextAdvanced(
            propPos + vec3(0, 0, LABEL_Z_OFFSET),
            String(entry.label),
            LABEL_COLOR,
            true,
            false,
            bg
          )
        end
      end
    end
  end
end

M.onUpdate = function(dt)
  if #trackedProps == 0 and #deliveryQueue == 0 then
    return
  end

  updateTimer = updateTimer - dt
  if updateTimer > 0 then
    return
  end
  updateTimer = UPDATE_INTERVAL

  local playerVehId = be:getPlayerVehicleID(0)
  local playerVeh = playerVehId and scenetree.findObjectById(playerVehId)
  local playerPos = playerVeh and vec3(playerVeh:getPosition())
  local walking = gameplay_walk and gameplay_walk.isWalking and gameplay_walk.isWalking()

  for index = #trackedProps, 1, -1 do
    local entry = trackedProps[index]
    local propPos = getObjectPos(entry.propId)

    if not propPos then
      table.remove(trackedProps, index)
    else
      if not entry.destinationPos then
        entry.destinationPos = getParkingSpotPos(entry.destination)
      end

      if entry.destinationPos then
        local distToDest = (propPos - entry.destinationPos):length()
        local inVehicle = not walking
        local playerGone = not playerPos or (playerPos - entry.destinationPos):length() > PLAYER_EXIT_RADIUS

        if distToDest <= DELIVERY_RADIUS and playerGone and inVehicle then
          log("I", "propCargo", string.format("Prop %d arrived (dist=%.1fm), queuing %d cargo", entry.propId, distToDest, #entry.cargoIds))
          deleteProp(entry.propId)
          table.remove(trackedProps, index)
          table.insert(deliveryQueue, {
            cargoIds = entry.cargoIds,
            destination = entry.destination,
          })
        end
      end
    end
  end

  if #deliveryQueue > 0 then
    local item = table.remove(deliveryQueue, 1)
    local confirmedCargoIds = {}
    for _, id in ipairs(item.cargoIds) do
      table.insert(confirmedCargoIds, {id = id})
    end
    log("I", "propCargo", string.format("Confirming %d cargo to %s/%s", #item.cargoIds, item.destination.facId, item.destination.psPath))
    dProgress.confirmDropOffData(
      {confirmedCargoIds = confirmedCargoIds, confirmedOfferIds = {}},
      item.destination.facId,
      item.destination.psPath
    )
  end
end

M.onDeliveryModeStopped = function()
  for _, entry in ipairs(trackedProps) do
    deleteProp(entry.propId)
  end
  table.clear(trackedProps)
  table.clear(deliveryQueue)
  updateTimer = 0
  log("I", "propCargo", "Delivery mode stopped - all props removed.")
end

M.getPropTasks = function()
  return deepcopy(trackedProps)
end

return M
