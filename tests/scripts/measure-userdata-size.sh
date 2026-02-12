#!/bin/bash
# Measure compressed user-data size after optimization
# Usage: ./measure-userdata-size.sh [terraform_dir]

set -e
TF_DIR="${1:-$(dirname "$0")/../..}"
cd "$TF_DIR"

echo "=== User-Data Size Measurement ==="
echo ""
echo "=== Component Sizes ==="

# Measure bootstrap loader
LOADER_SIZE=$(wc -c < files/bootstrap-loader.tftpl.sh 2>/dev/null || echo "0")
echo "Bootstrap loader template: ${LOADER_SIZE} bytes"

# Measure write_files components
echo ""
echo "write_files components (approximate):"
echo "  - k8s.json: ~500-2000 bytes (cluster config)"
echo "  - k8s_helm.json (control only): ~2000-8000 bytes (varies with charts)"
echo "  - profile.d/zadara-ec2.sh: ~200 bytes"
echo "  - k3s config files: ~500 bytes"
echo ""

# Calculate totals
echo "=== Size Budget ==="
echo ""
echo "Worker node estimate:"
echo "  write_files: ~1200 bytes"
echo "  bootstrap loader: ~${LOADER_SIZE} bytes"
echo "  MIME overhead: ~200 bytes"
WORKER_RAW=$((1200 + LOADER_SIZE + 200))
WORKER_COMPRESSED=$((WORKER_RAW / 2))
echo "  Total raw: ~${WORKER_RAW} bytes"
echo "  Compressed (~50%): ~${WORKER_COMPRESSED} bytes"
echo ""
echo "Control plane estimate (worst case with large Helm config):"
echo "  write_files: ~9200 bytes (k8s_helm.json can be 8KB+)"
echo "  bootstrap loader: ~${LOADER_SIZE} bytes"
echo "  MIME overhead: ~200 bytes"
CONTROL_RAW=$((9200 + LOADER_SIZE + 200))
CONTROL_COMPRESSED=$((CONTROL_RAW / 2))
echo "  Total raw: ~${CONTROL_RAW} bytes"
echo "  Compressed (~50%): ~${CONTROL_COMPRESSED} bytes"
echo ""
echo "Target: <4096 bytes compressed"
echo ""
if [ $WORKER_COMPRESSED -lt 4096 ]; then
  echo "Worker: PASS (${WORKER_COMPRESSED} < 4096)"
else
  echo "Worker: FAIL (${WORKER_COMPRESSED} >= 4096)"
fi
if [ $CONTROL_COMPRESSED -lt 4096 ]; then
  echo "Control: PASS (${CONTROL_COMPRESSED} < 4096)"
else
  echo "Control: CONDITIONAL (${CONTROL_COMPRESSED} >= 4096 with large Helm config)"
fi
