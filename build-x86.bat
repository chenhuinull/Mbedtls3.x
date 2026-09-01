@echo off
REM Thin wrapper: always build 32-bit (x86). All other arguments
REM (debug/release/clean) are forwarded to build.bat.
REM Note: clean is also forwarded, so "Build-x86.bat clean" cleans both archs.

setlocal enabledelayedexpansion
set "FORWARD="
:parse
if "%~1"=="" goto run
if /i "%~1"=="x86" goto skip
if /i "%~1"=="x64" goto skip
set "FORWARD=!FORWARD! %~1"
:skip
shift
goto parse
:run
call "%~dp0Build.bat" x86%FORWARD%
exit /b %ERRORLEVEL%
