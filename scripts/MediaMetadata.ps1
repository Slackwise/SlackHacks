# Find Git Bash with its bundled Perl and cygpath, without mistaking WSL's bash for Git Bash.
function Get-MediaMetadataGitBash {
    $roots = @()
    foreach ($name in @('git', 'bash.exe')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
        if ($command) {
            $parent = Split-Path -Parent $command.Source
            for ($i = 0; $i -lt 3 -and $parent; $i++) {
                $roots += $parent
                $parent = Split-Path -Parent $parent
            }
        }
    }

    foreach ($key in @('HKCU:\SOFTWARE\GitForWindows', 'HKLM:\SOFTWARE\GitForWindows',
                       'HKLM:\SOFTWARE\WOW6432Node\GitForWindows')) {
        $installation = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($installation.InstallPath) { $roots += $installation.InstallPath }
    }
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ($base) {
            $roots += Join-Path $base 'Git'
        }
    }
    if ($env:LOCALAPPDATA) {
        $roots += Join-Path $env:LOCALAPPDATA 'Programs\Git'
    }

    foreach ($root in $roots) {
        $bash = Join-Path $root 'bin\bash.exe'
        if ((Test-Path -LiteralPath $bash -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $root 'usr\bin\perl.exe') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $root 'usr\bin\cygpath.exe') -PathType Leaf)) {
            return $bash
        }
    }
}

# Builds the companion using Git for Windows' bundled Perl when available.
function Invoke-MediaMetadataBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    $script = Join-Path $RepoPath 'scripts\package-media-metadata.pl'
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
        throw "Media metadata builder not found: $script"
    }

    $bash = $null
    if ($env:OS -eq 'Windows_NT') {
        $bash = Get-MediaMetadataGitBash
    }

    if ($bash) {
        # Feed Bash via stdin so Windows PowerShell cannot strip the command's quotes.
        'cd -- "$(cygpath -u "$1")" && perl scripts/package-media-metadata.pl' | & $bash -s -- $RepoPath
    } else {
        $perl = Get-Command perl -ErrorAction SilentlyContinue
        if (-not $perl) { throw 'Git for Windows with its bundled Perl, or a Perl installation, is required to build SlackHacks: Media Metadata.' }
        & $perl.Source $script
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Media metadata build failed (exit $LASTEXITCODE)."
    }
}
