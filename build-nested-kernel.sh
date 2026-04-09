#!/bin/bash
# Build the OHCL Linux Kernel with KVM module support for nested virtualization.
#
# This script patches the x64 kernel config to enable KVM as loadable modules,
# builds the kernel, then shows how to build the OpenHCL nested IGVM.
#
# Prerequisites:
#   - Standard kernel build dependencies (gcc, make, flex, bison, libelf-dev, etc.)
#   - Install with: Microsoft/install-deps.sh
#
# Usage:
#   ./build-nested-kernel.sh
#
# After this script completes, build the nested IGVM from the openvmm repo:
#   cd <openvmm-repo>
#   cargo xflowey build-igvm x64-nested \
#     --custom-kernel <kernel-repo>/out/build/native/bin/x64/vmlinux \
#     --custom-kernel-modules <kernel-repo>/out/build/native/bin/x64/modules/kernel \
#     --custom-extra-rootfs <openvmm-repo>/openhcl/rootfs.kvm.config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG="Microsoft/hcl-x64.config"

echo "=== Patching kernel config for KVM nested virtualization ==="

# Enable KVM as loadable modules. These must be =m (not =y) because
# underhill_init loads them dynamically via finit_module.
if ! grep -q '^CONFIG_VIRTUALIZATION=y' "$CONFIG"; then
    # Replace the disabled markers with enabled config
    sed -i 's/^# CONFIG_VIRTUALIZATION is not set/CONFIG_VIRTUALIZATION=y/' "$CONFIG"

    # Append KVM options if not already present
    if ! grep -q '^CONFIG_KVM=' "$CONFIG"; then
        cat >> "$CONFIG" <<'EOF'
CONFIG_KVM=m
CONFIG_KVM_INTEL=m
CONFIG_KVM_AMD=m
EOF
    fi
    echo "KVM config options added."
else
    echo "KVM config already present."
fi

# Disable STRICT_DEVMEM so the paravisor can access VTL0 guest memory
# via /dev/mem. The guest RAM ranges are not in the OpenHCL kernel's
# e820 map, so strict devmem would block all guest memory access.
if grep -q '^CONFIG_STRICT_DEVMEM=y' "$CONFIG"; then
    sed -i 's/^CONFIG_STRICT_DEVMEM=y/# CONFIG_STRICT_DEVMEM is not set/' "$CONFIG"
    echo "STRICT_DEVMEM disabled."
else
    echo "STRICT_DEVMEM already disabled."
fi

echo ""
echo "=== Building kernel ==="
Microsoft/build-hcl-kernel.sh dev x64

echo ""
echo "=== Build complete ==="
echo ""
echo "Kernel:  $SCRIPT_DIR/out/build/native/bin/x64/vmlinux"
echo "Modules: $SCRIPT_DIR/out/build/native/bin/x64/modules/kernel/"
echo ""
echo "Verify KVM modules were built:"
ls -la out/build/native/bin/x64/modules/kernel/arch/x86/kvm/ 2>/dev/null || echo "  ERROR: KVM modules not found!"
echo ""
echo "=== Next steps ==="
echo ""
echo "Build the nested IGVM from the openvmm repo:"
echo ""
echo "  cd <openvmm-repo>"
echo "  cargo xflowey build-igvm x64-nested \\"
echo "    --custom-kernel $SCRIPT_DIR/out/build/native/bin/x64/vmlinux \\"
echo "    --custom-kernel-modules $SCRIPT_DIR/out/build/native/bin/x64/modules/kernel \\"
echo "    --custom-extra-rootfs \$(pwd)/openhcl/rootfs.kvm.config"
