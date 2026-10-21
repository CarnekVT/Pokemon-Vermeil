@echo off
cd /d "%~dp0"
where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    py -3 command_studio.py
) else (
    python command_studio.py
)
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error de inicio: comprueba que Python 3 con tkinter este instalado.
    pause
)
