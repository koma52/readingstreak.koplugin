@echo off
REM Convert PO files to MO files for all locales (Windows batch script)
REM This script requires gettext tools (msgfmt.exe) to be in PATH

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PLUGIN_DIR=%SCRIPT_DIR%.."
set "L10N_DIR=%PLUGIN_DIR%\l10n"

if not exist "%L10N_DIR%" (
    echo Error: l10n directory not found at %L10N_DIR%
    exit /b 1
)

REM Check if msgfmt is available
where msgfmt >nul 2>&1
if errorlevel 1 (
    echo Error: msgfmt command not found. Please install gettext tools.
    echo Download from: https://mlocati.github.io/articles/gettext-iconv-windows.html
    exit /b 1
)

REM Convert all PO files to MO files
for /d %%d in ("%L10N_DIR%\*") do (
    if exist "%%d\readingstreak.po" (
        echo Converting %%d\readingstreak.po to %%d\readingstreak.mo...
        msgfmt -o "%%d\readingstreak.mo" "%%d\readingstreak.po"
        if !errorlevel! equ 0 (
            echo Successfully converted %%~nxd\readingstreak.po
        ) else (
            echo Failed to convert %%~nxd\readingstreak.po
            exit /b 1
        )
    )
)

echo All PO files converted successfully!

