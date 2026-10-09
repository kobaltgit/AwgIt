#!/bin/sh
# AwgIt Installer for OpenWrt
# Downloads files automatically from GitHub repository: https://github.com/kobaltgit/AwgIt
# Supports:
#   1. One-line install directly on OpenWrt:
#      wget -qO- https://raw.githubusercontent.com/kobaltgit/AwgIt/main/src/install.sh | sh
#   2. Remote install from PC via SSH:
#      ./src/install.sh <router_ip>
# Default language: English (switchable via --lang ru)

set -e

REPO_RAW_URL="${REPO_RAW_URL:-https://raw.githubusercontent.com/kobaltgit/AwgIt/main}"
ROUTER_IP="192.168.1.1"
INSTALL_LANG="en"
CUSTOM_IP=0

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --lang|-l)
            INSTALL_LANG="$2"
            shift 2
            ;;
        --lang=*)
            INSTALL_LANG="${1#*=}"
            shift
            ;;
        ru|en)
            INSTALL_LANG="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [ROUTER_IP] [--lang en|ru]"
            exit 0
            ;;
        *)
            if [ "$CUSTOM_IP" -eq 0 ]; then
                ROUTER_IP="$1"
                CUSTOM_IP=1
            fi
            shift
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0" 2>/dev/null)" && pwd 2>/dev/null || echo ".")"

# Helper for bilingual messages
msg() {
    if [ "$INSTALL_LANG" = "ru" ]; then
        echo "$2"
    else
        echo "$1"
    fi
}

# Downloader function supporting curl, wget, and uclient-fetch with SSL resilience
fetch_file() {
    _url="$1"
    _dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -s -k -L -f -o "$_dest" "$_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate -O "$_dest" "$_url"
    elif command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch --no-check-certificate -q -O "$_dest" "$_url"
    else
        msg "Error: Neither curl nor wget found to download files!" \
            "Ошибка: Ни curl, ни wget не найдены для загрузки файлов!"
        return 1
    fi
}

# ========================================================
# Scenario 1: Running directly on OpenWrt router
# ========================================================
if [ -f /etc/openwrt_release ] || [ "$ROUTER_IP" = "localhost" ] || [ "$ROUTER_IP" = "127.0.0.1" ]; then
    msg "=== Local AwgIt Installation on OpenWrt [Lang: ${INSTALL_LANG}] ===" \
        "=== Локальная установка AwgIt на роутер OpenWrt [Язык: ${INSTALL_LANG}] ==="

    msg "1. Preparing directories (/www/awg, /www/cgi-bin)..." \
        "1. Подготовка директорий (/www/awg, /www/cgi-bin)..."
    mkdir -p /www/awg /www/awg/assets /www/cgi-bin

    msg "2. Installing web interface and assets..." \
        "2. Установка веб-интерфейса и ассетов..."
    if [ -f "$SCRIPT_DIR/index.html" ] && [ -f "$SCRIPT_DIR/qrcode.min.js" ]; then
        msg "   Using local files from $SCRIPT_DIR..." \
            "   Используются локальные файлы из $SCRIPT_DIR..."
        cp "$SCRIPT_DIR/index.html" "$SCRIPT_DIR/qrcode.min.js" /www/awg/
        [ -f "$SCRIPT_DIR/manifest.json" ] && cp "$SCRIPT_DIR/manifest.json" /www/awg/
        [ -f "$SCRIPT_DIR/assets/favicon.ico" ] && cp "$SCRIPT_DIR/assets/favicon.ico" /www/awg/assets/
        [ -f "$SCRIPT_DIR/favicon.ico" ] && cp "$SCRIPT_DIR/favicon.ico" /www/awg/
    else
        msg "   Downloading files from repository ($REPO_RAW_URL)..." \
            "   Загрузка файлов из репозитория ($REPO_RAW_URL)..."
        fetch_file "$REPO_RAW_URL/src/index.html" "/www/awg/index.html"
        fetch_file "$REPO_RAW_URL/src/qrcode.min.js" "/www/awg/qrcode.min.js"
        fetch_file "$REPO_RAW_URL/src/manifest.json" "/www/awg/manifest.json"
        fetch_file "$REPO_RAW_URL/src/assets/favicon.ico" "/www/awg/assets/favicon.ico"
    fi
    [ -f /www/awg/assets/favicon.ico ] && cp /www/awg/assets/favicon.ico /www/awg/favicon.ico

    msg "3. Installing CGI backend API (/www/cgi-bin/awg-api)..." \
        "3. Установка обработчика API (/www/cgi-bin/awg-api)..."
    if [ -f "$SCRIPT_DIR/awg-api" ]; then
        cp "$SCRIPT_DIR/awg-api" /www/cgi-bin/awg-api
    else
        fetch_file "$REPO_RAW_URL/src/awg-api" "/www/cgi-bin/awg-api"
    fi
    chmod +x /www/cgi-bin/awg-api

    msg "4. Checking OpenWrt kernel modules and packages..." \
        "4. Проверка модулей ядра и пакетов OpenWrt..."
    if ! command -v awg >/dev/null 2>&1 && ! command -v amneziawg >/dev/null 2>&1; then
        msg "WARNING: 'awg' tool not found. Ensure kmod-amneziawg and amneziawg-tools packages are installed!" \
            "ВНИМАНИЕ: Утилита awg не найдена. Убедитесь, что установлены пакеты kmod-amneziawg и amneziawg-tools!"
    fi

    msg "5. Reloading uhttpd web server..." \
        "5. Перезапуск веб-сервера uhttpd..."
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true

    echo ""
    msg "=== Installation successfully completed! ===" \
        "=== Установка успешно завершена! ==="
    msg "Control panel is available at: http://127.0.0.1/awg or http://<router_ip>/awg" \
        "Панель управления доступна по адресу: http://127.0.0.1/awg или http://<IP_роутера>/awg"
    exit 0
fi

# ========================================================
# Scenario 2: Remote deployment from PC via SSH/SCP
# ========================================================
msg "=== Remote AwgIt Installation on OpenWrt (${ROUTER_IP}) [Lang: ${INSTALL_LANG}] ===" \
    "=== Удаленная установка AwgIt на роутер OpenWrt (${ROUTER_IP}) [Язык: ${INSTALL_LANG}] ==="

msg "1. Testing SSH connection to router..." \
    "1. Проверка доступности роутера по SSH..."
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${ROUTER_IP}" "true" 2>/dev/null; then
    msg "Error: Failed to connect to root@${ROUTER_IP} via SSH." \
        "Ошибка: Не удалось подключиться к root@${ROUTER_IP} по SSH."
    msg "Please check router IP address and SSH keys." \
        "Проверьте IP-адрес роутера и настройки SSH-ключа."
    exit 1
fi

msg "2. Preparing directories on router..." \
    "2. Подготовка директорий на роутере..."
ssh -o StrictHostKeyChecking=no "root@${ROUTER_IP}" "mkdir -p /www/awg /www/awg/assets /www/cgi-bin"

# Determine file source (local or download from repo)
TEMP_DIR=""
SRC_INDEX="$SCRIPT_DIR/index.html"
SRC_QR="$SCRIPT_DIR/qrcode.min.js"
SRC_MAN="$SCRIPT_DIR/manifest.json"
SRC_FAV="$SCRIPT_DIR/assets/favicon.ico"
SRC_API="$SCRIPT_DIR/awg-api"

if [ ! -f "$SRC_INDEX" ] || [ ! -f "$SRC_QR" ] || [ ! -f "$SRC_API" ] || [ ! -f "$SRC_MAN" ]; then
    msg "3. Local files missing, downloading from GitHub repo..." \
        "3. Локальные файлы не найдены, загрузка из репозитория GitHub..."
    TEMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'awgit')"
    SRC_INDEX="$TEMP_DIR/index.html"
    SRC_QR="$TEMP_DIR/qrcode.min.js"
    SRC_MAN="$TEMP_DIR/manifest.json"
    SRC_FAV="$TEMP_DIR/favicon.ico"
    SRC_API="$TEMP_DIR/awg-api"

    fetch_file "$REPO_RAW_URL/src/index.html" "$SRC_INDEX"
    fetch_file "$REPO_RAW_URL/src/qrcode.min.js" "$SRC_QR"
    fetch_file "$REPO_RAW_URL/src/manifest.json" "$SRC_MAN"
    fetch_file "$REPO_RAW_URL/src/assets/favicon.ico" "$SRC_FAV"
    fetch_file "$REPO_RAW_URL/src/awg-api" "$SRC_API"
fi

msg "4. Uploading web interface and assets (Frontend)..." \
    "4. Загрузка веб-интерфейса и ассетов (Frontend)..."
scp -O -o StrictHostKeyChecking=no "$SRC_INDEX" "$SRC_QR" "$SRC_MAN" "root@${ROUTER_IP}:/www/awg/"
if [ -f "$SRC_FAV" ]; then
    scp -O -o StrictHostKeyChecking=no "$SRC_FAV" "root@${ROUTER_IP}:/www/awg/assets/favicon.ico"
    scp -O -o StrictHostKeyChecking=no "$SRC_FAV" "root@${ROUTER_IP}:/www/awg/favicon.ico"
fi

msg "5. Uploading API handler (CGI Backend)..." \
    "5. Загрузка обработчика API (CGI Backend)..."
scp -O -o StrictHostKeyChecking=no "$SRC_API" "root@${ROUTER_IP}:/www/cgi-bin/awg-api"
ssh -o StrictHostKeyChecking=no "root@${ROUTER_IP}" "chmod +x /www/cgi-bin/awg-api"

# Clean up temporary directory if used
[ -n "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"

msg "6. Checking kernel modules and reloading web server..." \
    "6. Проверка готовности ядра и окружения..."
ssh -o StrictHostKeyChecking=no "root@${ROUTER_IP}" "
if ! command -v awg >/dev/null 2>&1 && ! command -v amneziawg >/dev/null 2>&1; then
    echo 'WARNING: awg tool not found on router. Ensure kmod-amneziawg and amneziawg-tools are installed!'
fi
/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
"

msg "7. Testing API response..." \
    "7. Тест отклика API..."
ssh -o StrictHostKeyChecking=no "root@${ROUTER_IP}" "
if command -v curl >/dev/null 2>&1; then
    curl -s http://127.0.0.1/cgi-bin/awg-api?action=status | head -n 3
fi
" || true

echo ""
msg "=== Installation successfully completed! ===" \
    "=== Установка успешно завершена! ==="
msg "Control panel is available at: http://${ROUTER_IP}/awg" \
    "Панель управления доступна по адресу: http://${ROUTER_IP}/awg"
