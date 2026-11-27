$sourceDir    = Split-Path -Parent $PSScriptRoot # Resolves to the addon's root folder regardless of the caller's working directory, so double-clicking works.
. (Join-Path $PSScriptRoot 'OutputStyle.ps1')
. (Join-Path $PSScriptRoot 'MediaMetadata.ps1')

# Create a junction without replacing an unrelated existing folder or link.
function Set-AddonJunction {
    param([string]$Path, [string]$Target)

    $existing = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($existing) {
        $existingTarget = if ($existing.LinkType -eq 'Junction') { $existing.Target | Select-Object -First 1 }
        if ($existingTarget -and
            [IO.Path]::GetFullPath($existingTarget).TrimEnd('\') -eq [IO.Path]::GetFullPath($Target).TrimEnd('\')) {
            Write-ScriptStatus INFO "$Path is already linked."
            return
        }
        throw "Cannot create junction '$Path': an existing item points elsewhere or is not a junction."
    }
    New-Item -ItemType Junction -Path $Path -Target $Target -ErrorAction Stop | Out-Null
    Write-ScriptStatus OK "Linked '$Path' to '$Target'."
}

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

if ($MyInvocation.InvocationName -eq '.') { return }

# Check if script is running as administrator, if not, relaunch as administrator.
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-ScriptStatus WARN "Script is not running as administrator. Relaunching with administrator privileges..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    exit
}

try {
    Invoke-MediaMetadataBuild -RepoPath $sourceDir
    $mediaDir = Join-Path $sourceDir 'dist\SlackHacks_MediaMetadata'
    $wowRoot = Get-WowRoot
    Write-ScriptStatus INFO "Found WoW install at: $wowRoot"

    # Each installed game flavor (retail, classic, classic era, PTR, etc.) lives in its
    # own "_flavor_" folder directly under the WoW root, so discover them instead of
    # hardcoding names.
    $flavorPattern = '^_[a-z0-9_]+_$'
    $dirs = @{}
    Get-ChildItem -Path $wowRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $flavorPattern } |
        ForEach-Object { $dirs[$_.Name.Trim('_')] = Join-Path $_.FullName "Interface\AddOns" }

    $hadFailure = $false
    foreach ($dirName in $dirs.Keys) {
        $parentDir = $dirs[$dirName]
        if (-not (Test-Path -Path $parentDir)) {
            Write-ScriptStatus INFO "Skipping $($dirName.ToUpper()): directory does not exist"
            continue
        }

        foreach ($link in @(
            @{ Name = 'SlackHacks'; Target = $sourceDir },
            @{ Name = 'SlackHacks_MediaMetadata'; Target = $mediaDir }
        )) {
            try {
                Set-AddonJunction -Path (Join-Path $parentDir $link.Name) -Target $link.Target
            } catch {
                Write-ScriptStatus ERROR "Error while linking $($dirName.ToUpper()): $($_.Exception.Message)"
                $hadFailure = $true
            }
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
