@echo off
REM Trae el contenido del place a src/. Funciona desde cualquier PC: se situa
REM en la carpeta donde esta este .bat en lugar de una ruta fija.
cd /d "%~dp0"
rojo syncback --input "ññññññ.rbxl" default.project.json
echo Syncback completado!
pause
