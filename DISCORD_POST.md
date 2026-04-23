# Discord Post

## Title

RLS Career Overhaul 2.6.5.1 CareerMP Compatibility Patch v1.0.0-beta.2

## Message

The **v1.0.0-beta.2 hotfix** of the **RLS Career Overhaul 2.6.5.1 CareerMP Compatibility Patch** is available.

This patch is focused on making the newer RLS `2.6.5.1` build work in **online career mode** with `BeamMP + CareerMP`, without relying on the older `RLS_2.6.4_MPv3.8` package.

### What changed

- Fixed the minimap crash on rejoin caused by the old RLS minimap app override.
- Enforced CareerMP road/parked traffic settings on clients so AI traffic stays disabled when the server config disables it.
- Keeps all previous beta fixes: `career_careerMP` compatibility, BeamMP startup compatibility, prop cargo restore, cargo UI support, computer menu compatibility, and corrected `CareerMP.zip` packaging.

### Important update note

If you are updating from `v1.0.0-beta.1`, replace **both** generated zips:

- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip` fixes the minimap crash.
- `CareerMP.zip` fixes AI traffic config enforcement.

### Required mods

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

### Do not use together

- `RLS_2.6.4_MPv3.8.zip`
- `rls_career_overhaul_2.6.5.1.zip`

### Download / repository

https://github.com/ChiarelloB/RLS-CareerMP-Compatibility-Patch---Online-Career-Mode

### Note

The repository distributes the compatibility patch and build script. It does not redistribute the full original RLS mod archive.
