# Discord Post

## Title

RLS Career Overhaul 2.6.5.1 CareerMP Compatibility Patch

## Message

The first beta release of the **RLS Career Overhaul 2.6.5.1 CareerMP Compatibility Patch** is available.

This patch is focused on making the newer RLS `2.6.5.1` build work in **online career mode** with `BeamMP + CareerMP`, without relying on the older `RLS_2.6.4_MPv3.8` package.

### What changed

- Added compatibility with the `career_careerMP` entrypoint.
- Prevented RLS from disabling `BeamMP` on startup.
- Restored the `prop cargo` system.
- Added prop cargo support to the cargo UI.
- Added compatibility between the RLS computer menu and `CareerMP`.
- Fixed the `CareerMP.zip` packaging flow so `modScript.lua` loads correctly.

### Required mods

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

### Do not use together

- `RLS_2.6.4_MPv3.8.zip`
- `rls_career_overhaul_2.6.5.1.zip`

### Download / repository

`<PASTE_GITHUB_LINK_HERE>`

### Note

The repository distributes the compatibility patch and build script. It does not redistribute the full original RLS mod archive.
