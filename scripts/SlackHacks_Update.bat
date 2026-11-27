@echo off
setlocal
pushd "%~dp0.."

rem Check if the icon already exists
if exist "%USERPROFILE%\Desktop\SlackHacks Update.lnk" (
    rem If the icon exists, execute "git pull" in the repo root directory
    rem Check if Git is installed
    where git >nul 2>nul
    if errorlevel 1 (
        call :error "Git is not installed. Please install git first."
        pause
        popd
        exit /b 1
    )

    git pull
    if errorlevel 1 (
        call :error "Git pull failed."
        pause
        popd
        exit /b 1
    )

    git submodule update --init --recursive
    if errorlevel 1 (
        call :error "Git submodule update failed."
        pause
        popd
        exit /b 1
    )

    set "SLACKHACKS_REPO_PATH=%~dp0.."
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". (Join-Path $env:SLACKHACKS_REPO_PATH 'scripts\MediaMetadata.ps1'); Invoke-MediaMetadataBuild -RepoPath $env:SLACKHACKS_REPO_PATH"
    if errorlevel 1 (
        call :error "Media metadata build failed."
        pause
        popd
        exit /b 1
    )
) else (
    rem If the icon doesn't exist, create it
    echo. | more > "%USERPROFILE%\Desktop\SlackHacks Update.lnk"
    mklink /j "%USERPROFILE%\Desktop\SlackHacks Update.lnk" "%~f0"
    start "SlackHacks Update" "%~f0"
)
popd
exit /b

:error
set "SLACKHACKS_STATUS_MESSAGE=%~1"
set "SLACKHACKS_SCRIPT_DIR=%~dp0"
if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" if exist "%~dp0OutputStyle.ps1" (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command ". (Join-Path $env:SLACKHACKS_SCRIPT_DIR 'OutputStyle.ps1'); Write-ScriptStatus ERROR $env:SLACKHACKS_STATUS_MESSAGE"
    if not errorlevel 1 exit /b
)
echo %SLACKHACKS_STATUS_MESSAGE%
exit /b