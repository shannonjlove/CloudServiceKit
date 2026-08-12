#!/usr/bin/env bash
#
# Cloud Agent install script for CloudServiceKit.
#
# CloudServiceKit is an iOS/tvOS Swift package (it uses UIKit, CryptoKit and
# AuthenticationServices, and depends on OAuthSwift). It can only be *built and
# run* on macOS with Xcode. On a Linux Cloud Agent this script installs the
# upstream Swift toolchain so agents can resolve dependencies, inspect the
# package, and edit/navigate the Swift sources with full tooling.
#
# The script is idempotent: it is safe to run repeatedly.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SWIFTLY_HOME_DIR="${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}"

echo "==> Installing Swift toolchain system dependencies"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq \
  binutils \
  git \
  gnupg2 \
  libc6-dev \
  libcurl4-openssl-dev \
  libedit2 \
  libgcc-13-dev \
  libncurses-dev \
  libpython3-dev \
  libsqlite3-0 \
  libstdc++-13-dev \
  libxml2-dev \
  libz3-dev \
  pkg-config \
  tzdata \
  zip \
  unzip \
  zlib1g-dev

if [ ! -x "$SWIFTLY_HOME_DIR/bin/swiftly" ]; then
  echo "==> Installing Swift via swiftly"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/swiftly.tar.gz" \
    "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
  tar zxf "$tmp/swiftly.tar.gz" -C "$tmp"
  "$tmp/swiftly" init --quiet-shell-followup --assume-yes
  rm -rf "$tmp"
else
  echo "==> swiftly already installed, skipping toolchain install"
fi

# Make swift available for the rest of this script.
# shellcheck disable=SC1091
. "$SWIFTLY_HOME_DIR/env.sh"
hash -r

# Ensure non-login interactive shells (which read .bashrc) also find swift.
# swiftly only wires up .profile by default.
if ! grep -q 'swiftly/env.sh' "$HOME/.bashrc" 2>/dev/null; then
  {
    echo ''
    echo '# Added by CloudServiceKit .cursor/setup.sh'
    echo '. "$HOME/.local/share/swiftly/env.sh"'
  } >> "$HOME/.bashrc"
fi

echo "==> Resolving Swift package dependencies (pinned by Package.resolved)"
# `swift package resolve` rewrites Package.resolved with Linux-only transitive
# deps (OAuthSwift pulls in swift-crypto, Swifter, Kanna, etc. on Linux). Preserve
# the committed iOS/tvOS Package.resolved so the working tree stays clean.
resolved_file="$REPO_ROOT/Package.resolved"
resolved_backup=""
if [ -f "$resolved_file" ]; then
  resolved_backup="$(mktemp)"
  cp "$resolved_file" "$resolved_backup"
fi
swift package resolve --package-path "$REPO_ROOT"
if [ -n "$resolved_backup" ]; then
  mv "$resolved_backup" "$resolved_file"
fi

echo "==> Swift toolchain ready"
swift --version
