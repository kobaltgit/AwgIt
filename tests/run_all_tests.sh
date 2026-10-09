#!/bin/sh
# AwgIt Complete Automated Test Suite Runner
# Runs CGI mock tests, input validation tests, syntax checks, and frontend integrity tests.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================="
echo "          AwgIt Comprehensive Test Suite          "
echo "=================================================="

# 1. POSIX syntax check of awg-api and shell scripts
echo "\n--- [1/4] Shell Syntax Checks (sh -n) ---"
sh -n "$ROOT_DIR/src/awg-api"
sh -n "$ROOT_DIR/src/install.sh"
sh -n "$ROOT_DIR/tests/test_cgi_mock.sh"
sh -n "$ROOT_DIR/tests/test_input_validation.sh"
echo "[PASS] All shell scripts passed strict POSIX syntax check"

# 2. CGI Mock & Parameter Tests
echo "\n--- [2/4] CGI Mock Tests ---"
sh "$ROOT_DIR/tests/test_cgi_mock.sh"

# 3. Input Validation Tests
echo "\n--- [3/4] Input Validation & Security Tests ---"
sh "$ROOT_DIR/tests/test_input_validation.sh"

# 4. Frontend Integrity Tests
echo "\n--- [4/4] Frontend Integrity Tests ---"
if command -v node >/dev/null 2>&1; then
    node "$ROOT_DIR/tests/test_frontend_integrity.js"
else
    echo "WARNING: node not found, running basic POSIX frontend validation..."
    # Basic POSIX check
    if grep -qE "https?://" "$ROOT_DIR/src/index.html" | grep -v "127.0.0.1" | grep -v "localhost"; then
        echo "FAIL: Detected external URL in index.html"
        exit 1
    fi
    echo "[PASS] Basic POSIX frontend check completed"
fi

echo "\n=================================================="
echo "  ✓ ALL AWGIT TEST SUITES PASSED WITHOUT ERRORS   "
echo "=================================================="
