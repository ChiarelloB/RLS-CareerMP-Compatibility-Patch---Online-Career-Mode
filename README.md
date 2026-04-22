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

## Server Setup

Distribute these mods:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

Do not distribute these at the same time:

- `RLS_2.6.4_MPv3.8.zip`
- `rls_career_overhaul_2.6.5.1.zip`

## Notes

- This patch is intended for online career sessions, not standalone single-player use.
- The computer/workshop fix is included, but the full tuning, painting, and part-shopping flow should still be validated in a live multiplayer session before calling the release fully stable.
- Because the original RLS mod is third-party content, the recommended distribution format is **patch + build script**, not the complete repacked RLS archive.
