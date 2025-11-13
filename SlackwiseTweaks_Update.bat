@echo off

rem Check if the icon already exists
if exist "%USERPROFILE%\Desktop\SlackwiseTweaks Update.lnk" (
    rem If the icon exists, execute "git pull" in the current directory
    rem Check if Git is installed
    if not exist "%PATH%\git.exe" (
        echo Git is not installed. Please install git first.
        pause
        exit /b
    )

    git pull
    if errorlevel 1 (
        echo Git pull failed.
        pause
    )
) else (
    rem If the icon doesn't exist, create it
    echo. | more > "%USERPROFILE%\Desktop\SlackwiseTweaks Update.lnk"
    mklink /j "%USERPROFILE%\Desktop\SlackwiseTweaks Update.lnk" "%~f0"
    start "SlackwiseTweaks Update" "%~f0"
)