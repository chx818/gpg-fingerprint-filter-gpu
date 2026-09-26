@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo Building gpg-fingerprint-filter-gpu for Windows (x64)
echo =======================================================

set "GCC=%LOCALAPPDATA%\Microsoft\WinGet\Packages\BrechtSanders.WinLibs.POSIX.UCRT_Microsoft.Winget.Source_8wekyb3d8bbwe\mingw64\bin\g++.exe"
if not exist "!GCC!" (
    where g++ >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        set "GCC=g++"
    ) else (
        echo [ERROR] MinGW g++ not found!
        exit /b 1
    )
)

set "CUDA_INC=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0\include"
set "CUDA_LIB=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0\lib\x64"
set "GPG_INC=C:\Program Files\GnuPG\include"
set "GCRYPT_DLL=C:\Program Files\GnuPG\bin\libgcrypt-20.dll"

echo [1/2] Compiling C++ source files...
"!GCC!" -O3 -std=c++14 -static-libgcc -static-libstdc++ ^
    -I"." -I"!CUDA_INC!" -I"!GPG_INC!" ^
    main.cpp key_test.cpp key_test_pattern.cpp gpg_helper.cpp ^
    -L"!CUDA_LIB!" -lcuda -lnvrtc "!GCRYPT_DLL!" ^
    -o "gpg-fingerprint-filter-gpu.exe"

if !ERRORLEVEL! NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b !ERRORLEVEL!
)

echo [2/2] Updating dist\windows release...
if not exist "dist\windows" mkdir "dist\windows"
copy /y "gpg-fingerprint-filter-gpu.exe" "dist\windows\" >nul
copy /y "!GCRYPT_DLL!" "dist\windows\" >nul
copy /y "C:\Program Files\GnuPG\bin\libgpg-error-0.dll" "dist\windows\" >nul
copy /y "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0\bin\x64\nvrtc64_130_0.dll" "dist\windows\" >nul
copy /y "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0\bin\x64\nvrtc-builtins64_130.dll" "dist\windows\" >nul

echo Build finished successfully: dist\windows\gpg-fingerprint-filter-gpu.exe
