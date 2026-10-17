#Requires -Version 7.4
<#
.SYNOPSIS
Increments the TOC version and optionally creates its missing changelog.
.DESCRIPTION
Prompts default to yes. Existing changelogs are never overwritten.
Pass -GenerateChangelog:$false to bump only, or -UseCopilot:$false for commit-derived notes.
Dry runs preview local generation without prompts or invoking Copilot.
#>
[CmdletBinding()]
param(
    [Nullable[bool]]$GenerateChangelog,
    [Nullable[bool]]$UseCopilot,
    [switch]$Blank,
    [switch]$DryRun,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Shared.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try { Step-ProjectVersion -Configuration (Import-ProjectConfiguration $root) @PSBoundParameters }
finally { Pop-Location }
