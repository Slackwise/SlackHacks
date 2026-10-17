#Requires -Version 7.4
<#
.SYNOPSIS
Runs offline release regression tests using temporary Git repositories and mocked release APIs.
.DESCRIPTION
Requires only PowerShell and Git. Never uses publishing credentials or live release APIs.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Shared.psm1') -Force
$module = Get-Module Shared
$scratch = Join-Path ([IO.Path]::GetTempPath()) "release-tests-$([guid]::NewGuid().ToString('N'))"
$null = New-Item -ItemType Directory -Path $scratch
$script:passed = 0
$script:failed = 0

function Assert-Equal {
    param($Actual, $Expected, [string]$Message = 'Values differ')
    if ($Actual -cne $Expected) { throw "${Message}: expected '$Expected', got '$Actual'." }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action }
    catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw "Expected error matching '$Pattern', got: $($_.Exception.Message)" }
        return
    }
    throw "Expected an error matching '$Pattern'."
}

function Invoke-Test {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action
        $script:passed++
        Write-Host "PASS $Name" -ForegroundColor Green
    }
    catch {
        $script:failed++
        Write-Host "FAIL $Name`: $_`n$($_.ScriptStackTrace)" -ForegroundColor Red
    }
}

function New-TestRepository {
    $directory = Join-Path $scratch ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $directory
    $origin = Join-Path $directory 'origin.git'
    $repo = Join-Path $directory 'repo'
    $null = Invoke-Git @('init', '--bare', $origin)
    $null = Invoke-Git @('init', '-b', 'dev', $repo)
    Push-Location $repo
    try {
        $null = Invoke-Git @('config', 'user.name', 'Release Test')
        $null = Invoke-Git @('config', 'user.email', 'test@example.invalid')
        $null = Invoke-Git @('config', 'commit.gpgsign', 'false')
        $null = Invoke-Git @('config', 'tag.gpgsign', 'false')
        $null = Invoke-Git @('config', 'core.autocrlf', 'false')
        $null = Invoke-Git @('remote', 'add', 'origin', $origin)
        $null = New-Item -ItemType Directory -Path 'scripts', 'changelog'
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'defaults.env') -Destination 'scripts\defaults.env'
        Write-Utf8File '.gitignore' "dist/`n"
        Write-Utf8File 'SlackHacks.toc' "## Version: 1`n## Interface: 120000, 11505`n"
        Write-Utf8File 'feature.lua' 'return true'
        Write-Utf8File 'changelog\changelog-v1.md' "# Release `"one`"`n`nNotes with \paths and $([char]0x00e9).`n"
        $null = Invoke-Git @('add', '.')
        $null = Invoke-Git @('commit', '-m', 'Feature: initial feature')
        $null = Invoke-Git @('branch', 'prod')
        $null = Invoke-Git @('push', 'origin', 'prod')
    }
    finally { Pop-Location }
    return $repo
}

function Save-TestCommit {
    param([string]$Message)
    $null = Invoke-Git @('add', '.')
    $null = Invoke-Git @('commit', '-m', $Message)
}

function Invoke-TestScript {
    param([string]$Repository, [string]$Script, [string[]]$Arguments = @(), [string]$InputText = '')

    foreach ($file in 'Shared.psm1', $Script) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $Repository "scripts\$file") -Force
    }
    $executable = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
    $start = [Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME $executable))
    $start.WorkingDirectory = $Repository
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $start.RedirectStandardOutput = $start.RedirectStandardError = $true
    foreach ($argument in (@('-NoProfile', '-File', (Join-Path $Repository "scripts\$Script")) + $Arguments)) {
        $start.ArgumentList.Add($argument)
    }
    foreach ($key in (Read-EnvironmentFile (Join-Path $PSScriptRoot 'defaults.env')).Keys) {
        $null = $start.Environment.Remove($key)
    }
    foreach ($key in 'GITHUB_TOKEN', 'CURSEFORGE_API_TOKEN', 'RELEASE_PUSH') { $null = $start.Environment.Remove($key) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write($InputText)
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill($true)
            throw "Test script '$Script' timed out."
        }
        [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output.GetAwaiter().GetResult(); Errors = $errors.GetAwaiter().GetResult() }
    }
    finally { $process.Dispose() }
}

$environmentNames = @('GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL',
    'GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_TERMINAL_PROMPT')
$oldEnvironment = @{}
foreach ($name in $environmentNames) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}
$env:GIT_AUTHOR_NAME = $env:GIT_COMMITTER_NAME = 'Release Test'
$env:GIT_AUTHOR_EMAIL = $env:GIT_COMMITTER_EMAIL = 'test@example.invalid'
$env:GIT_CONFIG_NOSYSTEM = '1'
$env:GIT_CONFIG_GLOBAL = if ($IsWindows) { 'NUL' } else { '/dev/null' }
$env:GIT_TERMINAL_PROMPT = '0'

try {
    Invoke-Test 'All PowerShell entry points and module parse successfully' {
        foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object Extension -In '.ps1', '.psm1') {
            $tokens, $errors = $null, $null
            $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            if ($errors.Count) { throw "$($file.Name): $($errors.Message -join '; ')" }
        }
    }

    Invoke-Test 'Configuration precedence, quoting, empty settings, and environment isolation' {
        $repo = New-TestRepository
        Write-Utf8File (Join-Path $repo '.env') "ADDON_NAME='Local Name'`nCHANGELOG_FILE=`nexport TOC_FILE=`"Custom.toc`"`n"
        $oldName = $env:ADDON_NAME
        try {
            $env:ADDON_NAME = 'Shell Name'
            $config = Import-ProjectConfiguration $repo
            Assert-Equal $config.ADDON_NAME 'Shell Name'
            Assert-Equal $config.TOC_FILE 'Custom.toc'
            Assert-Equal $config.CHANGELOG_FILE ''
            Assert-Equal $env:ADDON_NAME 'Shell Name'
            Assert-Throws { Get-ProjectSetting @{} MISSING } 'Required setting'
        }
        finally { $env:ADDON_NAME = $oldName }
    }

    Invoke-Test 'TOC version writes preserve CRLF and reject invalid versions' {
        $path = Join-Path $scratch 'metadata.toc'
        Write-Utf8File $path "## Version: v16`r`n## Interface: 120000, 11505`r`n"
        Set-TocVersion $path 17
        Assert-Equal ([IO.File]::ReadAllText($path)) "## Version: 17`r`n## Interface: 120000, 11505`r`n"
        Assert-Equal ((Get-TocMetadata $path).Interfaces.Count) 2
        Write-Utf8File $path "## Version: invalid`n"
        Assert-Throws { Get-TocMetadata $path } 'non-numeric'
    }

    Invoke-Test 'Actual entry points honor Boolean flags, yes defaults, no selections, and EOF' {
        $repo = New-TestRepository
        $result = Invoke-TestScript $repo 'Step-AddonVersion.ps1' @('-GenerateChangelog:$false', '-NoOpen')
        Assert-Equal $result.ExitCode 0 $result.Errors
        Assert-Equal (Get-TocMetadata (Join-Path $repo 'SlackHacks.toc')).Version 2
        Assert-Equal (Test-Path (Join-Path $repo 'changelog\changelog-v2.md')) $false
        $result = Invoke-TestScript $repo 'Step-AddonVersion.ps1' @('-NoOpen') "`nn`n"
        Assert-Equal $result.ExitCode 0 $result.Errors
        Assert-Equal (Test-Path (Join-Path $repo 'changelog\changelog-v3.md')) $true
        $result = Invoke-TestScript $repo 'Step-AddonVersion.ps1' @('-NoOpen') "n`n"
        Assert-Equal $result.ExitCode 0 $result.Errors
        Assert-Equal (Get-TocMetadata (Join-Path $repo 'SlackHacks.toc')).Version 4
        Assert-Equal (Test-Path (Join-Path $repo 'changelog\changelog-v4.md')) $false
        $result = Invoke-TestScript $repo 'Step-AddonVersion.ps1' @('-NoOpen')
        Assert-Equal $result.ExitCode 1
        if ($result.Errors -notmatch 'No response received') { throw "EOF was not reported: $($result.Errors)" }
        Assert-Equal (Get-TocMetadata (Join-Path $repo 'SlackHacks.toc')).Version 4
        Push-Location $repo
        try { $null = Invoke-Git @('tag', 'v4') }
        finally { Pop-Location }
        $result = Invoke-TestScript $repo 'New-AddonChangelog.ps1' @('-UseCopilot:$false', '-NoOpen') "`n"
        Assert-Equal $result.ExitCode 0 $result.Errors
        Assert-Equal (Get-TocMetadata (Join-Path $repo 'SlackHacks.toc')).Version 5
        Assert-Equal (Test-Path (Join-Path $repo 'changelog\changelog-v5.md')) $true
    }

    Invoke-Test 'HTTP transport preserves UTF-8 JSON, binary uploads, multipart notes, and JSON arrays' {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $job = Start-ThreadJob -ArgumentList $listener -ScriptBlock {
            param($Listener)
            foreach ($index in 0..4) {
                $client = $Listener.AcceptTcpClient()
                try {
                    $stream = $client.GetStream()
                    $header = [Collections.Generic.List[byte]]::new()
                    while ($true) {
                        $value = $stream.ReadByte()
                        if ($value -lt 0) { throw 'Client disconnected before request headers.' }
                        $header.Add([byte]$value)
                        $count = $header.Count
                        if ($count -ge 4 -and $header[$count - 4] -eq 13 -and $header[$count - 3] -eq 10 -and
                            $header[$count - 2] -eq 13 -and $header[$count - 1] -eq 10) { break }
                    }
                    $headerText = [Text.Encoding]::ASCII.GetString($header.ToArray())
                    $length = if ($headerText -match '(?im)^Content-Length:\s*(\d+)') { [int]$Matches[1] } else { 0 }
                    $body = [byte[]]::new($length)
                    $offset = 0
                    while ($offset -lt $length) {
                        $read = $stream.Read($body, $offset, $length - $offset)
                        if (-not $read) { throw 'Client disconnected before request body.' }
                        $offset += $read
                    }
                    $responseBody = if ($index -eq 3) { '[]' } elseif ($index -eq 4) { '[{"id":1}]' } else { '{"id":1}' }
                    $bytes = [Text.Encoding]::UTF8.GetBytes($responseBody)
                    $headers = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: application/json; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
                    $stream.Write($headers)
                    $stream.Write($bytes)
                    $stream.Flush()
                    [pscustomobject]@{ Header = $headerText; Body = [Text.Encoding]::UTF8.GetString($body) }
                }
                finally { $client.Dispose() }
            }
        }
        try {
            $notes = "# Notes`r`n`"quotes`", \paths\, and $([char]0x00e9) $([char]0x2603)`n"
            $uri = "http://127.0.0.1:$port"
            $null = Invoke-ReleaseRequest -Uri $uri -Method POST -Body @{ body = $notes; generate_release_notes = $false }
            $path = Join-Path $scratch 'upload.zip'
            Write-Utf8File $path 'binary-archive'
            $null = Invoke-ReleaseRequest -Uri $uri -Method POST -FilePath $path
            $null = Invoke-ReleaseRequest -Uri $uri -Method POST -Form @{
                metadata = @{ changelog = $notes } | ConvertTo-Json -Compress
                file = Get-Item -LiteralPath $path
            }
            $empty = (Invoke-ReleaseRequest -Uri $uri).Data
            $single = (Invoke-ReleaseRequest -Uri $uri).Data
            Assert-Equal ($empty -is [array]) $true 'Empty JSON array lost its type'
            Assert-Equal $empty.Count 0
            Assert-Equal ($single -is [array]) $true 'Single JSON array lost its type'
            Assert-Equal $single.Count 1
            $null = Wait-Job $job -Timeout 10
            if ($job.State -ne 'Completed') { throw "HTTP test server did not finish: $($job.State)" }
            $requests = @(Receive-Job $job -ErrorAction Stop)
            $json = $requests[0].Body | ConvertFrom-Json -AsHashtable
            Assert-Equal $json.body $notes
            Assert-Equal $json.generate_release_notes $false
            Assert-Equal $requests[1].Body 'binary-archive'
            if ($requests[2].Header -notmatch 'multipart/form-data' -or $requests[2].Body -notmatch 'name="?metadata"?' -or
                $requests[2].Body -notmatch [regex]::Escape(($notes | ConvertTo-Json -Compress))) {
                throw 'Multipart metadata did not retain the original UTF-8 notes.'
            }
        }
        finally {
            $listener.Stop()
            Stop-Job $job
            Remove-Job $job -Force
        }
    }

    Invoke-Test 'Bump can skip notes, retain existing notes, and preview without writes' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            Step-ProjectVersion $config -GenerateChangelog $false
            Assert-Equal (Get-TocMetadata 'SlackHacks.toc').Version 2
            Assert-Equal (Test-Path 'changelog\changelog-v2.md') $false
            Write-Utf8File 'changelog\changelog-v3.md' "# Keep my notes`n"
            Step-ProjectVersion $config -GenerateChangelog $true -UseCopilot $false
            Assert-Equal (Get-Content -LiteralPath 'changelog\changelog-v3.md' -Raw) "# Keep my notes`n"
            Step-ProjectVersion $config -GenerateChangelog $true -UseCopilot $false -DryRun -NoOpen
            Assert-Equal (Get-TocMetadata 'SlackHacks.toc').Version 3
            Assert-Equal (Test-Path 'changelog\changelog-v4.md') $false
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Independent changelog bumps released versions and appends only new commits' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            $null = Invoke-Git @('tag', 'v1')
            Write-Utf8File 'feature.lua' 'return 2'
            Save-TestCommit 'Bag: add sorting'
            New-ProjectChangelog $config -BumpVersion $true -UseCopilot $false -NoOpen
            Assert-Equal (Get-TocMetadata 'SlackHacks.toc').Version 2
            $first = Get-Content -LiteralPath 'changelog\changelog-v2.md' -Raw
            if ($first -notmatch 'Add sorting') { throw 'Missing new entry.' }
            New-ProjectChangelog $config -BumpVersion $false -UseCopilot $false -NoOpen
            Assert-Equal (Get-Content -LiteralPath 'changelog\changelog-v2.md' -Raw) $first
            Save-TestCommit 'changelog-v2'
            Write-Utf8File 'feature.lua' 'return 3'
            Save-TestCommit 'Minimap: fix positioning'
            New-ProjectChangelog $config -BumpVersion $false -UseCopilot $false -NoOpen
            $second = Get-Content -LiteralPath 'changelog\changelog-v2.md' -Raw
            if (-not $second.StartsWith($first.TrimEnd())) { throw 'Existing notes were changed.' }
            Assert-Equal ([regex]::Matches($second, 'Add sorting').Count) 1
            Assert-Equal ([regex]::Matches($second, 'Fix positioning').Count) 1
            Assert-Equal ([regex]::Matches($second, '^# SlackHacks v2', 'Multiline').Count) 1
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Legacy changelogs append from their last commit without replacing manual notes' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            Write-Utf8File 'feature.lua' 'return 2'
            Save-TestCommit 'Bag: new filter'
            New-ProjectChangelog $config -BumpVersion $false -UseCopilot $false -NoOpen
            $notes = Get-Content -LiteralPath 'changelog\changelog-v1.md' -Raw
            if (-not $notes.StartsWith('# Release "one"') -or $notes -notmatch 'New filter') { throw 'Legacy append failed.' }
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Packaging includes addon/resources, excludes hidden tooling/tests, and rebuilds' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            $null = New-Item -ItemType Directory -Path 'Assets', 'Libs\Ace3\tests', 'Libs\Ace3\AceAddon', '.hidden'
            Write-Utf8File 'Assets\test.txt' 'asset'
            Write-Utf8File 'Libs\Ace3\tests\test.lua' 'test'
            Write-Utf8File 'Libs\Ace3\AceAddon\Addon.lua' 'library'
            Write-Utf8File '.hidden\secret.lua' 'hidden'
            Write-Utf8File 'scripts\tool.lua' 'tooling'
            $zip = New-ProjectArchive $config $repo
            $archive = [IO.Compression.ZipFile]::OpenRead($zip)
            try {
                $names = @($archive.Entries.FullName)
                foreach ($name in 'SlackHacks/feature.lua', 'SlackHacks/SlackHacks.toc', 'SlackHacks/Assets/test.txt', 'SlackHacks/Libs/Ace3/AceAddon/Addon.lua') {
                    if ($name -notin $names) { throw "Missing archive entry '$name'." }
                }
                if ($names -match 'tests|secret|tooling|\.release-staging|scripts') { throw 'Excluded file was packaged.' }
            }
            finally { $archive.Dispose() }
            $null = New-ProjectArchive $config $repo
            Assert-Throws { Resolve-ChildPath $repo '..' } 'strictly inside'
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Deployment rejects unpushed, dirty, mismatched, and stale releases' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $null = Invoke-Git @('tag', '-a', 'v1', '-m', 'release')
            Assert-Throws { Assert-PushedRelease v1 prod } 'has not been pushed'
            $null = Invoke-Git @('push', 'origin', 'v1')
            $commit = Assert-PushedRelease v1 prod
            Assert-Equal $commit (Invoke-Git @('rev-parse', 'HEAD'))
            Write-Utf8File 'untracked.txt' 'dirty'
            Assert-Throws { Assert-PushedRelease v1 prod } 'Commit or stash'
            Remove-Item -LiteralPath 'untracked.txt'
            Write-Utf8File 'feature.lua' 'return 2'
            Save-TestCommit 'Feature: next'
            Assert-Throws { Assert-PushedRelease v1 prod } 'HEAD is not'
            $null = Invoke-Git @('branch', '-f', 'prod', 'HEAD')
            $null = Invoke-Git @('push', 'origin', 'prod')
            $null = Invoke-Git @('checkout', 'v1')
            Assert-Throws { Assert-PushedRelease v1 prod } 'not the pushed'
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Lightweight tags work and mismatched remote tags fail' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $null = Invoke-Git @('tag', 'v1')
            $null = Invoke-Git @('push', 'origin', 'v1')
            $null = Assert-PushedRelease v1 prod
            Write-Utf8File 'feature.lua' 'return 2'
            Save-TestCommit 'Feature: next'
            $null = Invoke-Git @('tag', '-f', 'v1')
            $null = Invoke-Git @('branch', '-f', 'prod', 'HEAD')
            $null = Invoke-Git @('push', 'origin', 'prod')
            Assert-Throws { Assert-PushedRelease v1 prod } 'has not been pushed'
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Local releases resume immutably and refuse new commits or older versions' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            $config.RELEASE_PUSH = 'false'
            Invoke-ProjectRelease $config $repo
            $tag = Invoke-Git @('rev-parse', 'v1')
            Invoke-ProjectRelease $config $repo -Push $false
            Assert-Equal (Invoke-Git @('rev-parse', 'v1')) $tag
            Assert-Equal (Invoke-Git @('branch', '--show-current')) 'dev'
            Assert-Equal (Invoke-Git @('ls-remote', '--tags', 'origin', 'v1')) ''
            Write-Utf8File 'feature.lua' 'return 2'
            Save-TestCommit 'Feature: new work'
            Assert-Throws { Invoke-ProjectRelease $config $repo -DryRun } 'unreleased changes'
            $null = Invoke-Git @('tag', 'v2')
            Assert-Throws { Invoke-ProjectRelease $config $repo -Rerelease -DryRun } 'latest tagged version 2'
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Conflicted merges abort and return to dev without losing commits' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            Write-Utf8File 'feature.lua' 'dev change'
            Save-TestCommit 'dev change'
            $dev = Invoke-Git @('rev-parse', 'dev')
            $null = Invoke-Git @('checkout', 'prod')
            Write-Utf8File 'feature.lua' 'prod change'
            Save-TestCommit 'prod change'
            $null = Invoke-Git @('push', 'origin', 'prod')
            $null = Invoke-Git @('checkout', 'dev')
            Assert-Throws { Invoke-ProjectRelease $config $repo -NoPush } 'failed with exit code'
            Assert-Equal (Invoke-Git @('branch', '--show-current')) 'dev'
            Assert-Equal (Invoke-Git @('rev-parse', 'dev')) $dev
            Assert-Equal (Invoke-Git @('status', '--porcelain')) ''
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Publishing deploys pushed production, returns to dev on failure, and retries the same tag' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            $config.RELEASE_PUSH = 'false'
            $null = Invoke-Git @('checkout', '-b', 'release-work')
            & $module {
                $script:originalDeployment = ${function:Invoke-ProjectDeployment}
                function script:Invoke-ProjectDeployment {
                    param($Configuration, $RepositoryPath, [switch]$DryRun, [switch]$Rerelease)
                    if ((Invoke-Git @('branch', '--show-current')) -ne 'prod') { throw 'Deployment ran outside production.' }
                    $tag = "$(Get-ProjectSetting $Configuration TAG_PREFIX)$((Get-TocMetadata (Get-ProjectSetting $Configuration TOC_FILE)).Version)"
                    $null = Assert-PushedRelease $tag prod
                    throw 'offline deployment failed'
                }
            }
            try {
                Assert-Throws { Invoke-ProjectRelease $config $repo -Push $true } 'offline deployment failed'
                Assert-Equal (Invoke-Git @('branch', '--show-current')) 'dev'
                $tag = Invoke-Git @('rev-parse', 'v1')
                Assert-Throws { Invoke-ProjectRelease $config $repo -Push $true } 'offline deployment failed'
                Assert-Equal (Invoke-Git @('branch', '--show-current')) 'dev'
                Assert-Equal (Invoke-Git @('rev-parse', 'v1')) $tag
            }
            finally { & $module { Set-Item Function:script:Invoke-ProjectDeployment $script:originalDeployment } }
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Re-release tag leases reject concurrent remote changes without pushing production' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            Invoke-ProjectRelease $config $repo -NoPush
            $null = Invoke-Git @('push', 'origin', 'prod', 'v1')
            $oldProd = Invoke-Git @('rev-parse', 'prod')
            Write-Utf8File 'feature.lua' 'return 2'
            Save-TestCommit 'Feature: revised'
            $remote = Join-Path (Split-Path $repo -Parent) 'origin.git'
            & $module {
                param($Remote, $OldProd)
                $script:raceRemote = $Remote
                $script:raceCommit = $OldProd
                $script:originalPlannedCommand = ${function:Invoke-PlannedGitCommand}
                function script:Invoke-PlannedGitCommand {
                    param([string[]]$ArgumentList, [switch]$DryRun)
                    if ($ArgumentList[0] -eq 'push' -and '--atomic' -in $ArgumentList) {
                        $null = Invoke-Git @('--git-dir', $script:raceRemote, 'update-ref', 'refs/tags/v1', $script:raceCommit)
                    }
                    & $script:originalPlannedCommand $ArgumentList -DryRun:$DryRun
                }
            } $remote $oldProd
            try {
                Assert-Throws { Invoke-ProjectRelease $config $repo -Rerelease } 'failed with exit code'
                Assert-Equal (Invoke-Git @('branch', '--show-current')) 'dev'
                Assert-Equal (Invoke-Git @('--git-dir', $remote, 'rev-parse', 'refs/heads/prod')) $oldProd
                Assert-Equal (Invoke-Git @('--git-dir', $remote, 'rev-parse', 'refs/tags/v1')) $oldProd
            }
            finally { & $module { Set-Item Function:script:Invoke-PlannedGitCommand $script:originalPlannedCommand } }
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Failed branch recovery is reported without discarding work' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            $null = Invoke-Git @('checkout', '-b', 'release-work')
            Write-Utf8File 'feature.lua' 'branch change'
            Save-TestCommit 'branch change'
            Write-Utf8File 'feature.lua' 'unsaved work'
            $errors = @()
            try {
                Invoke-ProjectRelease $config $repo -NoPush -ErrorVariable +errors 2>$null
                throw 'Expected dirty-worktree rejection.'
            }
            catch {
                if ($_.Exception.Message -notmatch 'uncommitted changes') { throw }
            }
            Assert-Equal (Invoke-Git @('branch', '--show-current')) 'release-work'
            Assert-Equal (Get-Content 'feature.lua' -Raw) 'unsaved work'
            if (($errors -join "`n") -notmatch 'Could not return') { throw 'Branch recovery failure was not surfaced.' }
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Failure restoring a missing development branch makes a local release fail' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            $null = Invoke-Git @('branch', '-m', 'dev', 'release-work')
            Assert-Throws { Invoke-ProjectRelease $config $repo -NoPush } 'Could not return'
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Dry-run and invalid releases never publish or mutate branches/tags' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            $null = Invoke-Git @('checkout', '-b', 'release-work')
            Invoke-ProjectRelease $config $repo -DryRun
            Assert-Equal (Invoke-Git @('branch', '--show-current')) 'release-work'
            Assert-Equal (Invoke-Git @('tag', '--list')) ''
            Remove-Item -LiteralPath 'changelog\changelog-v1.md'
            Save-TestCommit 'remove notes'
            Assert-Throws { Invoke-ProjectRelease $config $repo -DryRun } 'non-empty changelog'
            Assert-Equal (Invoke-Git @('branch', '--show-current')) 'release-work'
        }
        finally { Pop-Location }
    }

    Invoke-Test 'Game versions resolve exact and latest compatible versions' {
        $catalog = @(
            [pscustomobject]@{ Id = 1; Name = '12.0.0'; Type = 'Retail' },
            [pscustomobject]@{ Id = 2; Name = '12.0.5'; Type = 'Retail' },
            [pscustomobject]@{ Id = 3; Name = '1.15.5'; Type = 'Classic Era' }
        )
        Assert-Equal ((Resolve-GameVersion @(120000, 11505) $catalog) -join ',') '1,3'
        Assert-Equal (Resolve-GameVersion @(120001) $catalog) 2
        Assert-Throws { Resolve-GameVersion @(11505) @($catalog[0]) } 'No compatible'
        Assert-Equal ((@('12.0.5', '12.0.10', '12.0.1 beta') | Sort-Object { Get-NumericVersionKey $_ }) -join ',') '12.0.1 beta,12.0.5,12.0.10'
    }

    Invoke-Test 'Upload receipts preserve legacy claims and block uncertain and revised attempts' {
        $directory = Join-Path $scratch 'receipts'
        $null = New-Item -ItemType Directory -Path $directory
        $key = Get-TextDigest 'project:v1'
        $path = Join-Path $directory "$key.json"
        Write-Utf8File $path '{"status":"pending","commit":"aaa"}' -CreateNew
        Assert-Throws { Get-UploadReceipt $directory $key aaa } 'pending or uncertain'
        Assert-Throws { Get-UploadReceipt $directory $key aaa -Rerelease } 'pending or uncertain'
        Assert-Throws { Write-Utf8File $path '{}' -CreateNew } 'already exists'
        Write-Utf8File "$path.complete" '{"status":"complete","commit":"aaa","file_id":22}'
        Assert-Equal (Get-UploadReceipt $directory $key aaa).FileId 22
        Assert-Throws { Get-UploadReceipt $directory $key bbb } 'different commit'
        Assert-Equal (Get-UploadReceipt $directory $key bbb -Rerelease).Path (Join-Path $directory "$key-bbb.json")
    }

    Invoke-Test 'Deployment reconciliation, checksums, re-release and uncertain upload protection' {
        $repo = New-TestRepository
        Push-Location $repo
        try {
            $config = Read-EnvironmentFile 'scripts\defaults.env'
            $config.GITHUB_TOKEN = $config.CURSEFORGE_API_TOKEN = 'offline-test-token'
            $null = Invoke-Git @('tag', '-a', 'v1', '-m', 'release')
            foreach ($deployer in 'Publish-GitHubRelease', 'Publish-CurseForgeRelease') {
                Assert-Throws { & $deployer $config $repo -DryRun } 'has not been pushed'
            }
            $null = Invoke-Git @('push', 'origin', 'v1')
            Publish-GitHubRelease $config $repo -DryRun
            Publish-CurseForgeRelease $config $repo -DryRun
            Assert-Equal (Test-Path 'dist') $false
            & $module {
                $script:originalRequest = ${function:Invoke-ReleaseRequest}
                $script:api = @{
                    Release = $null; Assets = @(); Creates = 0; Patches = 0; Uploads = 0; Deletes = 0
                    CurseUploads = 0; FailCurse = $false; FailUpload = $false; FailDelete = $false
                }
                function script:Invoke-ReleaseRequest {
                    param($Uri, $Method = 'GET', $Headers, $Body, $FilePath, $Form, $ExpectedStatus)
                    $uriText = "$Uri"
                    if ($uriText -match '/releases/tags/') {
                        if ($script:api.Release) { return [pscustomobject]@{ StatusCode = 200; Data = $script:api.Release } }
                        return [pscustomobject]@{ StatusCode = 404; Data = @{} }
                    }
                    if ($uriText.EndsWith('/releases') -and $Method -eq 'POST') {
                        $script:api.Creates++
                        $script:api.Release = $Body.Clone()
                        $script:api.Release.id = 10
                        $script:api.Release.html_url = 'offline-release'
                        return [pscustomobject]@{ StatusCode = 201; Data = $script:api.Release }
                    }
                    if ($uriText.EndsWith('/releases/10') -and $Method -eq 'PATCH') {
                        $script:api.Patches++
                        foreach ($name in $Body.Keys) { $script:api.Release[$name] = $Body[$name] }
                        return [pscustomobject]@{ StatusCode = 200; Data = $script:api.Release }
                    }
                    if ($uriText -match '/releases/10/assets\?' -and $Method -eq 'GET') {
                        return [pscustomobject]@{ StatusCode = 200; Data = @($script:api.Assets) }
                    }
                    if ($uriText -match '/releases/10/assets\?' -and $Method -eq 'POST') {
                        if ($script:api.FailUpload) { throw 'offline upload failed' }
                        $script:api.Uploads++
                        $asset = @{
                            id = 11; name = 'SlackHacks.zip'; state = 'uploaded'; size = (Get-Item $FilePath).Length
                            digest = 'sha256:' + (Get-FileHash $FilePath).Hash.ToLowerInvariant()
                        }
                        $script:api.Assets += $asset
                        return [pscustomobject]@{ StatusCode = 201; Data = $asset }
                    }
                    if ($uriText.EndsWith('/releases/assets/11') -and $Method -eq 'DELETE') {
                        if ($script:api.FailDelete) { throw 'offline delete failed' }
                        $script:api.Deletes++
                        $script:api.Assets = @()
                        return [pscustomobject]@{ StatusCode = 204; Data = $null }
                    }
                    if ($uriText.EndsWith('/game/version-types')) {
                        return [pscustomobject]@{ StatusCode = 200; Data = @(@{ id = 1; name = 'Retail' }, @{ id = 2; name = 'Classic Era' }) }
                    }
                    if ($uriText.EndsWith('/game/versions')) {
                        return [pscustomobject]@{ StatusCode = 200; Data = @(
                            @{ id = 12; name = '12.0.0'; gameVersionTypeID = 1 },
                            @{ id = 15; name = '1.15.5'; gameVersionTypeID = 2 }
                        ) }
                    }
                    if ($uriText.EndsWith('/upload-file')) {
                        $script:api.CurseUploads++
                        if ($script:api.FailCurse) { throw 'offline uncertain upload' }
                        $metadata = $Form.metadata | ConvertFrom-Json -AsHashtable
                        if ($metadata.changelog -cne (Get-Content -LiteralPath 'changelog\changelog-v1.md' -Raw)) { throw 'Changelog changed in multipart metadata.' }
                        if ($Form.file -isnot [IO.FileInfo]) { throw 'Upload does not use a file form part.' }
                        return [pscustomobject]@{ StatusCode = 200; Data = @{ id = 22 } }
                    }
                    throw "Unexpected offline request: $Method $Uri"
                }
            }
            try {
                Publish-GitHubRelease $config $repo
                Publish-GitHubRelease $config $repo
                $state = & $module { $script:api }
                Assert-Equal $state.Creates 1
                Assert-Equal $state.Uploads 1
                Assert-Equal $state.Release.generate_release_notes $false
                Assert-Equal $state.Release.body (Get-Content -LiteralPath 'changelog\changelog-v1.md' -Raw)
                $state.Release.body = 'old notes'
                Publish-GitHubRelease $config $repo
                Assert-Equal $state.Patches 1
                $state.Assets[0].digest = 'sha256:different'
                Assert-Throws { Publish-GitHubRelease $config $repo } 'Refusing to replace'
                $state.FailDelete = $true
                Assert-Throws { Publish-GitHubRelease $config $repo -Rerelease } 'delete failed'
                $state.FailDelete = $false
                $state.FailUpload = $true
                Assert-Throws { Publish-GitHubRelease $config $repo -Rerelease } 'upload failed'
                $state.FailUpload = $false
                Publish-GitHubRelease $config $repo -Rerelease
                Assert-Equal $state.Uploads 2
                Publish-CurseForgeRelease $config $repo
                Publish-CurseForgeRelease $config $repo
                Assert-Equal $state.CurseUploads 1
                Write-Utf8File 'feature.lua' 'return 2'
                Save-TestCommit 'Feature: revised'
                Invoke-ProjectRelease $config $repo -Rerelease -NoPush
                Assert-Equal (Invoke-Git @('branch', '--show-current')) 'dev'
                Invoke-ProjectRelease $config $repo -Rerelease
                Assert-Equal $state.CurseUploads 2
                Assert-Equal (Invoke-Git @('branch', '--show-current')) 'dev'
                $null = Invoke-Git @('checkout', 'prod')
                $key = Get-TextDigest "$($config.CURSEFORGE_PROJECT_ID):v1"
                foreach ($claim in Get-ChildItem (Get-DeploymentStatePath) -File | Where-Object Name -Like "$key*") {
                    Remove-Item -LiteralPath $claim.FullName
                }
                $state.FailCurse = $true
                Assert-Throws { Publish-CurseForgeRelease $config $repo } 'uncertain upload'
                Assert-Throws { Publish-CurseForgeRelease $config $repo -Rerelease } 'pending or uncertain'
                Assert-Equal $state.CurseUploads 3
            }
            finally {
                & $module { Set-Item -Path Function:script:Invoke-ReleaseRequest -Value $script:originalRequest }
            }
        }
        finally { Pop-Location }
    }
}
finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name]) }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}

Write-Host "`n$script:passed passed; $script:failed failed."
if ($script:failed) { exit 1 }
