# Changelog

## v1.0.0-beta.9

### Fixed

- Fixed RLS drag events in online CareerMP sessions where the opponent NPC spawned at Alder Dragway but would not drive into staging or start the race.
- Kept the drag runtime stack warm during world load so drag strip lights, staging logic, timeslips, and drag payout hooks are available before the event starts.
- Prevented the RLS vehicle-side `overrideAI` from being installed on registered drag racer vehicles, preserving the vanilla drag AI command flow used by `ai.setTarget`, `ai.setSpeed`, and launch staging.

### Validated

- Rebuilt both generated zips and validated the generated RLS archive with `zipfile.testzip()`.
- Confirmed the dedicated West Coast multiplayer test server loaded the updated RLS zip and CareerMP zip successfully.
- Manual smoke test passed: the Alder Dragway opponent NPC staged and the drag event started correctly in the online CareerMP session.

## v1.0.0-beta.8

### Fixed

- Added a multiplayer-safe RLS speed/red-light camera override so speed cameras can issue fines again without crashing when traffic data is missing or AI traffic is disabled.
- Hardened CareerMP speed/red-light notifications so nil vehicles, missing model data, or missing traffic signal timers no longer crash the client.
- Kept the RLS drag practice runtime loaded in CareerMP sessions, restoring the dependency used by drag strip lights, dragstrip freeroam events, and tuning shop drag jobs.
- Added a parcel loading timeout fallback so delivery commits do not hang forever if BeamMP does not return the vehicle cargo-container callback.
- Added defensive prop cargo dependency refreshes so prop delivery can recover when the module is loaded before all career delivery modules are ready.
- Forced full remote vehicle rendering in the CareerMP client patch to avoid grey placeholder orbs for players, walking beamlings/unicycles, and parked vehicles on late join.
- Reduced remote ghost refresh spam and explicitly syncs the walking unicycle inactive when a player enters a vehicle, helping prevent the beamling from staying behind.

### Validated

- Rebuilt both generated zips and validated the final archives with `zipfile.testzip()`.
- Confirmed the generated RLS zip includes the new safe `speedTraps.lua`, no longer unloads `gameplay_drag_dragTypes_dragPracticeRace`, still removes the legacy minimap override, and includes the cargo fallback changes.
- Confirmed the generated CareerMP zip includes the safe camera notification path, forced full remote rendering, and still removes the old `careermp.uilayout.json` preset.

## v1.0.0-beta.7

### Fixed

- Added an RLS `overrides/career/modules/tuning.lua` compatibility override so multiplayer tuning no longer crashes on `getObjectByID(nil)` after applying changes.
- Reacquired the tuned vehicle after respawn instead of continuing to use stale pre-respawn vehicle references during the tuning apply flow.
- Added multiplayer-safe tuning UI exit handling so backing out of the tuning screen no longer leaves players stuck inside a frozen vehicle.
- Reset tuning session state on close and after save completion so repeated tuning sessions can confirm purchases reliably instead of inheriting stale shopping state.

### Validated

- Validated the West Coast multiplayer tuning flow on the dedicated all-fixes test server: first tuning apply, confirm purchase, reopen tuning, and repeat tuning purchase all completed successfully in the final tested build.

## v1.0.0-beta.6

### Fixed

- Consolidated this compatibility update so the generated patch set now covers both the multiplayer traffic-disable regression and the workshop respawn/recovery/taxi regression in one release step.
- Patched the RLS `overrides/career/modules/playerDriving.lua` traffic setup path so CareerMP servers with `roadTrafficEnabled=false` and `parkedTrafficEnabled=false` no longer get forced fallback spawns.
- Fixed the RLS career traffic bootstrap interpreting `trafficAmount = 0` and `trafficParkedAmount = 0` as auto-spawn values during multiplayer startup.
- Disabled the extra default police traffic pool when the CareerMP server traffic config turns road traffic off, preventing the common `2 traffic + 2 parked` fallback case.
- Added inventory and workshop compatibility guards so a tuned vehicle no longer gets treated as AI traffic after respawn and stale vehicle references no longer break recovery or taxi actions.

### Validated

- Rebuilt both generated release zips and started a dedicated West Coast no-traffic test server with `roadTrafficEnabled=false`, `roadTrafficAmount=0`, `parkedTrafficEnabled=false`, and `parkedTrafficAmount=0`.
- Validated the workshop flow on a West Coast multiplayer test server: applying a tune, opening recovery with `R`, taking a taxi to a garage, and taking a taxi back to the last vehicle all completed without the previous softlock or `recoverPrompt` crash.

## v1.0.0-beta.5

### Fixed

- Patched both RLS insurance module paths (`career/modules` and `overrides/career/modules`) so multiplayer uses the repaired logic regardless of which path BeamNG loads first.
- Replaced broken multiplayer `Instant` repair handling with a safe `2 sec` repair flow to avoid charging players without actually repairing the vehicle.
- Fixed the repair screen so the displayed repair time matches the backend repair value in multiplayer sessions.
- Fixed the garage repair callback so repaired vehicles return to the garage flow correctly instead of leaving players inside the damaged vehicle.
- Fixed delayed repair handoff to use the current inventory vehicle reference instead of the stale pre-repair vehicle reference.

### Validated

- West Coast multiplayer repair flow now completes successfully: payment, repair, and garage return all worked in the validated test build.

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
