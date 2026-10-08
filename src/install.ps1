param(
    [string]$RouterIp = "192.168.1.1",
    [ValidateSet("en", "ru")]
    [string]$Lang = "en",
    [string]$RepoRawUrl = "https://raw.githubusercontent.com/kobaltgit/AwgIt/main"
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

function Msg([string]$En, [string]$Ru) {
    if ($Lang -eq "ru") { return $Ru } else { return $En }
}

$header = Msg "=== AwgIt Installer for OpenWrt ($RouterIp) [Lang: $Lang] ===" "=== Установка AwgIt на роутер OpenWrt ($RouterIp) [Язык: $Lang] ==="
Write-Host $header -ForegroundColor Cyan

# Check if local files exist, otherwise download from GitHub repo
$tempDir = $null
$srcIndex = Join-Path $ScriptDir "index.html"
$srcQr    = Join-Path $ScriptDir "qrcode.min.js"
$srcApi   = Join-Path $ScriptDir "awg-api"
$srcFav   = Join-Path $ScriptDir "assets\favicon.ico"

if (-not (Test-Path $srcIndex) -or -not (Test-Path $srcQr) -or -not (Test-Path $srcApi)) {
    Write-Host (Msg "Local files missing. Downloading from GitHub repository..." `
                    "Локальные файлы не найдены. Загрузка из репозитория GitHub...") -ForegroundColor Yellow
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("awgit_" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $srcIndex = Join-Path $tempDir "index.html"
    $srcQr    = Join-Path $tempDir "qrcode.min.js"
    $srcApi   = Join-Path $tempDir "awg-api"
    $srcFav   = Join-Path $tempDir "favicon.ico"

    Invoke-WebRequest -Uri "$RepoRawUrl/src/index.html" -OutFile $srcIndex -UseBasicParsing
    Invoke-WebRequest -Uri "$RepoRawUrl/src/qrcode.min.js" -OutFile $srcQr -UseBasicParsing
    Invoke-WebRequest -Uri "$RepoRawUrl/src/assets/favicon.ico" -OutFile $srcFav -UseBasicParsing
    Invoke-WebRequest -Uri "$RepoRawUrl/src/awg-api" -OutFile $srcApi -UseBasicParsing
}

try {
    Write-Host (Msg "1. Preparing directories on router..." "1. Подготовка директорий на роутере...") -ForegroundColor Yellow
    ssh -o StrictHostKeyChecking=no "root@$RouterIp" "mkdir -p /www/awg /www/awg/assets /www/cgi-bin"

    Write-Host (Msg "2. Uploading web interface (Frontend)..." "2. Загрузка веб-интерфейса (Frontend)...") -ForegroundColor Yellow
    scp -O -o StrictHostKeyChecking=no $srcIndex $srcQr "root@${RouterIp}:/www/awg/"
    if (Test-Path $srcFav) {
        scp -O -o StrictHostKeyChecking=no $srcFav "root@${RouterIp}:/www/awg/assets/favicon.ico"
        scp -O -o StrictHostKeyChecking=no $srcFav "root@${RouterIp}:/www/awg/favicon.ico"
    }

    Write-Host (Msg "3. Uploading API handler (CGI Backend)..." "3. Загрузка обработчика API (CGI Backend)...") -ForegroundColor Yellow
    scp -O -o StrictHostKeyChecking=no $srcApi "root@${RouterIp}:/www/cgi-bin/awg-api"
    ssh -o StrictHostKeyChecking=no "root@$RouterIp" "chmod +x /www/cgi-bin/awg-api"

    Write-Host (Msg "4. Reloading uhttpd web server and checking permissions..." "4. Перезапуск веб-сервера uhttpd и проверка...") -ForegroundColor Yellow
    ssh -o StrictHostKeyChecking=no "root@$RouterIp" "/etc/init.d/uhttpd reload; ls -la /www/awg /www/cgi-bin/awg-api"

    Write-Host ""
    Write-Host (Msg "=== Installation successfully completed! ===" "=== Установка успешно завершена! ===") -ForegroundColor Green
    Write-Host (Msg "Control panel is available at: http://$RouterIp/awg" "Панель управления доступна по адресу: http://$RouterIp/awg") -ForegroundColor Green
}
finally {
    if ($tempDir -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
