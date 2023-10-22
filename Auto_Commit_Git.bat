@echo off
setlocal enabledelayedexpansion

REM Prompt the user for a custom commit message
set /p commit_message=Enter a custom commit message (or press Enter for a generic message): 

REM Check if the user provided a custom message or left it empty
if "%commit_message%"=="" (
  set commit_message=Batch auto commit
)

REM Commit the changes with the custom message
git add .
git commit -m "!commit_message!"

REM Push the changes to the origin
git push origin

endlocal
