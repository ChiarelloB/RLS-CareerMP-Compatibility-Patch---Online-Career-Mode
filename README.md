# RLS CareerMP Compatibility Patch

Compatibility patch for running `RLS Career Overhaul 2.6.5.1` together with `CareerMP` in BeamNG.drive multiplayer career sessions.

This repository **does not redistribute the full RLS mod**. It only contains the modified files, plus a build script that overlays those files onto the original mod archives to generate the final server/client zips.

## Goal

Adapt RLS `2.6.5.1` for the online career flow used by `BeamMP + CareerMP`, while preserving the RLS overhaul features and removing the parts that break multiplayer loading.

## Base Versions

- `rls_career_overhaul_2.6.5.1.zip`
- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_river_highway_beta_0.0.5.zip`
- `River_Highway_Rework_PHI.zip`
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
- Adds an optional River Highway builder workflow that creates a map delta locally without committing or redistributing large third-party map assets.

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

### River Highway

- `scripts/build_river_highway_delta.py`
- `manifests/river_highway_delta_manifest.json`
- `patches/RiverHighway/overlay`

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

## Optional River Highway Compatibility

River Highway support is builder-only. This repository does **not** include the generated River delta zip and does **not** redistribute the PHI map or RLS River beta assets.

You must provide:

- `rls_career_overhaul_river_highway_beta_0.0.5.zip`
- `River_Highway_Rework_PHI.zip`
- A local BeamNG.drive installation folder, so the builder can read vanilla content archives when creating texture/material aliases.

Run:

```powershell
python .\scripts\build_river_highway_delta.py --rls-river-original "C:\BeamNG-Mod-Build\rls_career_overhaul_river_highway_beta_0.0.5.zip" --river-phi-original "C:\BeamNG-Mod-Build\River_Highway_Rework_PHI.zip" --beamng-root "D:\SteamLibrary\steamapps\common\BeamNG.drive" --out-dir ".\built"
```

If `python` does not work, use:

```powershell
py .\scripts\build_river_highway_delta.py --rls-river-original "C:\BeamNG-Mod-Build\rls_career_overhaul_river_highway_beta_0.0.5.zip" --river-phi-original "C:\BeamNG-Mod-Build\River_Highway_Rework_PHI.zip" --beamng-root "D:\SteamLibrary\steamapps\common\BeamNG.drive" --out-dir ".\built"
```

The script generates:

- `built\rls_career_overhaul_river_highway_beta_0.0.5_careermp_delta.zip`
- `built\river_highway_checksums.txt`

The River builder:

- Forces River Highway daylight startup for online loading.
- Adds the River career map Lua loader.
- Adds missing forest item definitions needed by the PHI River Highway map.
- Cleans problematic forest instance files that caused red/no-texture trees.
- Disables floating West Coast objects that appeared above the River map.
- Adds texture/material fallback aliases without storing binary assets in Git.

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
- `BeamNG root not found`: pass `--beamng-root` with the folder that contains `BeamNG.drive\content`.
- `River Highway PHI original zip not found`: check that `--river-phi-original` points to `River_Highway_Rework_PHI.zip`.
- The game still has the minimap crash: make sure you replaced the old generated RLS zip with the new one from `built`.
- AI traffic still appears when disabled: make sure you replaced the old generated `CareerMP.zip` with the new one from `built`.

## Server Setup

### West Coast / Base CareerMP Setup

Distribute these mods:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

### River Highway Setup

Distribute these mods:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`
- `River_Highway_Rework_PHI.zip`
- `rls_career_overhaul_river_highway_beta_0.0.5_careermp_delta.zip`

Set the server map to:

```text
/levels/river_highway/info.json
```

When updating from `v1.0.0-beta.1` or an older build, replace **both** generated files:

- Replace `rls_career_overhaul_2.6.5.1_careermp_compatible.zip` to fix the minimap crash on rejoin.
- Replace `CareerMP.zip` to enforce the server-side AI traffic settings on clients.
- For River Highway servers, also replace the generated River delta zip.

Do not distribute these at the same time:

- `RLS_2.6.4_MPv3.8.zip`
- `rls_career_overhaul_2.6.5.1.zip`
- `rls_career_overhaul_river_highway_beta_0.0.5.zip`

## Troubleshooting

- `ui_apps_minimap_minimap` fatal Lua error on rejoin: rebuild or download the latest compatible RLS zip. The old RLS minimap override must not be present in the final archive under `lua/ge/extensions/overrides/ui/apps/minimap/`.
- AI traffic appears even though CareerMP config disables it: make sure the updated generated `CareerMP.zip` is installed. The traffic config fix is in `lua/ge/extensions/careerMPEnabler.lua`, not in the RLS zip.
- River Highway has red or missing textures: rebuild the River delta with the correct `rls_career_overhaul_river_highway_beta_0.0.5.zip`, `River_Highway_Rework_PHI.zip`, and `--beamng-root`.
- River Highway has floating city pieces or floating trees: remove the original RLS River beta zip from the server/client mods and use only the generated River delta together with PHI.

## Notes

- This patch is intended for online career sessions, not standalone single-player use.
- The computer/workshop fix is included, but the full tuning, painting, and part-shopping flow should still be validated in a live multiplayer session before calling the release fully stable.
- Because the original RLS mod is third-party content, the recommended distribution format is **patch + build script**, not the complete repacked RLS archive.
