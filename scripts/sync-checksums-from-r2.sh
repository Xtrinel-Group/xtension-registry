#!/bin/bash
# Download actual R2 Sentrinel zips and update manifest checksums
# Run with R2 credentials: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, R2_ENDPOINT

set -e

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$R2_ENDPOINT" ]; then
  echo "ERROR: Set R2 credentials: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, R2_ENDPOINT"
  exit 1
fi

export AWS_DEFAULT_REGION="auto"
BUCKET="vaast-xtensions"
TMP_DIR=$(mktemp -d)

echo "Downloading Sentrinel zips from R2 and computing checksums..."
echo

for MANIFEST in registry/official/*.json; do
  ID=$(grep -o '"id": *"[^"]*"' "$MANIFEST" | cut -d'"' -f4)
  R2_PATH=$(grep -o '"r2Path": *"[^"]*"' "$MANIFEST" | cut -d'"' -f4)

  if [ -z "$R2_PATH" ]; then
    echo "SKIP: $ID (no r2Path)"
    continue
  fi

  echo "Downloading $R2_PATH..."
  ZIP_FILE="$TMP_DIR/$(basename $R2_PATH)"

  if ! aws s3 cp "s3://$BUCKET/$R2_PATH" "$ZIP_FILE" --endpoint-url "$R2_ENDPOINT" 2>&1; then
    echo "ERROR: Failed to download $R2_PATH"
    echo "  (File may not exist in R2)"
    continue
  fi

  # Compute SHA-256
  if command -v sha256sum &> /dev/null; then
    CHECKSUM=$(sha256sum "$ZIP_FILE" | awk '{print $1}')
  elif command -v shasum &> /dev/null; then
    CHECKSUM=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
  else
    echo "ERROR: No sha256sum or shasum command found"
    exit 1
  fi

  echo "  → SHA-256: $CHECKSUM"

  # Update manifest
  python3 << EOF
import json
with open('$MANIFEST', 'r') as f:
    data = json.load(f)
data['checksum'] = '$CHECKSUM'
with open('$MANIFEST', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
EOF

  echo "  → Updated $MANIFEST"
  echo
done

rm -rf "$TMP_DIR"
echo "Done. All Sentrinel manifests updated with R2 checksums."
