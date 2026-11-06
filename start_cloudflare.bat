@echo off
title FA26 Demo - Host Server ^& Cloudflare Tunnel

:: 1. Ensure local PostgreSQL is running on port 5432
netstat -ano | findstr ":5432 " | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    if exist "%LOCALAPPDATA%\Programs\PostgreSQL\pgsql\bin\pg_ctl.exe" (
        "%LOCALAPPDATA%\Programs\PostgreSQL\pgsql\bin\pg_ctl.exe" -D "%LOCALAPPDATA%\Programs\PostgreSQL\pgsql\data" -l "%LOCALAPPDATA%\Programs\PostgreSQL\pgsql\logfile.log" start
    )
)

:: 2. Launch pgAdmin 4 if it isn't already running
tasklist /FI "IMAGENAME eq pgAdmin4.exe" 2>NUL | find /I /N "pgAdmin4.exe">NUL
if %ERRORLEVEL% NEQ 0 (
    if exist "C:\Program Files\PostgreSQL\17\pgAdmin 4\runtime\pgAdmin4.exe" (
        echo Opening pgAdmin 4...
        start "" "C:\Program Files\PostgreSQL\17\pgAdmin 4\runtime\pgAdmin4.exe"
    ) else if exist "C:\Program Files\pgAdmin 4\runtime\pgAdmin4.exe" (
        echo Opening pgAdmin 4...
        start "" "C:\Program Files\pgAdmin 4\runtime\pgAdmin4.exe"
    ) else if exist "%LOCALAPPDATA%\Programs\pgAdmin 4\runtime\pgAdmin4.exe" (
        echo Opening pgAdmin 4...
        start "" "%LOCALAPPDATA%\Programs\pgAdmin 4\runtime\pgAdmin4.exe"
    )
)

:: 3. Start the separated Godot Server (Server.tscn) on port 8080 if not already running
netstat -ano | findstr ":8080 " | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    if exist "%USERPROFILE%\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" (
        echo Starting dedicated Godot Server on port 8080...
        start "FA26 Godot Dedicated Server (Port 8080)" "%USERPROFILE%\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path "%~dp0godot_poc" res://Server.tscn
        timeout /t 2 /nobreak >nul
    ) else (
        echo [Note] Run Server.tscn in Godot to listen on port 8080.
    )
)

:: 4. Start Cloudflare Tunnel using cloudflare/config.yml
echo Starting Cloudflare Tunnel using cloudflare\config.yml...
echo Copy the https://....trycloudflare.com link below into the Godot Client UI.
echo.

if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\cloudflared.exe" (
    "%LOCALAPPDATA%\Microsoft\WindowsApps\cloudflared.exe" tunnel --config "%~dp0cloudflare\config.yml"
) else (
    cloudflared tunnel --config "%~dp0cloudflare\config.yml"
)

pause
