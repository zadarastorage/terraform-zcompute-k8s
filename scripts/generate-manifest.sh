#!/bin/bash
# Generate SHA256 manifest for bootstrap scripts
# Usage: ./generate-manifest.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Generating MANIFEST.sha256..."

# Find all .sh files in common/, control-plane/, worker/
# Output format compatible with sha256sum -c
{
  for dir in common control-plane worker; do
    if [ -d "$dir" ]; then
      # shellcheck disable=SC2044
      for f in $(find "$dir" -maxdepth 1 -name '*.sh' 2>/dev/null | sort); do
        [ -f "$f" ] && sha256sum "$f"
      done
    fi
  done
} > MANIFEST.sha256

echo "Generated MANIFEST.sha256 with $(wc -l < MANIFEST.sha256) entries:"
cat MANIFEST.sha256

# Verify the manifest is valid
echo ""
echo "Verifying manifest..."
sha256sum -c MANIFEST.sha256
echo "Manifest verification passed."
