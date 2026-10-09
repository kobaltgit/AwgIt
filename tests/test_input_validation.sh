#!/bin/sh
set -e

urldecode() {
    [ -z "$1" ] && return 0
    # Replace + with space, then replace %XX with \xXX, then feed to printf %b
    printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g; s/%\([0-9a-fA-F][0-9a-fA-F]\)/\\x\1/g')"
}

# Test urldecode
res=$(urldecode "Hello%20World%21+Plus%20Sign")
echo "Decoded: [$res]"
[ "$res" = "Hello World! Plus Sign" ] || { echo "urldecode test failed"; exit 1; }

# Test key validation (AmneziaWG / WireGuard base64 key: 44 chars ending in =)
is_valid_key() {
    case "$1" in
        *[!A-Za-z0-9+/=]*) return 1 ;;
    esac
    [ "${#1}" -eq 44 ] || return 1
    return 0
}

if is_valid_key "iN28w4m1Bf2g6S8zK9L0mN1oP2qR3sT4uV5wX6yZ7aA="; then
    echo "Key 1 valid: OK"
else
    echo "Key 1 valid: FAIL"
    exit 1
fi

if is_valid_key "invalid; rm -rf /; key"; then
    echo "Malicious key accepted: FAIL"
    exit 1
else
    echo "Malicious key rejected: OK"
fi

if is_valid_key "shortKey="; then
    echo "Short key accepted: FAIL"
    exit 1
else
    echo "Short key rejected: OK"
fi

# Test safe name sanitization (replaces spaces with underscores)
sanitize_name() {
    printf '%s' "$1" | tr ' ' '_' | sed 's/[^a-zA-Z0-9._-]//g' | cut -c 1-64
}

clean_name=$(sanitize_name "My Phone (iPhone); rm -rf /")
echo "Sanitized name: [$clean_name]"
[ "$clean_name" = "My_Phone_iPhone_rm_-rf_" ] || { echo "Sanitize name failed"; exit 1; }

# Test safe text sanitization (UTF-8, emojis, stripping dangerous shell chars)
sanitize_text() {
    printf '%s' "$1" | tr -d '\r\n"\\;`$&|><' | tr -d "'" | cut -c 1-128
}

clean_text=$(sanitize_text "📱 Телефон 1; \`reboot\`")
echo "Sanitized text: [$clean_text]"
[ "$clean_text" = "📱 Телефон 1 reboot" ] || { echo "Sanitize text failed"; exit 1; }

# Test IP sanitization (IPv4 with optional /CIDR)
is_valid_cidr() {
    _ip="$1"
    case "$_ip" in
        *[!0-9./]*) return 1 ;;
    esac
    _ip_part="${_ip%%/*}"
    _cidr_part="${_ip#*/}"
    [ "$_ip_part" = "$_cidr_part" ] && _cidr_part="32"

    o1=$(printf '%s' "$_ip_part" | cut -d '.' -f 1)
    o2=$(printf '%s' "$_ip_part" | cut -d '.' -f 2)
    o3=$(printf '%s' "$_ip_part" | cut -d '.' -f 3)
    o4=$(printf '%s' "$_ip_part" | cut -d '.' -f 4)

    [ -n "$o1" ] && [ -n "$o2" ] && [ -n "$o3" ] && [ -n "$o4" ] || return 1
    [ "$o1" -ge 0 ] 2>/dev/null && [ "$o1" -le 255 ] || return 1
    [ "$o2" -ge 0 ] 2>/dev/null && [ "$o2" -le 255 ] || return 1
    [ "$o3" -ge 0 ] 2>/dev/null && [ "$o3" -le 255 ] || return 1
    [ "$o4" -ge 0 ] 2>/dev/null && [ "$o4" -le 255 ] || return 1
    [ "$_cidr_part" -ge 0 ] 2>/dev/null && [ "$_cidr_part" -le 32 ] || return 1
    return 0
}

if is_valid_cidr "10.9.0.5/32" && is_valid_cidr "192.168.1.1" && ! is_valid_cidr "10.9.0.300" && ! is_valid_cidr "10.9.0.1; reboot"; then
    echo "CIDR validation: OK"
else
    echo "CIDR validation: FAIL"
    exit 1
fi

echo "ALL TESTS PASSED!"
