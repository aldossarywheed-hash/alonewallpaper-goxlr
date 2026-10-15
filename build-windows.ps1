$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host '=== GoXLR Utility Windows Release Build ===' -ForegroundColor Cyan

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Cargo/Rust was not found. Install Rust from https://rustup.rs/ first.'
}
if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
    throw 'rustup was not found. Install Rust using rustup.'
}
if (-not (Get-Command makensis -ErrorAction SilentlyContinue)) {
    throw 'NSIS was not found. Install NSIS 3.x and put makensis.exe on PATH.'
}

rustup target add x86_64-pc-windows-msvc

Write-Host '[1/3] Building utility...' -ForegroundColor Yellow
cargo build --manifest-path=Cargo.toml --release --all-features --target x86_64-pc-windows-msvc

New-Item -ItemType Directory -Force target\release | Out-Null
$bins = 'goxlr-daemon.exe','goxlr-client.exe','goxlr-defaults.exe','goxlr-launcher.exe','goxlr-firmware.exe'
foreach ($bin in $bins) {
    $src = Join-Path 'target\x86_64-pc-windows-msvc\release' $bin
    if (Test-Path $src) { Copy-Item $src (Join-Path 'target\release' $bin) -Force }
}

Write-Host '[2/3] Getting/building UI wrapper...' -ForegroundColor Yellow
if (-not (Test-Path 'goxlr-utility-ui')) {
    git clone --depth 1 https://github.com/GoXLR-on-Linux/goxlr-utility-ui-wrapper-app.git goxlr-utility-ui
}

if (-not (Get-Command cargo-tauri -ErrorAction SilentlyContinue)) {
    cargo install tauri-cli --locked
}

cargo build --manifest-path=goxlr-utility-ui\src-tauri\Cargo.toml --target-dir=target --release

Write-Host '[3/3] Building NSIS installer...' -ForegroundColor Yellow
New-Item -ItemType Directory -Force ci\Output | Out-Null
$version = '1.2.4-wallpaper'
& makensis "/DPRODUCT_VERSION=$version" 'ci\nsis\goxlr-utility.nsi'
if ($LASTEXITCODE -ne 0) { throw 'NSIS installer build failed.' }

Write-Host "`nDONE: $((Resolve-Path "ci\Output\goxlr-utility-$version.exe").Path)" -ForegroundColor Green
