@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM GoXLR Utility - Windows build helper
REM Builds the Rust utility and creates the Windows NSIS installer.
REM Run this file from the repository root on Windows 10/11 x64.

cd /d "%~dp0"

echo.
echo ===============================================
echo   GoXLR Utility - Windows Release Build
echo ===============================================
echo.

where cargo >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Rust/Cargo was not found.
    echo Install Rust from https://rustup.rs/ and run this script again.
    exit /b 1
)

where rustup >nul 2>nul
if errorlevel 1 (
    echo [ERROR] rustup was not found. Please install Rust using rustup.
    exit /b 1
)

where makensis >nul 2>nul
if errorlevel 1 (
    echo [ERROR] NSIS was not found.
    echo Install NSIS 3.x, make sure makensis.exe is on PATH, then rerun.
    exit /b 1
)

REM Use the native Windows MSVC target.
rustup target add x86_64-pc-windows-msvc
if errorlevel 1 exit /b 1

REM Build the utility. The wallpaper UI is embedded in daemon/web-content.
echo.
echo [1/3] Building GoXLR Utility...
cargo build --manifest-path=Cargo.toml --release --all-features --target x86_64-pc-windows-msvc
if errorlevel 1 (
    echo [ERROR] Rust build failed.
    exit /b 1
)

REM The current installer expects these binaries in target\release.
if not exist target\release mkdir target\release
for %%F in (goxlr-daemon.exe goxlr-client.exe goxlr-defaults.exe goxlr-launcher.exe goxlr-firmware.exe) do (
    if exist target\x86_64-pc-windows-msvc\release\%%F copy /Y target\x86_64-pc-windows-msvc\release\%%F target\release\%%F >nul
)

REM Build the Windows UI wrapper used by the launcher/installer.
echo.
echo [2/3] Getting Windows UI wrapper...
if not exist goxlr-utility-ui (
    git clone --depth 1 https://github.com/GoXLR-on-Linux/goxlr-utility-ui-wrapper-app.git goxlr-utility-ui
    if errorlevel 1 (
        echo [ERROR] Could not clone the UI wrapper repository.
        exit /b 1
    )
)

where cargo-tauri >nul 2>nul
if errorlevel 1 (
    echo [INFO] cargo-tauri not found. Installing it...
    cargo install tauri-cli --locked
    if errorlevel 1 exit /b 1
)

cargo build --manifest-path=goxlr-utility-ui\src-tauri\Cargo.toml --target-dir=target --release
if errorlevel 1 (
    echo [ERROR] UI wrapper build failed.
    exit /b 1
)

REM The exact wrapper binary name can vary with the wrapper repository.
REM Copy the first matching Windows executable into target\release.
for /r "target\release" %%F in (goxlr-utility-ui.exe) do (
    copy /Y "%%F" "target\release\goxlr-utility-ui.exe" >nul
)

if not exist target\release\goxlr-daemon.exe (
    echo [ERROR] goxlr-daemon.exe was not produced.
    exit /b 1
)
if not exist target\release\goxlr-launcher.exe (
    echo [ERROR] goxlr-launcher.exe was not produced.
    exit /b 1
)

REM Build the installer. The NSIS script will place it in ci\Output.
echo.
echo [3/3] Building installer...
if not exist ci\Output mkdir ci\Output

set "PRODUCT_VERSION=1.2.4-wallpaper"
makensis /DPRODUCT_VERSION=%PRODUCT_VERSION% ci\nsis\goxlr-utility.nsi
if errorlevel 1 (
    echo [ERROR] NSIS installer build failed.
    exit /b 1
)

echo.
echo ===============================================
echo BUILD COMPLETE
echo ===============================================
echo Installer:
echo   %CD%\ci\Output\goxlr-utility-%PRODUCT_VERSION%.exe
echo.
echo NOTE: Install the official GoXLR Windows driver before running it.
echo ===============================================
exit /b 0
