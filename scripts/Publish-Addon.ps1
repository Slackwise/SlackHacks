#Requires -Version 7.4
<#
.SYNOPSIS
Deploys the pushed production release to GitHub and CurseForge.
#>
[CmdletBinding()]
param([switch]$DryRun, [switch]$Rerelease)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ReleaseUtils.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try { Invoke-ProjectDeployment -Configuration (Import-ProjectConfiguration $root) -RepositoryPath $root @PSBoundParameters }
finally { Pop-Location }
