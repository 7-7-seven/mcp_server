@echo off
:: =============================================================================
:: Odoo MCP Server — Setup Script for Windows
:: Usage: Double-click setup.bat  OR  run from Command Prompt
:: =============================================================================

setlocal EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%config.json"

echo.
echo  ==========================================
echo       Odoo MCP Server - Setup Wizard
echo  ==========================================
echo.

:: ── Step 1: Check Python ─────────────────────────────────────────
echo [1/5] Checking Python...

:: Try python3 first, then python, then py launcher
set "PYTHON_BIN="

where python3 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=*" %%i in ('where python3') do (
        if "!PYTHON_BIN!"=="" set "PYTHON_BIN=%%i"
    )
)

if "!PYTHON_BIN!"=="" (
    where python >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        for /f "tokens=*" %%i in ('where python') do (
            if "!PYTHON_BIN!"=="" set "PYTHON_BIN=%%i"
        )
    )
)

if "!PYTHON_BIN!"=="" (
    where py >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        for /f "tokens=*" %%i in ('where py') do (
            if "!PYTHON_BIN!"=="" set "PYTHON_BIN=%%i"
        )
    )
)

if "!PYTHON_BIN!"=="" (
    echo  ERROR: Python not found.
    echo  Download from https://www.python.org/downloads/
    echo  Make sure to check "Add Python to PATH" during install.
    pause
    exit /b 1
)

:: Verify it is actually Python 3 (not Python 2)
for /f "tokens=2 delims= " %%v in ('"!PYTHON_BIN!" --version 2^>^&1') do set PYVER=%%v
for /f "tokens=1 delims=." %%m in ("!PYVER!") do set PY_MAJOR=%%m
if "!PY_MAJOR!" LSS "3" (
    echo  ERROR: Python 3 is required but found Python !PYVER! at !PYTHON_BIN!
    echo  Download Python 3 from https://www.python.org/downloads/
    pause
    exit /b 1
)

echo  OK: Python !PYVER! at !PYTHON_BIN!

:: ── Step 2: Install dependencies ─────────────────────────────────
echo.
echo [2/5] Installing Python dependencies...
"!PYTHON_BIN!" -m pip install --quiet --upgrade mcp requests
if %ERRORLEVEL% NEQ 0 (
    echo  ERROR: pip install failed. Try running as Administrator.
    pause
    exit /b 1
)
echo  OK: mcp, requests installed

:: ── Step 3: Collect Odoo connection details ───────────────────────
echo.
echo [3/5] Odoo connection details
echo       (Press Enter to keep the default shown in brackets)
echo.

set "ODOO_URL="
set /p "ODOO_URL=  Odoo URL          [http://localhost:8069]: "
if "!ODOO_URL!"=="" set "ODOO_URL=http://localhost:8069"

:ask_db
set "ODOO_DB="
set /p "ODOO_DB=  Database name     : "
if "!ODOO_DB!"=="" (
    echo   ERROR: Database name is required.
    goto ask_db
)

:ask_token
set "ODOO_TOKEN="
set /p "ODOO_TOKEN=  API Token (Bearer): "
if "!ODOO_TOKEN!"=="" (
    echo   ERROR: Token is required. Generate one in Odoo - MCP Server - Configurations.
    goto ask_token
)

:: ── Step 4: Test connection ───────────────────────────────────────
echo.
echo [4/5] Testing Odoo connection...
curl -s -o "%TEMP%\mcp_health.json" -w "%%{http_code}" ^
    "%ODOO_URL%/mcp/health" ^
    -H "X-Odoo-Database: !ODOO_DB!" > "%TEMP%\mcp_status.txt" 2>nul

set /p HTTP_STATUS=<"%TEMP%\mcp_status.txt"
if "!HTTP_STATUS!"=="200" (
    set /p HEALTH_RESP=<"%TEMP%\mcp_health.json"
    echo  OK: Connected! !HEALTH_RESP!
) else (
    echo  WARNING: Could not reach Odoo (HTTP !HTTP_STATUS!^). Is Odoo running?
    set /p "CONTINUE=  Continue anyway? [y/N]: "
    if /i not "!CONTINUE!"=="y" exit /b 1
)

:: ── Step 5: Write config.json ─────────────────────────────────────
echo.
echo [5/5] Writing config and Claude Desktop config...

(
    echo {
    echo   "odoo_url":   "!ODOO_URL!",
    echo   "odoo_db":    "!ODOO_DB!",
    echo   "odoo_token": "!ODOO_TOKEN!"
    echo }
) > "%CONFIG_FILE%"
echo  OK: Saved config.json

:: Detect Claude config path on Windows
set "CLAUDE_CONFIG=%APPDATA%\Claude\claude_desktop_config.json"
if not exist "%APPDATA%\Claude" mkdir "%APPDATA%\Claude"

"!PYTHON_BIN!" -c ^
"import json,os; ^
cfg=json.load(open(r'%CLAUDE_CONFIG%')) if os.path.exists(r'%CLAUDE_CONFIG%') else {}; ^
cfg.setdefault('mcpServers',{})['odoo']={'command':r'!PYTHON_BIN!','args':[r'%SCRIPT_DIR%server.py']}; ^
json.dump(cfg,open(r'%CLAUDE_CONFIG%','w'),indent=2); ^
print('OK: Saved',r'%CLAUDE_CONFIG%')"

:: ── Done ──────────────────────────────────────────────────────────
echo.
echo  ==========================================
echo           Setup complete!
echo  ==========================================
echo.
echo   Next steps:
echo   1. Restart Claude Desktop
echo   2. Look for the hammer icon in the chat input
echo   3. Ask Claude: "Search for partners in Odoo"
echo.
pause
