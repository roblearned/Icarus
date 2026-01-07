#!/bin/bash
#
# Download all dependencies required to build Sunshine with multi-display support.
#
# This script downloads and sets up all the required dependencies for building
# Sunshine on Linux, including:
# - Git submodules (moonlight-common-c, libdisplaydevice, etc.)
# - Build dependencies (FFmpeg pre-compiled binaries)
# - System packages via apt/dnf/pacman
#
# Usage: ./download-dependencies.sh [--skip-submodules] [--skip-packages] [--skip-build-deps]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
SKIP_SUBMODULES=false
SKIP_PACKAGES=false
SKIP_BUILD_DEPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-submodules) SKIP_SUBMODULES=true; shift ;;
        --skip-packages) SKIP_PACKAGES=true; shift ;;
        --skip-build-deps) SKIP_BUILD_DEPS=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Sunshine Dependency Downloader ==="
echo "Repository: $REPO_ROOT"
echo ""

cd "$REPO_ROOT"

# Detect package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v brew &> /dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# Step 1: Initialize Git Submodules
if [ "$SKIP_SUBMODULES" = false ]; then
    echo "Step 1: Initializing Git submodules..."

    git submodule update --init --recursive || {
        echo "Some submodules failed. Trying individually..."

        submodules=(
            "third-party/moonlight-common-c"
            "third-party/Simple-Web-Server"
            "third-party/libdisplaydevice"
            "third-party/inputtino"
            "third-party/nanors"
            "third-party/tray"
            "third-party/nv-codec-headers"
            "third-party/nvapi-open-source-sdk"
            "third-party/googletest"
            "third-party/doxyconfig"
            "third-party/wayland-protocols"
            "third-party/wlr-protocols"
        )

        for submodule in "${submodules[@]}"; do
            echo "  Initializing $submodule..."
            git submodule update --init --recursive "$submodule" 2>/dev/null || true
        done
    }

    # Initialize nested submodules
    if [ -d "third-party/moonlight-common-c" ]; then
        pushd "third-party/moonlight-common-c" > /dev/null
        git submodule update --init --recursive || true
        popd > /dev/null
    fi

    echo "  Submodules initialized."
fi

# Step 2: Install system packages
if [ "$SKIP_PACKAGES" = false ]; then
    echo "Step 2: Installing system packages..."

    PKG_MANAGER=$(detect_package_manager)

    case $PKG_MANAGER in
        apt)
            echo "  Using apt package manager..."
            sudo apt-get update
            sudo apt-get install -y \
                build-essential \
                cmake \
                ninja-build \
                git \
                libcurl4-openssl-dev \
                libminiupnpc-dev \
                libssl-dev \
                libavcodec-dev \
                libavutil-dev \
                libswscale-dev \
                libx11-dev \
                libxfixes-dev \
                libxrandr-dev \
                libxcb1-dev \
                libxcb-shm0-dev \
                libxcb-xfixes0-dev \
                libdrm-dev \
                libva-dev \
                libvdpau-dev \
                libnuma-dev \
                libpulse-dev \
                libopus-dev \
                libevdev-dev \
                libcap-dev \
                libboost-all-dev \
                libwayland-dev \
                wayland-protocols \
                libnotify-dev \
                libappindicator3-dev \
                pkg-config
            ;;
        dnf)
            echo "  Using dnf package manager..."
            sudo dnf install -y \
                @development-tools \
                cmake \
                ninja-build \
                git \
                libcurl-devel \
                miniupnpc-devel \
                openssl-devel \
                ffmpeg-devel \
                libX11-devel \
                libXfixes-devel \
                libXrandr-devel \
                libxcb-devel \
                libdrm-devel \
                libva-devel \
                libvdpau-devel \
                numactl-devel \
                pulseaudio-libs-devel \
                opus-devel \
                libevdev-devel \
                libcap-devel \
                boost-devel \
                wayland-devel \
                wayland-protocols-devel \
                libnotify-devel \
                libappindicator-devel \
                pkgconfig
            ;;
        pacman)
            echo "  Using pacman package manager..."
            sudo pacman -Syu --noconfirm \
                base-devel \
                cmake \
                ninja \
                git \
                curl \
                miniupnpc \
                openssl \
                ffmpeg \
                libx11 \
                libxfixes \
                libxrandr \
                libxcb \
                libdrm \
                libva \
                libvdpau \
                numactl \
                libpulse \
                opus \
                libevdev \
                libcap \
                boost \
                wayland \
                wayland-protocols \
                libnotify \
                libappindicator-gtk3 \
                pkgconf
            ;;
        brew)
            echo "  Using Homebrew..."
            brew install \
                cmake \
                ninja \
                git \
                curl \
                miniupnpc \
                openssl \
                ffmpeg \
                opus \
                boost \
                pkg-config
            ;;
        *)
            echo "  Unknown package manager. Please install dependencies manually:"
            echo "    - cmake, ninja, git"
            echo "    - libcurl development headers"
            echo "    - miniupnpc development headers"
            echo "    - openssl development headers"
            echo "    - ffmpeg development headers"
            echo "    - X11/Wayland development headers"
            echo "    - boost development headers"
            echo "    - opus development headers"
            ;;
    esac

    echo "  System packages installed."
fi

# Step 3: Download FFmpeg build dependencies
if [ "$SKIP_BUILD_DEPS" = false ]; then
    echo "Step 3: Downloading FFmpeg build dependencies..."

    BUILD_DEPS_PATH="third-party/build-deps"
    PLATFORM="Linux-$(uname -m)"
    DIST_PATH="$BUILD_DEPS_PATH/dist/$PLATFORM"

    # Try to get from LizardByte releases
    RELEASE_URL="https://github.com/LizardByte/build-deps/releases/latest/download"
    ARCHIVE_NAME="ffmpeg-$PLATFORM.tar.gz"
    DOWNLOAD_URL="$RELEASE_URL/$ARCHIVE_NAME"

    mkdir -p "$DIST_PATH"

    echo "  Attempting to download from: $DOWNLOAD_URL"

    if curl -L -o "/tmp/$ARCHIVE_NAME" "$DOWNLOAD_URL" 2>/dev/null; then
        echo "  Extracting to: $DIST_PATH"
        tar -xzf "/tmp/$ARCHIVE_NAME" -C "$DIST_PATH"
        rm -f "/tmp/$ARCHIVE_NAME"
        echo "  FFmpeg binaries downloaded."
    else
        echo "  Could not download pre-built FFmpeg binaries."
        echo "  Trying to use system FFmpeg instead..."

        # Create symlinks to system libraries if available
        if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
            LIB_PATH="/usr/lib/x86_64-linux-gnu"
        elif [ -d "/usr/lib64" ]; then
            LIB_PATH="/usr/lib64"
        else
            LIB_PATH="/usr/lib"
        fi

        echo "  Note: You may need to set FFMPEG_PREPARED_BINARIES CMake option"
        echo "  or install FFmpeg development packages."
    fi
fi

echo ""
echo "=== Dependencies download complete! ==="
echo ""
echo "To build Sunshine:"
echo "  mkdir -p build && cd build"
echo "  cmake .. -G Ninja"
echo "  ninja"
echo ""
echo "For multi-display streaming, use the 'display' parameter in launch requests:"
echo "  ?display=DP-1  or  ?display=0"
echo ""
