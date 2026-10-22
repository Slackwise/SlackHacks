#Requires -Version 7.4
<#
.SYNOPSIS
Merges into production, tags, atomically pushes, and deploys the release.
.DESCRIPTION
Requires a clean worktree and committed changelog. Returns to dev even after failures.
Existing releases are resumed without retagging; new changes require a version bump
or an explicit -Rerelease. Dry runs leave the current branch unchanged.
.PARAMETER NoPush
Prepares a local release only. Does not deploy.
.PARAMETER Push
Overrides the RELEASE_PUSH configuration explicitly.
.PARAMETER ReturnBranch
Branch to restore after success or failure (default dev, matching the existing workflow).
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Target,
    [string]$ReturnBranch = 'dev',
    [switch]$DryRun,
    [switch]$NoPush,
    [Nullable[bool]]$Push,
    [switch]$Rerelease
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ReleaseUtils.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try { Invoke-ProjectRelease -Configuration (Import-ProjectConfiguration $root) -RepositoryPath $root @PSBoundParameters }
finally { Pop-Location }
