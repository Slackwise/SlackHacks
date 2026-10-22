#Requires -Version 7.4
<#
.SYNOPSIS
Creates or appends to the current version's changelog independently of a version bump.
.DESCRIPTION
If the TOC version is not newer than the latest version tag, offers to bump it (default yes).
Existing notes are retained. A commit checkpoint prevents repeated entries on subsequent runs.
Use -BumpVersion:$false to keep the current version, and -UseCopilot:$false for local generation.
#>
[CmdletBinding()]
param(
    [Nullable[bool]]$BumpVersion,
    [Nullable[bool]]$UseCopilot,
    [switch]$Blank,
    [switch]$DryRun,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ReleaseUtils.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try { New-ProjectChangelog -Configuration (Import-ProjectConfiguration $root) @PSBoundParameters }
finally { Pop-Location }
