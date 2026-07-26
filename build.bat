@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

REM --- Project settings ---
set "PROJECT_NAME=Mbed TLS 3.x"
title !PROJECT_NAME! Build

REM ============================================================
REM  !PROJECT_NAME! -- One-click build script
REM  Usage: build.bat [debug|release|clean] [/ninja|/make]
REM ============================================================

REM --- Tool paths (edit if needed) ---
set "BASE_PATH=D:\Project\DevEnv"
set "MINGW_PATH=!BASE_PATH!\mingw64"
set "CMAKE_PATH=!BASE_PATH!\cmake"
set "NINJA_PATH=!BASE_PATH!\ninja"

REM ============================================================
REM  Resolve toolchain: hardcoded path -> system PATH -> error
REM ============================================================

REM --- Resolve CMake ---
set "CMAKE_EXE=!CMAKE_PATH!\bin\cmake.exe"
if not exist "!CMAKE_EXE!" (
    echo [INFO] CMake not found at hardcoded path, searching PATH...
    set "CMAKE_EXE="
    for /f "delims=" %%i in ('where cmake 2^>nul') do (
        set "CMAKE_EXE=%%i"
        goto :cmake_found
    )
    :cmake_found
    if "!CMAKE_EXE!"=="" (
        echo [ERROR] cmake.exe not found.
        echo        Please install CMake or edit CMAKE_PATH in build.bat.
        pause
        exit /b 1
    )
    for %%i in ("!CMAKE_EXE!") do set "CMAKE_BIN=%%~dpi"
    set "CMAKE_PATH=!CMAKE_BIN:~0,-1!"
    echo [INFO] Found CMake at: !CMAKE_PATH!
)

REM --- Resolve MinGW ---
set "CC_EXE=!MINGW_PATH!\bin\gcc.exe"
if not exist "!CC_EXE!" (
    echo [INFO] MinGW not found at hardcoded path, searching PATH...
    set "CC_EXE="
    for /f "delims=" %%i in ('where gcc 2^>nul') do (
        set "CC_EXE=%%i"
        goto :cc_found
    )
    :cc_found
    if "!CC_EXE!"=="" (
        echo [ERROR] gcc.exe not found.
        echo        Please install MinGW-w64 or edit MINGW_PATH in build.bat.
        pause
        exit /b 1
    )
    for %%i in ("!CC_EXE!") do set "CC_BIN=%%~dpi"
    set "CC_BIN=!CC_BIN:~0,-1!"
    for %%i in ("!CC_BIN!") do set "MINGW_PATH=%%~dpi"
    set "MINGW_PATH=!MINGW_PATH:~0,-1!"
    echo [INFO] Found MinGW at: !MINGW_PATH!
)

REM --- Resolve Ninja (optional; fallback to MinGW Makefiles) ---
set "NINJA_EXE=!NINJA_PATH!\ninja.exe"
if not exist "!NINJA_EXE!" (
    set "NINJA_EXE="
    for /f "delims=" %%i in ('where ninja 2^>nul') do (
        set "NINJA_EXE=%%i"
        goto :ninja_found
    )
    :ninja_found
    rem.
)
if "!NINJA_EXE!"=="" (
    echo [INFO] Ninja not found, falling back to MinGW Makefiles
    set "CMAKE_GENERATOR=MinGW Makefiles"
) else (
    echo [INFO] Found Ninja at: !NINJA_EXE!
    set "CMAKE_GENERATOR=Ninja"
)

REM --- Setup PATH ---
set "PATH=!MINGW_PATH!\bin;!PATH!"
if not "!NINJA_EXE!"=="" (
    for %%i in ("!NINJA_EXE!") do set "NINJA_BIN=%%~dpi"
    set "PATH=!NINJA_BIN:~0,-1!;!PATH!"
)

REM --- Enter project directory ---
set "PROJECT_DIR=%~dp0"
if "!PROJECT_DIR:~-1!"=="\" set "PROJECT_DIR=!PROJECT_DIR:~0,-1!"
cd /d "!PROJECT_DIR!"

REM --- Parse arguments ---
set "BUILD_TYPE=Release"
set "DO_CLEAN=0"
if /i "%1"=="debug"    set "BUILD_TYPE=Debug"
if /i "%2"=="debug"    set "BUILD_TYPE=Debug"
if /i "%1"=="release"  set "BUILD_TYPE=Release"
if /i "%2"=="release"  set "BUILD_TYPE=Release"
if /i "%1"=="clean"    (set "DO_CLEAN=1" & set "BUILD_TYPE=Release")
if /i "%2"=="clean"    (set "DO_CLEAN=1" & set "BUILD_TYPE=Release")
if /i "%1"=="/ninja"   set "CMAKE_GENERATOR=Ninja"
if /i "%2"=="/ninja"   set "CMAKE_GENERATOR=Ninja"
if /i "%1"=="/make"    set "CMAKE_GENERATOR=MinGW Makefiles"
if /i "%2"=="/make"    set "CMAKE_GENERATOR=MinGW Makefiles"

REM --- Clean ---
if "!DO_CLEAN!"=="1" (
    echo [CLEAN] Deleting build and out directories...
    if exist "build" rmdir /s /q build
    if exist "out"   rmdir /s /q out
    echo [CLEAN] Done.
    exit /b 0
)

REM --- Build info ---
echo ============================================
echo  !PROJECT_NAME! Build
echo  CMake  : !CMAKE_EXE!
echo  CC     : !CC_EXE!
echo  Gen    : !CMAKE_GENERATOR!
echo  Mode   : !BUILD_TYPE!
echo ============================================

REM --- Configure ---
echo.
echo [1/2] Configuring ^(!BUILD_TYPE!^)...
set "CC=!CC_EXE!"
"!CMAKE_EXE!" -G "!CMAKE_GENERATOR!" -B build -S . -DCMAKE_BUILD_TYPE=!BUILD_TYPE! -DENABLE_TESTING=Off -DENABLE_PROGRAMS=Off -DUSE_SHARED_MBEDTLS_LIBRARY=On -DCMAKE_C_FLAGS=-static-libgcc
if errorlevel 1 (
    echo [ERROR] CMake configure failed ^(code !errorlevel!^)
    pause
    exit /b !errorlevel!
)

REM --- Build ---
echo.
echo [2/2] Building ^(!BUILD_TYPE!^)...
"!CMAKE_EXE!" --build build
if errorlevel 1 (
    echo [ERROR] Build failed ^(code !errorlevel!^)
    pause
    exit /b !errorlevel!
)

REM --- Copy output ---
echo.
echo === Copying to out\ ===
if exist "out" rmdir /s /q "out"
mkdir "out"
xcopy /y /q "build\library\libmbed*.*" "out\" >nul

REM --- Done ---
echo.
echo ============================================
echo  !PROJECT_NAME! SUCCESS ^(!BUILD_TYPE!^)
echo ============================================
echo  Output: out\
for %%F in ("out\*") do echo   %%~nxF  %%~zF bytes
echo ============================================
pause
