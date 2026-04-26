local M = {}

local originals = {}
local wrappers = {}

local function clearLocalDragOwner()
    _G.RLSCareerMP_LocalDragOwnerVehId = nil
end

local function markLocalDragOwner(data)
    if not data or not data.racers or not be then
        return
    end
    local playerVehId = be:getPlayerVehicleID(0)
    for vehId, racer in pairs(data.racers) do
        if racer and (racer.isPlayable or vehId == playerVehId) then
            _G.RLSCareerMP_LocalDragOwnerVehId = vehId
            return
        end
    end
end

local function getFreeroamSession()
    return gameplay_events_freeroam_session
end

local function getDragData()
    if not gameplay_drag_general or not gameplay_drag_general.getData then
        return nil
    end

    local ok, data = pcall(gameplay_drag_general.getData)
    if ok then
        return data
    end
    return nil
end

local function clearStaleStartedFlagIfNeeded()
    local data = getDragData()
    if not data or not data.isStarted then
        return
    end

    local session = getFreeroamSession()
    if session and not session.dragPracticeActive and not session.dragPracticeFlow and not session.mActiveRace and not session.staged then
        data.isStarted = false
        data.isCompleted = false
    end
end

local function normalizeCompletedDragState()
    local data = getDragData()
    if not data or not data.isCompleted then
        return
    end

    -- Activity drag missions can leave isStarted=true after the finish. The
    -- next flowgraph start node then refuses to run, so the second run never
    -- stages the opponent or starts the UI tree.
    data.isStarted = false
    clearLocalDragOwner()
end

local function resetCompletedDragDataBeforeStart()
    local data = getDragData()
    if not data or not data.isCompleted then
        return data
    end

    if gameplay_drag_general and gameplay_drag_general.resetDragRace then
        pcall(gameplay_drag_general.resetDragRace)
    end

    data = getDragData()
    if data then
        data.isStarted = false
        data.isCompleted = false
    end
    clearLocalDragOwner()
    return data
end

local function refreshDragPresentation()
    local data = getDragData()
    if data then
        data.isCompleted = false
    end

    if gameplay_drag_times and gameplay_drag_times.onExtensionLoaded then
        pcall(gameplay_drag_times.onExtensionLoaded)
    end

    if ui_gameplayAppContainers then
        pcall(ui_gameplayAppContainers.showApp, 'gameplayApps', 'drag')
    end

    if guihooks and guihooks.trigger then
        guihooks.trigger('updateTreeLightStaging', true)
    end
end

local function getLiveVehicle(racer)
    if not racer or not racer.vehId or not scenetree or not scenetree.findObjectById then
        return nil
    end

    local ok, veh = pcall(scenetree.findObjectById, racer.vehId)
    if ok and veh then
        racer.vehObj = veh
        return veh
    end

    racer.vehObj = nil
    racer.isValid = false
    return nil
end

local function queueVehicleCommand(racer, command)
    local veh = getLiveVehicle(racer)
    if not veh or not command then
        return false
    end

    local ok = pcall(function()
        veh:queueLuaCommand(command)
    end)

    if not ok then
        racer.vehObj = nil
        racer.isValid = false
        return false
    end

    return true
end

local function restoreVanillaAiForDragRacer(racer, phaseName)
    if not racer or racer.isPlayable then
        return
    end

    -- RLS can install vehicle-side overrideAI before the drag racer is fully
    -- registered. Keep correcting this during drag setup because the delayed
    -- vehicle-spawn hook may run after the first staging tick.
    queueVehicleCommand(racer, [[
        if overrideAI then
            extensions.unload("overrideAI")
            ai = require("ai")
        end
    ]])
end

local function shouldRekick(racer, key, dtSim, interval)
    local timerKey = "rlsCareerMPDragAiCompat_" .. key
    racer[timerKey] = (racer[timerKey] or interval) + (dtSim or 0)
    if racer[timerKey] >= interval then
        racer[timerKey] = 0
        return true
    end
    return false
end

local function rekickStageAi(racer, dtSim)
    local data = getDragData()
    if not data or not data.strip or not data.strip.lanes or not data.strip.lanes[racer.lane] then
        return
    end
    if not shouldRekick(racer, "stage", dtSim, 0.5) then
        return
    end

    local laneData = data.strip.lanes[racer.lane]
    local stageWaypoint = laneData.waypoints and laneData.waypoints.stage and laneData.waypoints.stage.waypoint
    local endLine = laneData.waypoints and laneData.waypoints.endLine
    if not stageWaypoint or not endLine or not endLine.name then
        return
    end

    local distance = 0
    if gameplay_drag_utils and gameplay_drag_utils.getFrontWheelDistanceFromStagePos then
        distance = gameplay_drag_utils.getFrontWheelDistanceFromStagePos(racer) or 0
    end

    local aiSpeed = math.max(1, (stageWaypoint.speed or 3) - (distance / 4))
    queueVehicleCommand(racer, 'ai.setState({mode = "manual"})')
    queueVehicleCommand(racer, 'electrics.values.throttleOverride = nil')
    queueVehicleCommand(racer, 'controller.setFreeze(0)')
    queueVehicleCommand(racer, 'ai.setSpeedMode("' .. tostring(stageWaypoint.mode or "set") .. '")')
    queueVehicleCommand(racer, 'ai.setSpeed(' .. tostring(aiSpeed) .. ')')
    queueVehicleCommand(racer, 'ai.setTarget("' .. tostring(endLine.name) .. '")')
end

local function rekickRaceAi(racer, dtSim)
    local data = getDragData()
    if not data or not data.strip or not data.strip.lanes or not data.strip.lanes[racer.lane] then
        return
    end
    if not shouldRekick(racer, "race", dtSim, 0.5) then
        return
    end

    local laneData = data.strip.lanes[racer.lane]
    local endLine = laneData.waypoints and laneData.waypoints.endLine
    local waypoint = endLine and endLine.waypoint
    if not endLine or not waypoint or not endLine.name then
        return
    end

    queueVehicleCommand(racer, 'electrics.values.throttleOverride = nil')
    queueVehicleCommand(racer, 'controller.setFreeze(0)')
    queueVehicleCommand(racer, 'ai.setSpeed(' .. tostring(waypoint.speed or 30) .. ')')
    queueVehicleCommand(racer, 'ai.setSpeedMode("' .. tostring(waypoint.mode or "set") .. '")')
    queueVehicleCommand(racer, 'ai.setTarget("' .. tostring(endLine.name) .. '")')
end

local function rekickDragAiIfNeeded(phase, racer, dtSim)
    if not phase or phase.completed or not racer or racer.isPlayable then
        return
    end

    if not getLiveVehicle(racer) then
        return
    end

    if phase.name == "stage" and phase.started then
        rekickStageAi(racer, dtSim)
    elseif phase.name == "race" and phase.started then
        rekickRaceAi(racer, dtSim)
    end
end

local function wrapDragPhaseFunction(name)
    if not gameplay_drag_utils or type(gameplay_drag_utils[name]) ~= "function" then
        originals[name] = nil
        wrappers[name] = nil
        return
    end

    if gameplay_drag_utils[name] == wrappers[name] then
        return
    end

    local original = gameplay_drag_utils[name]
    originals[name] = original
    wrappers[name] = function(phase, racer, dtSim)
        restoreVanillaAiForDragRacer(racer, phase and phase.name or name)
        local ok, result = pcall(original, phase, racer, dtSim)
        if not ok then
            if racer then
                racer.vehObj = nil
                racer.isValid = false
            end
            clearLocalDragOwner()
            if gameplay_drag_general and gameplay_drag_general.resetDragRace then
                pcall(gameplay_drag_general.resetDragRace)
            end
            return nil
        end
        restoreVanillaAiForDragRacer(racer, phase and phase.name or name)
        rekickDragAiIfNeeded(phase, racer, dtSim)
        return result
    end

    gameplay_drag_utils[name] = wrappers[name]
end

local function patchDragUtils()
    if not gameplay_drag_utils then
        return
    end

    wrapDragPhaseFunction("stage")
    wrapDragPhaseFunction("countdown")
    wrapDragPhaseFunction("race")
end

local function patchDragGeneral()
    if not gameplay_drag_general then
        return
    end

    if type(gameplay_drag_general.getDragIsStarted) == "function" and gameplay_drag_general.getDragIsStarted ~= wrappers.getDragIsStarted then
        local originalGetDragIsStarted = gameplay_drag_general.getDragIsStarted
        originals.getDragIsStarted = originalGetDragIsStarted
        wrappers.getDragIsStarted = function()
            clearStaleStartedFlagIfNeeded()
            return originalGetDragIsStarted()
        end
        gameplay_drag_general.getDragIsStarted = wrappers.getDragIsStarted
    end

    if type(gameplay_drag_general.startDragRaceActivity) == "function" and gameplay_drag_general.startDragRaceActivity ~= wrappers.startDragRaceActivity then
        local originalStartDragRaceActivity = gameplay_drag_general.startDragRaceActivity
        originals.startDragRaceActivity = originalStartDragRaceActivity
        wrappers.startDragRaceActivity = function(lane)
            clearStaleStartedFlagIfNeeded()
            local data = resetCompletedDragDataBeforeStart()
            if data then
                data.isStarted = false
                data.isCompleted = false
            end
            local result = originalStartDragRaceActivity(lane)
            if result then
                markLocalDragOwner(getDragData())
                refreshDragPresentation()
            end
            return result
        end
        gameplay_drag_general.startDragRaceActivity = wrappers.startDragRaceActivity
    end
end

local function onExtensionLoaded()
    patchDragGeneral()
    patchDragUtils()
end

local function onUpdate()
    patchDragGeneral()
    patchDragUtils()
    normalizeCompletedDragState()
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M
