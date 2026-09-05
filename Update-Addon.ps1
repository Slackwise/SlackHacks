$ADDON_REPO = "https://github.com/Slackwise/SlackHacks";

$LIB_REPOS = ,"https://github.com/WoWUIDev/Ace3";

function Assert-GitInstalled {
    if (Get-Command -Name git -ErrorAction SilentlyContinue) {
        return;
    }

    Add-Type -AssemblyName System.Windows.Forms;
    [System.Windows.Forms.MessageBox]::Show(
        "Git is required to update this addon. Please install Git for Windows from https://git-scm.com/download/win and try again.",
        "Git Not Found",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null;

    exit 1;
}

function Get-LatestCommitInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl,

        [Parameter(Mandatory = $false)]
        [string]$Branch
    )

    if ($RepoUrl -notmatch 'github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?(/tree/(?<branch>[^/]+))?/?$') {
        throw "Unable to parse GitHub owner/repo from URL: $RepoUrl";
    }

    $owner = $Matches['owner'];
    $repo = $Matches['repo'];
    $headers = @{ 'User-Agent' = 'SlackHacks-Update-Addon' };

    if ([string]::IsNullOrEmpty($Branch)) {
        # Fall back to a branch embedded in the URL (e.g. .../tree/<branch>); otherwise the API defaults to the repo's default branch.
        $Branch = $Matches['branch'];
    }

    $uri = "https://api.github.com/repos/$owner/$repo/commits";
    if (-not [string]::IsNullOrEmpty($Branch)) {
        $uri += "/$Branch";
    }

    $commitInfo = Invoke-RestMethod -Uri $uri -Headers $headers;

    return [PSCustomObject]@{
        Owner  = $owner;
        Repo   = $repo;
        Branch = $Branch;
        Sha    = $commitInfo.sha;
    };
}
