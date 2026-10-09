# AwgIt: AmneziaWG Web Manager для OpenWrt

<p align="center">
  <a href="README.md">English</a> • <strong>Русский</strong>
</p>

<p align="center">
  <a href="https://github.com/kobaltgit/AwgIt/releases"><img src="https://img.shields.io/badge/%D1%80%D0%B5%D0%BB%D0%B8%D0%B7-v0.1.0-blue.svg" alt="Релиз v0.1.0"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/%D0%9B%D0%B8%D1%86%D0%B5%D0%BD%D0%B7%D0%B8%D1%8F-MIT-yellow.svg" alt="Лицензия: MIT"></a>
  <a href="https://github.com/kobaltgit/AwgIt/actions/workflows/release.yml"><img src="https://github.com/kobaltgit/AwgIt/actions/workflows/release.yml/badge.svg" alt="Тесты и Релизы"></a>
  <img src="https://img.shields.io/badge/OpenWrt-21.02%20%7C%2022.03%20%7C%2023.05-brightgreen.svg" alt="Поддержка OpenWrt">
  <img src="https://img.shields.io/badge/%D0%9F%D0%B0%D0%BC%D1%8F%D1%82%D1%8C%20(RAM)-0%25%20(%D0%91%D0%B5%D0%B7%20%D0%B4%D0%B5%D0%BC%D0%BE%D0%BD%D0%BE%D0%B2)-success.svg" alt="0% нагрузки">
</p>

<p align="center">
  <strong>Ультралегковесный веб-интерфейс управления клиентами AmneziaWG прямо на роутере OpenWrt.</strong><br>
  <em>Нулевые накладные расходы • Без Docker • Генерация QR-кодов и .conf в 1 клик • Тёмная тема в стиле wg-easy</em>
</p>

<p align="center">
  <img src="src/assets/screenshot.jpg" alt="Скриншот интерфейса AwgIt" width="850">
</p>

---

## ⚡ Особенности и Преимущества

* 🚀 **0% фоновой нагрузки:** Никаких демонов, Node.js, Python или Docker. Работает через встроенный `uhttpd` и POSIX CGI (`/bin/sh`).
* 📱 **Онбординг клиентов в 1 клик:** Кнопка `+ Новый клиент` генерирует пару ключей (`awg genkey`), назначает IP и мгновенно выводит QR-код со всеми параметрами маскировки (`Jc`, `Jmin`, `Jmax`, `S1`, `S2`, `H1-H4`).
* 🛡️ **Защита от сотовых блокировок (ТСПУ / DPI):** Поддержка обфусцированного протокола AmneziaWG для стабильной работы через LTE российских операторов (МТС, МегаФон, Билайн, Tele2).
* 🔒 **Изоляция от сторонних прокси (sing-box / Passwall):** Архитектура с `fwmark 0x1000` и политиками маршрутизации гарантирует прямые ответы клиентам без искажения портов со стороны conntrack и без влияния на рабочий трафик нейросетей.
* 📊 **Живая телеметрия и пульс сети:** Векторный бегущий график активности (SVG Sparkline), плавно «дышащий» индикатор сессии (`status-breathe`), объёмы трафика и скорости приёма/отдачи в реальном времени.
* 📱 **Честная адаптивность (CSS Grid):** Продуманная 3-ярусная раскладка на смартфонах без потери метрик скорости и без горизонтального скролла.

---

## 🏗️ Архитектура

```mermaid
flowchart LR
    Browser["Браузер (ПК / Смартфон)"] <-->|uhttpd / HTTP| CGI["CGI API (/www/cgi-bin/awg-api)"]
    CGI <-->|uci| NetworkConfig["/etc/config/network"]
    CGI <-->|awg genkey / awg set| Kernel["kmod-amneziawg (awg0)"]
    Kernel <-->|UDP 49155 / fwmark 0x1000| LTE["Мобильный клиент (LTE)"]
```

---

## 📚 Документация проекта

| Документ | Описание |
|:---|:---|
| [PROJECT_DESCRIPTION.md](docs/PROJECT_DESCRIPTION.md) | Полное описание архитектуры, компонентов и сетевой модели |
| [ROADMAP.md](docs/ROADMAP.md) | Дорожная карта, этапы реализации и критерии приемки |
| [BUGS_AND_ISSUES.md](docs/BUGS_AND_ISSUES.md) | Журнал обнаруженных сетевых инцидентов, багов ядра и их решений |

---

## 🚀 Быстрый старт (Установка в 1 команду)

### 1. Прямо на роутере OpenWrt (Рекомендуемый способ):
Подключитесь к роутеру по SSH и выполните команду:
```sh
wget -qO- https://raw.githubusercontent.com/kobaltgit/AwgIt/main/src/install.sh | sh -s -- --lang ru
```

### 2. Удалённо с ПК (Linux / macOS):
```bash
./src/install.sh --lang ru <IP_РОУТЕРА>
```

### 3. Удалённо с Windows (PowerShell):
```powershell
.\src\install.ps1 -RouterIp <IP_РОУТЕРА> -Lang ru
```

После завершения панель управления доступна по адресу: **`http://<IP_РОУТЕРА>/awg`** (например, `http://192.168.1.1/awg`).

---

## 📄 Лицензия

Проект распространяется под свободной лицензией MIT — подробности в файле [LICENSE](LICENSE).
