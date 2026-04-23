# RLS CareerMP Compatibility Patch

Compatibility patch for running `RLS Career Overhaul 2.6.5.1` together with `CareerMP` in BeamNG.drive multiplayer career sessions.

This repository **does not redistribute the full RLS mod**. It only contains the modified files, plus a build script that overlays those files onto the original mod archives to generate the final server/client zips.

## Goal

Adapt RLS `2.6.5.1` for the online career flow used by `BeamMP + CareerMP`, while preserving the RLS overhaul features and removing the parts that break multiplayer loading.

## Base Versions

- `rls_career_overhaul_2.6.5.1.zip`
- `CareerMP.zip`
- `CareerMPBanking.zip`
- BeamNG.drive `0.38.5`
- BeamMP `3.9.x`

## What This Patch Changes

- Keeps `BeamMP` active when RLS starts.
- Restores the `prop cargo` system in RLS `2.6.5.1`.
- Makes the `career_careerMP` entrypoint reuse the RLS-overhauled career implementation.
- Adds compatibility between the RLS computer menu hook and the hook used by `CareerMP`.
- Fixes the `CareerMP.zip` packaging flow so `modScript.lua` loads correctly in BeamNG.
- Adds a defensive computer tether cleanup to avoid closing tuning, painting, or part-shopping screens when switching into the vehicle.
- Removes the old RLS minimap app override from release builds so the vanilla/CareerMP minimap can load without `ui_apps_minimap_minimap` crashes.
- Applies CareerMP server traffic settings on the client, including disabling road and parked AI traffic when the server config has them turned off.

## Changed Files

### RLS

- `lua/ge/extensions/overhaul/extensionManager.lua`
- `lua/ge/extensions/career/modules/delivery/propCargo.lua`
- `lua/ge/extensions/overrides/career/careerMP.lua`
- `lua/ge/extensions/overrides/career/modules/computer.lua`
- `lua/ge/extensions/overrides/career/modules/delivery/cargoCards.lua`
- `lua/ge/extensions/overrides/career/modules/delivery/cargoScreen.lua`
- `mod_info/RLSCO24/info.json`

### CareerMP

- `lua/ge/extensions/careerMPEnabler.lua`

## Build The Release Zips

1. Make sure you have the original RLS and CareerMP zip files.
2. Run:

```bash
python scripts/build_release.py --rls-original "C:\\path\\to\\rls_career_overhaul_2.6.5.1.zip" --careermp-original "C:\\path\\to\\CareerMP.zip" --out-dir ".\\built"
```

3. The script generates:

- `built/rls_career_overhaul_2.6.5.1_careermp_compatible.zip`
- `built/CareerMP.zip`
- `built/checksums.txt`

## Beginner Windows Build Guide

Use this section if you are not used to Python or command line tools.

### 1. Install Python

- Install Python 3 from https://www.python.org/downloads/
- During installation, enable **Add python.exe to PATH**.
- After installing, open PowerShell and run:

```powershell
python --version
```

- If that does not work, try:

```powershell
py --version
```

### 2. Download this patch

- Download this repository as a zip from GitHub.
- Extract it somewhere easy, for example:

```text
C:\RLS-CareerMP-Patch
```

### 3. Put the original mods somewhere easy

You need the original files:

- `rls_career_overhaul_2.6.5.1.zip`
- `CareerMP.zip`

Example:

```text
C:\BeamNG-Mod-Build\rls_career_overhaul_2.6.5.1.zip
C:\BeamNG-Mod-Build\CareerMP.zip
```

### 4. Open PowerShell in the patch folder

In PowerShell, go to the extracted patch folder:

```powershell
cd "C:\RLS-CareerMP-Patch"
```

### 5. Build the compatible zips

Run this command, changing the paths if your files are somewhere else:

```powershell
python .\scripts\build_release.py --rls-original "C:\BeamNG-Mod-Build\rls_career_overhaul_2.6.5.1.zip" --careermp-original "C:\BeamNG-Mod-Build\CareerMP.zip" --out-dir ".\built"
```

If your computer uses the Python launcher instead of `python`, run:

```powershell
py .\scripts\build_release.py --rls-original "C:\BeamNG-Mod-Build\rls_career_overhaul_2.6.5.1.zip" --careermp-original "C:\BeamNG-Mod-Build\CareerMP.zip" --out-dir ".\built"
```

### 6. Use the generated files

After the script finishes, open the `built` folder. These are the files you should use:

- `built\rls_career_overhaul_2.6.5.1_careermp_compatible.zip`
- `built\CareerMP.zip`

Use those generated files on the server/client setup together with `CareerMPBanking.zip`.

Do **not** also install the original `rls_career_overhaul_2.6.5.1.zip`, because it will conflict with the compatible RLS zip.

### Common Build Problems

- `python is not recognized`: reinstall Python and enable **Add python.exe to PATH**, or use the `py` command instead.
- `RLS original zip not found`: check that the path after `--rls-original` points to the real original RLS zip.
- `CareerMP original zip not found`: check that the path after `--careermp-original` points to the real original CareerMP zip.
- The game still has the minimap crash: make sure you replaced the old generated RLS zip with the new one from `built`.
- AI traffic still appears when disabled: make sure you replaced the old generated `CareerMP.zip` with the new one from `built`.

## Server Setup

Distribute these mods:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

When updating from `v1.0.0-beta.1` or an older build, replace **both** generated files:

- Replace `rls_career_overhaul_2.6.5.1_careermp_compatible.zip` to fix the minimap crash on rejoin.
- Replace `CareerMP.zip` to enforce the server-side AI traffic settings on clients.

Do not distribute these at the same time:

- `RLS_2.6.4_MPv3.8.zip`
- `rls_career_overhaul_2.6.5.1.zip`

## Troubleshooting

- `ui_apps_minimap_minimap` fatal Lua error on rejoin: rebuild or download the latest compatible RLS zip. The old RLS minimap override must not be present in the final archive under `lua/ge/extensions/overrides/ui/apps/minimap/`.
- AI traffic appears even though CareerMP config disables it: make sure the updated generated `CareerMP.zip` is installed. The traffic config fix is in `lua/ge/extensions/careerMPEnabler.lua`, not in the RLS zip.

## Notes

- This patch is intended for online career sessions, not standalone single-player use.
- The computer/workshop fix is included, but the full tuning, painting, and part-shopping flow should still be validated in a live multiplayer session before calling the release fully stable.
- Because the original RLS mod is third-party content, the recommended distribution format is **patch + build script**, not the complete repacked RLS archive.
