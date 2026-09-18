$sourceDir    = "$PSScriptRoot" # Resolves to the script's own folder regardless of the caller's working directory, so double-clicking works.

# Blizzard/Battle.net don't reliably write a WoW "InstallPath" key anymore, so we
# derive the shared parent folder (which holds _retail_/_classic_era_/etc.) from
# the Windows uninstall registry entries, falling back to the default location.
function Get-WowRoot {
    $flavorPattern = '^_[a-z0-9_]+_$'

    # Look for a "World of Warcraft" uninstall entry and use its InstallLocation.
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $entry = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "World of Warcraft*" -and $_.InstallLocation } |
        Select-Object -First 1
    if ($entry) {
        $installLocation = $entry.InstallLocation.TrimEnd('\')
        $leaf = Split-Path -Leaf $installLocation
        if ($leaf -match $flavorPattern) {
            return Split-Path -Parent $installLocation
        }
        return $installLocation
    }

    # Give up and use the standard default install location.
    return "C:\Program Files (x86)\World of Warcraft"
}

$wowRoot = Get-WowRoot

$dirs = @{
    retail = "$wowRoot\_retail_\Interface\AddOns\SlackHacks"
    forever = "$wowRoot\_classic_beta_\Interface\AddOns\SlackHacks"
    classic = "$wowRoot\_classic_era_\Interface\AddOns\SlackHacks"
    beta = "$wowRoot\_beta_\Interface\AddOns\SlackHacks"
}

# Check if script is running as administrator, if not, relaunch as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script is not running as administrator. Relaunching with administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    exit
}

foreach ($dirName in $dirs.Keys) {
    $parentDir = Split-Path -Parent $dirs[$dirName]
    if (-not (Test-Path -Path $parentDir)) {
        Write-Host "Skipping ${dirName}: directory does not exist"
        continue
    }
    
    try {
        New-Item -ItemType Junction -Path $dirs[$dirName] -Target $sourceDir -ErrorAction Stop
        Write-Host "Junctioned $dirName directory." -ForegroundColor Green
    } catch [System.IO.IOException] {
        Write-Host "$dirName directory is already linked." -ForegroundColor Cyan
    } catch {
        Write-Host "Error while trying to junction $dirName directory: $_" -ForegroundColor Yellow
    }
}

Write-Host "Done! SlackHacks addon links are set up." -ForegroundColor Green
pause
