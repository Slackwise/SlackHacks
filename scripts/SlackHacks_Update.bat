@echo off
pushd "%~dp0.."

rem Check if the icon already exists
if exist "%USERPROFILE%\Desktop\SlackHacks Update.lnk" (
    rem If the icon exists, execute "git pull" in the repo root directory
    rem Check if Git is installed
    if not exist "%PATH%\git.exe" (
        echo Git is not installed. Please install git first.
        pause
        popd
        exit /b
    )

    git pull
    if errorlevel 1 (
        echo Git pull failed.
        pause
    )
) else (
    rem If the icon doesn't exist, create it
    echo. | more > "%USERPROFILE%\Desktop\SlackHacks Update.lnk"
    mklink /j "%USERPROFILE%\Desktop\SlackHacks Update.lnk" "%~f0"
    start "SlackHacks Update" "%~f0"
)
popd