#!/bin/bash

# ==============================================
# ПОЛНАЯ УСТАНОВКА VPN БАЛАНСИРОВЩИКА
# ==============================================

set -e  # Прерывать при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логотип
echo -e "${BLUE}"
echo '╔══════════════════════════════════════════════════════════╗'
echo '║         VPN БАЛАНСИРОВЩИК - ПОЛНАЯ УСТАНОВКА            ║'
echo '║         Приватный репозиторий + Авто-обновление         ║'
echo '╚══════════════════════════════════════════════════════════╝'
echo -e "${NC}"

# ==============================================
# ЗАПРОС ДАННЫХ
# ==============================================

echo -e "${YELLOW}Введите данные для доступа к ПРИВАТНОМУ репозиторию:${NC}"
echo ""

read -p "👉 GitHub username: " GITHUB_USER
read -p "👉 Название репозитория: " REPO_NAME
read -p "👉 Имя файла с ключами (например vpnnn.txt): " KEYS_FILE
read -s -p "👉 GitHub Personal Access Token (с доступом к repo): " GITHUB_TOKEN
echo ""
read -p "👉 Порт для VLESS (по умолчанию 443): " XRAY_PORT
XRAY_PORT=${XRAY_PORT:-443}

# ==============================================
# ПРОВЕРКА ДОСТУПА
# ==============================================

echo -e "\n${YELLOW}Проверяю доступ к репозиторию...${NC}"

TEST_URL="https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/${KEYS_FILE}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token ${GITHUB_TOKEN}" "${TEST_URL}")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Доступ к файлу подтвержден!${NC}"
else
    echo -e "${RED}❌ Ошибка доступа к файлу (код: $HTTP_CODE)${NC}"
    echo "Проверьте:"
    echo "  - Правильность имени пользователя"
    echo "  - Название репозитория"
    echo "  - Имя файла"
    echo "  - Токен имеет доступ к repo"
    exit 1
fi

# ==============================================
# ОБНОВЛЕНИЕ СИСТЕМЫ
# ==============================================

echo -e "\n${YELLOW}1. Обновляю систему...${NC}"
apt update && apt upgrade -y
apt install -y curl wget git python3-pip python3-venv unzip nginx cron openssl

# ==============================================
# УСТАНОВКА XRAY
# ==============================================

echo -e "\n${YELLOW}2. Устанавливаю Xray...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# ==============================================
# ГЕНЕРАЦИЯ КЛЮЧЕЙ
# ==============================================

echo -e "\n${YELLOW}3. Генерирую ключи безопасности...${NC}"

# Генерация UUID для клиентов
UUID=$(cat /proc/sys/kernel/random/uuid)

# Генерация ключей Reality
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')

# Генерация short ID
SHORT_ID=$(openssl rand -hex 8)

echo -e "${GREEN}  ✓ UUID: $UUID${NC}"
echo -e "${GREEN}  ✓ Private Key: $PRIVATE_KEY${NC}"
echo -e "${GREEN}  ✓ Public Key: $PUBLIC_KEY${NC}"
echo -e "${GREEN}  ✓ Short ID: $SHORT_ID${NC}"

# ==============================================
# СОЗДАНИЕ КОНФИГУРАЦИИ XRAY
# ==============================================

echo -e "\n${YELLOW}4. Создаю конфигурацию Xray...${NC}"

cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": ${XRAY_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.microsoft.com:443",
          "serverNames": [
            "www.microsoft.com",
            "www.bing.com",
            "www.google.com"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "balancers": [
      {
        "tag": "vpn-servers",
        "selector": [],
        "strategy": {
          "type": "leastPing"
        }
      }
    ],
    "rules": [
      {
        "type": "field",
        "outboundTag": "direct",
        "network": "udp"
      }
    ]
  }
}
EOF

# ==============================================
# СОЗДАНИЕ СКРИПТА ПАРСЕРА
# ==============================================

echo -e "\n${YELLOW}5. Создаю скрипт для парсинга ключей из приватного репозитория...${NC}"

cat > /usr/local/bin/parse_keys.py << 'PYEOF'
#!/usr/bin/env python3
import base64
import json
import re
import urllib.parse
import sys

def parse_vless_key(key_str):
    """Парсит VLESS ключ БЕЗ СОКРАЩЕНИЙ, сохраняя все параметры"""
    try:
        if not key_str.startswith('vless://'):
            return None
        
        # Сохраняем оригинальный ключ полностью
        original_key = key_str.strip()
        
        # Извлекаем имя из комментария если есть
        name = ''
        if '#' in key_str:
            base_key, name = key_str.split('#', 1)
        else:
            base_key = key_str
        
        # Убираем vless://
        content = base_key[8:]
        
        # Разделяем на основную часть и параметры
        if '?' in content:
            auth_part, params_str = content.split('?', 1)
            params = dict(urllib.parse.parse_qsl(params_str))
        else:
            auth_part = content
            params = {}
        
        # Парсим uuid@host:port
        if '@' in auth_part:
            uuid, host_port = auth_part.split('@', 1)
        else:
            return None
        
        if ':' in host_port:
            host, port_str = host_port.split(':', 1)
            try:
                port = int(port_str)
            except:
                port = 443
        else:
            host = host_port
            port = 443
        
        return {
            'host': host,
            'port': port,
            'uuid': uuid,
            'name': name,
            'params': params,
            'full_key': original_key  # Сохраняем полный оригинальный ключ
        }
    except Exception as e:
        print(f"Error parsing key: {e}", file=sys.stderr)
        return None

def parse_any_key(key_str):
    """Парсит любой ключ (VLESS, SS, и т.д.)"""
    key_str = key_str.strip()
    
    if key_str.startswith('vless://'):
        return parse_vless_key(key_str)
    elif key_str.startswith('ss://'):
        # Для SS ключей просто возвращаем как есть
        return {
            'type': 'ss',
            'full_key': key_str,
            'host': extract_host_from_ss(key_str)
        }
    else:
        # Для неизвестных ключей
        return {
            'type': 'unknown',
            'full_key': key_str
        }

def extract_host_from_ss(ss_key):
    """Извлекает хост из SS ключа"""
    try:
        if '@' in ss_key:
            host_part = ss_key.split('@')[1]
            if ':' in host_part:
                return host_part.split(':')[0]
    except:
        pass
    return None

if __name__ == "__main__":
    # Тестирование
    for line in sys.stdin:
        parsed = parse_any_key(line)
        if parsed:
            print(json.dumps(parsed, ensure_ascii=False))
PYEOF

chmod +x /usr/local/bin/parse_keys.py

# ==============================================
# СОЗДАНИЕ СКРИПТА ЗАГРУЗКИ КЛЮЧЕЙ
# ==============================================

echo -e "\n${YELLOW}6. Создаю скрипт загрузки ключей из приватного репозитория...${NC}"

cat > /usr/local/bin/fetch_keys.py << PYEOF
#!/usr/bin/env python3
import requests
import json
import sys
import os
import base64
from urllib.parse import urlparse

GITHUB_USER = "${GITHUB_USER}"
REPO_NAME = "${REPO_NAME}"
KEYS_FILE = "${KEYS_FILE}"
GITHUB_TOKEN = "${GITHUB_TOKEN}"

def fetch_private_file():
    """Загружает файл из приватного репозитория GitHub"""
    url = f"https://api.github.com/repos/{GITHUB_USER}/{REPO_NAME}/contents/{KEYS_FILE}"
    
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3.raw"
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        # GitHub API возвращает содержимое в base64 если не указан raw
        if response.headers.get('Content-Type', '').startswith('application/json'):
            data = response.json()
            content = base64.b64decode(data['content']).decode('utf-8')
        else:
            content = response.text
        
        return content
    except Exception as e:
        print(f"Error fetching file: {e}", file=sys.stderr)
        return None

def main():
    content = fetch_private_file()
    if content:
        print(content)
        return 0
    return 1

if __name__ == "__main__":
    sys.exit(main())
PYEOF

chmod +x /usr/local/bin/fetch_keys.py

# ==============================================
# СОЗДАНИЕ ОСНОВНОГО СКРИПТА ОБНОВЛЕНИЯ
# ==============================================

echo -e "\n${YELLOW}7. Создаю основной скрипт обновления серверов...${NC}"

cat > /usr/local/bin/update_servers.py << 'PYEOF'
#!/usr/bin/env python3
import json
import subprocess
import sys
import os
import time
import re
from datetime import datetime

# Подключаем наши модули
sys.path.append('/usr/local/bin')
from parse_keys import parse_any_key
from fetch_keys import fetch_private_file

CONFIG_PATH = "/usr/local/etc/xray/config.json"
BACKUP_PATH = "/usr/local/etc/xray/config_backup.json"
LOG_PATH = "/var/log/vpn-balancer.log"

def log_message(msg):
    """Записывает сообщение в лог"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_PATH, 'a') as f:
        f.write(f"[{timestamp}] {msg}\n")
    print(f"[{timestamp}] {msg}")

def fetch_servers():
    """Загружает сервера из приватного репозитория"""
    log_message("Загрузка ключей из приватного репозитория...")
    
    content = fetch_private_file()
    if not content:
        log_message("❌ Не удалось загрузить файл")
        return []
    
    servers = []
    vless_servers = []
    
    for line in content.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        
        parsed = parse_any_key(line)
        if parsed:
            servers.append(parsed)
            if line.startswith('vless://'):
                vless_servers.append(parsed)
    
    log_message(f"✅ Загружено всего ключей: {len(servers)}")
    log_message(f"✅ VLESS ключей: {len(vless_servers)}")
    
    return vless_servers  # Возвращаем только VLESS для балансировки

def update_xray_config(servers):
    """Обновляет конфигурацию Xray с новыми серверами"""
    try:
        # Читаем текущую конфигурацию
        with open(CONFIG_PATH, 'r') as f:
            config = json.load(f)
        
        # Создаем outbounds для каждого сервера
        outbounds = []
        
        for i, server in enumerate(servers):
            # Используем полный оригинальный ключ для настроек
            full_key = server.get('full_key', '')
            
            # Формируем потоковые настройки
            streamSettings = {
                "network": server['params'].get('type', 'tcp'),
                "security": server['params'].get('security', 'none')
            }
            
            # Добавляем Reality если есть
            if server['params'].get('security') == 'reality':
                reality_settings = {
                    "serverName": server['params'].get('sni', ''),
                    "fingerprint": server['params'].get('fp', 'chrome'),
                    "publicKey": server['params'].get('pbk', ''),
                    "shortId": server['params'].get('sid', ''),
                    "spiderX": server['params'].get('spx', '')
                }
                streamSettings['realitySettings'] = reality_settings
            
            # Добавляем gRPC если есть
            if server['params'].get('type') == 'grpc':
                streamSettings['grpcSettings'] = {
                    "serviceName": server['params'].get('serviceName', ''),
                    "mode": server['params'].get('mode', 'gun')
                }
            
            outbound = {
                "protocol": "vless",
                "tag": f"vpn-server-{i}",
                "settings": {
                    "vnext": [
                        {
                            "address": server['host'],
                            "port": server['port'],
                            "users": [
                                {
                                    "id": server['uuid'],
                                    "flow": server['params'].get('flow', ''),
                                    "encryption": server['params'].get('encryption', 'none')
                                }
                            ]
                        }
                    ]
                },
                "streamSettings": streamSettings
            }
            outbounds.append(outbound)
        
        # Добавляем стандартные outbounds
        outbounds.append({
            "protocol": "freedom",
            "tag": "direct"
        })
        outbounds.append({
            "protocol": "blackhole",
            "tag": "block"
        })
        
        # Обновляем конфигурацию
        config['outbounds'] = outbounds
        
        # Обновляем selector для балансировщика
        for balancer in config.get('routing', {}).get('balancers', []):
            if balancer['tag'] == 'vpn-servers':
                balancer['selector'] = [f"vpn-server-{i}" for i in range(len(servers))]
        
        # Создаем резервную копию
        if os.path.exists(CONFIG_PATH):
            os.rename(CONFIG_PATH, BACKUP_PATH)
        
        # Сохраняем новую конфигурацию
        with open(CONFIG_PATH, 'w') as f:
            json.dump(config, f, indent=2)
        
        log_message(f"✅ Конфигурация обновлена: {len(servers)} серверов добавлено")
        return True
        
    except Exception as e:
        log_message(f"❌ Ошибка обновления конфигурации: {e}")
        return False

def reload_xray():
    """Перезагружает Xray"""
    try:
        # Проверяем конфигурацию
        result = subprocess.run(['/usr/local/bin/xray', 'check', '-c', CONFIG_PATH], 
                              capture_output=True, text=True)
        
        if result.returncode != 0:
            log_message(f"❌ Ошибка в конфигурации: {result.stderr}")
            return False
        
        # Перезагружаем Xray
        subprocess.run(['systemctl', 'reload', 'xray'], check=True)
        log_message("✅ Xray успешно перезагружен")
        return True
        
    except Exception as e:
        log_message(f"❌ Ошибка перезагрузки Xray: {e}")
        return False

def main():
    log_message("=" * 50)
    log_message("🔄 НАЧАЛО ОБНОВЛЕНИЯ СЕРВЕРОВ")
    
    servers = fetch_servers()
    
    if len(servers) >= 2:  # Нужно минимум 2 сервера для балансировки
        if update_xray_config(servers):
            reload_xray()
    else:
        log_message(f"⚠️ Недостаточно серверов: {len(servers)} (нужно минимум 2)")
    
    log_message("🏁 ЗАВЕРШЕНО")
    
if __name__ == "__main__":
    main()
PYEOF

chmod +x /usr/local/bin/update_servers.py

# ==============================================
# ТЕСТОВЫЙ ЗАПУСК
# ==============================================

echo -e "\n${YELLOW}8. Тестовый запуск загрузки ключей...${NC}"
/usr/bin/python3 /usr/local/bin/update_servers.py

# ==============================================
# СОЗДАНИЕ CRON ДЛЯ АВТО-ОБНОВЛЕНИЯ
# ==============================================

echo -e "\n${YELLOW}9. Настраиваю автоматическое обновление...${NC}"

cat > /etc/cron.d/vpn-balancer << EOF
# Обновление списка серверов каждые 5 минут
*/5 * * * * root /usr/bin/python3 /usr/local/bin/update_servers.py >> /var/log/vpn-balancer-cron.log 2>&1
EOF

chmod 644 /etc/cron.d/vpn-balancer

# ==============================================
# СОЗДАНИЕ SERVICE ДЛЯ АВТОЗАПУСКА
# ==============================================

echo -e "\n${YELLOW}10. Создаю systemd сервис...${NC}"

cat > /etc/systemd/system/vpn-balancer.service << EOF
[Unit]
Description=VPN Balancer Auto-Updater
After=network.target xray.service
Wants=xray.service

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/local/bin/update_servers.py
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/vpn-balancer.timer << EOF
[Unit]
Description=Run VPN Balancer updater every 5 minutes
Requires=vpn-balancer.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable vpn-balancer.timer
systemctl start vpn-balancer.timer
systemctl enable xray
systemctl restart xray

# ==============================================
# СОЗДАНИЕ СКРИПТА МОНИТОРИНГА
# ==============================================

echo -e "\n${YELLOW}11. Создаю скрипты мониторинга...${NC}"

cat > /usr/local/bin/balancer-status << 'EOF'
#!/bin/bash

echo "╔══════════════════════════════════════════════════════════╗"
echo "║              VPN БАЛАНСИРОВЩИК - СТАТУС                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "📊 СТАТУС XRAY:"
systemctl status xray --no-pager | grep -E "Active|Loaded"
echo ""

echo "🔄 СТАТУС АВТО-ОБНОВЛЕНИЯ:"
systemctl status vpn-balancer.timer --no-pager | grep "Active"
echo ""

echo "🔢 ПОСЛЕДНЕЕ ОБНОВЛЕНИЕ:"
tail -5 /var/log/vpn-balancer.log
echo ""

echo "🌍 АКТИВНЫЕ СЕРВЕРА:"
grep -A2 "vpn-server-" /usr/local/etc/xray/config.json | grep "address" | cut -d'"' -f4 | nl
echo ""

echo "📈 ТОП-5 СЕРВЕРОВ ПО ТРАФИКУ:"
if [ -f /var/log/xray/access.log ]; then
    tail -100 /var/log/xray/access.log | grep "proxy" | awk '{print $5}' | sort | uniq -c | sort -rn | head -5
else
    echo "   Лог-файл еще не создан"
fi
echo ""

echo "🔑 ВАШ VLESS КЛЮЧ (для клиентов):"
SERVER_IP=$(curl -s ifconfig.me)
echo "vless://${UUID}@${SERVER_IP}:${XRAY_PORT}?encryption=none&security=reality&type=tcp&flow=xtls-rprx-vision&sni=www.microsoft.com&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#VPN-Balancer"
echo ""
EOF

chmod +x /usr/local/bin/balancer-status

# ==============================================
# СОЗДАНИЕ АЛИАСОВ
# ==============================================

echo "alias balancer-status='/usr/local/bin/balancer-status'" >> ~/.bashrc
echo "alias balancer-logs='tail -f /var/log/vpn-balancer.log'" >> ~/.bashrc
echo "alias balancer-update='sudo /usr/bin/python3 /usr/local/bin/update_servers.py'" >> ~/.bashrc
source ~/.bashrc

# ==============================================
# ФИНАЛЬНЫЙ ВЫВОД
# ==============================================

clear
SERVER_IP=$(curl -s ifconfig.me)

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         ✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}🔑 ВАШ ЕДИНСТВЕННЫЙ VLESS КЛЮЧ (для всех клиентов):${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}vless://${UUID}@${SERVER_IP}:${XRAY_PORT}?encryption=none&security=reality&type=tcp&flow=xtls-rprx-vision&sni=www.microsoft.com&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#VPN-Balancer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📊 ИНФОРМАЦИЯ О ПОДКЛЮЧЕННЫХ СЕРВЕРАХ:${NC}"
/usr/local/bin/balancer-status | grep -A10 "АКТИВНЫЕ СЕРВЕРА"
echo ""
echo -e "${YELLOW}📋 ДОСТУПНЫЕ КОМАНДЫ:${NC}"
echo -e "  ${GREEN}balancer-status${NC}  - Показать статус балансировщика"
echo -e "  ${GREEN}balancer-logs${NC}   - Показать логи обновлений"
echo -e "  ${GREEN}balancer-update${NC} - Принудительно обновить список серверов"
echo ""
echo -e "${YELLOW}📁 ФАЙЛЫ:${NC}"
echo -e "  Конфигурация: ${GREEN}/usr/local/etc/xray/config.json${NC}"
echo -e "  Логи: ${GREEN}/var/log/vpn-balancer.log${NC}"
echo -e "  Скрипты: ${GREEN}/usr/local/bin/${NC}"
echo ""
echo -e "${YELLOW}🔍 ПРОВЕРКА:${NC}"
echo -e "  ${GREEN}curl http://${SERVER_IP}:${XRAY_PORT}${NC} - должен вернуть страницу Microsoft"
echo ""
echo -e "${GREEN}✅ ГОТОВО! ВСТАВЬТЕ ЭТОТ ОДИН КЛЮЧ В ВАШУ ПОДПИСКУ${NC}"
echo -e "${RED}⚠️  ВАЖНО: Сохраните этот ключ, он больше не покажется!${NC}"
echo ""

# Сохраняем ключ в файл
mkdir -p /root/vpn-keys
cat > /root/vpn-keys/balancer-key.txt << EOF
🔑 VLESS КЛЮЧ БАЛАНСИРОВЩИКА (СОЗДАН: $(date))
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
vless://${UUID}@${SERVER_IP}:${XRAY_PORT}?encryption=none&security=reality&type=tcp&flow=xtls-rprx-vision&sni=www.microsoft.com&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#VPN-Balancer
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ПАРАМЕТРЫ:
- UUID: ${UUID}
- Private Key: ${PRIVATE_KEY}
- Public Key: ${PUBLIC_KEY}
- Short ID: ${SHORT_ID}
- Порт: ${XRAY_PORT}
- SNI: www.microsoft.com

ИСТОЧНИК КЛЮЧЕЙ:
- GitHub: ${GITHUB_USER}/${REPO_NAME}/${KEYS_FILE}
- Токен: ${GITHUB_TOKEN:0:10}...

ДАТА УСТАНОВКИ: $(date)
EOF

chmod 600 /root/vpn-keys/balancer-key.txt

echo -e "${YELLOW}💾 Ключ также сохранен в файле: ${GREEN}/root/vpn-keys/balancer-key.txt${NC}"
echo ""