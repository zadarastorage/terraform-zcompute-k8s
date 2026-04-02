#!/bin/bash
IFS=$'\n'
until [ -e /etc/zadara/k8s.json ]; do sleep 1s; done
_log() { echo "[$(date +%s)][$0] ${@}"; }

GPU_ENABLED=$(jq -c -r '.gpu.enabled // false' /etc/zadara/k8s.json)
if [ "${GPU_ENABLED}" != "true" ]; then
	_log "GPU setup not enabled, skipping"
	exit 0
fi

GPU_MODEL=$(jq -c -r '.gpu.model' /etc/zadara/k8s.json)
GPU_COUNT=$(jq -c -r '.gpu.count' /etc/zadara/k8s.json)
GPU_PCI_ID=$(jq -c -r '.gpu.pci_device_id' /etc/zadara/k8s.json)
DRIVER_VERSION=$(jq -c -r '.gpu.driver_version // "570"' /etc/zadara/k8s.json)
DRIVER_URL=$(jq -c -r '.gpu.driver_url // ""' /etc/zadara/k8s.json)

GPU_HW_COUNT=$(lspci -n -d "${GPU_PCI_ID}" 2>/dev/null | wc -l)
if [ "${GPU_HW_COUNT}" -eq 0 ]; then
	_log "WARNING: GPU config expects ${GPU_MODEL} (${GPU_PCI_ID}) but no matching PCI device found. Skipping driver install."
	exit 0
fi
_log "Detected ${GPU_HW_COUNT} ${GPU_MODEL} GPU(s) (PCI: ${GPU_PCI_ID})"

# Install kernel headers and build dependencies
export DEBIAN_FRONTEND=noninteractive
_log "Installing kernel headers and build dependencies"
apt-get -o Acquire::ForceIPv4=true -qq update
apt-get install -o Acquire::ForceIPv4=true -qq -y \
	linux-headers-$(uname -r) build-essential pkg-config libglvnd-dev

# Resolve driver URL
if [ -z "${DRIVER_URL}" ]; then
	_log "Resolving latest NVIDIA ${DRIVER_VERSION}.x driver URL"
	DRIVER_FULL_VERSION=$(curl -sfL "https://us.download.nvidia.com/tesla/" | \
		grep -oP "${DRIVER_VERSION}\.[0-9.]+" | sort -V | tail -1)
	if [ -z "${DRIVER_FULL_VERSION}" ]; then
		_log "ERROR: Could not resolve NVIDIA driver version for branch ${DRIVER_VERSION}"
		exit 1
	fi
	DRIVER_URL="https://us.download.nvidia.com/tesla/${DRIVER_FULL_VERSION}/NVIDIA-Linux-x86_64-${DRIVER_FULL_VERSION}.run"
fi

# Download and install NVIDIA driver
_log "Downloading NVIDIA driver from ${DRIVER_URL}"
curl -sfL -o /tmp/nvidia-driver.run "${DRIVER_URL}"
chmod +x /tmp/nvidia-driver.run

_log "Installing NVIDIA driver (silent, DKMS)"
/tmp/nvidia-driver.run --silent --dkms --no-cc-version-check 2>&1
rm -f /tmp/nvidia-driver.run

nvidia-smi || { _log "ERROR: nvidia-smi failed after driver install"; exit 1; }
_log "NVIDIA driver installed successfully"

# Install nvidia-container-toolkit
_log "Installing nvidia-container-toolkit"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
	gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
	sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
	tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get -o Acquire::ForceIPv4=true -qq update
apt-get install -o Acquire::ForceIPv4=true -qq -y nvidia-container-toolkit

# Configure containerd for NVIDIA runtime (k3s uses embedded containerd)
CONTAINERD_TEMPLATE="/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl"
mkdir -p "$(dirname ${CONTAINERD_TEMPLATE})"
_log "Configuring containerd NVIDIA runtime"
nvidia-ctk runtime configure --runtime=containerd \
	--config="${CONTAINERD_TEMPLATE}" \
	--set-as-default 2>&1 || _log "WARN: nvidia-ctk configure returned non-zero"

# Install nvtop for GPU monitoring
_log "Installing nvtop"
apt-get install -o Acquire::ForceIPv4=true -qq -y nvtop 2>/dev/null || \
	_log "WARN: nvtop package not available"

_log "GPU setup complete: ${GPU_COUNT}x ${GPU_MODEL}"
