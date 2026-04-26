from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path


RLS_INFO_PATH = "mod_info/RLSCO24/info.json"
PATCH_VERSION = "v1.0.0-beta.13"

RLS_REMOVE_PREFIXES = (
    # RLS 2.6.5.x ships a legacy minimap app override that can remain in the
    # final zip after patch overlay and crash BeamNG on rejoin.
    "lua/ge/extensions/overrides/ui/apps/minimap/",
)

CAREERMP_REMOVE_PREFIXES = (
    # BeamNG 0.34 can discover mod-provided files under /settings but return
    # nil while reading them through jsonReadFile, which crashes ui/apps.lua.
    "settings/ui_apps/layouts/default/careermp.uilayout.json",
)


def sha256sum(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_zip_entries(zip_path: Path) -> dict[str, bytes]:
    data: dict[str, bytes] = {}
    with zipfile.ZipFile(zip_path, "r") as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            data[info.filename.replace("\\", "/")] = zf.read(info.filename)
    return data


def overlay_directory(entries: dict[str, bytes], patch_dir: Path) -> None:
    for file_path in patch_dir.rglob("*"):
        if file_path.is_dir():
            continue
        rel = file_path.relative_to(patch_dir).as_posix()
        entries[rel] = file_path.read_bytes()


def remove_entry_prefixes(entries: dict[str, bytes], prefixes: tuple[str, ...]) -> None:
    for name in list(entries):
        if any(name.startswith(prefix) for prefix in prefixes):
            del entries[name]


def replace_required(text: str, old: str, new: str, path: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Unable to patch {label} in {path}; source file layout changed.")
    return text.replace(old, new, 1)


def patch_careermp_entries(entries: dict[str, bytes]) -> None:
    """Apply small generated safety fixes to CareerMP files.

    CareerMP's drag display sync broadcasts txClearAll while the display module
    is initializing. RLS reloads drag display state aggressively to keep online
    drag races alive, and that clear broadcast can echo back late and wipe the
    second drag attempt. Keep the network clear for real race resets, but
    suppress it during module initialization and ignore stale remote clears
    while a local drag race is already active.
    """

    display_path = "lua/ge/extensions/gameplay/drag/display.lua"
    display = entries.get(display_path)
    if display:
        text = display.decode("utf-8").replace("\r\n", "\n")
        text = text.replace(
            '  if MPVehicleGE.isOwn(be:getPlayerVehicleID(0)) then\n'
            '    TriggerServerEvent("txClearDisplay", "")\n'
            "  end\n",
            '  if MPVehicleGE.isOwn(be:getPlayerVehicleID(0)) and not rawget(_G, "RLSCareerMP_SuppressDragClearBroadcast") then\n'
            '    TriggerServerEvent("txClearDisplay", "")\n'
            "  end\n",
        )
        text = text.replace(
            '  if MPVehicleGE.isOwn(be:getPlayerVehicleID(0)) then\n'
            '    TriggerServerEvent("txClearAll", "")\n'
            "  end\n",
            '  if MPVehicleGE.isOwn(be:getPlayerVehicleID(0)) and not rawget(_G, "RLSCareerMP_SuppressDragClearBroadcast") then\n'
            '    TriggerServerEvent("txClearAll", "")\n'
            "  end\n",
        )
        text = text.replace(
            "  init()\n"
            "  clearAll()\n",
            "  init()\n"
            '  local previousSuppressClear = rawget(_G, "RLSCareerMP_SuppressDragClearBroadcast")\n'
            "  _G.RLSCareerMP_SuppressDragClearBroadcast = true\n"
            "  clearAll()\n"
            "  _G.RLSCareerMP_SuppressDragClearBroadcast = previousSuppressClear\n",
        )
        entries[display_path] = text.encode("utf-8")

    sync_path = "lua/ge/extensions/careerMPDragDisplays.lua"
    sync = entries.get(sync_path)
    if sync:
        text = sync.decode("utf-8").replace("\r\n", "\n")
        text = replace_required(
            text,
            "local driverLightBlinkState = {\n"
            "\tlane = nil,\n"
            "\tisBlinking = false,\n"
            "\ttimer = 0,\n"
            "\tfrequency = 1/6,\n"
            "\tisOn = false\n"
            "}\n"
            "\n",
            "local driverLightBlinkState = {\n"
            "\tlane = nil,\n"
            "\tisBlinking = false,\n"
            "\ttimer = 0,\n"
            "\tfrequency = 1/6,\n"
            "\tisOn = false\n"
            "}\n"
            "\n"
            "local function hasLocalDragRaceActive()\n"
            "\tif rawget(_G, \"RLSCareerMP_LocalDragOwnerVehId\") then\n"
            "\t\treturn true\n"
            "\tend\n"
            "\tif not (gameplay_drag_general and gameplay_drag_general.getData) then\n"
            "\t\treturn false\n"
            "\tend\n"
            "\tlocal ok, currentDragData = pcall(gameplay_drag_general.getData)\n"
            "\tif not ok or not currentDragData or not currentDragData.racers then\n"
            "\t\treturn false\n"
            "\tend\n"
            "\tlocal playerVehId = be and be.getPlayerVehicleID and be:getPlayerVehicleID(0) or nil\n"
            "\tfor vehId, racer in pairs(currentDragData.racers) do\n"
            "\t\tif racer and (racer.isPlayable or vehId == playerVehId) then\n"
            "\t\t\treturn true\n"
            "\t\tend\n"
            "\tend\n"
            "\treturn false\n"
            "end\n"
            "\n"
            "local function isOwnServerVehicle(serverVehicleID)\n"
            "\tif not (serverVehicleID and MPVehicleGE and MPVehicleGE.getGameVehicleID and MPVehicleGE.isOwn) then\n"
            "\t\treturn false\n"
            "\tend\n"
            "\tlocal gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID)\n"
            "\treturn gameVehicleID and MPVehicleGE.isOwn(gameVehicleID) or false\n"
            "end\n"
            "\n"
            "local function shouldAdoptRemoteDragData(decodedData)\n"
            "\tif not decodedData or not decodedData.dragData then\n"
            "\t\treturn false\n"
            "\tend\n"
            "\tif decodedData.serverVehicleID and isOwnServerVehicle(decodedData.serverVehicleID) then\n"
            "\t\treturn true\n"
            "\tend\n"
            "\treturn not hasLocalDragRaceActive()\n"
            "end\n"
            "\n",
            sync_path,
            "CareerMP drag display local session guard",
        )
        text = text.replace(
            "\tif gameplay_drag_general then\n"
            "\t\tif not dragData then\n"
            "\t\t\tgameplay_drag_general.setDragRaceData(decodedData.dragData)\n"
            "\t\t\tdragData = gameplay_drag_general.getData()\n"
            "\t\tend\n"
            "\tend\n",
            "\tif gameplay_drag_general then\n"
            "\t\tif not dragData and shouldAdoptRemoteDragData(decodedData) then\n"
            "\t\t\tgameplay_drag_general.setDragRaceData(decodedData.dragData)\n"
            "\t\t\tdragData = gameplay_drag_general.getData()\n"
            "\t\telseif not dragData then\n"
            "\t\t\treturn\n"
            "\t\tend\n"
            "\tend\n",
        )
        text = text.replace(
            "local function rxClearAll()\n"
            "\tif not dragData then\n"
            "\t\tdragData = gameplay_drag_general.getData()\n"
            "\t\treturn\n"
            "\tend\n",
            "local function rxClearAll()\n"
            "\tlocal localDragStarted = gameplay_drag_general and gameplay_drag_general.getDragIsStarted and gameplay_drag_general.getDragIsStarted()\n"
            "\tif localDragStarted then\n"
            "\t\treturn\n"
            "\tend\n"
            "\tif not dragData then\n"
            "\t\tdragData = gameplay_drag_general and gameplay_drag_general.getData and gameplay_drag_general.getData() or nil\n"
            "\t\tif not dragData then return end\n"
            "\tend\n",
        )
        text = text.replace(
            "\tclearLights()\n"
            "\tclearDisplay()\n"
            "\tgameplay_drag_general._clear()\n",
            "\tlocal localDragStarted = gameplay_drag_general and gameplay_drag_general.getDragIsStarted and gameplay_drag_general.getDragIsStarted()\n"
            "\tclearLights()\n"
            "\tclearDisplay()\n"
            "\tif gameplay_drag_general and gameplay_drag_general._clear and not localDragStarted then\n"
            "\t\tgameplay_drag_general._clear()\n"
            "\tend\n"
            "\tdragData = nil\n",
        )
        entries[sync_path] = text.encode("utf-8")

    player_list_path = "ui/modules/apps/CareerMP-PlayerList/app.js"
    player_list = entries.get(player_list_path)
    if player_list:
        text = player_list.decode("utf-8").replace("\r\n", "\n")
        text = replace_required(
            text,
            "\tconst applyPlayerListStyle = function(useNewDesign) {\n",
            "\tconst hideContextMenu = function() {\n"
            "\t\tconst menu = document.getElementById(\"playerlist-contextmenu\");\n"
            "\t\tif (menu) menu.style.display = \"none\";\n"
            "\t};\n"
            "\n"
            "\tconst bindContextButton = function(id, action) {\n"
            "\t\tconst button = document.getElementById(id);\n"
            "\t\tif (!button) return;\n"
            "\t\tbutton.onclick = function() {\n"
            "\t\t\taction();\n"
            "\t\t\thideContextMenu();\n"
            "\t\t};\n"
            "\t};\n"
            "\n"
            "\tconst applyPlayerListStyle = function(useNewDesign) {\n",
            player_list_path,
            "CareerMP player list context helpers",
        )
        text = replace_required(
            text,
            "\t\t\t\t\tdocument.getElementById(\"pl-context-Pay100000Button\").onclick = function() {\n"
            "\t\t\t\t\t\tpayPlayer(parsedList[i].name, 100000);\n"
            "\t\t\t\t\t}\n"
            "\n",
            "\t\t\t\t\tbindContextButton(\"pl-context-Pay100000Button\", function() {\n"
            "\t\t\t\t\t\tpayPlayer(parsedList[i].name, 100000);\n"
            "\t\t\t\t\t});\n"
            "\n"
            "\t\t\t\t\tbindContextButton(\"pl-context-QueueEventsButton\", function() {\n"
            "\t\t\t\t\t\tapplyQueuesForPlayer(parsedList[i].id);\n"
            "\t\t\t\t\t});\n"
            "\n"
            "\t\t\t\t\tbindContextButton(\"pl-context-RestoreVehicles\", function() {\n"
            "\t\t\t\t\t\trestorePlayerVehicle(parsedList[i].name);\n"
            "\t\t\t\t\t});\n"
            "\n"
            "\t\t\t\t\tbindContextButton(\"pl-context-OpenProfileButton\", function() {\n"
            "\t\t\t\t\t\tviewPlayer(parsedList[i].name);\n"
            "\t\t\t\t\t});\n"
            "\n",
            player_list_path,
            "CareerMP player list queue context menu",
        )
        text = replace_required(
            text,
            "function payPlayer(targetPlayerName, amount) {\n"
            "\tbngApi.engineLua('careerMPPlayerPayments.payPlayer(\"' + targetPlayerName + '\", ' + amount + ')')\n"
            "}\n"
            "\n",
            "function payPlayer(targetPlayerName, amount) {\n"
            "\tbngApi.engineLua('careerMPPlayerPayments.payPlayer(\"' + targetPlayerName + '\", ' + amount + ')')\n"
            "}\n"
            "\n"
            "function viewPlayer(targetPlayerName) {\n"
            "\topenExternalLink(`https://forum.beammp.com/u/${targetPlayerName}/summary`)\n"
            "}\n"
            "\n"
            "function restorePlayerVehicle(targetPlayerName) {\n"
            "\tbngApi.engineLua('MPVehicleGE.restorePlayerVehicle(\"' + targetPlayerName + '\")')\n"
            "}\n"
            "\n"
            "function applyQueuesForPlayer(targetPlayerID) {\n"
            "\tvar numericPlayerId = parseInt(targetPlayerID, 10);\n"
            "\tif (isNaN(numericPlayerId)) return;\n"
            "\tbngApi.engineLua('MPVehicleGE.applyPlayerQueues(' + numericPlayerId + ')')\n"
            "}\n"
            "\n",
            player_list_path,
            "CareerMP player list BeamMP helper functions",
        )
        entries[player_list_path] = text.encode("utf-8")

    player_list_html_path = "ui/modules/apps/CareerMP-PlayerList/app.html"
    player_list_html = entries.get(player_list_html_path)
    if player_list_html:
        text = player_list_html.decode("utf-8").replace("\r\n", "\n")
        text = replace_required(
            text,
            "\t\t<button id=\"pl-context-Pay100000Button\">Pay $100000</button>\n",
            "\t\t<button id=\"pl-context-Pay100000Button\">Pay $100000</button>\n"
            "\t\t<button id=\"pl-context-QueueEventsButton\">Queue Events</button>\n"
            "\t\t<button id=\"pl-context-RestoreVehicles\">Restore Vehicles</button>\n"
            "\t\t<button id=\"pl-context-OpenProfileButton\">Open Profile</button>\n",
            player_list_html_path,
            "CareerMP player list BeamMP context buttons",
        )
        text = replace_required(
            text,
            "\t\t<button class=\"buttons\" id=\"show-button\" onclick=\"toggleList()\">&lt;</button>\n",
            "\t\t<button class=\"buttons\" id=\"show-button\" onclick=\"toggleList()\">&lt;</button>\n"
            f"\t\t<div id=\"rls-careermp-patch-version\" title=\"If this does not say {PATCH_VERSION}, clear your BeamMP client mod cache and rejoin.\" style=\"font-size: 10px; color: #ff8c2a; background: rgba(0, 0, 0, 0.65); padding: 2px 5px; margin-top: 2px; border-left: 2px solid #ff8c2a; white-space: nowrap;\">RLS CareerMP Patch {PATCH_VERSION}</div>\n",
            player_list_html_path,
            "CareerMP player list visible patch version marker",
        )
        entries[player_list_html_path] = text.encode("utf-8")

    entries["rls_careermp_patch_version.txt"] = (
        f"RLS CareerMP Compatibility Patch {PATCH_VERSION}\n"
        "Queue apply is manual by default in this build.\n"
    ).encode("utf-8")


def patch_rls_entries(entries: dict[str, bytes], output_name: str) -> None:
    """Keep BeamNG mod metadata aligned with the generated compatibility zip."""

    info = entries.get(RLS_INFO_PATH)
    if not info:
        return

    data = json.loads(info.decode("utf-8-sig"))
    data["filename"] = output_name
    entries[RLS_INFO_PATH] = (json.dumps(data, ensure_ascii=False, indent=4) + "\n").encode("utf-8")


def write_zip(zip_path: Path, entries: dict[str, bytes]) -> None:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for name in sorted(entries):
            zf.writestr(name, entries[name])


def build_mod(base_zip: Path, patch_dir: Path, output_zip: Path, remove_prefixes: tuple[str, ...] = ()) -> tuple[int, str]:
    entries = read_zip_entries(base_zip)
    remove_entry_prefixes(entries, remove_prefixes)
    overlay_directory(entries, patch_dir)
    if patch_dir.name == "CareerMP":
        patch_careermp_entries(entries)
    elif patch_dir.name == "RLS":
        patch_rls_entries(entries, output_zip.name)
    write_zip(output_zip, entries)
    return output_zip.stat().st_size, sha256sum(output_zip)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent

    parser = argparse.ArgumentParser(description="Build the CareerMP-compatible RLS release zips.")
    parser.add_argument("--rls-original", required=True, type=Path, help="Path to the original rls_career_overhaul zip")
    parser.add_argument("--careermp-original", required=True, type=Path, help="Path to the original CareerMP.zip")
    parser.add_argument("--out-dir", type=Path, default=repo_root / "built", help="Output directory for the generated zips")
    args = parser.parse_args()

    rls_original = args.rls_original.expanduser().resolve()
    careermp_original = args.careermp_original.expanduser().resolve()
    out_dir = args.out_dir.expanduser().resolve()

    if not rls_original.is_file():
        raise SystemExit(f"RLS original zip not found: {rls_original}")
    if not careermp_original.is_file():
        raise SystemExit(f"CareerMP original zip not found: {careermp_original}")

    out_dir.mkdir(parents=True, exist_ok=True)

    rls_patch_dir = repo_root / "patches" / "RLS"
    careermp_patch_dir = repo_root / "patches" / "CareerMP"

    rls_out = out_dir / f"{rls_original.stem}_careermp_compatible.zip"
    careermp_out = out_dir / "CareerMP.zip"

    rls_size, rls_hash = build_mod(rls_original, rls_patch_dir, rls_out, RLS_REMOVE_PREFIXES)
    cmp_size, cmp_hash = build_mod(careermp_original, careermp_patch_dir, careermp_out, CAREERMP_REMOVE_PREFIXES)

    checksums = out_dir / "checksums.txt"
    checksums.write_text(
        "\n".join(
            [
                f"{rls_hash}  {rls_out.name}",
                f"{cmp_hash}  {careermp_out.name}",
                "",
                f"{rls_out.name} size={rls_size}",
                f"{careermp_out.name} size={cmp_size}",
            ]
        ),
        encoding="utf-8",
    )

    print(f"Built: {rls_out}")
    print(f"Built: {careermp_out}")
    print(f"Wrote: {checksums}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
