param(
    [string]$RepoPath
)

function Show-ErrorMessageBox {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Title = 'Error'
    )

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Assert-GitInstalled {
    if (Get-Command -Name git -ErrorAction SilentlyContinue) {
        return
    }

    Show-ErrorMessageBox -Title 'Git Not Found' -Message 'Git is required to update this addon. Please install Git for Windows from https://git-scm.com/download/win and try again.'

    exit 1
}

function Invoke-GitPull {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    git -C $Path pull
    if ($LASTEXITCODE -ne 0) {
        Show-ErrorMessageBox -Title 'Git Pull Failed' -Message "Failed to pull the latest changes for '$Path'. Please resolve any git issues and try again."
        exit 1
    }

    git -C $Path submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) {
        Show-ErrorMessageBox -Title 'Git Submodule Update Failed' -Message "Failed to update submodules for '$Path'. Please resolve any git issues and try again."
        exit 1
    }
}

function Get-LatestCommitInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl,

        [Parameter(Mandatory = $false)]
        [string]$Branch
    )

    if ($RepoUrl -notmatch 'github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?(/tree/(?<branch>[^/]+))?/?$') {
        throw "Unable to parse GitHub owner/repo from URL: $RepoUrl"
    }

    $owner = $Matches['owner']
    $repo = $Matches['repo']
    $headers = @{ 'User-Agent' = 'SlackHacks-Update-Addon' }

    if ([string]::IsNullOrEmpty($Branch)) {
        # Fall back to a branch embedded in the URL (e.g. .../tree/<branch>); otherwise the API defaults to the repo's default branch.
        $Branch = $Matches['branch']
    }

    $uri = "https://api.github.com/repos/$owner/$repo/commits"
    if (-not [string]::IsNullOrEmpty($Branch)) {
        $uri += "/$Branch"
    }

    $commitInfo = Invoke-RestMethod -Uri $uri -Headers $headers

    return [PSCustomObject]@{
        Owner  = $owner
        Repo   = $repo
        Branch = $Branch
        Sha    = $commitInfo.sha
    }
}

try {
    if (-not $PSBoundParameters.ContainsKey('RepoPath')) {
        # Running from inside the repo; git can't overwrite this file while it's executing, so
        # copy ourselves to temp and re-run from there, passing along where the repo actually lives.
        $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) (Split-Path -Path $PSCommandPath -Leaf)
        Copy-Item -Path $PSCommandPath -Destination $tempScript -Force

        $shellPath = (Get-Process -Id $PID).Path
        & $shellPath -NoProfile -ExecutionPolicy Bypass -File $tempScript -RepoPath $PSScriptRoot
        exit $LASTEXITCODE
    }

    Set-Location -Path $RepoPath

    Assert-GitInstalled
    Invoke-GitPull -Path $RepoPath
} catch {
    Show-ErrorMessageBox -Title 'Update Failed' -Message "$($_.Exception.Message)`n`n$($_.ScriptStackTrace)"
    exit 1
}
