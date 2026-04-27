-- Server-controlled progress alpha client bridge.
-- This module gates career startup behind a server session and mirrors the
-- active online save JSON files back to the server after normal Career saves.

local M = {}

local state = {
  enabled = false,
  required = false,
  authenticated = false,
  inFlight = false,
  registrationDisabled = false,
  username = "",
  accountId = "",
  saveName = "",
  revision = 0,
  message = "Waiting for server progress configuration...",
  lastUpload = 0,
  lastError = "",
  mode = "localJson",
}

local clientConfig = {}
local fallbackSaveName = ""
local uploadTimer = 0
local uploadRequested = false
local uploadInFlight = false

local function diag(message)
  log("W", "CareerMPProgress", tostring(message))
end

local function toast(messageType, title, msg, timeout)
  if guihooks and guihooks.trigger then
    guihooks.trigger("toastrMsg", {
      type = messageType,
      title = title,
      msg = msg,
      config = { timeOut = timeout or 3500 }
    })
  end
end

local function decodeJson(data)
  if type(data) == "table" then
    return data
  end
  local ok, decoded = pcall(jsonDecode, data or "{}")
  if ok and type(decoded) == "table" then
    return decoded
  end
  return {}
end

local function sendEvent(eventName, payload)
  if not (MPCoreNetwork and MPCoreNetwork.isMPSession and MPCoreNetwork.isMPSession()) then
    state.lastError = "Not connected to a BeamMP session."
    return false
  end
  TriggerServerEvent(eventName, jsonEncode(payload or {}))
  return true
end

local function sanitizeRelativePath(relPath)
  relPath = tostring(relPath or ""):gsub("\\", "/")
  if relPath == "" or relPath:sub(1, 1) == "/" or relPath:find("..", 1, true) then
    return nil
  end
  if relPath:sub(-5) ~= ".json" then
    return nil
  end
  return relPath
end

local function ensureParentDirectory(filePath)
  local dir = path.split(filePath)
  if dir and dir ~= "" and FS and FS.directoryCreate then
    FS:directoryCreate(dir, true)
  end
end

local function getSaveRoot(saveName)
  return "settings/cloud/saves/" .. tostring(saveName or "") .. "/autosave1"
end

local function applySnapshot(snapshot, saveName)
  if type(snapshot) ~= "table" or type(snapshot.files) ~= "table" then
    return false
  end

  local root = getSaveRoot(saveName)
  local written = 0
  for relPath, fileData in pairs(snapshot.files) do
    local safeRelPath = sanitizeRelativePath(relPath)
    if safeRelPath and type(fileData) == "table" then
      local target = root .. "/" .. safeRelPath
      ensureParentDirectory(target)
      if jsonWriteFile(target, fileData, true) then
        written = written + 1
      end
    end
  end

  if written > 0 then
    diag("applied server snapshot files=" .. tostring(written) .. " save=" .. tostring(saveName))
  end
  return written > 0
end

local function collectSaveFiles(savePath)
  local result = {}
  if not savePath or savePath == "" or not FS or not FS.findFiles then
    return result
  end

  local files = FS:findFiles(savePath .. "/", "*.json", -1, true, true) or {}
  for i = 1, tableSize(files) do
    local filePath = tostring(files[i] or ""):gsub("\\", "/")
    if filePath:sub(1, #savePath) == savePath and filePath:sub(-4) ~= ".tmp" then
      local relPath = filePath:sub(#savePath + 2)
      relPath = sanitizeRelativePath(relPath)
      if relPath then
        local data = jsonReadFile(filePath)
        if type(data) == "table" then
          result[relPath] = data
        end
      end
    end
  end
  return result
end

local function buildSnapshot()
  if not (state.authenticated and state.saveName ~= "") then
    return nil
  end
  if not (career_saveSystem and career_saveSystem.getCurrentSaveSlot) then
    return nil
  end

  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if tostring(saveSlot or "") ~= tostring(state.saveName) then
    return nil
  end

  local files = collectSaveFiles(savePath)
  local payload = {
    token = state.token,
    accountId = state.accountId,
    saveName = state.saveName,
    revision = tonumber(state.revision) or 0,
    level = getCurrentLevelIdentifier and getCurrentLevelIdentifier() or nil,
    capturedAt = os.time(),
    files = files,
    summary = {
      money = career_modules_playerAttributes and career_modules_playerAttributes.getAttributeValue and career_modules_playerAttributes.getAttributeValue("money") or nil,
      vehicleCount = career_modules_inventory and career_modules_inventory.getVehicles and tableSize(career_modules_inventory.getVehicles() or {}) or 0,
    }
  }

  local maxBytes = tonumber(clientConfig.serverProgressMaxSnapshotBytes) or 180000
  local encoded = jsonEncode(payload)
  if #encoded > maxBytes then
    payload.truncated = true
    payload.files = {
      ["info.json"] = files["info.json"],
      ["career/general.json"] = files["career/general.json"],
      ["career/playerAttributes.json"] = files["career/playerAttributes.json"],
      ["career/attributeLog.json"] = files["career/attributeLog.json"],
      ["career/inventory.json"] = files["career/inventory.json"],
    }
    encoded = jsonEncode(payload)
    if #encoded > maxBytes then
      payload.files = {
        ["info.json"] = files["info.json"],
        ["career/general.json"] = files["career/general.json"],
        ["career/playerAttributes.json"] = files["career/playerAttributes.json"],
        ["career/inventory.json"] = files["career/inventory.json"],
      }
    end
  end

  return payload
end

local function uploadSnapshot(reason)
  if uploadInFlight then
    uploadRequested = true
    return false
  end

  local snapshot = buildSnapshot()
  if not snapshot then
    return false
  end

  snapshot.reason = reason or "autosave"
  uploadInFlight = true
  if not sendEvent("careerMPProgressUpload", snapshot) then
    uploadInFlight = false
    return false
  end

  return true
end

local function startCareerFromSession(payload)
  local saveName = tostring(payload.saveName or "")
  if saveName == "" then
    state.lastError = "Server did not provide an online save name."
    state.message = state.lastError
    return
  end

  state.authenticated = true
  state.required = false
  state.inFlight = false
  state.accountId = tostring(payload.accountId or "")
  state.username = tostring(payload.username or state.username or "")
  state.saveName = saveName
  state.revision = tonumber(payload.revision) or 0
  state.token = tostring(payload.token or "")
  state.message = "Authenticated. Loading online career save..."
  state.lastError = ""

  applySnapshot(payload.snapshot, saveName)

  local enabler = extensions and extensions.careerMPEnabler or careerMPEnabler
  if enabler and enabler.startCareerWithSaveName then
    enabler.startCareerWithSaveName(saveName)
  else
    state.lastError = "CareerMP enabler is not ready."
    state.message = state.lastError
  end
end

local function rxAuthResult(data)
  local payload = decodeJson(data)
  if not payload.ok then
    state.inFlight = false
    state.authenticated = false
    state.required = true
    state.lastError = tostring(payload.message or "Login failed.")
    state.message = state.lastError
    toast("error", "Online Progress", state.lastError, 4500)
    return
  end

  toast("success", "Online Progress", "Logged in as " .. tostring(payload.username or "online account") .. ".", 2500)
  startCareerFromSession(payload)
end

local function rxUploadAccepted(data)
  local payload = decodeJson(data)
  uploadInFlight = false
  uploadRequested = false
  state.revision = tonumber(payload.revision) or state.revision
  state.lastUpload = os.time()
  state.message = "Online progress saved. Revision " .. tostring(state.revision)
end

local function rxUploadRejected(data)
  local payload = decodeJson(data)
  uploadInFlight = false
  uploadRequested = false
  state.lastError = tostring(payload.message or "Server rejected the progress snapshot.")
  state.message = state.lastError
  toast("warning", "Online Progress", state.lastError, 5000)
end

local function rxNotice(data)
  local payload = decodeJson(data)
  local message = tostring(payload.message or "")
  if message ~= "" then
    state.message = message
    toast(payload.type or "info", payload.title or "Online Progress", message, 3500)
  end
end

local function normalizeCredentials(username, password)
  username = tostring(username or ""):gsub("^%s+", ""):gsub("%s+$", "")
  password = tostring(password or "")
  return username, password
end

local function submitCredentials(kind, username, password)
  username, password = normalizeCredentials(username, password)
  if username == "" or password == "" then
    state.lastError = "Enter username and password."
    state.message = state.lastError
    return false
  end

  state.inFlight = true
  state.username = username
  state.message = kind == "register" and "Creating online account..." or "Logging in..."
  return sendEvent(kind == "register" and "careerMPProgressRegister" or "careerMPProgressLogin", {
    username = username,
    password = password,
    fallbackSaveName = fallbackSaveName,
    clientName = MPConfig and MPConfig.getNickname and MPConfig.getNickname() or username,
  })
end

function M.requestLogin(config, defaultSaveName)
  clientConfig = type(config) == "table" and config or {}
  fallbackSaveName = tostring(defaultSaveName or fallbackSaveName or "")
  if clientConfig.serverProgressEnabled ~= true then
    return false
  end

  state.enabled = true
  state.required = not state.authenticated
  state.registrationDisabled = clientConfig.serverProgressAllowRegistration == false
  state.mode = tostring(clientConfig.serverProgressMode or "localJson")
  state.message = state.authenticated and "Online progress is active." or "Login required to load this server career."

  if state.authenticated and state.saveName ~= "" then
    startCareerFromSession({
      ok = true,
      saveName = state.saveName,
      accountId = state.accountId,
      username = state.username,
      token = state.token,
      revision = state.revision,
    })
  end

  return true
end

function M.login(username, password)
  return submitCredentials("login", username, password)
end

function M.register(username, password)
  if clientConfig.serverProgressAllowRegistration == false then
    state.lastError = "Registration is disabled on this server."
    state.message = state.lastError
    return false
  end
  return submitCredentials("register", username, password)
end

function M.getUiState()
  return deepcopy(state)
end

function M.forceUpload()
  uploadSnapshot("manual")
end

local function onSaveFinished()
  if state.authenticated then
    uploadSnapshot("saveFinished")
  end
end

local function onServerLeave()
  if state.authenticated then
    uploadSnapshot("serverLeave")
  end
  state.authenticated = false
  state.required = false
  state.inFlight = false
  state.token = nil
  state.accountId = ""
  state.saveName = ""
  state.revision = 0
  state.message = "Disconnected from server progress session."
end

local function onUpdate(dtReal)
  if not state.authenticated then return end
  uploadTimer = uploadTimer + (dtReal or 0)
  local interval = tonumber(clientConfig.serverProgressUploadIntervalSeconds) or 60
  if uploadTimer >= interval then
    uploadTimer = 0
    uploadSnapshot("interval")
  elseif uploadRequested and not uploadInFlight then
    uploadSnapshot("queued")
  end
end

local function onExtensionLoaded()
  AddEventHandler("careerMPProgressAuthResult", rxAuthResult)
  AddEventHandler("careerMPProgressUploadAccepted", rxUploadAccepted)
  AddEventHandler("careerMPProgressUploadRejected", rxUploadRejected)
  AddEventHandler("careerMPProgressNotice", rxNotice)
  log("W", "CareerMPProgress", "Server progress alpha client loaded")
end

M.onSaveFinished = onSaveFinished
M.onServerLeave = onServerLeave
M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded

return M
