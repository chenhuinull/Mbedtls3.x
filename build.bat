@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

set "PROJECT_NAME=mbedtls3.x"
set "PROJECT_DIR=%~dp0"
if "!PROJECT_DIR:~-1!"=="\" set "PROJECT_DIR=!PROJECT_DIR:~0,-1!"
cd /d "!PROJECT_DIR!"
title !PROJECT_NAME! Build

REM Usage: build.bat [debug|release] [clean]
set "BUILD_TYPE=Release"
for %%A in ("%~1" "%~2") do (
    if /i "%%~A"=="debug" set "BUILD_TYPE=Debug"
    if /i "%%~A"=="release" set "BUILD_TYPE=Release"
    if /i "%%~A"=="clean" goto clean
)

REM Fixed portable toolchain. No system toolchain fallback is allowed.
set "W64DEVKIT_DIR=!PROJECT_DIR!\DevEnv\w64devkit"
set "W64DEVKIT_BIN=!W64DEVKIT_DIR!\bin"
set "W64DEVKIT_SFX=!PROJECT_DIR!\DevEnv\w64devkit.exe"
set "CMAKE_EXE=!W64DEVKIT_BIN!\cmake.exe"
set "CC_EXE=!W64DEVKIT_BIN!\gcc.exe"
set "NINJA_EXE=!W64DEVKIT_BIN!\ninja.exe"

if not exist "!CC_EXE!" (
    if not exist "!W64DEVKIT_SFX!" (
        echo [ERROR] Missing !W64DEVKIT_SFX!
        goto failed
    )
    echo [INFO] Extracting w64devkit...
    "!W64DEVKIT_SFX!" -y "-o!PROJECT_DIR!\DevEnv" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to extract w64devkit.
        goto failed
    )
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
echo  Mode      : !BUILD_TYPE!
echo  CRT       : UCRT
echo ============================================

echo.
echo [1/2] Configuring...
"!CMAKE_EXE!" -G Ninja -B build -S . ^
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
"!CMAKE_EXE!" --build build
if errorlevel 1 (
    echo [ERROR] Build failed.
    goto failed
)

set "OUTPUT_DIR=!PROJECT_DIR!\out"
set "LIBRARY_DIR=!PROJECT_DIR!\build\library"
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
echo  !PROJECT_NAME! SUCCESS ^(!BUILD_TYPE!^)
echo  Output: !OUTPUT_DIR!
echo ============================================

pause
exit /b 0

:clean
echo [CLEAN] Deleting build and out directories...
if exist "build" rmdir /s /q "build"
if exist "out" rmdir /s /q "out"
echo [CLEAN] Done.
exit /b 0

:failed
pause
exit /b 1
