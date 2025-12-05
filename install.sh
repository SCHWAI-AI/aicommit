#!/bin/sh
#
# AICommit Installation Script
# https://github.com/SCHW-AI/aicommit
#
# This script installs aicommit on your system.
# It detects your OS and architecture and downloads the appropriate binary.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/SCHW-AI/aicommit/main/install.sh | sh
#   wget -qO- https://raw.githubusercontent.com/SCHW-AI/aicommit/main/install.sh | sh
#

set -e

# Configuration
REPO_OWNER="SCHW-AI"
REPO_NAME="aicommit"
BINARY_NAME="aicommit"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
    exit 1
}

# Detect OS
detect_os() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$OS" in
        linux*)
            OS="linux"
            ;;
        darwin*)
            OS="darwin"
            ;;
        msys*|mingw*|cygwin*)
            OS="windows"
            ;;
        freebsd*)
            OS="freebsd"
            ;;
        openbsd*)
            OS="openbsd"
            ;;
        *)
            error "Unsupported OS: $OS"
            ;;
    esac
    echo "$OS"
}

# Detect architecture
detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        i386|i686)
            ARCH="386"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l|armv7)
            ARCH="arm"
            ARM_VERSION="7"
            ;;
        armv6l|armv6)
            ARCH="arm"
            ARM_VERSION="6"
            ;;
        *)
            error "Unsupported architecture: $ARCH"
            ;;
    esac
    echo "$ARCH"
}

# Get latest release version
get_latest_version() {
    if command -v curl > /dev/null 2>&1; then
        VERSION=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    elif command -v wget > /dev/null 2>&1; then
        VERSION=$(wget -qO- "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    else
        error "Neither curl nor wget found. Please install one of them."
    fi
    
    if [ -z "$VERSION" ]; then
        error "Failed to get latest version"
    fi
    
    echo "$VERSION"
}

# Download file
download_file() {
    URL="$1"
    OUTPUT="$2"
    
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL "$URL" -o "$OUTPUT"
    elif command -v wget > /dev/null 2>&1; then
        wget -q "$URL" -O "$OUTPUT"
    else
        error "Neither curl nor wget found. Please install one of them."
    fi
}

# Verify checksum
verify_checksum() {
    FILE="$1"
    CHECKSUM_URL="$2"
    
    info "Verifying checksum..."
    
    # Download checksums file
    CHECKSUMS_FILE="/tmp/checksums.txt"
    download_file "$CHECKSUM_URL" "$CHECKSUMS_FILE"
    
    # Extract expected checksum
    FILENAME=$(basename "$FILE")
    EXPECTED=$(grep "$FILENAME" "$CHECKSUMS_FILE" | awk '{print $1}')
    
    if [ -z "$EXPECTED" ]; then
        warn "Checksum not found for $FILENAME, skipping verification"
        return 0
    fi
    
    # Calculate actual checksum
    if command -v sha256sum > /dev/null 2>&1; then
        ACTUAL=$(sha256sum "$FILE" | awk '{print $1}')
    elif command -v shasum > /dev/null 2>&1; then
        ACTUAL=$(shasum -a 256 "$FILE" | awk '{print $1}')
    else
        warn "No checksum utility found, skipping verification"
        return 0
    fi
    
    # Compare checksums
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        error "Checksum verification failed"
    fi
    
    info "Checksum verified successfully"
}

# Install binary
install_binary() {
    OS="$1"
    ARCH="$2"
    VERSION="$3"
    
    # Construct download URL
    ARCHIVE_NAME="${BINARY_NAME}_${OS^}_"
    case "$ARCH" in
        amd64)
            ARCHIVE_NAME="${ARCHIVE_NAME}x86_64"
            ;;
        386)
            ARCHIVE_NAME="${ARCHIVE_NAME}i386"
            ;;
        *)
            ARCHIVE_NAME="${ARCHIVE_NAME}${ARCH}"
            ;;
    esac
    
    if [ "$OS" = "windows" ]; then
        ARCHIVE_NAME="${ARCHIVE_NAME}.zip"
    else
        ARCHIVE_NAME="${ARCHIVE_NAME}.tar.gz"
    fi
    
    DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/v$VERSION/$ARCHIVE_NAME"
    CHECKSUM_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/v$VERSION/checksums.txt"
    
    # Create temp directory
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    
    info "Downloading $BINARY_NAME v$VERSION for $OS/$ARCH..."
    
    # Download archive
    ARCHIVE_PATH="$TMP_DIR/$ARCHIVE_NAME"
    download_file "$DOWNLOAD_URL" "$ARCHIVE_PATH"
    
    # Verify checksum
    verify_checksum "$ARCHIVE_PATH" "$CHECKSUM_URL"
    
    # Extract archive
    info "Extracting archive..."
    cd "$TMP_DIR"
    if [ "$OS" = "windows" ]; then
        unzip -q "$ARCHIVE_NAME"
    else
        tar -xzf "$ARCHIVE_NAME"
    fi
    
    # Find binary
    if [ "$OS" = "windows" ]; then
        BINARY_FILE="$BINARY_NAME.exe"
    else
        BINARY_FILE="$BINARY_NAME"
    fi
    
    if [ ! -f "$BINARY_FILE" ]; then
        error "Binary not found in archive"
    fi
    
    # Check if we need sudo
    if [ -w "$INSTALL_DIR" ]; then
        SUDO=""
    else
        SUDO="sudo"
        warn "Installation requires sudo privileges"
    fi
    
    # Install binary
    info "Installing $BINARY_NAME to $INSTALL_DIR..."
    $SUDO mkdir -p "$INSTALL_DIR"
    $SUDO mv "$BINARY_FILE" "$INSTALL_DIR/"
    $SUDO chmod +x "$INSTALL_DIR/$BINARY_FILE"
    
    # Verify installation
    if command -v "$BINARY_NAME" > /dev/null 2>&1; then
        info "Installation successful!"
        info ""
        info "Run '$BINARY_NAME --help' to get started"
        info ""
        info "Next steps:"
        info "  1. Get an API key from https://aistudio.google.com/apikey"
        info "  2. Set your API key: export GEMINI_API_KEY='your-key'"
        info "  3. Navigate to a git repository and run: aicommit"
    else
        warn "Installation completed but $BINARY_NAME not found in PATH"
        warn "You may need to add $INSTALL_DIR to your PATH"
        warn "Add this to your shell profile:"
        warn "  export PATH=\"\$PATH:$INSTALL_DIR\""
    fi
}

# Check for package manager installation
suggest_package_manager() {
    OS="$1"
    
    info ""
    info "Alternative installation methods:"
    
    case "$OS" in
        darwin)
            if command -v brew > /dev/null 2>&1; then
                info "  Using Homebrew:"
                info "    brew tap SCHW-AI/tap"
                info "    brew install aicommit"
            fi
            ;;
        linux)
            if command -v apt > /dev/null 2>&1; then
                info "  Using APT:"
                info "    echo 'deb [trusted=yes] https://apt.schwai.ai/ /' | sudo tee /etc/apt/sources.list.d/schwai.list"
                info "    sudo apt update && sudo apt install aicommit"
            elif command -v yum > /dev/null 2>&1; then
                info "  Using YUM:"
                info "    sudo yum-config-manager --add-repo https://rpm.schwai.ai/aicommit.repo"
                info "    sudo yum install aicommit"
            elif command -v pacman > /dev/null 2>&1; then
                info "  Using Pacman:"
                info "    yay -S aicommit"
            fi
            ;;
        windows)
            info "  Using Scoop:"
            info "    scoop bucket add schwai https://github.com/SCHW-AI/scoop-bucket"
            info "    scoop install aicommit"
            info ""
            info "  Using Chocolatey:"
            info "    choco install aicommit"
            info ""
            info "  Using WinGet:"
            info "    winget install SCHWAI.AICommit"
            ;;
    esac
}

# Main installation flow
main() {
    info "AICommit Installer"
    info "=================="
    info ""
    
    # Detect system
    OS=$(detect_os)
    ARCH=$(detect_arch)
    info "Detected: $OS/$ARCH"
    
    # Get latest version
    info "Getting latest version..."
    VERSION=$(get_latest_version)
    info "Latest version: v$VERSION"
    
    # Install
    install_binary "$OS" "$ARCH" "$VERSION"
    
    # Suggest package manager
    suggest_package_manager "$OS"
}

# Run main function
main "$@"
