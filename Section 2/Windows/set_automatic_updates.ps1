[CmdletBinding()]
param(
    [ValidateRange(0,7)]
    [int]$InstallDay = 0,
    [ValidateRange(0,23)]
    [int]$InstallTime = 3,
    [switch]$ScanNow
)

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Error "run in an elevated PowerShell session"
    exit 1
}

$regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

try {
    if (-not (Test-Path -LiteralPath $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    New-ItemProperty -Path $regPath -Name 'NoAutoUpdate' -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPath -Name 'AUOptions' -Value 4 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPath -Name 'ScheduledInstallDay' -Value $InstallDay -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPath -Name 'ScheduledInstallTime' -Value $InstallTime -PropertyType DWord -Force | Out-Null
}
catch {
    Write-Error "failed to set registry policy at ${regPath}: $($_.Exception.Message)"
    exit 2
}

try {
    Set-Service -Name 'wuauserv' -StartupType Manual -ErrorAction Stop
    Start-Service -Name 'wuauserv' -ErrorAction Stop
}
catch {
    Write-Warning "could not ensure Windows Update service is running: $($_.Exception.Message)"
}

try {
    $au = New-Object -ComObject 'Microsoft.Update.AutoUpdate'
    $settings = $au.Settings
    $settings.NotificationLevel = 4
    try { $settings.Save() | Out-Null } catch { }
    try { $au.EnableService() | Out-Null } catch { }
    if ($ScanNow) {
        try { $au.DetectNow() } catch { Write-Verbose "DetectNow failed: $($_.Exception.Message)" }
    }
}
catch {
    Write-Verbose "WUA COM path not available or blocked by policy: $($_.Exception.Message)"
}

# read back values for display, falling back to parameters if missing
try {
    $read = Get-ItemProperty -Path $regPath -Name AUOptions,ScheduledInstallDay,ScheduledInstallTime -ErrorAction Stop
    if ($read.AUOptions -ne 4) { throw "AUOptions check failed; current value is $($read.AUOptions)" }
    $day  = if ($null -ne $read.ScheduledInstallDay)  { $read.ScheduledInstallDay }  else { $InstallDay }
    $time = if ($null -ne $read.ScheduledInstallTime) { $read.ScheduledInstallTime } else { $InstallTime }
    Write-Host "Automatic Updates enabled. Scheduled install policy set to day $day at ${time}:00."
    exit 0
}
catch {
    Write-Warning "policy write succeeded but verification failed: $($_.Exception.Message)"
    exit 5
}