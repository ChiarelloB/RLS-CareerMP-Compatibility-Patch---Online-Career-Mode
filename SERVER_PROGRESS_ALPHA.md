# Server-Controlled Progress Alpha

This is an experimental alpha workflow for servers that want player progress to be controlled by the BeamMP server instead of allowing players to reuse or edit their normal single-player save.

Version: `v1.1.0-auth-alpha.1`

## What It Does

- Requires a username/password before CareerMP starts the RLS career save.
- Creates a separate online save name per account, for example `RLSOnline_server-progress-alpha_acct_...`.
- Stores progress snapshots on the BeamMP server as JSON files.
- Rejects stale uploads when the client revision does not match the server revision.
- Keeps the storage code behind a small provider layer so a real backend can replace local JSON later.

## Important Alpha Limits

- This is not full anti-cheat yet.
- Passwords are salted/hashed, but the alpha hash is intentionally simple because BeamMP server Lua has limited standard crypto tools.
- Money, garage, tuning, repair, delivery, fines, banking, marketplace, and insurance are still mostly client-driven in this alpha.
- A modified client can still cheat until phase 2 moves critical transactions to server-authoritative validation.
- The current goal is to block casual single-player-save abuse and prove the login/save flow with the community.

## Build Command

Run this from the repository folder:

```powershell
python .\scripts\build_server_progress_alpha.py --rls-original "C:\BeamNG-Mod-Build\rls_career_overhaul_2.6.5.1.zip" --careermp-original "C:\BeamNG-Mod-Build\CareerMP.zip" --server-template "C:\Users\bruni\Documents\PROJETOS\Jogos\BEANG\servers\main\onlinecareer-west-coast-complete" --server-dir "C:\Users\bruni\Documents\PROJETOS\Jogos\BEANG\servers\tests\server-progress-alpha" --out-dir ".\built-server-progress-alpha"
```

If `python` does not work, use `py`:

```powershell
py .\scripts\build_server_progress_alpha.py --rls-original "C:\BeamNG-Mod-Build\rls_career_overhaul_2.6.5.1.zip" --careermp-original "C:\BeamNG-Mod-Build\CareerMP.zip" --server-template "C:\Users\bruni\Documents\PROJETOS\Jogos\BEANG\servers\main\onlinecareer-west-coast-complete" --server-dir "C:\Users\bruni\Documents\PROJETOS\Jogos\BEANG\servers\tests\server-progress-alpha" --out-dir ".\built-server-progress-alpha"
```

## Generated Files

- `built-server-progress-alpha\CareerMP_server_progress_alpha.zip`
- `built-server-progress-alpha\rls_career_overhaul_2.6.5.1_server_progress_alpha.zip`
- `built-server-progress-alpha\ready-to-use-server-progress-alpha.zip`
- `built-server-progress-alpha\checksums-server-progress-alpha.txt`
- `servers\tests\server-progress-alpha`

Inside the ready-to-use server, the generated client file is still named `Resources\Client\CareerMP.zip` because BeamMP clients expect the server mod filename. The alpha marker is inside the zip.

## Server Data

The server writes alpha data here after it starts:

```text
Resources\Server\CareerMPProgressAuth\data\
```

Expected files:

- `accounts.json`
- `saves\<accountId>.json`

Do not commit the generated `data` folder.

The builder uses port `30848` by default for the isolated local test server. Use `--port <number>` if that port is already taken.

## Server Config

CareerMP client config receives these alpha keys:

```json
{
  "serverProgressEnabled": true,
  "serverProgressMode": "localJson",
  "serverProgressServerId": "server-progress-alpha",
  "serverProgressAllowRegistration": true,
  "serverProgressRequireLogin": true,
  "serverProgressUploadIntervalSeconds": 60,
  "serverProgressSaveNamePrefix": "RLSOnline",
  "serverProgressMaxSnapshotBytes": 180000
}
```

The auth resource also has its own config:

```text
Resources\Server\CareerMPProgressAuth\config\config.json
```

## Admin Commands

Run these in the BeamMP server console:

```text
ProgressAuth list
ProgressAuth reset <username>
ProgressAuth setpassword <username> <newPassword>
```

## Test Checklist

- Start the alpha server.
- Join with a fresh player.
- Confirm the login/register UI appears before CareerMP starts.
- Register a new account.
- Confirm CareerMP starts only after login.
- Earn or spend a small amount, then wait for autosave or force a normal career save.
- Leave and rejoin with the same account.
- Confirm the online save reloads from the server.
- Try the wrong password and confirm CareerMP does not start.
- Start single-player with another save and confirm it does not affect the online account.
- Restart the server and confirm the account/save still exists.

## Troubleshooting

- Login UI never appears: replace the server `CareerMP.zip` with the alpha build and clear BeamMP client cache.
- Career starts without login: check `Resources\Server\CareerMP\config\config.json` and confirm `serverProgressEnabled` is `true`.
- Login succeeds but progress does not persist: check `Resources\Server\CareerMPProgressAuth\data\` for account/save JSON files.
- Stale revision rejected: rejoin the server so the client reloads the latest server snapshot.
- Never install this alpha over the stable server unless you intentionally want to test server-controlled saves.
