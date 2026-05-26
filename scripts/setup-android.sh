#!/bin/bash

# Omarchy Setup - Android / Expo Development Environment
# Sets up Android SDK, emulator, and shell environment for React Native / Expo development.
# Requires: android-studio (install via install-slow-packages.sh first)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ANDROID_SDK_DIR="/opt/android-sdk"
ANDROID_STUDIO_JBR="/opt/android-studio/jbr"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# SDK components to install
SDK_PACKAGES=(
    "platform-tools"
    "build-tools;35.0.0"
    "platforms;android-35"
    "emulator"
    "system-images;android-35;google_apis;x86_64"
)

# Emulator config
AVD_NAME="Pixel_API_35"
AVD_DEVICE="pixel_6"
AVD_IMAGE="system-images;android-35;google_apis;x86_64"

echo "=== Android / Expo Development Setup ==="
echo

# Check that Android Studio is installed
if [ ! -d "$ANDROID_STUDIO_JBR" ]; then
    echo "❌ Android Studio not found at /opt/android-studio"
    echo "   Install it first: yay -S android-studio"
    echo "   Or run: ./install-slow-packages.sh"
    exit 1
fi

# Set JAVA_HOME for this session (sdkmanager needs it)
export JAVA_HOME="$ANDROID_STUDIO_JBR"
export PATH="$JAVA_HOME/bin:$PATH"

# Ensure SDK directory exists and is writable
echo "📁 Setting up Android SDK directory..."
if [ ! -d "$ANDROID_SDK_DIR" ]; then
    sudo mkdir -p "$ANDROID_SDK_DIR"
fi
if [ ! -w "$ANDROID_SDK_DIR" ]; then
    sudo chmod -R a+w "$ANDROID_SDK_DIR"
    echo "   → Made $ANDROID_SDK_DIR writable"
else
    echo "   → $ANDROID_SDK_DIR already writable"
fi

# Install modern cmdline-tools (the old tools/bin/sdkmanager doesn't work with Java 11+)
SDKMANAGER="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
if [ ! -f "$SDKMANAGER" ]; then
    echo
    echo "📥 Downloading modern cmdline-tools..."
    TMP_ZIP=$(mktemp /tmp/cmdline-tools-XXXXXX.zip)
    TMP_DIR=$(mktemp -d /tmp/cmdline-tools-XXXXXX)
    curl -sL "$CMDLINE_TOOLS_URL" -o "$TMP_ZIP"
    unzip -qo "$TMP_ZIP" -d "$TMP_DIR"
    mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
    # Remove old install if present
    rm -rf "$ANDROID_SDK_DIR/cmdline-tools/latest"
    mv "$TMP_DIR/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
    rm -f "$TMP_ZIP"
    rm -rf "$TMP_DIR"
    echo "   → cmdline-tools installed"
else
    echo "   → cmdline-tools already installed"
fi

# Accept all licenses
echo
echo "📜 Accepting SDK licenses..."
yes | "$SDKMANAGER" --licenses > /dev/null 2>&1 || true
echo "   → Licenses accepted"

# Install SDK components
echo
echo "📦 Installing SDK components..."
for pkg in "${SDK_PACKAGES[@]}"; do
    pkg_dir="$ANDROID_SDK_DIR/$(echo "$pkg" | tr ';' '/')"
    if [ -d "$pkg_dir" ]; then
        echo "   → $pkg (already installed)"
    else
        echo "   → Installing $pkg..."
        "$SDKMANAGER" --install "$pkg" || echo "   ⚠️  Failed to install $pkg"
    fi
done
echo "   → SDK components ready"

# Create emulator AVD
echo
echo "📱 Setting up Android emulator..."
AVDMANAGER="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/avdmanager"
EMULATOR="$ANDROID_SDK_DIR/emulator/emulator"

# Check if AVD already exists (in either standard or XDG location)
AVD_EXISTS=false
if [ -f "$HOME/.android/avd/${AVD_NAME}.ini" ]; then
    AVD_EXISTS=true
elif [ -f "$HOME/.config/.android/avd/${AVD_NAME}.ini" ]; then
    AVD_EXISTS=true
fi

if [ "$AVD_EXISTS" = true ]; then
    echo "   → Emulator $AVD_NAME already exists"
else
    echo "no" | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "$AVD_IMAGE" -d "$AVD_DEVICE" > /dev/null 2>&1
    echo "   → Created emulator: $AVD_NAME"
fi

# Symlink AVD from XDG location to standard location if needed
# (some tools like avdmanager create AVDs in ~/.config/.android/ instead of ~/.android/)
if [ -d "$HOME/.config/.android/avd" ] && [ ! -L "$HOME/.android/avd/${AVD_NAME}.ini" ]; then
    if [ -f "$HOME/.config/.android/avd/${AVD_NAME}.ini" ]; then
        mkdir -p "$HOME/.android/avd"
        ln -sf "$HOME/.config/.android/avd/${AVD_NAME}.ini" "$HOME/.android/avd/${AVD_NAME}.ini"
        ln -sf "$HOME/.config/.android/avd/${AVD_NAME}.avd" "$HOME/.android/avd/${AVD_NAME}.avd"
        echo "   → Symlinked AVD to ~/.android/avd/ (emulator compatibility)"
    fi
fi

# Verify emulator can find the AVD
if [ -f "$EMULATOR" ]; then
    AVDS=$(ANDROID_HOME="$ANDROID_SDK_DIR" "$EMULATOR" -list-avds 2>/dev/null)
    if echo "$AVDS" | grep -q "$AVD_NAME"; then
        echo "   → Emulator verified: $AVD_NAME"
    else
        echo "   ⚠️  Emulator created but not detected. You may need to create one via Android Studio."
    fi
fi

# Add environment variables to ~/.bashrc
echo
echo "🔧 Configuring shell environment..."
BASHRC="$HOME/.bashrc"
CHANGED=false

if ! grep -q 'export JAVA_HOME=/opt/android-studio/jbr' "$BASHRC" 2>/dev/null; then
    echo '' >> "$BASHRC"
    echo '# Android / Expo development' >> "$BASHRC"
    echo 'export JAVA_HOME=/opt/android-studio/jbr' >> "$BASHRC"
    CHANGED=true
fi

if ! grep -q 'export ANDROID_HOME=/opt/android-sdk' "$BASHRC" 2>/dev/null; then
    [ "$CHANGED" = false ] && echo '' >> "$BASHRC"
    echo 'export ANDROID_HOME=/opt/android-sdk' >> "$BASHRC"
    CHANGED=true
fi

if ! grep -q 'ANDROID_HOME/platform-tools' "$BASHRC" 2>/dev/null; then
    echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator' >> "$BASHRC"
    CHANGED=true
fi

if [ "$CHANGED" = true ]; then
    echo "   → Added JAVA_HOME, ANDROID_HOME, and PATH to ~/.bashrc"
else
    echo "   → Shell environment already configured"
fi

echo
echo "✅ Android development environment ready!"
echo
echo "   Run 'source ~/.bashrc' to apply environment changes."
echo "   Then use 'expo run:android' or 'nr android' to build and run."
