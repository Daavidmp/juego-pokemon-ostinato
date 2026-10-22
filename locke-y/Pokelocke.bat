@echo off
rem Pokelocke: abre el lanzador en el navegador. Cierra esta ventana para apagarlo.
cd /d "%~dp0"
py -3 app\main.py
if errorlevel 1 pause
