#!/bin/bash
# Author: Shoaloak (Axel Koolhaas) 2024
# Description: Fix iOS binary entitlements/access for "Operation not permitted"

ENTITLEMENT="com.apple.private.security.container-manager"
binaries=("sh" "bash" "zsh" "dash"      # Shell 
          "ls" "cat" "find" "cp" "mv"   # File management
          "rm" "mkdir" "rmdir" "touch"
          "file" "ln" "du" "scp"
          "chmod" "chown" "chgrp"       # Permissions
          "plutil" "otool" "nm" "lldb"  # Debugging
          )

# Confirmation
echo "This script will inject an entitlement into key binaries."
read -p "Are you sure? (y/n)" -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT # Remove temp_dir on exit

for bin in "${binaries[@]}"; do
    # Check if binary exists
    if ! command -v $bin &> /dev/null; then
        echo "Binary '$bin' not found. Skipping."
        continue
    fi

    # Check if the binary already has the entitlement
    if ldid -e "$(which $bin)" | grep -q "${ENTITLEMENT}"; then
        echo "Binary '$bin' already has the entitlement. Skipping."
        continue
    fi

    # Logging
    echo "Injecting entitlement into $bin..."

    # Dump current entitlements
    ldid -e "$(which $bin)" > "${temp_dir}/${bin}.xml"

    # Inject new entitlement using sed
    sed -i'' "s|</dict>|    <key>${ENTITLEMENT}</key>\
    <true/>\
</dict>|" "${temp_dir}/${bin}.xml"

    # Overwrite binary
    ldid -S"${temp_dir}/${bin}.xml" "$(which $bin)"
done

echo "Entitlement injection completed."
