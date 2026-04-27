from __future__ import annotations

import argparse
from pathlib import Path


PATCH_VERSION = "v1.0.0-beta.14"
SERVER_RELATIVE_PATH = Path("Resources/Server/CareerMP/careerMP.lua")


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Unable to patch {label}; source layout changed.")
    return text.replace(old, new, 1)


def replace_any_required(text: str, options: tuple[str, ...], new: str, label: str) -> str:
    for old in options:
        if old in text:
            return text.replace(old, new, 1)
    raise RuntimeError(f"Unable to patch {label}; source layout changed.")


def normalize_newlines(text: str) -> str:
    return text.replace("\r\r\n", "\n").replace("\r\n", "\n").replace("\r", "\n")


CORE_HOTFIX_HELPERS = (
    "local RLSCareerMP_Beta14ServerHotfix = true\n"
    "\n"
    "local function isPlayerConnected(player_id)\n"
    "\tfor id in pairs(MP.GetPlayers()) do\n"
    "\t\tif tostring(id) == tostring(player_id) then\n"
    "\t\t\treturn true\n"
    "\t\tend\n"
    "\tend\n"
    "\treturn false\n"
    "end\n"
    "\n"
    "local function safeTriggerClientEvent(player_id, eventName, data)\n"
    "\tif tostring(player_id) == \"-1\" then\n"
    "\t\tfor id in pairs(MP.GetPlayers()) do\n"
    "\t\t\tsafeTriggerClientEvent(id, eventName, data)\n"
    "\t\tend\n"
    "\t\treturn true\n"
    "\tend\n"
    "\tif not isPlayerConnected(player_id) then\n"
    "\t\treturn false\n"
    "\tend\n"
    "\tlocal ok, err = pcall(MP.TriggerClientEvent, player_id, eventName, data or \"\")\n"
    "\tif not ok then\n"
    "\t\tdiag(\"TriggerClientEvent failed event=\" .. tostring(eventName) .. \" player=\" .. playerLabel(player_id) .. \" err=\" .. tostring(err))\n"
    "\t\treturn false\n"
    "\tend\n"
    "\treturn true\n"
    "end\n"
    "\n"
    "local function safeTriggerClientEventJson(player_id, eventName, payload)\n"
    "\tif tostring(player_id) == \"-1\" then\n"
    "\t\tfor id in pairs(MP.GetPlayers()) do\n"
    "\t\t\tsafeTriggerClientEventJson(id, eventName, payload)\n"
    "\t\tend\n"
    "\t\treturn true\n"
    "\tend\n"
    "\tif not isPlayerConnected(player_id) then\n"
    "\t\treturn false\n"
    "\tend\n"
    "\tlocal ok, err = pcall(MP.TriggerClientEventJson, player_id, eventName, payload or {})\n"
    "\tif not ok then\n"
    "\t\tdiag(\"TriggerClientEventJson failed event=\" .. tostring(eventName) .. \" player=\" .. playerLabel(player_id) .. \" err=\" .. tostring(err))\n"
    "\t\treturn false\n"
    "\tend\n"
    "\treturn true\n"
    "end\n"
    "\n"
    "local function safeJsonDecode(data)\n"
    "\tif not data or data == \"\" or data == \"null\" then\n"
    "\t\treturn nil\n"
    "\tend\n"
    "\tlocal ok, decoded = pcall(Util.JsonDecode, data)\n"
    "\tif not ok or type(decoded) ~= \"table\" then\n"
    "\t\tdiag(\"JsonDecode failed: \" .. tostring(decoded))\n"
    "\t\treturn nil\n"
    "\tend\n"
    "\treturn decoded\n"
    "end\n"
    "\n"
    "local function broadcastVehicleStates(reason)\n"
    "\tdiag(\"broadcastVehicleStates reason=\" .. tostring(reason) .. \" states=\" .. tostring(countTableEntries(vehicleStates)))\n"
    "\tsafeTriggerClientEventJson(-1, \"rxCareerVehSync\", vehicleStates)\n"
    "end\n"
    "\n"
    "local function removeVehicleStatesForPlayer(player_id)\n"
    "\tlocal prefix = tostring(player_id) .. \"-\"\n"
    "\tlocal removed = 0\n"
    "\tfor serverVehicleID in pairs(vehicleStates) do\n"
    "\t\tif tostring(serverVehicleID):sub(1, #prefix) == prefix then\n"
    "\t\t\tvehicleStates[serverVehicleID] = nil\n"
    "\t\t\tremoved = removed + 1\n"
    "\t\tend\n"
    "\tend\n"
    "\treturn removed\n"
    "end\n"
    "\n"
    "local function findPlayerIdByNameOrId(value)\n"
    "\tif value == nil then return nil, nil end\n"
    "\tlocal wanted = tostring(value):lower()\n"
    "\tfor id in pairs(MP.GetPlayers()) do\n"
    "\t\tlocal name = safePlayerName(id)\n"
    "\t\tif tostring(id):lower() == wanted or (name and tostring(name):lower() == wanted) then\n"
    "\t\t\treturn id, name\n"
    "\t\tend\n"
    "\tend\n"
    "\treturn nil, nil\n"
    "end\n"
)


BASE_HELPERS = (
    "\n"
    "local function countTableEntries(t)\n"
    "\tif type(t) ~= \"table\" then return 0 end\n"
    "\tlocal count = 0\n"
    "\tfor _ in pairs(t) do count = count + 1 end\n"
    "\treturn count\n"
    "end\n"
    "\n"
    "local function safePlayerName(player_id)\n"
    "\tif MP.GetPlayerName then\n"
    "\t\tlocal ok, result = pcall(MP.GetPlayerName, player_id)\n"
    "\t\tif ok and result then\n"
    "\t\t\treturn result\n"
    "\t\tend\n"
    "\tend\n"
    "\treturn nil\n"
    "end\n"
    "\n"
    "local function playerLabel(player_id)\n"
    "\tlocal name = safePlayerName(player_id)\n"
    "\tif name then\n"
    "\t\treturn tostring(player_id) .. \":\" .. tostring(name)\n"
    "\tend\n"
    "\treturn tostring(player_id)\n"
    "end\n"
    "\n"
    "local function diag(message)\n"
    "\tprint(\"[CareerMP-DIAG] ---------- \" .. tostring(message))\n"
    "end\n"
    "\n"
    + CORE_HOTFIX_HELPERS
    + "\n"
)


BETA13_SAFE_PLAYER_NAME = (
    "local function safePlayerName(player_id)\n"
    "\tif MP.GetPlayerName then\n"
    "\t\tlocal ok, result = pcall(MP.GetPlayerName, player_id)\n"
    "\t\tif ok and result then\n"
    "\t\t\treturn result\n"
    "\t\tend\n"
    "\tend\n"
    "\treturn nil\n"
    "end\n"
    "\n"
)


def insert_helper_block(text: str) -> str:
    if "RLSCareerMP_Beta14ServerHotfix" in text:
        return text

    diag_anchor = (
        "local function diag(message)\n"
        "\tprint(\"[CareerMP-DIAG] ---------- \" .. tostring(message))\n"
        "end\n"
        "\n"
        "local signalTimer = MP.CreateTimer()\n"
    )
    if diag_anchor in text:
        return replace_required(
            text,
            diag_anchor,
            "local function diag(message)\n"
            "\tprint(\"[CareerMP-DIAG] ---------- \" .. tostring(message))\n"
            "end\n"
            "\n"
            + BETA13_SAFE_PLAYER_NAME
            + CORE_HOTFIX_HELPERS
            + "\n"
            "local signalTimer = MP.CreateTimer()\n",
            "beta14 server helper block",
        )

    return replace_required(
        text,
        "local loadedPrefabs = {}\n\nlocal signalTimer = MP.CreateTimer()\n",
        "local loadedPrefabs = {}\n"
        + BASE_HELPERS
        + "local signalTimer = MP.CreateTimer()\n",
        "beta14 base server helper block",
    )


def patch_text(text: str) -> str:
    text = normalize_newlines(text)
    if "RLSCareerMP_Beta14ServerHotfix" in text and "function careerForceResyncRequested" in text:
        if "local function safePlayerName(player_id)" not in text:
            text = replace_required(
                text,
                "local RLSCareerMP_Beta14ServerHotfix = true\n",
                BETA13_SAFE_PLAYER_NAME + "local RLSCareerMP_Beta14ServerHotfix = true\n",
                "beta14 safe player name upgrade",
            )
        text = text.replace("requestedBy = MP.GetPlayerName(player_id)", "requestedBy = safePlayerName(player_id)")
        text = text.replace("targetName = MP.GetPlayerName(player_id)", "targetName = safePlayerName(player_id)")
        return text

    text = insert_helper_block(text)

    if 'MP.RegisterEvent("careerForceResyncRequested","careerForceResyncRequested")' not in text:
        text = replace_required(
            text,
            '\tMP.RegisterEvent("careerVehicleActiveHandler","careerVehicleActiveHandler")\n',
            '\tMP.RegisterEvent("careerVehicleActiveHandler","careerVehicleActiveHandler")\n'
            '\tMP.RegisterEvent("careerForceResyncRequested","careerForceResyncRequested")\n',
            "force resync server event registration",
        )

    text = replace_any_required(
        text,
        (
            "function careerVehSyncRequested(player_id)\n"
            "\tsynced = true\n"
            "\tdiag(\"careerVehSyncRequested player=\" .. playerLabel(player_id) .. \" states=\" .. tostring(countTableEntries(vehicleStates)))\n"
            "\tMP.TriggerClientEventJson(player_id, \"rxCareerVehSync\", vehicleStates)\n"
            "end\n",
            "function careerVehSyncRequested(player_id)\n"
            "\tsynced = true\n"
            "\tMP.TriggerClientEventJson(player_id, \"rxCareerVehSync\", vehicleStates)\n"
            "end\n",
        ),
        "function careerVehSyncRequested(player_id)\n"
        "\tsynced = true\n"
        "\tdiag(\"careerVehSyncRequested player=\" .. playerLabel(player_id) .. \" states=\" .. tostring(countTableEntries(vehicleStates)))\n"
        "\tsafeTriggerClientEventJson(player_id, \"rxCareerVehSync\", vehicleStates)\n"
        "end\n",
        "safe career vehicle sync response",
    )

    text = replace_any_required(
        text,
        (
            "function careerPrefabSync(player_id, data)\n"
            "\tlocal prefab = Util.JsonDecode(data)\n"
            "\tdiag(\"careerPrefabSync player=\" .. playerLabel(player_id) .. \" name=\" .. tostring(prefab and prefab.pName) .. \" load=\" .. tostring(prefab and prefab.pLoad))\n"
            "\tif prefab.pLoad == true then\n"
            "\t\tloadedPrefabs[player_id][prefab.pName] = prefab\n"
            "\telseif prefab.pLoad == false then\n"
            "\t\tloadedPrefabs[player_id][prefab.pName] = nil\n"
            "\tend\n"
            "\tfor id in pairs(MP.GetPlayers()) do\n"
            "\t\tif player_id ~= id then\n"
            "\t\t\tMP.TriggerClientEvent(id, \"rxPrefabSync\", data)\n"
            "\t\tend\n"
            "\tend\n"
            "end\n",
            "function careerPrefabSync(player_id, data)\n"
            "\tlocal prefab = Util.JsonDecode(data)\n"
            "\tif prefab.pLoad == true then\n"
            "\t\tloadedPrefabs[player_id][prefab.pName] = prefab\n"
            "\telseif prefab.pLoad == false then\n"
            "\t\tloadedPrefabs[player_id][prefab.pName] = nil\n"
            "\tend\n"
            "\tfor id in pairs(MP.GetPlayers()) do\n"
            "\t\tif player_id ~= id then\n"
            "\t\t\tMP.TriggerClientEvent(id, \"rxPrefabSync\", data)\n"
            "\t\tend\n"
            "\tend\n"
            "end\n",
        ),
        "function careerPrefabSync(player_id, data)\n"
        "\tlocal prefab = safeJsonDecode(data)\n"
        "\tdiag(\"careerPrefabSync player=\" .. playerLabel(player_id) .. \" name=\" .. tostring(prefab and prefab.pName) .. \" load=\" .. tostring(prefab and prefab.pLoad))\n"
        "\tif not prefab or not prefab.pName then\n"
        "\t\treturn\n"
        "\tend\n"
        "\tloadedPrefabs[player_id] = loadedPrefabs[player_id] or {}\n"
        "\tif prefab.pLoad == true then\n"
        "\t\tloadedPrefabs[player_id][prefab.pName] = prefab\n"
        "\telseif prefab.pLoad == false then\n"
        "\t\tloadedPrefabs[player_id][prefab.pName] = nil\n"
        "\tend\n"
        "\tfor id in pairs(MP.GetPlayers()) do\n"
        "\t\tif player_id ~= id then\n"
        "\t\t\tsafeTriggerClientEvent(id, \"rxPrefabSync\", data)\n"
        "\t\tend\n"
        "\tend\n"
        "end\n",
        "guarded prefab sync",
    )

    text = replace_any_required(
        text,
        (
            "function careerSyncRequested(player_id)\n"
            "\tdiag(\"careerSyncRequested player=\" .. playerLabel(player_id) .. \" roadTraffic=\" .. tostring(Config.client.roadTrafficEnabled) .. \"/\" .. tostring(Config.client.roadTrafficAmount) .. \" parked=\" .. tostring(Config.client.parkedTrafficEnabled) .. \"/\" .. tostring(Config.client.parkedTrafficAmount) .. \" skipOtherPlayersVehicles=\" .. tostring(Config.client.skipOtherPlayersVehicles))\n"
            "\tMP.TriggerClientEventJson(player_id, \"rxCareerSync\", Config.client)\n"
            "end\n",
            "function careerSyncRequested(player_id)\n"
            "\tMP.TriggerClientEventJson(player_id, \"rxCareerSync\", Config.client)\n"
            "end\n",
        ),
        "function careerSyncRequested(player_id)\n"
        "\tdiag(\"careerSyncRequested player=\" .. playerLabel(player_id) .. \" roadTraffic=\" .. tostring(Config.client.roadTrafficEnabled) .. \"/\" .. tostring(Config.client.roadTrafficAmount) .. \" parked=\" .. tostring(Config.client.parkedTrafficEnabled) .. \"/\" .. tostring(Config.client.parkedTrafficAmount) .. \" skipOtherPlayersVehicles=\" .. tostring(Config.client.skipOtherPlayersVehicles))\n"
        "\tsafeTriggerClientEventJson(player_id, \"rxCareerSync\", Config.client)\n"
        "end\n",
        "safe career sync response",
    )

    text = replace_required(
        text,
        "\t\t\t\t\tMP.TriggerClientEventJson(player_id, \"rxPrefabSync\", loadedPrefabs[id][k])\n",
        "\t\t\t\t\tsafeTriggerClientEventJson(player_id, \"rxPrefabSync\", loadedPrefabs[id][k])\n",
        "safe prefab replay",
    )

    text = replace_any_required(
        text,
        (
            "function careerVehicleActiveHandler(player_id, data)\n"
            "\tlocal vehicleData = Util.JsonDecode(data)\n"
            "\tdiag(\"careerVehicleActiveHandler player=\" .. playerLabel(player_id) .. \" serverVehicleID=\" .. tostring(vehicleData and vehicleData.serverVehicleID) .. \" active=\" .. tostring(vehicleData and vehicleData.active))\n"
            "\tif vehicleStates[vehicleData.serverVehicleID] then\n"
            "\t\tvehicleStates[vehicleData.serverVehicleID].active = vehicleData.active\n"
            "\telse\n"
            "\t\tvehicleStates[vehicleData.serverVehicleID] = {}\n"
            "\t\tvehicleStates[vehicleData.serverVehicleID].active = vehicleData.active\n"
            "\tend\n"
            "\tMP.TriggerClientEventJson(-1, \"rxCareerVehSync\", vehicleStates)\n"
            "end\n",
            "function careerVehicleActiveHandler(player_id, data)\n"
            "\tlocal vehicleData = Util.JsonDecode(data)\n"
            "\tif vehicleStates[vehicleData.serverVehicleID] then\n"
            "\t\tvehicleStates[vehicleData.serverVehicleID].active = vehicleData.active\n"
            "\telse\n"
            "\t\tvehicleStates[vehicleData.serverVehicleID] = {}\n"
            "\t\tvehicleStates[vehicleData.serverVehicleID].active = vehicleData.active\n"
            "\tend\n"
            "\tMP.TriggerClientEventJson(-1, \"rxCareerVehSync\", vehicleStates)\n"
            "end\n",
        ),
        "function careerVehicleActiveHandler(player_id, data)\n"
        "\tlocal vehicleData = safeJsonDecode(data)\n"
        "\tdiag(\"careerVehicleActiveHandler player=\" .. playerLabel(player_id) .. \" serverVehicleID=\" .. tostring(vehicleData and vehicleData.serverVehicleID) .. \" active=\" .. tostring(vehicleData and vehicleData.active))\n"
        "\tif not vehicleData or not vehicleData.serverVehicleID then\n"
        "\t\treturn\n"
        "\tend\n"
        "\tlocal serverVehicleID = tostring(vehicleData.serverVehicleID)\n"
        "\tvehicleStates[serverVehicleID] = vehicleStates[serverVehicleID] or {}\n"
        "\tvehicleStates[serverVehicleID].active = vehicleData.active == true\n"
        "\tbroadcastVehicleStates(\"activeChanged\")\n"
        "end\n"
        "\n"
        "function careerForceResyncRequested(player_id, data)\n"
        "\tlocal payload = safeJsonDecode(data) or {}\n"
        "\tlocal targetValue = payload.targetName or payload.targetPlayerName or payload.playerName or payload.playerID\n"
        "\tlocal targetID, targetName = findPlayerIdByNameOrId(targetValue)\n"
        "\tif not targetID then\n"
        "\t\tdiag(\"careerForceResyncRequested failed requester=\" .. playerLabel(player_id) .. \" target=\" .. tostring(targetValue))\n"
        "\t\treturn\n"
        "\tend\n"
        "\tlocal removed = removeVehicleStatesForPlayer(targetID)\n"
        "\tlocal notice = {\n"
        "\t\tplayerID = tostring(targetID),\n"
        "\t\ttargetName = targetName,\n"
        "\t\treason = \"manualResync\",\n"
        "\t\trequestedBy = safePlayerName(player_id),\n"
        "\t\tremovedStates = removed,\n"
        "\t}\n"
        "\tdiag(\"careerForceResyncRequested requester=\" .. playerLabel(player_id) .. \" target=\" .. playerLabel(targetID) .. \" removed=\" .. tostring(removed))\n"
        "\tsafeTriggerClientEventJson(-1, \"rxCareerForceDeleteVehicles\", notice)\n"
        "\tbroadcastVehicleStates(\"forceResync\")\n"
        "\tsafeTriggerClientEventJson(targetID, \"rxCareerForceResyncOwnVehicles\", notice)\n"
        "end\n",
        "guarded vehicle active and force resync handling",
    )

    text = replace_any_required(
        text,
        (
            "function onPlayerJoinHandler(player_id)\n"
            "\tloadedPrefabs[player_id] = {}\n"
            "\tdiag(\"playerJoin player=\" .. playerLabel(player_id) .. \" players=\" .. tostring(countTableEntries(MP.GetPlayers())) .. \" states=\" .. tostring(countTableEntries(vehicleStates)))\n"
            "end\n",
            "function onPlayerJoinHandler(player_id)\n"
            "\tloadedPrefabs[player_id] = {}\n"
            "end\n",
        ),
        "function onPlayerJoinHandler(player_id)\n"
        "\tlocal removed = removeVehicleStatesForPlayer(player_id)\n"
        "\tloadedPrefabs[player_id] = {}\n"
        "\tdiag(\"playerJoin player=\" .. playerLabel(player_id) .. \" players=\" .. tostring(countTableEntries(MP.GetPlayers())) .. \" states=\" .. tostring(countTableEntries(vehicleStates)) .. \" removedStale=\" .. tostring(removed))\n"
        "\tif removed > 0 then\n"
        "\t\tbroadcastVehicleStates(\"joinCleanup\")\n"
        "\tend\n"
        "end\n",
        "join stale vehicle cleanup",
    )

    text = replace_any_required(
        text,
        (
            "function onVehicleSpawnHandler(player_id, vehicle_id,  data)\n"
            "\tvehicleStates[player_id .. \"-\" .. vehicle_id] = {}\n"
            "\tvehicleStates[player_id .. \"-\" .. vehicle_id].active = true\n"
            "\tdiag(\"vehicleSpawn player=\" .. playerLabel(player_id) .. \" vehicle_id=\" .. tostring(vehicle_id) .. \" states=\" .. tostring(countTableEntries(vehicleStates)))\n"
            "\tMP.TriggerClientEventJson(-1, \"rxCareerVehSync\", vehicleStates)\n"
            "end\n",
            "function onVehicleSpawnHandler(player_id, vehicle_id,  data)\n"
            "\tvehicleStates[player_id .. \"-\" .. vehicle_id] = {}\n"
            "\tvehicleStates[player_id .. \"-\" .. vehicle_id].active = true\n"
            "\tMP.TriggerClientEventJson(-1, \"rxCareerVehSync\", vehicleStates)\n"
            "end\n",
        ),
        "function onVehicleSpawnHandler(player_id, vehicle_id,  data)\n"
        "\tlocal serverVehicleID = tostring(player_id) .. \"-\" .. tostring(vehicle_id)\n"
        "\tvehicleStates[serverVehicleID] = {active = true}\n"
        "\tdiag(\"vehicleSpawn player=\" .. playerLabel(player_id) .. \" vehicle_id=\" .. tostring(vehicle_id) .. \" states=\" .. tostring(countTableEntries(vehicleStates)))\n"
        "\tbroadcastVehicleStates(\"vehicleSpawn\")\n"
        "end\n",
        "safe vehicle spawn state broadcast",
    )

    text = replace_any_required(
        text,
        (
            "function onVehicleDeletedHandler(player_id, vehicle_id)\n"
            "\tif vehicleStates[player_id .. \"-\" .. vehicle_id] then\n"
            "\t\tvehicleStates[player_id .. \"-\" .. vehicle_id] = nil\n"
            "\tend\n"
            "\tdiag(\"vehicleDeleted player=\" .. playerLabel(player_id) .. \" vehicle_id=\" .. tostring(vehicle_id) .. \" states=\" .. tostring(countTableEntries(vehicleStates)))\n"
            "end\n",
            "function onVehicleDeletedHandler(player_id, vehicle_id)\n"
            "\tif vehicleStates[player_id .. \"-\" .. vehicle_id] then\n"
            "\t\tvehicleStates[player_id .. \"-\" .. vehicle_id] = nil\n"
            "\tend\n"
            "end\n",
        ),
        "function onVehicleDeletedHandler(player_id, vehicle_id)\n"
        "\tlocal serverVehicleID = tostring(player_id) .. \"-\" .. tostring(vehicle_id)\n"
        "\tif vehicleStates[serverVehicleID] then\n"
        "\t\tvehicleStates[serverVehicleID] = nil\n"
        "\tend\n"
        "\tdiag(\"vehicleDeleted player=\" .. playerLabel(player_id) .. \" vehicle_id=\" .. tostring(vehicle_id) .. \" states=\" .. tostring(countTableEntries(vehicleStates)))\n"
        "\tbroadcastVehicleStates(\"vehicleDeleted\")\n"
        "end\n",
        "safe vehicle delete state broadcast",
    )

    text = replace_any_required(
        text,
        (
            "function onPlayerDisconnectHandler(player_id)\n"
            "\tloadedPrefabs[player_id] = nil\n"
            "\tledger.send[player_id] = nil\n"
            "\tledger.receive[player_id] = nil\n"
            "\tdiag(\"playerDisconnect player=\" .. playerLabel(player_id) .. \" players=\" .. tostring(countTableEntries(MP.GetPlayers())) .. \" states=\" .. tostring(countTableEntries(vehicleStates)) .. \" prefabs=\" .. tostring(countTableEntries(loadedPrefabs)))\n"
            "end\n",
            "function onPlayerDisconnectHandler(player_id)\n"
            "\tloadedPrefabs[player_id] = nil\n"
            "\tledger.send[player_id] = nil\n"
            "\tledger.receive[player_id] = nil\n"
            "end\n",
        ),
        "function onPlayerDisconnectHandler(player_id)\n"
        "\tlocal removed = removeVehicleStatesForPlayer(player_id)\n"
        "\tloadedPrefabs[player_id] = nil\n"
        "\tledger.send[player_id] = nil\n"
        "\tledger.receive[player_id] = nil\n"
        "\tlocal notice = {\n"
        "\t\tplayerID = tostring(player_id),\n"
        "\t\ttargetName = safePlayerName(player_id),\n"
        "\t\treason = \"disconnectCleanup\",\n"
        "\t\tremovedStates = removed,\n"
        "\t}\n"
        "\tdiag(\"playerDisconnect player=\" .. playerLabel(player_id) .. \" players=\" .. tostring(countTableEntries(MP.GetPlayers())) .. \" states=\" .. tostring(countTableEntries(vehicleStates)) .. \" prefabs=\" .. tostring(countTableEntries(loadedPrefabs)) .. \" removed=\" .. tostring(removed))\n"
        "\tif removed > 0 then\n"
        "\t\tsafeTriggerClientEventJson(-1, \"rxCareerForceDeleteVehicles\", notice)\n"
        "\t\tbroadcastVehicleStates(\"disconnectCleanup\")\n"
        "\tend\n"
        "end\n",
        "disconnect stale vehicle cleanup",
    )

    text = replace_required(
        text,
        '\tif commandPrefix == "CareerMP " or "CMP " then\n',
        '\tif commandPrefix == "CareerMP " or commandPrefix == "CMP " then\n',
        "console command prefix condition",
    )

    return text


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply the RLS CareerMP beta14 server stability hotfix.")
    parser.add_argument("--server-root", type=Path, help="BeamMP server root containing Resources/Server/CareerMP/careerMP.lua")
    parser.add_argument("--server-lua", type=Path, help="Direct path to careerMP.lua")
    parser.add_argument("--no-backup", action="store_true", help="Do not write a .bak file before patching")
    args = parser.parse_args()

    if not args.server_root and not args.server_lua:
        raise SystemExit("Provide --server-root or --server-lua.")

    server_lua = args.server_lua or (args.server_root / SERVER_RELATIVE_PATH)
    server_lua = server_lua.resolve()
    if not server_lua.is_file():
        raise SystemExit(f"careerMP.lua not found: {server_lua}")

    original = server_lua.read_text(encoding="utf-8-sig")
    patched = patch_text(original)
    if patched == normalize_newlines(original):
        print(f"Already patched: {server_lua}")
        return 0

    if not args.no_backup:
        backup = server_lua.with_suffix(server_lua.suffix + f".{PATCH_VERSION}.bak")
        if not backup.exists():
            backup.write_text(original, encoding="utf-8")
            print(f"Backup: {backup}")

    # Use bytes so Windows text-mode newline translation cannot turn CRLF into CRCRLF.
    server_lua.write_bytes(patched.replace("\n", "\r\n").encode("utf-8"))
    print(f"Patched {PATCH_VERSION}: {server_lua}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
