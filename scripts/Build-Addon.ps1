#Requires -Version 7.4
<#
.SYNOPSIS
Packages the addon without requiring Bash or external archive tools.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ReleaseUtils.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try { $null = New-ProjectArchive -Configuration (Import-ProjectConfiguration $root) -RepositoryPath $root }
finally { Pop-Location }
