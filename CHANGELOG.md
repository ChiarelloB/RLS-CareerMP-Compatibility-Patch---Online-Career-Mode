# Changelog

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
