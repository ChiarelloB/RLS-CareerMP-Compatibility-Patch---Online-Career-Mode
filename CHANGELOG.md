# Changelog

## v1.0.0-beta.4

### Fixed

- CareerMP now passes the active multiplayer level into the RLS career startup call, preventing River Highway sessions from falling back to `west_coast_usa`.
- The generated `CareerMP.zip` now removes the legacy `careermp.uilayout.json` preset to avoid `ui/apps.lua` nil layout crashes on BeamNG 0.34.

### Validated

- River Highway multiplayer smoke test passed for loading, minimap, rejoin, map integrity, and garage/computer interaction.

## v1.0.0-beta.3

### Added

- Added a builder-only River Highway compatibility workflow.
- Added `build_river_highway_delta.py` to generate the River delta zip from user-provided original archives.
- Added a River manifest and small overlay package for daylight startup, career map loading, forest cleanup, texture/material aliases, and floating West Coast object cleanup.
- Added beginner-friendly River Highway build and server setup documentation.

### Changed

- Builders now preserve other files in the output directory instead of deleting the entire `built` folder.

## v1.0.0-beta.2

### Fixed

- Removed the legacy RLS minimap app override during release builds to prevent `ui_apps_minimap_minimap` nil crashes after rejoining.
- Synced CareerMP road and parked traffic settings to BeamNG runtime settings so server-side traffic disable flags are enforced on clients.
- Added a runtime traffic guard that keeps AI traffic and parked traffic disabled when the CareerMP server config turns them off.

### Upgrade Notes

- Servers updating from `v1.0.0-beta.1` must replace both generated release zips: the RLS compatible zip fixes the minimap, and the generated `CareerMP.zip` fixes traffic config enforcement.

## v1.0.0-beta.1

### Added

- Compatibility between the `career_careerMP` entrypoint and the RLS-overhauled career implementation.
- Reintroduced `propCargo.lua` for RLS `2.6.5.1`.
- Prop cargo card flow in `cargoScreen.lua`.
- `propCargo` filter support in `cargoCards.lua`.
- `build_release.py` script for generating the final release zips from the original mod archives.

### Changed

- Updated `extensionManager.lua` so it no longer disables `multiplayerbeammp`.
- Updated `careerMPEnabler.lua` so it also responds to `onComputerMenuOpened`.
- Updated `computer.lua` so the computer tether is cleared when moving into submenus or closing the menu.
- Updated `mod_info/RLSCO24/info.json` to identify the compatible variant.

### Fixed

- RLS only loading through `career_career` and not through `career_careerMP`.
- Missing prop cargo support in the `2.6.5.1` port.
- Incorrect `CareerMP.zip` packaging that prevented `modScript.lua` from loading.
- Hook mismatch between the RLS computer menu and `CareerMP`.

### Pending Final Validation

- Full online tuning, painting, and part-shopping flow after the computer tether cleanup.
