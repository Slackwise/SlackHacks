#Requires -Version 7.4
<#
.SYNOPSIS
Publishes the pushed production release to GitHub, reconciling safe retries.
.PARAMETER Rerelease
Permits replacing an existing ZIP whose digest differs. Release notes are always synchronized.
#>
[CmdletBinding()]
param([switch]$DryRun, [switch]$Rerelease)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Shared.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try { Publish-GitHubRelease -Configuration (Import-ProjectConfiguration $root) -RepositoryPath $root @PSBoundParameters }
finally { Pop-Location }
