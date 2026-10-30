@echo off
rem Vuelve a crear Pokelocke.exe. PyInstaller va en un entorno dentro de tools\, sin tocar el sistema.
cd /d "%~dp0.."
if not exist tools\build-venv (
  py -3 -m venv tools\build-venv
  tools\build-venv\Scripts\python -m pip install -q pyinstaller
)
tools\build-venv\Scripts\pyinstaller --noconfirm --onefile --noconsole --name Pokelocke --distpath . --workpath tools\build --specpath tools\build app\main.py
rem El que se reparte, el instalador: tools\instalador\PokelockeSetup.exe (ver README)
tools\build-venv\Scripts\python app\empaquetar.py
