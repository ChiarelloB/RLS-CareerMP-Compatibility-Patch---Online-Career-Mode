-- CareerMP server-controlled progress alpha.
-- Local JSON storage is intentionally behind helper functions so a future
-- backend provider can replace it without changing the client protocol.

local RESOURCE_DIR = "Resources/Server/CareerMPProgressAuth/"
local CONFIG_PATH = RESOURCE_DIR .. "config/config.json"
local DATA_DIR = RESOURCE_DIR .. "data/"
local ACCOUNTS_PATH = DATA_DIR .. "accounts.json"
local SAVES_DIR = DATA_DIR .. "saves/"

local defaultConfig = {
    enabled = true,
    mode = "localJson",
    serverId = "server-progress-alpha",
    allowRegistration = true,
    requireLogin = true,
    saveNamePrefix = "RLSOnline",
    uploadIntervalSeconds = 60,
    maxSnapshotBytes = 180000,
    serverSecret = "",
}

local config = {}
local accounts = { users = {} }
local sessions = {}
local sessionsByAccount = {}

local function decodeJson(data)
    local ok, decoded = pcall(Util.JsonDecode, data or "{}")
    if ok and type(decoded) == "table" then
        return decoded
    end
    return {}
end

local function encodeJson(value)
    return Util.JsonEncode(value or {})
end

local function ensureDir(path)
    if not FS.IsDirectory(path) then
        FS.CreateDirectory(path)
    end
end

local function readJson(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local raw = file:read("*all")
    file:close()
    return decodeJson(raw)
end

local function writeJson(path, value)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(encodeJson(value))
    file:close()
    return true
end

local function trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function normalizeUsername(username)
    username = trim(username):lower()
    username = username:gsub("[^%w%._%-]", "")
    return username
end

local function hashString(value)
    value = tostring(value or "")
    local h1 = 5381
    local h2 = 2166136261 % 2147483647
    for i = 1, #value do
        local b = string.byte(value, i)
        h1 = ((h1 * 33) + b) % 2147483647
        h2 = ((h2 * 16777619) + b) % 2147483647
    end
    return tostring(h1) .. ":" .. tostring(h2)
end

local function makeSalt(username)
    return hashString(tostring(os.time()) .. ":" .. tostring(math.random()) .. ":" .. tostring(username))
end

local function hashPassword(password, salt)
    return hashString(tostring(salt or "") .. "::" .. tostring(password or "") .. "::CareerMPProgressAlpha")
end

local function makeAccountId(username)
    return "acct_" .. (hashString(username):gsub(":", ""))
end

local function makeSessionToken(playerId, accountId)
    return hashString(tostring(playerId) .. ":" .. tostring(accountId) .. ":" .. tostring(os.time()) .. ":" .. tostring(math.random()))
end

local function savePathForAccount(accountId)
    return SAVES_DIR .. tostring(accountId or "unknown") .. ".json"
end

local function makeSaveName(accountId)
    local prefix = tostring(config.saveNamePrefix or "RLSOnline")
    local serverId = tostring(config.serverId or "server"):gsub("[^%w_%-]", "")
    return prefix .. "_" .. serverId .. "_" .. tostring(accountId or "account")
end

local function signSave(accountId, revision, files, summary)
    return hashString(tostring(config.serverSecret or "") .. "::" .. tostring(accountId) .. "::" .. tostring(revision) .. "::" .. encodeJson(files or {}) .. "::" .. encodeJson(summary or {}))
end

local function ensureConfig()
    ensureDir(RESOURCE_DIR)
    ensureDir(RESOURCE_DIR .. "config/")
    ensureDir(DATA_DIR)
    ensureDir(SAVES_DIR)

    config = readJson(CONFIG_PATH) or {}
    for key, value in pairs(defaultConfig) do
        if config[key] == nil then
            config[key] = value
        end
    end

    if tostring(config.serverSecret or "") == "" or tostring(config.serverSecret) == "CHANGE_ME" then
        math.randomseed(os.time())
        config.serverSecret = hashString("secret:" .. tostring(os.time()) .. ":" .. tostring(math.random()))
    end

    writeJson(CONFIG_PATH, config)
end

local function loadAccounts()
    accounts = readJson(ACCOUNTS_PATH) or { users = {} }
    accounts.users = type(accounts.users) == "table" and accounts.users or {}
end

local function saveAccounts()
    ensureDir(DATA_DIR)
    writeJson(ACCOUNTS_PATH, accounts)
end

local storageProvider = {}

function storageProvider.loadSave(accountId, username)
    local save = readJson(savePathForAccount(accountId)) or {}
    save.accountId = save.accountId or accountId
    save.username = save.username or username
    save.revision = tonumber(save.revision) or 0
    save.files = type(save.files) == "table" and save.files or {}
    save.summary = type(save.summary) == "table" and save.summary or {}
    return save
end

function storageProvider.saveSnapshot(accountId, username, revision, files, summary, truncated)
    local save = storageProvider.loadSave(accountId, username)
    local mergedFiles = type(save.files) == "table" and save.files or {}
    for relPath, fileData in pairs(files or {}) do
        if type(relPath) == "string" and type(fileData) == "table" then
            mergedFiles[relPath] = fileData
        end
    end

    save.accountId = accountId
    save.username = username
    save.revision = revision
    save.lastSeen = os.time()
    save.files = mergedFiles
    save.summary = summary or {}
    save.truncated = truncated == true
    save.serverSignature = signSave(accountId, revision, mergedFiles, summary)
    writeJson(savePathForAccount(accountId), save)
    return save
end

local function sendJson(playerId, eventName, payload)
    MP.TriggerClientEventJson(playerId, eventName, payload or {})
end

local function sendAuthError(playerId, message)
    sendJson(playerId, "careerMPProgressAuthResult", {
        ok = false,
        message = message,
    })
end

local function buildSnapshotForClient(save)
    if not save or not save.files or next(save.files) == nil then
        return nil
    end
    return {
        revision = tonumber(save.revision) or 0,
        files = save.files,
        summary = save.summary or {},
        serverSignature = save.serverSignature,
        truncated = save.truncated == true,
    }
end

local function completeLogin(playerId, username, account)
    if sessionsByAccount[account.accountId] and sessionsByAccount[account.accountId] ~= playerId then
        sendAuthError(playerId, "This account is already online.")
        return
    end

    local save = storageProvider.loadSave(account.accountId, username)
    local token = makeSessionToken(playerId, account.accountId)
    sessions[playerId] = {
        username = username,
        accountId = account.accountId,
        token = token,
        connectedAt = os.time(),
    }
    sessionsByAccount[account.accountId] = playerId

    account.lastLogin = os.time()
    saveAccounts()

    sendJson(playerId, "careerMPProgressAuthResult", {
        ok = true,
        username = username,
        accountId = account.accountId,
        token = token,
        saveName = makeSaveName(account.accountId),
        revision = tonumber(save.revision) or 0,
        snapshot = buildSnapshotForClient(save),
        mode = config.mode,
    })
end

local function validateCredentials(username, password)
    username = normalizeUsername(username)
    password = tostring(password or "")
    if username == "" or #username < 3 then
        return nil, nil, "Username must have at least 3 valid characters."
    end
    if password == "" or #password < 4 then
        return nil, nil, "Password must have at least 4 characters."
    end
    return username, password, nil
end

function careerMPProgressRegister(playerId, data)
    if not config.enabled then
        sendAuthError(playerId, "Server progress auth is disabled.")
        return
    end
    if not config.allowRegistration then
        sendAuthError(playerId, "Registration is disabled on this server.")
        return
    end

    local payload = decodeJson(data)
    local username, password, errorMessage = validateCredentials(payload.username, payload.password)
    if errorMessage then
        sendAuthError(playerId, errorMessage)
        return
    end
    if accounts.users[username] then
        sendAuthError(playerId, "This username already exists.")
        return
    end

    local salt = makeSalt(username)
    accounts.users[username] = {
        username = username,
        accountId = makeAccountId(username),
        salt = salt,
        passwordHash = hashPassword(password, salt),
        createdAt = os.time(),
    }
    saveAccounts()
    print("[CareerMPProgressAuth] Registered account " .. username)
    completeLogin(playerId, username, accounts.users[username])
end

function careerMPProgressLogin(playerId, data)
    if not config.enabled then
        sendAuthError(playerId, "Server progress auth is disabled.")
        return
    end

    local payload = decodeJson(data)
    local username, password, errorMessage = validateCredentials(payload.username, payload.password)
    if errorMessage then
        sendAuthError(playerId, errorMessage)
        return
    end

    local account = accounts.users[username]
    if not account or hashPassword(password, account.salt) ~= account.passwordHash then
        sendAuthError(playerId, "Invalid username or password.")
        return
    end

    completeLogin(playerId, username, account)
end

local function validateSession(playerId, payload)
    local session = sessions[playerId]
    if not session then
        return nil, "No active server progress session."
    end
    if tostring(payload.token or "") ~= tostring(session.token or "") then
        return nil, "Invalid progress session token."
    end
    return session, nil
end

function careerMPProgressUpload(playerId, data)
    local payload = decodeJson(data)
    local session, errorMessage = validateSession(playerId, payload)
    if errorMessage then
        sendJson(playerId, "careerMPProgressUploadRejected", { message = errorMessage })
        return
    end

    local save = storageProvider.loadSave(session.accountId, session.username)
    local incomingRevision = tonumber(payload.revision) or 0
    if incomingRevision ~= (tonumber(save.revision) or 0) then
        sendJson(playerId, "careerMPProgressUploadRejected", {
            message = "Stale progress snapshot rejected. Rejoin to reload server progress.",
            serverRevision = tonumber(save.revision) or 0,
        })
        return
    end

    local files = type(payload.files) == "table" and payload.files or {}
    local summary = type(payload.summary) == "table" and payload.summary or {}
    local newRevision = incomingRevision + 1
    storageProvider.saveSnapshot(session.accountId, session.username, newRevision, files, summary, payload.truncated == true)
    sendJson(playerId, "careerMPProgressUploadAccepted", { revision = newRevision })
end

function careerMPProgressOnPlayerDisconnect(playerId)
    local session = sessions[playerId]
    if session then
        sessionsByAccount[session.accountId] = nil
    end
    sessions[playerId] = nil
end

local function splitWords(text)
    local words = {}
    for word in tostring(text or ""):gmatch("%S+") do
        table.insert(words, word)
    end
    return words
end

function careerMPProgressConsole(message)
    local words = splitWords(message)
    if words[1] ~= "ProgressAuth" then
        return ""
    end

    local command = words[2] or "help"
    if command == "list" then
        print("[CareerMPProgressAuth] Accounts:")
        for username, account in pairs(accounts.users or {}) do
            local save = storageProvider.loadSave(account.accountId, username)
            print(" - " .. username .. " accountId=" .. tostring(account.accountId) .. " revision=" .. tostring(save.revision or 0))
        end
    elseif command == "reset" and words[3] then
        local username = normalizeUsername(words[3])
        local account = accounts.users[username]
        if account then
            writeJson(savePathForAccount(account.accountId), {
                accountId = account.accountId,
                username = username,
                revision = 0,
                files = {},
                summary = {},
                resetAt = os.time(),
            })
            print("[CareerMPProgressAuth] Reset save for " .. username)
        end
    elseif command == "setpassword" and words[3] and words[4] then
        local username = normalizeUsername(words[3])
        local account = accounts.users[username]
        if account then
            account.salt = makeSalt(username)
            account.passwordHash = hashPassword(words[4], account.salt)
            saveAccounts()
            print("[CareerMPProgressAuth] Password changed for " .. username)
        end
    else
        print("[CareerMPProgressAuth] Commands: ProgressAuth list | ProgressAuth reset <username> | ProgressAuth setpassword <username> <password>")
    end
    return ""
end

ensureConfig()
loadAccounts()

MP.RegisterEvent("careerMPProgressRegister", "careerMPProgressRegister")
MP.RegisterEvent("careerMPProgressLogin", "careerMPProgressLogin")
MP.RegisterEvent("careerMPProgressUpload", "careerMPProgressUpload")
MP.RegisterEvent("onPlayerDisconnect", "careerMPProgressOnPlayerDisconnect")
MP.RegisterEvent("onConsoleInput", "careerMPProgressConsole")

print("[CareerMPProgressAuth] ---------- Server progress alpha loaded")
