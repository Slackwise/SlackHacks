function Write-ScriptStatus {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
        [string]$Level,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $colors = @{ INFO = 'Cyan'; OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red' }
    if ($null -ne $env:NO_COLOR -or [Console]::IsOutputRedirected) {
        Write-Host $Message
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $colors[$Level]
    }
}
