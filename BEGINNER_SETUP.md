# Beginner Setup Guide

If you are new to this project, start here.

## The Most Important Thing

Most users do **not** need Python.

You only need Python if **you are the person generating the compatible zip files** from the original mods.

If a server owner, friend, or Discord post already gave you these finished files:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

then you can skip the Python part completely.

## Option A: I Just Want To Play

If someone already gave you the finished compatible files:

1. Install:
- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

2. Do **not** also install:
- `rls_career_overhaul_2.6.5.1.zip`
- `RLS_2.6.4_MPv3.8.zip`

3. Launch BeamNG / BeamMP and join the server.

That is it.

No Python is needed for this.

## Option B: I Want To Host A Server

For a normal West Coast setup, the server should use:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`

Use only the compatible RLS zip, not the original RLS zip.

If you want traffic fully disabled on your server:

- replace **both** generated files, not just `CareerMP.zip`
- set `roadTrafficEnabled` to `false`
- set `parkedTrafficEnabled` to `false`
- set `roadTrafficAmount` to `0`
- set `parkedTrafficAmount` to `0`
- set `autoUpdate` to `false` in the CareerMP server config so the patched files do not get overwritten later

## Option C: I Need To Build The Files Myself

You only need this section if you do **not** already have the finished compatible zips.

You will need:

- the original `rls_career_overhaul_2.6.5.1.zip`
- the original `CareerMP.zip`
- Python installed on Windows

Then run:

```powershell
python .\scripts\build_release.py --rls-original "C:\path\to\rls_career_overhaul_2.6.5.1.zip" --careermp-original "C:\path\to\CareerMP.zip" --out-dir ".\built"
```

If `python` does not work, try:

```powershell
py .\scripts\build_release.py --rls-original "C:\path\to\rls_career_overhaul_2.6.5.1.zip" --careermp-original "C:\path\to\CareerMP.zip" --out-dir ".\built"
```

The script will create:

- `built\rls_career_overhaul_2.6.5.1_careermp_compatible.zip`
- `built\CareerMP.zip`

## Add-on Maps

RLS add-on maps usually work by stacking the add-on map zip on top of the base compatible RLS setup.

That means:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`
- the RLS add-on map zip you want to use

Example:

- `rls_career_overhaul_italy_2.1.zip`

River Highway is a special case and needs its own extra compatibility delta.

## River Highway

River Highway is **not** the simple setup.

It needs:

- `CareerMP.zip`
- `CareerMPBanking.zip`
- `rls_career_overhaul_2.6.5.1_careermp_compatible.zip`
- `River_Highway_Rework_PHI.zip`
- `rls_career_overhaul_river_highway_beta_0.0.5_careermp_delta.zip`

The River delta is builder-only and is covered in the main README.

## Prop Cargo: How It Works

`Prop Cargo` is not turned in the same way as normal parcel cards.

Basic flow:

1. Start a `Prop Cargo` delivery from the cargo screen.
2. Physical props will spawn at the pickup area.
3. Move those props to the destination.
4. When the prop reaches the destination area, get back into a vehicle and move away a little.
5. The drop-off should then confirm automatically.

Important:

- if the prop reaches the destination but you stay standing next to it, the turn-in may not confirm yet
- the system expects the prop to arrive, then the player to be back in a vehicle and clear the drop-off area

## Common Beginner Mistakes

- Installing the original RLS zip together with the compatible RLS zip.
- Thinking Python is required even when the finished compatible files are already provided.
- Using old `2.6.4` multiplayer RLS files together with the new compatible build.
- Forgetting `CareerMPBanking.zip`.
- For River Highway, installing the original old River RLS beta together with the generated River delta.

## If Something Still Does Not Work

Check these first:

- Are you using the generated compatible RLS zip, not the original one?
- Did you also install `CareerMPBanking.zip`?
- If using an add-on map, did you keep the base compatible RLS zip installed too?
- If using River Highway, are you using the PHI map and the generated River delta, not the original old River beta by itself?
- If traffic is supposed to be off, did you replace both generated zips and not only `CareerMP.zip`?
- If traffic is still wrong on a server, is `autoUpdate` turned off in the CareerMP server config?

If you are still stuck, send:

- a screenshot of your mod list
- the map name you are trying to use
- whether you are using ready-made files or building with Python
- the exact error message
