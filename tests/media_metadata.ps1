$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\MediaMetadata.ps1')

$fixture = Join-Path ([IO.Path]::GetTempPath()) ("SlackHacks Media Metadata " + [guid]::NewGuid().ToString('N'))
$scripts = Join-Path $fixture 'scripts'
$builder = Join-Path $scripts 'package-media-metadata.pl'
$marker = Join-Path $fixture 'built'
$originalPath = $env:PATH

try {
    New-Item -ItemType Directory -Path $scripts | Out-Null
    @'
use strict;
use warnings;
system('git', '--version') == 0 or die "Git is unavailable in Git Bash\n";
open my $fh, '>', 'built' or die $!;
print {$fh} "built\n";
close $fh or die $!;
'@ | Set-Content -LiteralPath $builder -Encoding ASCII

    # Match an elevated shell where neither Git nor Perl is on PATH.
    $env:PATH = "$env:SystemRoot\System32;$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if ((Get-Command git -ErrorAction SilentlyContinue) -or
        (Get-Command perl -ErrorAction SilentlyContinue)) {
        throw 'Test requires a PATH without Git or Perl.'
    }
    Invoke-MediaMetadataBuild -RepoPath $fixture
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        throw 'Git Bash did not execute the builder.'
    }

    Set-Content -LiteralPath $builder -Value 'exit 9;' -Encoding ASCII
    try {
        Invoke-MediaMetadataBuild -RepoPath $fixture
        throw 'Builder failure was not reported.'
    } catch {
        if ($_.Exception.Message -notmatch 'exit 9') { throw }
    }
    Write-Output 'Media metadata Git Bash discovery tests passed.'
} finally {
    $env:PATH = $originalPath
    if (Test-Path -LiteralPath $builder) { Remove-Item -LiteralPath $builder }
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker }
    if (Test-Path -LiteralPath $scripts) { Remove-Item -LiteralPath $scripts }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture }
}
