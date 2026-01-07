<#
.SYNOPSIS
    Downloads all dependencies required to build Sunshine with multi-display support.

.DESCRIPTION
    This script downloads and sets up all the required dependencies for building
    Sunshine on Windows, including:
    - Git submodules (moonlight-common-c, libdisplaydevice, etc.)
    - Build dependencies (FFmpeg pre-compiled binaries)
    - vcpkg dependencies (curl, miniupnpc, openssl, etc.)

.EXAMPLE
    .\download-dependencies.ps1

.NOTES
    Run this from the Sunshine repository root directory.
    Requires: Git, PowerShell 5.1+, Internet connection
#>

param(
    [switch]$SkipSubmodules,
    [switch]$SkipVcpkg,
    [switch]$SkipBuildDeps,
    [string]$VcpkgRoot = "$env:USERPROFILE\vcpkg"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

Write-Host "=== Sunshine Dependency Downloader ===" -ForegroundColor Cyan
Write-Host "Repository: $RepoRoot"
Write-Host ""

# Change to repo root
Push-Location $RepoRoot

try {
    # Step 1: Initialize Git Submodules
    if (-not $SkipSubmodules) {
        Write-Host "Step 1: Initializing Git submodules..." -ForegroundColor Yellow

        # Initialize all submodules
        git submodule update --init --recursive
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Some submodules may have failed. Trying individually..."

            $submodules = @(
                "third-party/moonlight-common-c",
                "third-party/Simple-Web-Server",
                "third-party/libdisplaydevice",
                "third-party/inputtino",
                "third-party/nanors",
                "third-party/tray",
                "third-party/ViGEmClient",
                "third-party/nv-codec-headers",
                "third-party/nvapi-open-source-sdk",
                "third-party/googletest",
                "third-party/doxyconfig"
            )

            foreach ($submodule in $submodules) {
                Write-Host "  Initializing $submodule..."
                git submodule update --init --recursive $submodule 2>$null
            }
        }

        # Initialize nested submodules
        Push-Location "third-party/moonlight-common-c"
        git submodule update --init --recursive
        Pop-Location

        Write-Host "  Submodules initialized." -ForegroundColor Green
    }

    # Step 2: Download build-deps (FFmpeg pre-compiled binaries)
    if (-not $SkipBuildDeps) {
        Write-Host "Step 2: Downloading FFmpeg build dependencies..." -ForegroundColor Yellow

        $buildDepsPath = "third-party/build-deps"
        $buildDepsUrl = "https://github.com/LizardByte/build-deps/releases/latest/download"

        # Determine platform
        $platform = "Windows-x86_64"
        $ffmpegArchive = "ffmpeg-$platform.zip"
        $ffmpegUrl = "$buildDepsUrl/$ffmpegArchive"

        $distPath = "$buildDepsPath/dist/$platform"

        if (-not (Test-Path $distPath)) {
            New-Item -ItemType Directory -Force -Path $distPath | Out-Null
        }

        # Download FFmpeg binaries
        $downloadPath = "$env:TEMP\$ffmpegArchive"
        Write-Host "  Downloading from: $ffmpegUrl"

        try {
            Invoke-WebRequest -Uri $ffmpegUrl -OutFile $downloadPath -UseBasicParsing

            # Extract
            Write-Host "  Extracting to: $distPath"
            Expand-Archive -Path $downloadPath -DestinationPath $distPath -Force
            Remove-Item $downloadPath -Force

            Write-Host "  FFmpeg binaries downloaded." -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not download FFmpeg binaries. You may need to build them manually."
            Write-Warning "See: https://github.com/LizardByte/build-deps"
        }
    }

    # Step 3: Setup vcpkg and install dependencies
    if (-not $SkipVcpkg) {
        Write-Host "Step 3: Setting up vcpkg and installing dependencies..." -ForegroundColor Yellow

        # Clone vcpkg if not present
        if (-not (Test-Path $VcpkgRoot)) {
            Write-Host "  Cloning vcpkg to $VcpkgRoot..."
            git clone https://github.com/microsoft/vcpkg.git $VcpkgRoot
        }

        # Bootstrap vcpkg
        $vcpkgExe = "$VcpkgRoot\vcpkg.exe"
        if (-not (Test-Path $vcpkgExe)) {
            Write-Host "  Bootstrapping vcpkg..."
            Push-Location $VcpkgRoot
            .\bootstrap-vcpkg.bat
            Pop-Location
        }

        # Install required packages
        $packages = @(
            "curl:x64-windows",
            "miniupnpc:x64-windows",
            "openssl:x64-windows"
        )

        foreach ($package in $packages) {
            Write-Host "  Installing $package..."
            & $vcpkgExe install $package
        }

        Write-Host "  vcpkg dependencies installed." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Add the following to your CMake command:" -ForegroundColor Cyan
        Write-Host "    -DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot\scripts\buildsystems\vcpkg.cmake"
    }

    Write-Host ""
    Write-Host "=== Dependencies download complete! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "To build Sunshine:" -ForegroundColor Cyan
    Write-Host "  mkdir build"
    Write-Host "  cd build"
    Write-Host "  cmake .. -G `"Visual Studio 17 2022`" -DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot\scripts\buildsystems\vcpkg.cmake"
    Write-Host "  cmake --build . --config Release"
    Write-Host ""

}
finally {
    Pop-Location
}
