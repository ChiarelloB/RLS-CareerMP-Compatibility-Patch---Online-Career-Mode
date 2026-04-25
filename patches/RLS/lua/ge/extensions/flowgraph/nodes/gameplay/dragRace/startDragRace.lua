-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Start Drag Race'

C.description = 'Start the drag race activity. Use after vehicles are set up.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'lane', description = 'Lane number for freeroam context (optional)', hidden = true },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Flow output after starting', impulse = true },
  { dir = 'out', type = 'bool', name = 'success', description = 'True if race started successfully' },
}

C.tags = {'gameplay', 'utils'}

local function resetCompletedRaceIfNeeded()
  local dragData = gameplay_drag_dragBridge.getData()
  if not dragData or not dragData.isCompleted then
    return dragData
  end

  -- BeamNG's drag activity can keep isStarted=true after a completed run.
  -- On retries that makes this node stop before it restages the AI opponent.
  gameplay_drag_dragBridge.resetDragRace()
  dragData = gameplay_drag_dragBridge.getData()
  if dragData then
    dragData.isStarted = false
    dragData.isCompleted = false
  end
  return dragData
end

function C:workOnce()
  local dragData = resetCompletedRaceIfNeeded()

  if not dragData then
    self:__setNodeError('start', 'Drag data not available. Load drag data first.')
    self.pinOut.success.value = false
    self.pinOut.flow.value = true
    return
  end

  if dragData.isStarted then
    self:__setNodeError('start', 'Drag race is already started')
    self.pinOut.success.value = false
    self.pinOut.flow.value = true
    return
  end

  local lane = self.pinIn.lane.value
  local result = gameplay_drag_dragBridge.startDragRaceActivity(lane)

  if result then
    self:__setNodeError(nil, nil)
    self.pinOut.success.value = true
  else
    self:__setNodeError('start', 'Failed to start drag race activity')
    self.pinOut.success.value = false
  end

  self.pinOut.flow.value = true
end

return _flowgraph_createNode(C)
