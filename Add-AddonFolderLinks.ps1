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

# Check if script is running as administrator, if not, relaunch as administrator.
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script is not running as administrator. Relaunching with administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    exit
}

try {
    $wowRoot = Get-WowRoot
    Write-Host "Found WoW install at: $wowRoot" -ForegroundColor Green

    # Each installed game flavor (retail, classic, classic era, PTR, etc.) lives in its
    # own "_flavor_" folder directly under the WoW root, so discover them instead of
    # hardcoding names.
    $flavorPattern = '^_[a-z0-9_]+_$'
    $dirs = @{}
    Get-ChildItem -Path $wowRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $flavorPattern } |
        ForEach-Object { $dirs[$_.Name.Trim('_')] = Join-Path $_.FullName "Interface\AddOns\SlackHacks" }

    $hadFailure = $false
    foreach ($dirName in $dirs.Keys) {
        $parentDir = Split-Path -Parent $dirs[$dirName]
        if (-not (Test-Path -Path $parentDir)) {
            Write-Host "Skipping $($dirName.ToUpper()): directory does not exist"
            continue
        }

        $targetPath = $dirs[$dirName]
        $existingItem = Get-Item -Path $targetPath -Force -ErrorAction SilentlyContinue
        if ($existingItem -and $existingItem.LinkType -eq "Junction") {
            $existingTarget = ($existingItem.Target | Select-Object -First 1)
            if ($existingTarget -and $existingTarget.TrimEnd('\') -ne $sourceDir.TrimEnd('\')) {
                Remove-Item -Path $targetPath -Force
                Write-Host "$($dirName.ToUpper()) was linked to '$existingTarget'; removing and relinking to '$sourceDir'." -ForegroundColor Yellow
            }
        }

        try {
            New-Item -ItemType Junction -Path $dirs[$dirName] -Target $sourceDir -ErrorAction Stop | Out-Null
            Write-Host "$($dirName.ToUpper()) succeeded." -ForegroundColor Green
        } catch [System.IO.IOException] {
            Write-Host "$($dirName.ToUpper()) is already linked." -ForegroundColor Cyan
        } catch {
            Write-Host "Error while trying to junction $($dirName.ToUpper()):" -ForegroundColor Red
            Write-Error $_
            $hadFailure = $true
        }
    }

    if ($hadFailure) {
        Write-Host "Finished with errors; see above." -ForegroundColor Red
    } else {
        Write-Host "Done! SlackHacks addon links are set up." -ForegroundColor Green
    }
} finally {
    pause
}
