@echo off
set "PATH=C:\Users\vamsi\AppData\Local\Microsoft\WinGet\Packages\OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe\node-v24.20.0-win-x64;%PATH%"

if "%~1"=="" (
    echo Maya AI Rummy Deployment Helper
    echo.
    echo Usage:
    echo   .\deploy.cmd login       - Login to Firebase CLI in your browser
    echo   .\deploy.cmd rules       - Deploy Firestore security rules only
    echo   .\deploy.cmd functions   - Deploy Cloud Functions only
    echo   .\deploy.cmd backend     - Deploy both Firestore rules and Cloud Functions
    echo   .\deploy.cmd hosting     - Deploy Firebase Hosting
    echo   .\deploy.cmd all         - Deploy everything to maya-rummy-vk
    exit /b 0
)

if /i "%~1"=="login" (
    call "%~dp0functions\node_modules\.bin\firebase.cmd" login
    exit /b %ERRORLEVEL%
)

if /i "%~1"=="rules" (
    call "%~dp0functions\node_modules\.bin\firebase.cmd" deploy --only firestore:rules --project maya-rummy-vk
    exit /b %ERRORLEVEL%
)

if /i "%~1"=="functions" (
    call "%~dp0functions\node_modules\.bin\firebase.cmd" deploy --only functions --project maya-rummy-vk
    exit /b %ERRORLEVEL%
)

if /i "%~1"=="hosting" (
    call "%~dp0functions\node_modules\.bin\firebase.cmd" deploy --only hosting --project maya-rummy-vk
    exit /b %ERRORLEVEL%
)

if /i "%~1"=="backend" (
    call "%~dp0functions\node_modules\.bin\firebase.cmd" deploy --only firestore:rules,functions --project maya-rummy-vk
    exit /b %ERRORLEVEL%
)

if /i "%~1"=="all" (
    call "%~dp0functions\node_modules\.bin\firebase.cmd" deploy --project maya-rummy-vk
    exit /b %ERRORLEVEL%
)

call "%~dp0functions\node_modules\.bin\firebase.cmd" %*
