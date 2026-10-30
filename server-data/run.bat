@echo off
setlocal
set "SERVER_CFG_PATH="
set "SERVER_DATA_DIR="
set "FXSERVER_EXE="

if exist "%~dp0server-data\server.cfg" set "SERVER_CFG_PATH=%~dp0server-data\server.cfg"
if not defined SERVER_CFG_PATH if exist "%~dp0server.cfg" set "SERVER_CFG_PATH=%~dp0server.cfg"
if not defined SERVER_CFG_PATH for /r "%~dp0" %%F in (server.cfg) do if not defined SERVER_CFG_PATH (
  findstr /i /r /c:"^[ ]*sv_licenseKey[ ]*" "%%~fF" >nul 2>nul && set "SERVER_CFG_PATH=%%~fF"
)
if not defined SERVER_CFG_PATH for /r "%~dp0" %%F in (server.cfg) do if not defined SERVER_CFG_PATH set "SERVER_CFG_PATH=%%~fF"
if defined SERVER_CFG_PATH for %%I in ("%SERVER_CFG_PATH%") do set "SERVER_DATA_DIR=%%~dpI"

if not defined FXSERVER_EXE if exist "%~dp0server\FXServer.exe" set "FXSERVER_EXE=%~dp0server\FXServer.exe"
if not defined FXSERVER_EXE if exist "%~dp0FXServer.exe" set "FXSERVER_EXE=%~dp0FXServer.exe"
if not defined FXSERVER_EXE if defined SERVER_DATA_DIR if exist "%SERVER_DATA_DIR%\..\server\FXServer.exe" set "FXSERVER_EXE=%SERVER_DATA_DIR%\..\server\FXServer.exe"
if not defined FXSERVER_EXE if defined SERVER_DATA_DIR if exist "%SERVER_DATA_DIR%\..\FXServer.exe" set "FXSERVER_EXE=%SERVER_DATA_DIR%\..\FXServer.exe"
if not defined FXSERVER_EXE for /r "%~dp0" %%F in (FXServer.exe) do if not defined FXSERVER_EXE set "FXSERVER_EXE=%%~fF"

if not defined SERVER_DATA_DIR (
  echo Could not find server.cfg in this server folder.
  pause
  exit /b 1
)

if not defined FXSERVER_EXE (
  echo Could not find FXServer.exe in this server folder.
  pause
  exit /b 1
)

cd /d "%SERVER_DATA_DIR%"
echo Using config: "%SERVER_CFG_PATH%"
"%FXSERVER_EXE%" +set onesync on +exec "%SERVER_CFG_PATH%"
pause
endlocal