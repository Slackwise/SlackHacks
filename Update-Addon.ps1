$ADDON_REPO = "https://github.com/Slackwise/SlackHacks";

$LIB_REPOS = ,"https://github.com/WoWUIDev/Ace3";

function Get-LatestCommitHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl,

        [Parameter(Mandatory = $false)]
        [string]$Branch
    )

    if ($RepoUrl -notmatch 'github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?/?$') {
        throw "Unable to parse GitHub owner/repo from URL: $RepoUrl";
    }

    $owner = $Matches['owner'];
    $repo = $Matches['repo'];
    $headers = @{ 'User-Agent' = 'SlackHacks-Update-Addon' };

    if ([string]::IsNullOrEmpty($Branch)) {
        # Look up the repo's default branch, since it isn't always "main" or "master".
        $repoInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo" -Headers $headers;
        $Branch = $repoInfo.default_branch;
    }

    $commitInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/commits/$Branch" -Headers $headers;

    return $commitInfo.sha;
}