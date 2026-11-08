@echo off
rem Runs every automated test without opening the game.
rem Finds Godot in GODOT_DIR automatically (prefers the *console* .exe, which shows output).
rem Edit GODOT_DIR if your Godot lives somewhere else.
set GODOT_DIR=C:\Users\johnd\Desktop\Game Dev\Tools\Godot
set GODOT=
for %%f in ("%GODOT_DIR%\Godot*.exe") do set GODOT=%%f
for %%f in ("%GODOT_DIR%\Godot*console*.exe") do set GODOT=%%f
if not defined GODOT (
  echo Couldn't find a Godot .exe in %GODOT_DIR%
  echo Edit run_tests.bat and set GODOT_DIR to the folder your Godot .exe is in.
  pause
  exit /b 1
)
echo Using %GODOT%
echo Scanning the project first (so Godot knows every script's name)...
"%GODOT%" --headless --path "%~dp0." --import >nul 2>&1
echo.
echo Running tests...
"%GODOT%" --headless --fixed-fps 120 --path "%~dp0." -s res://addons/agent_kit/run_tests.gd %*
echo.
pause
