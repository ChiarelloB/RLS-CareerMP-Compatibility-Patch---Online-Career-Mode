from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import zipfile
from pathlib import Path

from build_release import (
    CAREERMP_REMOVE_PREFIXES,
    PATCH_VERSION,
    RLS_REMOVE_PREFIXES,
    overlay_directory,
    patch_careermp_entries,
    patch_rls_entries,
    read_zip_entries,
    remove_entry_prefixes,
    replace_required,
    sha256sum,
    write_zip,
)


ALPHA_VERSION = "v1.1.0-auth-alpha.1"
DEFAULT_PORT = 30848


def filetime_from_stat(path: Path) -> int:
    return int((path.stat().st_mtime + 11644473600) * 10000000)


def is_inside(child: Path, parent: Path) -> bool:
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def safe_replace_tree(target: Path, repo_parent: Path) -> None:
    if not target.exists():
        return
    if not is_inside(target, repo_parent) or "server-progress-alpha" not in target.as_posix().lower():
        raise RuntimeError(f"Refusing to delete non-alpha server directory: {target}")
    shutil.rmtree(target)


def patch_alpha_enabler(entries: dict[str, bytes]) -> None:
    path = "lua/ge/extensions/careerMPEnabler.lua"
    text = entries[path].decode("utf-8").replace("\r\n", "\n")
    if "serverProgressEnabled" in text and "startCareerWithSaveName" in text:
        entries[path] = text.encode("utf-8")
        return

    helpers = (
        "local function buildCareerSaveName()\n"
        "\tlocal saveNickname = nickname\n"
        "\tif clientConfig and clientConfig.serverSaveNameEnabled then\n"
        "\t\tsaveNickname = clientConfig.serverSaveName\n"
        "\tend\n"
        "\treturn tostring(saveNickname or MPConfig.getNickname()) .. tostring(clientConfig and clientConfig.serverSaveSuffix or \"\")\n"
        "end\n"
        "\n"
        "local function ensureProgressClientLoaded()\n"
        "\tlocal progressClient = extensions and extensions.careerMPProgressClient or careerMPProgressClient\n"
        "\tif not progressClient and extensions and extensions.load then\n"
        "\t\tpcall(extensions.load, \"careerMPProgressClient\")\n"
        "\t\tprogressClient = extensions.careerMPProgressClient or careerMPProgressClient\n"
        "\tend\n"
        "\treturn progressClient\n"
        "end\n"
        "\n"
        "local function showProgressAuthLoadError()\n"
        "\tif guihooks and guihooks.trigger then\n"
        "\t\tguihooks.trigger(\"toastrMsg\", {\n"
        "\t\t\ttype = \"error\",\n"
        "\t\t\ttitle = \"Online Progress\",\n"
        "\t\t\tmsg = \"Server progress login is enabled, but the auth client did not load.\",\n"
        "\t\t\tconfig = { timeOut = 6000 }\n"
        "\t\t})\n"
        "\tend\n"
        "end\n"
        "\n"
        "local function startCareerWithSaveName(saveName)\n"
        "\tif careerMPActive then\n"
        "\t\treturn\n"
        "\tend\n"
        "\tlocal currentLevel = getCurrentLevelIdentifier and getCurrentLevelIdentifier() or nil\n"
        "\tcareer_career.createOrLoadCareerAndStart(tostring(saveName or buildCareerSaveName()), false, false, nil, nil, nil, currentLevel)\n"
        "\tcareerMPActive = true\n"
        "end\n"
        "\n"
    )

    text = replace_required(
        text,
        "local function rxCareerSync(data)\n",
        helpers + "local function rxCareerSync(data)\n",
        path,
        "server progress helper injection",
    )
    text = replace_required(
        text,
        "\tif not careerMPActive then\n"
        "\t\tif clientConfig.serverSaveNameEnabled then\n"
        "\t\t\tnickname = clientConfig.serverSaveName\n"
        "\t\tend\n"
        "\t\tlocal currentLevel = getCurrentLevelIdentifier and getCurrentLevelIdentifier() or nil\n"
        "\t\tcareer_career.createOrLoadCareerAndStart(nickname .. clientConfig.serverSaveSuffix, false, false, nil, nil, nil, currentLevel)\n"
        "\t\tcareerMPActive = true\n"
        "\tend\n",
        "\tif not careerMPActive then\n"
        "\t\tlocal targetSaveName = buildCareerSaveName()\n"
        "\t\tif clientConfig.serverProgressEnabled == true then\n"
        "\t\t\tlocal progressClient = ensureProgressClientLoaded()\n"
        "\t\t\tif progressClient and progressClient.requestLogin then\n"
        "\t\t\t\tprogressClient.requestLogin(clientConfig, targetSaveName)\n"
        "\t\t\t\treturn\n"
        "\t\t\tend\n"
        "\t\t\tshowProgressAuthLoadError()\n"
        "\t\t\treturn\n"
        "\t\tend\n"
        "\t\tstartCareerWithSaveName(targetSaveName)\n"
        "\tend\n",
        path,
        "server progress gated career start",
    )
    text = replace_required(
        text,
        "\tif extensions.disableSerialization then\n"
        "\t\textensions.disableSerialization(\"career_career\")\n"
        "\tend\n",
        "\tif extensions.disableSerialization then\n"
        "\t\textensions.disableSerialization(\"career_career\")\n"
        "\tend\n"
        "\tensureProgressClientLoaded()\n",
        path,
        "server progress client pre-load",
    )
    text = replace_required(
        text,
        "\tsetGameplaySettings(userGameplaySettings)\n"
        "end\n",
        "\tsetGameplaySettings(userGameplaySettings)\n"
        "\tclientConfig = nil\n"
        "\tcareerMPActive = false\n"
        "\tsyncRequested = false\n"
        "\ttrafficRuntimeTimer = 0\n"
        "\tremoteGhostRefreshTimer = 0\n"
        "end\n",
        path,
        "server progress leave reset",
    )
    text = replace_required(
        text,
        "M.getClientConfig = getClientConfig\n",
        "M.getClientConfig = getClientConfig\n"
        "M.startCareerWithSaveName = startCareerWithSaveName\n",
        path,
        "server progress public career start",
    )
    entries[path] = text.encode("utf-8")


def patch_alpha_ui_apps(entries: dict[str, bytes]) -> None:
    path = "lua/ge/extensions/careerMPUIApps.lua"
    text = entries[path].decode("utf-8").replace("\r\n", "\n")
    if "careermpprogressauth" not in text:
        text = replace_required(
            text,
            "\t}\n}\n\nlocal function findApp(layout, name)\n",
            "\t},\n"
            "\tcareermpprogressauth = {\n"
            "\t\tappName = \"careermpprogressauth\",\n"
            "\t\tplacement = {\n"
            "\t\t\twidth = \"380px\",\n"
            "\t\t\theight = \"315px\",\n"
            "\t\t\ttop = \"90px\",\n"
            "\t\t\tleft = \"calc(50% - 190px)\",\n"
            "\t\t\tposition = \"absolute\"\n"
            "\t\t}\n"
            "\t}\n"
            "}\n\nlocal function findApp(layout, name)\n",
            path,
            "server progress auth app registration",
        )
        text = replace_required(
            text,
            "\tupdated = checkApp(layout, multiplayerApps.careermpplayerlist) or updated\n",
            "\tupdated = checkApp(layout, multiplayerApps.careermpplayerlist) or updated\n"
            "\tupdated = checkApp(layout, multiplayerApps.careermpprogressauth) or updated\n",
            path,
            "server progress auth app layout injection",
        )
    entries[path] = text.encode("utf-8")


def patch_alpha_markers(entries: dict[str, bytes]) -> None:
    for path in (
        "ui/modules/apps/CareerMP-PlayerList/app.html",
        "rls_careermp_patch_version.txt",
    ):
        data = entries.get(path)
        if not data:
            continue
        text = data.decode("utf-8").replace(PATCH_VERSION, ALPHA_VERSION)
        entries[path] = text.encode("utf-8")
    entries["rls_careermp_server_progress_alpha.txt"] = (
        f"RLS CareerMP Server Progress Alpha {ALPHA_VERSION}\n"
        "This build gates career startup behind a server-side login/session.\n"
        "It stores alpha progress snapshots in the BeamMP server resource data folder.\n"
    ).encode("utf-8")


def build_careermp_alpha(base_zip: Path, alpha_patch_dir: Path, output_zip: Path) -> tuple[int, str]:
    entries = read_zip_entries(base_zip)
    remove_entry_prefixes(entries, CAREERMP_REMOVE_PREFIXES)
    overlay_directory(entries, alpha_patch_dir.parent.parent / "CareerMP")
    patch_careermp_entries(entries)
    overlay_directory(entries, alpha_patch_dir)
    patch_alpha_enabler(entries)
    patch_alpha_ui_apps(entries)
    patch_alpha_markers(entries)
    write_zip(output_zip, entries)
    return output_zip.stat().st_size, sha256sum(output_zip)


def build_rls_alpha(base_zip: Path, rls_patch_dir: Path, output_zip: Path) -> tuple[int, str]:
    entries = read_zip_entries(base_zip)
    remove_entry_prefixes(entries, RLS_REMOVE_PREFIXES)
    overlay_directory(entries, rls_patch_dir)
    patch_rls_entries(entries, output_zip.name)
    entries["rls_server_progress_alpha_note.txt"] = (
        f"Built for server progress alpha {ALPHA_VERSION}.\n"
        "The server-controlled progress gate lives in CareerMP_server_progress_alpha.zip.\n"
    ).encode("utf-8")
    write_zip(output_zip, entries)
    return output_zip.stat().st_size, sha256sum(output_zip)


def patch_server_config_toml(config_path: Path, port: int) -> None:
    text = config_path.read_text(encoding="utf-8")
    replacements = {
        r"(?m)^Port\s*=.*$": f"Port = {port}",
        r"(?m)^Name\s*=.*$": 'Name = "RLS CareerMP Server Progress Alpha"',
        r"(?m)^Map\s*=.*$": 'Map = "/levels/west_coast_usa/info.json"',
        r"(?m)^Description\s*=.*$": 'Description = "Server-controlled progress alpha test"',
    }
    for pattern, replacement in replacements.items():
        text = re.sub(pattern, replacement, text)
    config_path.write_text(text, encoding="utf-8")


def patch_careermp_server_config(config_path: Path) -> None:
    data = json.loads(config_path.read_text(encoding="utf-8-sig"))
    client = data.setdefault("client", {})
    client.update(
        {
            "serverProgressEnabled": True,
            "serverProgressMode": "localJson",
            "serverProgressServerId": "server-progress-alpha",
            "serverProgressAllowRegistration": True,
            "serverProgressRequireLogin": True,
            "serverProgressUploadIntervalSeconds": 60,
            "serverProgressSaveNamePrefix": "RLSOnline",
            "serverProgressMaxSnapshotBytes": 180000,
            "serverSaveNameEnabled": True,
            "serverSaveName": "server-progress-alpha",
            "serverSaveSuffix": "",
        }
    )
    server = data.setdefault("server", {})
    server["autoUpdate"] = False
    config_path.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")


def patch_progress_auth_config(config_path: Path) -> None:
    data = json.loads(config_path.read_text(encoding="utf-8-sig"))
    data.update(
        {
            "enabled": True,
            "mode": "localJson",
            "serverId": "server-progress-alpha",
            "allowRegistration": True,
            "requireLogin": True,
            "saveNamePrefix": "RLSOnline",
            "uploadIntervalSeconds": 60,
            "maxSnapshotBytes": 180000,
        }
    )
    config_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def write_client_mods_json(client_dir: Path) -> None:
    mods = {}
    for zip_path in sorted(client_dir.glob("*.zip")):
        mods[zip_path.name] = {
            "filesize": zip_path.stat().st_size,
            "hash": sha256sum(zip_path),
            "lastwrite": filetime_from_stat(zip_path),
            "protected": False,
        }
    (client_dir / "mods.json").write_text(json.dumps(mods, indent=4) + "\n", encoding="utf-8")


def copy_server_template(
    server_template: Path,
    server_dir: Path,
    careermp_zip: Path,
    rls_zip: Path,
    server_resource_dir: Path,
    port: int,
    repo_parent: Path,
) -> None:
    safe_replace_tree(server_dir, repo_parent)
    shutil.copytree(
        server_template,
        server_dir,
        ignore=shutil.ignore_patterns("Server.log", "Server.old.log", "*.log", "Cache", "data"),
    )

    client_dir = server_dir / "Resources" / "Client"
    client_dir.mkdir(parents=True, exist_ok=True)
    for zip_path in list(client_dir.glob("*.zip")):
        lower = zip_path.name.lower()
        if lower == "careermp.zip" or lower.startswith("rls_career_overhaul_"):
            zip_path.unlink()

    shutil.copy2(careermp_zip, client_dir / "CareerMP.zip")
    shutil.copy2(rls_zip, client_dir / rls_zip.name)
    write_client_mods_json(client_dir)

    target_resource = server_dir / "Resources" / "Server" / "CareerMPProgressAuth"
    if target_resource.exists():
        shutil.rmtree(target_resource)
    shutil.copytree(server_resource_dir, target_resource)

    patch_careermp_server_config(server_dir / "Resources" / "Server" / "CareerMP" / "config" / "config.json")
    patch_progress_auth_config(target_resource / "config" / "config.json")
    patch_server_config_toml(server_dir / "ServerConfig.toml", port)


def zip_directory(source_dir: Path, output_zip: Path) -> tuple[int, str]:
    if output_zip.exists():
        output_zip.unlink()
    output_zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for file_path in sorted(source_dir.rglob("*")):
            if file_path.is_dir():
                continue
            rel = file_path.relative_to(source_dir).as_posix()
            if rel.startswith("Resources/Server/CareerMPProgressAuth/data/"):
                continue
            if rel.lower().endswith(".log"):
                continue
            zf.write(file_path, rel)
    return output_zip.stat().st_size, sha256sum(output_zip)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    workspace_root = repo_root.parent

    parser = argparse.ArgumentParser(description="Build the server-controlled progress alpha artifacts.")
    parser.add_argument("--rls-original", required=True, type=Path, help="Path to the original RLS zip")
    parser.add_argument("--careermp-original", required=True, type=Path, help="Path to the original CareerMP.zip")
    parser.add_argument("--out-dir", type=Path, default=repo_root / "built-server-progress-alpha")
    parser.add_argument("--server-template", type=Path, default=workspace_root / "servers" / "main" / "onlinecareer-west-coast-complete")
    parser.add_argument("--server-dir", type=Path, default=workspace_root / "servers" / "tests" / "server-progress-alpha")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()

    rls_original = args.rls_original.expanduser().resolve()
    careermp_original = args.careermp_original.expanduser().resolve()
    out_dir = args.out_dir.expanduser().resolve()
    server_template = args.server_template.expanduser().resolve()
    server_dir = args.server_dir.expanduser().resolve()

    for required in (rls_original, careermp_original):
        if not required.is_file():
            raise SystemExit(f"Required original zip not found: {required}")
    if not server_template.is_dir():
        raise SystemExit(f"Server template not found: {server_template}")

    out_dir.mkdir(parents=True, exist_ok=True)

    careermp_out = out_dir / "CareerMP_server_progress_alpha.zip"
    rls_out = out_dir / "rls_career_overhaul_2.6.5.1_server_progress_alpha.zip"
    ready_to_use_out = out_dir / "ready-to-use-server-progress-alpha.zip"

    careermp_size, careermp_hash = build_careermp_alpha(
        careermp_original,
        repo_root / "patches" / "ServerProgressAlpha" / "CareerMP",
        careermp_out,
    )
    rls_size, rls_hash = build_rls_alpha(
        rls_original,
        repo_root / "patches" / "RLS",
        rls_out,
    )

    copy_server_template(
        server_template,
        server_dir,
        careermp_out,
        rls_out,
        repo_root / "server_resources" / "CareerMPProgressAuth",
        args.port,
        workspace_root,
    )
    ready_size, ready_hash = zip_directory(server_dir, ready_to_use_out)

    checksums = out_dir / "checksums-server-progress-alpha.txt"
    checksums.write_text(
        "\n".join(
            [
                f"{careermp_hash}  {careermp_out.name}",
                f"{rls_hash}  {rls_out.name}",
                f"{ready_hash}  {ready_to_use_out.name}",
                "",
                f"{careermp_out.name} size={careermp_size}",
                f"{rls_out.name} size={rls_size}",
                f"{ready_to_use_out.name} size={ready_size}",
                f"version={ALPHA_VERSION}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Built: {careermp_out}")
    print(f"Built: {rls_out}")
    print(f"Built: {ready_to_use_out}")
    print(f"Prepared server: {server_dir}")
    print(f"Wrote: {checksums}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
