@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

set "PROJECT_NAME=mbedtls3.x"
set "PROJECT_DIR=%~dp0"
if "!PROJECT_DIR:~-1!"=="\" set "PROJECT_DIR=!PROJECT_DIR:~0,-1!"
cd /d "!PROJECT_DIR!"
title !PROJECT_NAME! Build

REM Usage: Build.bat [x86|x64] [debug|release|clean]
REM   x86    Build 32-bit DLL
REM   x64    Build 64-bit DLL (default)
REM   clean  Remove build and out directories
set "ARCH=x64"
set "BUILD_TYPE=Release"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="x86" ( set "ARCH=x86" ) else if /i "%~1"=="x64" ( set "ARCH=x64" ) else if /i "%~1"=="debug" ( set "BUILD_TYPE=Debug" ) else if /i "%~1"=="release" ( set "BUILD_TYPE=Release" ) else if /i "%~1"=="clean" ( goto clean ) else ( echo [ERROR] Unknown argument: %~1 & goto failed )
shift
goto parse_args
:args_done

if "!ARCH!"=="x86" (
    set "W64DEVKIT_DIR=!PROJECT_DIR!\Toolchain\w64devkit-x86"
    set "W64DEVKIT_SFX=!PROJECT_DIR!\Toolchain\w64devkit-x86.exe"
    set "BUILD_DIR=build-x86"
    set "OUTPUT_DIR=!PROJECT_DIR!\Out-x86"
) else (
    set "W64DEVKIT_DIR=!PROJECT_DIR!\Toolchain\w64devkit"
    set "W64DEVKIT_SFX=!PROJECT_DIR!\Toolchain\w64devkit.exe"
    set "BUILD_DIR=build"
    set "OUTPUT_DIR=!PROJECT_DIR!\Out"
)

set "W64DEVKIT_BIN=!W64DEVKIT_DIR!\bin"
set "CMAKE_EXE=!W64DEVKIT_BIN!\cmake.exe"
set "CC_EXE=!W64DEVKIT_BIN!\gcc.exe"
set "NINJA_EXE=!W64DEVKIT_BIN!\ninja.exe"

if not exist "!CC_EXE!" (
    if not exist "!W64DEVKIT_SFX!" (
        echo [ERROR] Missing !W64DEVKIT_SFX!
        goto failed
    )
    echo [INFO] Extracting w64devkit ^(!ARCH!^)...
    REM Extract to a staging dir first: both SFX archives unpack into a folder
    REM named "w64devkit", so a direct extraction would overwrite the other arch.
    set "SFX_STAGE=!PROJECT_DIR!\Toolchain\_sfx_stage_!ARCH!"
    if exist "!SFX_STAGE!" rmdir /s /q "!SFX_STAGE!"
    "!W64DEVKIT_SFX!" -y "-o!SFX_STAGE!" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to extract w64devkit.
        if exist "!SFX_STAGE!" rmdir /s /q "!SFX_STAGE!"
        goto failed
    )
    if not exist "!SFX_STAGE!\w64devkit\bin\gcc.exe" (
        echo [ERROR] Unexpected w64devkit archive layout.
        if exist "!SFX_STAGE!" rmdir /s /q "!SFX_STAGE!"
        goto failed
    )
    move "!SFX_STAGE!\w64devkit" "!W64DEVKIT_DIR!" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to move extracted w64devkit to !W64DEVKIT_DIR!
        if exist "!SFX_STAGE!" rmdir /s /q "!SFX_STAGE!"
        goto failed
    )
    rmdir /s /q "!SFX_STAGE!"
)

for %%F in ("!CMAKE_EXE!" "!CC_EXE!" "!NINJA_EXE!") do (
    if not exist "%%~F" (
        echo [ERROR] Missing w64devkit tool: %%~F
        goto failed
    )
)

REM Ensure GCC helper programs also come from this w64devkit package.
set "PATH=!W64DEVKIT_BIN!;!PATH!"

echo ============================================
echo  !PROJECT_NAME! Build
echo  Toolchain : !W64DEVKIT_DIR!
echo  Arch      : !ARCH!
echo  Mode      : !BUILD_TYPE!
echo  CRT       : UCRT
echo ============================================

echo.
echo [1/2] Configuring...
"!CMAKE_EXE!" -G Ninja -B !BUILD_DIR! -S . ^
    -DCMAKE_BUILD_TYPE=!BUILD_TYPE! ^
    -DCMAKE_C_COMPILER="!CC_EXE!" ^
    -DCMAKE_MAKE_PROGRAM="!NINJA_EXE!" ^
    -DCMAKE_C_FLAGS="-static-libgcc -mcrtdll=ucrt" ^
    -DUSE_SHARED_MBEDTLS_LIBRARY=On ^
    -DENABLE_TESTING=Off ^
    -DENABLE_PROGRAMS=Off
if errorlevel 1 (
    echo [ERROR] CMake configure failed.
    goto failed
)

echo.
echo [2/2] Building...
"!CMAKE_EXE!" --build !BUILD_DIR!
if errorlevel 1 (
    echo [ERROR] Build failed.
    goto failed
)

set "LIBRARY_DIR=!PROJECT_DIR!\!BUILD_DIR!\library"
set "FOUND_ARTIFACT=0"
for %%F in ("!LIBRARY_DIR!\libmbed*.dll" "!LIBRARY_DIR!\libmbed*.dll.a" "!LIBRARY_DIR!\libmbed*.a") do (
    if exist "%%~F" set "FOUND_ARTIFACT=1"
)
if "!FOUND_ARTIFACT!"=="0" (
    echo [ERROR] Shared-library artifacts not found in !LIBRARY_DIR!
    goto failed
)

if exist "!OUTPUT_DIR!" rmdir /s /q "!OUTPUT_DIR!"
mkdir "!OUTPUT_DIR!"
for %%F in ("!LIBRARY_DIR!\libmbed*.dll" "!LIBRARY_DIR!\libmbed*.dll.a" "!LIBRARY_DIR!\libmbed*.a") do (
    if exist "%%~F" (
        copy /y "%%~F" "!OUTPUT_DIR!\" >nul
        if errorlevel 1 (
            echo [ERROR] Failed to copy build artifact: %%~F
            goto failed
        )
    )
)

echo.
echo ============================================
echo  !PROJECT_NAME! SUCCESS ^(!ARCH! !BUILD_TYPE!^)
echo  Output: !OUTPUT_DIR!
echo ============================================

pause
exit /b 0

:clean
echo [CLEAN] Deleting build and Out directories...
if exist "build" rmdir /s /q "build"
if exist "build-x86" rmdir /s /q "build-x86"
if exist "Out" rmdir /s /q "Out"
if exist "Out-x86" rmdir /s /q "Out-x86"
echo [CLEAN] Done.
exit /b 0

:failed
pause
exit /b 1
