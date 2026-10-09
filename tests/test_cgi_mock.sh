#!/bin/sh
# AwgIt Test Suite: End-to-end POSIX sh CGI simulation
# Tests:
# 1. Parameter parsing
# 2. Key validation and sanitization
# 3. generate_conf output format
# 4. JSON structure validation

set -e

echo "=== Running AwgIt Mock & Syntax Tests ==="

# 1. Test pure POSIX urldecode
urldecode() {
    [ -z "$1" ] && return 0
    printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g; s/%\([0-9a-fA-F][0-9a-fA-F]\)/\\x\1/g')" 2>/dev/null || printf '%s' "$1"
}

TEST_INPUT="action=create&name=My%20Test%20Phone%2BExtra&allowed_ips=10.9.0.2%2F32"
RAW_NAME=$(printf '%s' "$TEST_INPUT" | tr '&' '\n' | grep '^name=' | head -n 1 | cut -d '=' -f 2)
NAME=$(urldecode "$RAW_NAME")

if [ "$NAME" != "My Test Phone+Extra" ]; then
    echo "FAIL: Decoded name mismatch: $NAME"
    exit 1
fi
echo "[PASS] urldecode test"

# 2. Test sanitize_name (spaces converted to underscores for WireGuard compatibility)
sanitize_name() {
    printf '%s' "$1" | tr ' ' '_' | sed 's/[^a-zA-Z0-9._-]//g' | cut -c 1-64
}

CLEAN_NAME=$(sanitize_name "$NAME")
if [ "$CLEAN_NAME" != "My_Test_PhoneExtra" ]; then
    echo "FAIL: Sanitized name mismatch: $CLEAN_NAME"
    exit 1
fi
echo "[PASS] sanitize_name test (spaces -> underscores)"

# 2.1 Test sanitize_text (preserves UTF-8 / Cyrillic / emojis, strips dangerous shell chars)
sanitize_text() {
    printf '%s' "$1" | tr -d '\r\n"\\;`$&|><' | tr -d "'" | cut -c 1-128
}

DIRTY_TEXT="🏠 Семья / Family'; rm -rf /; \`reboot\` \$VAR"
CLEAN_TEXT=$(sanitize_text "$DIRTY_TEXT")
if [ "$CLEAN_TEXT" != "🏠 Семья / Family rm -rf / reboot VAR" ]; then
    echo "FAIL: Sanitized text mismatch: [$CLEAN_TEXT]"
    exit 1
fi
echo "[PASS] sanitize_text test (Cyrillic + Emoji preserved, shell chars stripped)"

# 3. Test generate_conf
JC="4"; JMIN="40"; JMAX="70"; S1="15"; S2="32"; H1="1"; H2="2"; H3="3"; H4="4"
SERVER_PUB="SERVER_TEST_PUB_KEY_12345678901234567890123="
EXT_IP="198.51.100.1"
SERVER_PORT="49155"

generate_conf() {
    _client_ip="$1"
    _client_priv="$2"
    printf "[Interface]\nAddress = %s\nPrivateKey = %s\nDNS = 10.9.0.1, 77.88.8.8\nJc = %s\nJmin = %s\nJmax = %s\nS1 = %s\nS2 = %s\nH1 = %s\nH2 = %s\nH3 = %s\nH4 = %s\n\n[Peer]\nPublicKey = %s\nEndpoint = %s:%s\nAllowedIPs = 0.0.0.0/0\nPersistentKeepalive = 25\n" \
        "$_client_ip" "$_client_priv" "$JC" "$JMIN" "$JMAX" "$S1" "$S2" "$H1" "$H2" "$H3" "$H4" "$SERVER_PUB" "$EXT_IP" "$SERVER_PORT"
}

CONF_OUTPUT=$(generate_conf "10.9.0.2/24" "CLIENT_TEST_PRIV_KEY_1234567890123456789012=")

# Verify mandatory fields in conf
for field in "Address = 10.9.0.2/24" "PrivateKey = CLIENT_TEST_PRIV_KEY" "Jc = 4" "S1 = 15" "H1 = 1" "PublicKey = SERVER_TEST_PUB" "Endpoint = 198.51.100.1:49155"; do
    if ! printf '%s' "$CONF_OUTPUT" | grep -qF "$field"; then
        echo "FAIL: Missing conf field: $field"
        exit 1
    fi
done
echo "[PASS] generate_conf test"

# 4. Test JSON formatting
CONF_JSON=$(printf '%s' "$CONF_OUTPUT" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
JSON_PAYLOAD=$(printf '{"status":"ok","name":"%s","config":"%s"}' "$CLEAN_NAME" "$CONF_JSON")

# Simple JSON sanity check
if ! printf '%s' "$JSON_PAYLOAD" | grep -q '"status":"ok"'; then
    echo "FAIL: Invalid JSON structure"
    exit 1
fi
echo "[PASS] JSON payload formatting test"

# 5. Test v0.2.0 Auth Guard Mock
ADMIN_PASS_MOCK="SecretPass123"
REQ_PASS_VALID="SecretPass123"
REQ_PASS_INVALID="WrongPass"

check_auth() {
    _admin="$1"
    _req="$2"
    if [ -n "$_admin" ] && [ "$_req" != "$_admin" ]; then
        return 1
    fi
    return 0
}

if ! check_auth "$ADMIN_PASS_MOCK" "$REQ_PASS_VALID"; then
    echo "FAIL: Valid pass rejected"
    exit 1
fi
if check_auth "$ADMIN_PASS_MOCK" "$REQ_PASS_INVALID"; then
    echo "FAIL: Invalid pass accepted"
    exit 1
fi
if ! check_auth "" "$REQ_PASS_INVALID"; then
    echo "FAIL: No pass set should allow access"
    exit 1
fi
echo "[PASS] Auth Guard mock test"

# 6. Test v0.2.0 Categories Sanitization
DIRTY_CATS='[{"name":"Family\x27; rm -rf /","icon":"🏠"}]'
SAFE_CATS=$(printf '%s' "$DIRTY_CATS" | tr -d '\r\n\\;`$&|><' | tr -d "'")
if [ "$SAFE_CATS" != '[{"name":"Familyx27 rm -rf /","icon":"🏠"}]' ]; then
    echo "FAIL: Categories sanitization mismatch: $SAFE_CATS"
    exit 1
fi
echo "[PASS] Categories JSON sanitization test"

# 7. Test set_password Old Password Verification Mock
verify_old_password() {
    _admin="$1"
    _old="$2"
    if [ -n "$_admin" ] && [ "$_old" != "$_admin" ]; then
        return 1
    fi
    return 0
}

if ! verify_old_password "ExistingPass" "ExistingPass"; then
    echo "FAIL: Valid current password rejected"
    exit 1
fi
if verify_old_password "ExistingPass" "WrongOldPass"; then
    echo "FAIL: Invalid current password accepted"
    exit 1
fi
if ! verify_old_password "" "AnyPass"; then
    echo "FAIL: First time password setup without existing password should succeed"
    exit 1
fi
echo "[PASS] Set password verification mock test"

echo "=== All tests passed successfully! ==="
