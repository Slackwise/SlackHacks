#Requires -Version 7.4
<#
.SYNOPSIS
Publishes a pushed production release to CurseForge with persistent upload receipts.
.PARAMETER Rerelease
Allows a new file for a revised commit; previous CurseForge files must be managed manually.
.PARAMETER ListVersions
Lists available game versions without requiring a release checkout.
.PARAMETER Filter
Restricts the listed versions by name, slug, or game type.
#>
[CmdletBinding()]
param([switch]$DryRun, [switch]$Rerelease, [switch]$ListVersions, [string]$Filter = '')

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Shared.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try { Publish-CurseForgeRelease -Configuration (Import-ProjectConfiguration $root) -RepositoryPath $root @PSBoundParameters }
finally { Pop-Location }
