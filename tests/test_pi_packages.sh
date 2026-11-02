#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
sandbox="$(make_sandbox)"
stub_bin="$sandbox/bin"
node_root="$sandbox/node"
mkdir -p "$stub_bin" "$node_root/include/node"
: > "$node_root/include/node/node.h"

cat > "$stub_bin/node" <<EOF
#!/bin/bash
printf '%s' '$node_root/bin/node'
EOF
chmod +x "$stub_bin/node"

cat > "$stub_bin/pi" <<EOF
#!/bin/bash
printf '%s' "\$npm_config_nodedir" > '$sandbox/nodedir'
EOF
chmod +x "$stub_bin/pi"

(
    PATH="$stub_bin:$PATH"; export PATH
    unset npm_config_nodedir
    # shellcheck source=../scripts/install-pi-packages.sh
    . "$REPO/scripts/install-pi-packages.sh"
    PI_PACKAGES_SHARED=(test-package)
    install_pi_packages
)

assert_eq "$node_root" "$(<"$sandbox/nodedir")" \
    "pi packages use the active Node installation headers"

cleanup_sandbox "$sandbox"
finish_tests
