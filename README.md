# nssm-service-kit

Run a Python app as **Windows services** with [NSSM](https://nssm.cc), described
by one JSON file. Two PowerShell scripts that fail loudly instead of silently.

Extracted from the production deploy of a Telegram bot + API + streaming gateway
that runs on a Windows PC.

## What you get

- `scripts/install-services.ps1`: installs or reinstalls every service in the
  JSON: runs `python <script>` from a working directory, logs to one file that
  rotates **online** at 10 MB, starts automatically, `PYTHONUTF8=1`.
- `scripts/manage-services.ps1`: `status | start | stop | restart` for a list of
  services or for everything named `prefix-*`.
- `-DryRun` on the installer to see what it would do without admin rights.

## Why "fail loudly"

Without administrator rights, `Restart-Service -ErrorAction SilentlyContinue`
does nothing: the script looks successful while the service keeps running the
OLD code. Both scripts check for elevation first and report every failure with
a non-zero exit code.

## Use

```powershell
# 1. describe your services (copy services.example.json)
# 2. in an elevated PowerShell:
.\scripts\install-services.ps1 -Config .\services.json
.\scripts\manage-services.ps1 -Action restart -Prefix myapp
.\scripts\manage-services.ps1 -Action status  -Prefix myapp
```

`services.json`:

```json
{
  "prefix": "myapp",
  "python": "C:\\myapp\\.venv\\Scripts\\python.exe",
  "logsDir": "C:\\myapp\\logs",
  "services": [
    { "name": "bot", "script": "C:\\myapp\\svc\\svc_bot.py", "description": "MyApp bot" }
  ]
}
```

Services are named `<prefix>-<name>`. Two copies of an app on the same machine
(say, two editions) just use different prefixes, and installing one never
touches the other.

## Operational lessons baked in

- Never truncate a log file a running service holds open: use `nssm rotate <service>`
  (the installer already enables online rotation).
- Restarting a service that is in the middle of a long upload or job cuts it off:
  if you use a job queue with leases, the job comes back after the lease expires.
- Services running as LocalSystem share the same `%TEMP%`: give each copy its own
  file names for sessions and locks.

## Tests

```bash
pip install pytest && pytest      # needs PowerShell (pwsh or powershell); skips otherwise
```

## License

MIT
