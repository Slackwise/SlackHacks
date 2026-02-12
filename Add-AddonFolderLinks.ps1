$sourceDir    = "$PSScriptRoot"
$dirs = @{
    retail = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\SlackHacks"
    classic = "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\SlackHacks"
    beta = "C:\Program Files (x86)\World of Warcraft\_beta_\Interface\AddOns\SlackHacks"
}

# Check if script is running as administrator, if not, relaunch as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Script is not running as administrator. Relaunching with administrator privileges..."
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
        Write-Host "Junctioned $dirName directory."
    } catch [System.IO.IOException] {
        Write-Error "$dirName directory already exists!"
    } catch {
        Write-Error "Error while trying to junction $dirName directory:"
        Write-Error $_
    }
}

pause
