#!/bin/bash
# Package Xtensions into .zip with checksums for registry

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_DIR="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="$(dirname "$REGISTRY_DIR")"
OUTPUT_DIR="$REGISTRY_DIR/packages"

mkdir -p "$OUTPUT_DIR"

echo "Packaging Sentrinels..."

for SENTRINEL_DIR in "$REPOS_DIR"/sentrinel-*/; do
  if [ ! -d "$SENTRINEL_DIR" ]; then
    continue
  fi

  SENTRINEL_NAME=$(basename "$SENTRINEL_DIR")
  MANIFEST="$SENTRINEL_DIR/manifest.json"

  if [ ! -f "$MANIFEST" ]; then
    echo "SKIP: $SENTRINEL_NAME (no manifest)"
    continue
  fi

  VERSION=$(grep -o '"version": *"[^"]*"' "$MANIFEST" | cut -d'"' -f4)
  if [ -z "$VERSION" ]; then
    echo "SKIP: $SENTRINEL_NAME (no version in manifest)"
    continue
  fi

  ZIP_NAME="${SENTRINEL_NAME}-v${VERSION}.zip"
  ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

  echo "Packaging $SENTRINEL_NAME v$VERSION..."

  # Create zip with dist/ and manifest.json
  cd "$SENTRINEL_DIR"
  zip -r "$ZIP_PATH" dist/ manifest.json -q

  # Compute SHA-256
  if command -v sha256sum &> /dev/null; then
    CHECKSUM=$(sha256sum "$ZIP_PATH" | awk '{print $1}')
  elif command -v shasum &> /dev/null; then
    CHECKSUM=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
  else
    echo "ERROR: No sha256sum or shasum command found"
    exit 1
  fi

  echo "  → $ZIP_NAME"
  echo "  → SHA-256: $CHECKSUM"

  # Update manifest with checksum and r2Path
  REGISTRY_MANIFEST="$REGISTRY_DIR/registry/official/${SENTRINEL_NAME}.json"
  if [ -f "$REGISTRY_MANIFEST" ]; then
    # Use Python to update JSON (safer than sed)
    python3 -c "
import json, sys
with open('$REGISTRY_MANIFEST', 'r') as f:
    data = json.load(f)
data['checksum'] = '$CHECKSUM'
data['r2Path'] = 'sentrinels/$ZIP_NAME'
with open('$REGISTRY_MANIFEST', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print('Updated $REGISTRY_MANIFEST')
"
  else
    echo "  WARNING: No registry manifest at $REGISTRY_MANIFEST"
  fi

  echo ""
done

echo "Packaging Mezo..."
MEZO_DIR="$REPOS_DIR/mezo-xtension"
if [ -d "$MEZO_DIR" ]; then
  MANIFEST="$MEZO_DIR/manifest.json"
  VERSION=$(grep -o '"version": *"[^"]*"' "$MANIFEST" | cut -d'"' -f4)
  ZIP_NAME="mezo-v${VERSION}.zip"
  ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

  cd "$MEZO_DIR"
  zip -r "$ZIP_PATH" dist/ manifest.json -q

  if command -v sha256sum &> /dev/null; then
    CHECKSUM=$(sha256sum "$ZIP_PATH" | awk '{print $1}')
  elif command -v shasum &> /dev/null; then
    CHECKSUM=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
  fi

  echo "  → $ZIP_NAME"
  echo "  → SHA-256: $CHECKSUM"

  # Update community manifest
  REGISTRY_MANIFEST="$REGISTRY_DIR/registry/community/mezo.json"
  python3 -c "
import json
with open('$REGISTRY_MANIFEST', 'r') as f:
    data = json.load(f)
data['checksum'] = '$CHECKSUM'
# Mezo uses downloadUrl (GitHub Release), not r2Path
# But add checksum so installer can verify
with open('$REGISTRY_MANIFEST', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print('Updated $REGISTRY_MANIFEST')
"
  echo ""
fi

echo "Done. Packages in $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Upload .zip files to R2 bucket 'vaast-xtensions' under 'sentrinels/'"
echo "2. Run publish workflow to rebuild registry.json"
echo "3. Test installation in VAAST"
