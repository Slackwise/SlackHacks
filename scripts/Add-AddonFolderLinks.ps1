$sourceDir    = Split-Path -Parent $PSScriptRoot # Resolves to the addon's root folder regardless of the caller's working directory, so double-clicking works.
. (Join-Path $PSScriptRoot 'OutputStyle.ps1')

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
    Write-ScriptStatus WARN "Script is not running as administrator. Relaunching with administrator privileges..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    exit
}

try {
    $wowRoot = Get-WowRoot
    Write-ScriptStatus INFO "Found WoW install at: $wowRoot"

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
            Write-ScriptStatus INFO "Skipping $($dirName.ToUpper()): directory does not exist"
            continue
        }

        $targetPath = $dirs[$dirName]
        $existingItem = Get-Item -Path $targetPath -Force -ErrorAction SilentlyContinue
        if ($existingItem -and $existingItem.LinkType -eq "Junction") {
            $existingTarget = ($existingItem.Target | Select-Object -First 1)
            if ($existingTarget -and $existingTarget.TrimEnd('\') -ne $sourceDir.TrimEnd('\')) {
                Remove-Item -Path $targetPath -Force
                Write-ScriptStatus WARN "$($dirName.ToUpper()) was linked to '$existingTarget'; removing and relinking to '$sourceDir'."
            }
        }

        try {
            New-Item -ItemType Junction -Path $dirs[$dirName] -Target $sourceDir -ErrorAction Stop | Out-Null
            Write-ScriptStatus OK "$($dirName.ToUpper()) succeeded."
        } catch [System.IO.IOException] {
            Write-ScriptStatus INFO "$($dirName.ToUpper()) is already linked."
        } catch {
            Write-ScriptStatus ERROR "Error while trying to junction $($dirName.ToUpper()):"
            Write-Error $_
            $hadFailure = $true
        }
    }

    if ($hadFailure) {
        Write-ScriptStatus ERROR "Finished with errors; see above."
    } else {
        Write-ScriptStatus OK "Done! SlackHacks addon links are set up."
    }
} finally {
    pause
}
