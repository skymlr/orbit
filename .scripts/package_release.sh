#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/Orbit.xcodeproj"
SCHEME="Orbit"
DERIVED_DATA_PATH="${ROOT_DIR}/build"
PRODUCT_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/Orbit.app"
OUTPUT_DIR="${ROOT_DIR}/dist"
OUTPUT_ZIP="${OUTPUT_DIR}/Orbit-macOS.zip"

echo "Building release app..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

if [[ ! -d "${PRODUCT_PATH}" ]]; then
  echo "Expected app bundle not found at: ${PRODUCT_PATH}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_ZIP}"

echo "Packaging zip..."
ditto -c -k --sequesterRsrc --keepParent "${PRODUCT_PATH}" "${OUTPUT_ZIP}"

echo "Created ${OUTPUT_ZIP}"
