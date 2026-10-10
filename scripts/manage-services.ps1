<#
.SYNOPSIS
  Status / start / stop / restart for a group of Windows services, failing LOUDLY.

.DESCRIPTION
  Without administrator rights `Restart-Service -ErrorAction SilentlyContinue`
  does nothing and the service keeps running the OLD code while the script looks
  successful. This script checks for elevation first and reports every failure.

.EXAMPLE
  .\manage-services.ps1 -Action restart -Services myapp-bot,myapp-api
  .\manage-services.ps1 -Action status  -Prefix myapp
#>
param(
    [ValidateSet("status", "start", "stop", "restart")][string]$Action = "status",
    [string[]]$Services,
    [string]$Prefix
)

$ErrorActionPreference = "Stop"

if (-not $Services) {
    if (-not $Prefix) { throw "Pass -Services a,b,c or -Prefix name (matches name-*)" }
    $Services = (Get-Service "$Prefix-*" | Select-Object -ExpandProperty Name)
    if (-not $Services) { throw "No services match '$Prefix-*'" }
}

if ($Action -ne "status") {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { throw "'$Action' needs an elevated (Administrator) PowerShell." }
}

$failed = @()
foreach ($name in $Services) {
    try {
        switch ($Action) {
            "start"   { Write-Host "Starting $name ...";   Start-Service $name }
            "stop"    { Write-Host "Stopping $name ...";   Stop-Service $name -Force }
            "restart" { Write-Host "Restarting $name ..."; Restart-Service $name -Force }
        }
    } catch {
        $failed += $name
        Write-Host "FAILED $name : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Get-Service $Services | Select-Object Name, Status | Format-Table -AutoSize
if ($failed.Count -gt 0) { exit 1 }
