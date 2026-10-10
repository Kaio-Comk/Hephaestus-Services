<#
.SYNOPSIS
  Install (or reinstall) Windows services with NSSM from a JSON description.

.DESCRIPTION
  Each service runs `python <script>` from a working directory, logs to one file
  that rotates online at 10 MB, and starts automatically. Reinstalling is safe:
  an existing service with the same name is stopped and removed first.
  Must run as Administrator (it refuses to run otherwise instead of failing silently).

.EXAMPLE
  .\install-services.ps1 -Config .\services.json
#>
param(
    [Parameter(Mandatory = $true)][string]$Config,
    [string]$Nssm = "C:\Program Files\nssm\nssm.exe",
    [string]$LogsDir,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { throw "Run this script from an elevated (Administrator) PowerShell." }
}

$cfg = Get-Content -Raw -Path $Config | ConvertFrom-Json
if (-not $cfg.python)   { throw "services.json: 'python' is required" }
if (-not $cfg.services) { throw "services.json: 'services' is required" }

$prefix = if ($cfg.prefix) { "$($cfg.prefix)-" } else { "" }
if (-not $LogsDir) { $LogsDir = if ($cfg.logsDir) { $cfg.logsDir } else { Join-Path (Split-Path -Parent $Config) "logs" } }

if ($DryRun) {
    foreach ($s in $cfg.services) { Write-Host "[dry-run] would install $prefix$($s.name): $($cfg.python) $($s.script)" }
    return
}

Assert-Admin
if (-not (Test-Path $Nssm)) { throw "nssm not found at $Nssm" }
New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null

foreach ($s in $cfg.services) {
    $name = "$prefix$($s.name)"
    $log  = Join-Path $LogsDir "$name.svc.log"
    $dir  = if ($s.workingDir) { $s.workingDir } else { Split-Path -Parent $s.script }

    Write-Host "Installing $name ..." -ForegroundColor Cyan
    & $Nssm stop $name 2>$null | Out-Null
    & $Nssm remove $name confirm 2>$null | Out-Null

    & $Nssm install $name $cfg.python $s.script | Out-Null
    & $Nssm set $name AppDirectory $dir | Out-Null
    & $Nssm set $name Description ($(if ($s.description) { $s.description } else { $name })) | Out-Null
    & $Nssm set $name AppStdout $log | Out-Null
    & $Nssm set $name AppStderr $log | Out-Null
    & $Nssm set $name AppEnvironmentExtra "PYTHONUTF8=1" | Out-Null
    & $Nssm set $name AppRotateFiles 1 | Out-Null
    & $Nssm set $name AppRotateOnline 1 | Out-Null
    & $Nssm set $name AppRotateBytes 10485760 | Out-Null
    & $Nssm set $name Start SERVICE_AUTO_START | Out-Null

    & $Nssm start $name | Out-Null
}

Write-Host "`nStatus:" -ForegroundColor Yellow
Get-Service "$prefix*" | Format-Table -AutoSize
