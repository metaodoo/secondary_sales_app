#!/usr/bin/env bash
set -euo pipefail

# Shokti+ Local Release Build Script
# Usage:
#   ./scripts/build_release.sh           # Builds Universal APK (recommended)
#   ./scripts/build_release.sh --split   # Builds Split ABI APKs (arm64 + armeabi-v7a)
#   ./scripts/build_release.sh --all     # Builds both Universal and Split APKs

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RAW_VERSION=$(grep '^version:' pubspec.yaml | head -n1 | awk '{print $2}')
VERSION_NAME=$(echo "$RAW_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$RAW_VERSION" | cut -d'+' -f2)

BUILD_MODE="${1:---universal}"

echo "=========================================================="
echo " Building Shokti+ Release APK"
echo " Version:      v${VERSION_NAME}"
echo " Build Number: ${BUILD_NUMBER}"
echo " Mode:         ${BUILD_MODE}"
echo "=========================================================="

if [ "$BUILD_MODE" = "--all" ]; then
    echo ">> Building Universal APK..."
    flutter build apk --release --build-name="$VERSION_NAME" --build-number="$BUILD_NUMBER"
    echo ">> Building Split ABI APKs..."
    flutter build apk --release --split-per-abi --build-name="$VERSION_NAME" --build-number="$BUILD_NUMBER"
elif [ "$BUILD_MODE" = "--split" ]; then
    echo ">> Building Split ABI APKs..."
    flutter build apk --release --split-per-abi --build-name="$VERSION_NAME" --build-number="$BUILD_NUMBER"
else
    echo ">> Building Universal APK..."
    flutter build apk --release --build-name="$VERSION_NAME" --build-number="$BUILD_NUMBER"
fi

echo "=========================================================="
echo " Release Build Complete! Standardized Artifacts:"
echo "=========================================================="
ls -lh output/apk/Shokti*.apk
echo "=========================================================="
