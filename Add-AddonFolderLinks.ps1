$sourceDir    = "$PSScriptRoot"
$retailDir    = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\SlackwiseTweaks"
$classicDir   = "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\SlackwiseTweaks"

# Check if script is running as administrator, if not, relaunch as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script is not running as administrator. Relaunching with administrator privileges..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    exit
}

try {
    New-Item -ItemType Junction -Path $retailDir -Target $sourceDir -ErrorAction Stop
    Write-Host "Junctioned retail dir."
} catch [System.IO.IOException] {
    Write-Host "Retail dir already exists!"
} catch {
    Write-Host "Error while trying to junction retail dir:"
    Write-Host $_
}

try {
    New-Item -ItemType Junction -Path $classicDir -Target $sourceDir -ErrorAction Stop
    Write-Host "Junctioned classic dir."
} catch [System.IO.IOException] {
    Write-Host "classic dir already exists!"
} catch {
    Write-Host "Error while trying to junction classic dir:"
    Write-Host $_
}

pause
