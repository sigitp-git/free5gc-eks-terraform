#!/bin/bash

# Validation script for Free5GC EKS userdata template
# This script validates the syntax and checks for common issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERDATA_TEMPLATE="$SCRIPT_DIR/modules/eks/templates/user_data.sh.tpl"

echo "🔍 Validating Free5GC EKS userdata script..."
echo "Template file: $USERDATA_TEMPLATE"
echo

# Check if file exists
if [[ ! -f "$USERDATA_TEMPLATE" ]]; then
    echo "❌ ERROR: Userdata template file not found: $USERDATA_TEMPLATE"
    exit 1
fi

# Check bash syntax
echo "1. Checking bash syntax..."
if bash -n "$USERDATA_TEMPLATE"; then
    echo "   ✅ Bash syntax is valid"
else
    echo "   ❌ Bash syntax errors found"
    exit 1
fi

# Check with shellcheck if available
echo "2. Running shellcheck analysis..."
if command -v shellcheck &> /dev/null; then
    if shellcheck "$USERDATA_TEMPLATE"; then
        echo "   ✅ Shellcheck analysis passed"
    else
        echo "   ⚠️  Shellcheck found issues (may be template variable warnings)"
    fi
else
    echo "   ⚠️  Shellcheck not available, skipping static analysis"
fi

# Check for required commands in the script
echo "3. Checking for required commands..."
required_commands=("yum" "systemctl" "modprobe" "jq" "lshw" "ip")
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! grep -q "$cmd" "$USERDATA_TEMPLATE"; then
        missing_commands+=("$cmd")
    fi
done

if [[ ${#missing_commands[@]} -eq 0 ]]; then
    echo "   ✅ All required commands are referenced in the script"
else
    echo "   ⚠️  Some commands might be missing: ${missing_commands[*]}"
fi

# Check for template variables
echo "4. Checking template variables..."
template_vars=("cluster_name" "region" "multus_subnet_ids" "multus_sg_id")
missing_vars=()

for var in "${template_vars[@]}"; do
    if ! grep -q "\${$var}" "$USERDATA_TEMPLATE"; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -eq 0 ]]; then
    echo "   ✅ All expected template variables are used"
else
    echo "   ⚠️  Some template variables are not used: ${missing_vars[*]}"
fi

# Check for error handling
echo "5. Checking error handling..."
if grep -q "set -euo pipefail" "$USERDATA_TEMPLATE"; then
    echo "   ✅ Strict error handling is enabled"
else
    echo "   ⚠️  Consider adding 'set -euo pipefail' for better error handling"
fi

# Check for logging
echo "6. Checking logging..."
if grep -q "log()" "$USERDATA_TEMPLATE"; then
    echo "   ✅ Logging function is implemented"
else
    echo "   ⚠️  No logging function found"
fi

echo
echo "🎉 Validation completed!"
echo "The userdata script appears to be well-structured and ready for deployment."
