@echo off
title Cloudflare Tunnel - FA26 Demo

:: Start local postgres if it isn't running already
netstat -ano | findstr ":5432 " | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    if exist "%LOCALAPPDATA%\Programs\PostgreSQL\pgsql\bin\pg_ctl.exe" (
        "%LOCALAPPDATA%\Programs\PostgreSQL\pgsql\bin\pg_ctl.exe" -D "%LOCALAPPDATA%\Programs\PostgreSQL\pgsql\data" -l "%LOCALAPPDATA%\Programs\PostgreSQL\pgsql\logfile.log" start
    )
)

echo Starting cloudflared tunnel on port 8080...
echo Copy the https://....trycloudflare.com link below into the Godot UI.
echo.

if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\cloudflared.exe" (
    "%LOCALAPPDATA%\Microsoft\WindowsApps\cloudflared.exe" tunnel --loglevel debug --url http://127.0.0.1:8080
) else (
    cloudflared tunnel --loglevel debug --url http://127.0.0.1:8080
)

pause
