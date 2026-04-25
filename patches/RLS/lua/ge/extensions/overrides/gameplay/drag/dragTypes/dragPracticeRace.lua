-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {
  "gameplay_drag_general",
  "gameplay_drag_utils"
}

local dGeneral, dUtils
local dragData
local logTag = ""
local freeroamEvents = require("gameplay/events/freeroamEvents")
local freeroamUtils = require("gameplay/events/freeroam/utils")
local raceSession
local freeroamSession
local hasActivityStarted = false
local dqTimer = 0

local function clearLocalState()
  dragData = nil
  hasActivityStarted = false
  dqTimer = 0
end

local function onExtensionLoaded()
  dGeneral = gameplay_drag_general
  dUtils = gameplay_drag_utils
  raceSession = gameplay_events_freeroam_raceSession
  freeroamSession = gameplay_events_freeroam_session
  clearLocalState()
end

local function resetDragRace()
  if raceSession then
    raceSession.endDragPracticeFreeroamHud()
  end
  if freeroamSession then
    freeroamSession.dragPracticeFlow = false
    freeroamSession.dragPracticeActive = false
    freeroamSession.staged = nil
    freeroamSession.mActiveRace = nil
    freeroamSession.timerActive = false
    freeroamSession.in_race_time = 0
    freeroamSession.maxSpeed = 0
  end
  if gameplay_drag_general and gameplay_drag_general._setGameplayContext then
    gameplay_drag_general._setGameplayContext("freeroam")
  end
  if not dragData then return end

  gameplay_drag_general.resetDragRace()

  hasActivityStarted = false
  dqTimer = 0
  if guihooks then
    guihooks.trigger('updateTreeLightStaging', false)
    guihooks.trigger('ChangeState', {state = 'freeroam'})
  end
  dragData = dGeneral.getData()
end

local function finishAndResetRace()
  resetDragRace()
end

local function startActivity()
  dragData = dGeneral.getData()

  if not dragData then
    log('E', logTag, 'No drag race data found')
    return
  end

  dragData.isStarted = true
  hasActivityStarted = dragData.isStarted
  dqTimer = 0

  local dials = {}
  if dragData.racers then
    for _,racer in pairs(dragData.racers) do
      table.insert(dials, {vehId = racer.vehId, dial = 0})
    end
  end
  dUtils.setDialsData(dials)

  if raceSession and dragData.racers then
    for _, racer in pairs(dragData.racers) do
      if racer.isPlayable then
        raceSession.beginDragPracticeFreeroamHud(racer.vehId)
        break
      end
    end
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if hasActivityStarted then
    if not dragData then
      log('E', logTag, 'No drag data found!')
      return
    end
    if not dragData.racers then
      log('E', logTag, 'There is no racers in the drag data.')
      return
    end

    local hasDisqualifiedRacer = false
    for vehId, racer in pairs(dragData.racers) do
      if racer.isDesqualified then
        hasDisqualifiedRacer = true
        break
      end
    end
    if not hasDisqualifiedRacer then
      dqTimer = 0
    end

    for vehId, racer in pairs(dragData.racers) do
      if racer.isFinished then
        dragData.isCompleted = true
        finishAndResetRace()
        return
      end

      dUtils.updateRacer(racer)

      local phase = racer.phases[racer.currentPhase]
      dUtils[phase.name](phase, racer, dtSim)

      if racer.isPlayable and phase.name == "race" and racer.timersStarted and freeroamSession then
        freeroamSession.in_race_time = racer.timers.timer.value or 0
        local spd = racer.vehSpeed * freeroamSession.speedUnit
        if spd > freeroamSession.maxSpeed then
          freeroamSession.maxSpeed = spd
        end
      end

      if phase.completed and not racer.isFinished then
        log('I', logTag, 'Racer: '.. racer.vehId ..' completed phase: '.. phase.name)
        if phase.name == "stage" then
          if not raceSession or not raceSession.isRaceHudShown() then
            freeroamUtils.displayStagedMessage(racer.vehId, "drag")
          end
        elseif phase.name == "countdown" then
          freeroamUtils.saveAndSetTrafficAmount(0)
          if raceSession and raceSession.isRaceHudShown() then
            raceSession.beginDragPracticeFreeroamRace(racer.vehId)
          else
            freeroamUtils.displayStartMessage("drag")
          end
        elseif phase.name == "race" then
          if racer.timers.time_1_4.value and racer.timers.time_1_4.value > 0 then
            freeroamEvents.payoutDragRace("drag", racer.timers.time_1_4.value, racer.vehSpeed * 2.2369362921, vehId)
          end
          freeroamUtils.restoreTrafficAmount()
        end
        dUtils.changeRacerPhase(racer)
        if racer.isFinished then
          dragData.isCompleted = true
          finishAndResetRace()
          return
        end
      end

      if not dUtils.isRacerInsideBoundary(racer) then
        freeroamUtils.restoreTrafficAmount()
        finishAndResetRace()
        return
      end
    end

    if hasDisqualifiedRacer then
      dqTimer = dqTimer + dtSim
      if dqTimer > 3 then
        dqTimer = 0
        dragData.isCompleted = true
        freeroamUtils.restoreTrafficAmount()
        finishAndResetRace()
        return
      end
    end
  end
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.startActivity = startActivity
M.resetDragRace = resetDragRace

M.jumpDescualifiedDrag = function()
end

return M
