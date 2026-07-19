#!/usr/bin/env bash
# This script initializes directories for gocryptfs-based secret management
# Run this once after initial setup or if directories are missing

set -e

TARGET_USER="${SUDO_USER:-${USER:-$(whoami)}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

SECRET_DIR="${TARGET_HOME}/secret"
CIPHER_DIR="${TARGET_HOME}/.secret-encrypted"

echo "Setting up secret directories..."

# Create the mount point if it doesn't exist
if [[ ! -d $SECRET_DIR ]]; then
  echo "Creating mount point $SECRET_DIR..."
  mkdir -p "$SECRET_DIR"
  chmod 700 "$SECRET_DIR"
else
  echo "Mount point $SECRET_DIR already exists"
fi

# Create the encrypted storage directory if it doesn't exist
if [[ ! -d $CIPHER_DIR ]]; then
  echo "Creating encrypted storage $CIPHER_DIR..."
  mkdir -p "$CIPHER_DIR"
  chmod 700 "$CIPHER_DIR"
else
  echo "Encrypted storage $CIPHER_DIR already exists"
fi

# Create temp file for rofi if needed
touch /tmp/rofi 2>/dev/null || true

echo "Setup complete!"
echo "Run 's' (sudo secret-mgr) the first time to initialize and set your password"
echo "Then use 's' to mount/unmount and 'ss' to pick secrets with rofi"
