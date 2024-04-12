$sourceFolder = "$PSScriptRoot"
$retailDir = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\SlackUI"
$classicDir = "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\SlackUI"

# Check if script is running as administrator, if not, relaunch as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script is not running as administrator. Relaunching with administrator privileges..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    exit
}

# Check if destination folders exist, create if not
if (!(Test-Path -Path $retailDir -PathType Container)) {
    New-Item -ItemType Junction -Path retailDir -Target $sourceFolder
    Write-Host "Junctioned retail dir."
} else {
    Write-Host "Retail dir already exists!"
}

if (!(Test-Path -Path $classicDir -PathType Container)) {
    New-Item -ItemType Junction -Path $classicDir -Target $sourceFolder
    Write-Host "Junctioned classic dir."
} else {
    Write-Host "Classic dir already exists!"
}

pause