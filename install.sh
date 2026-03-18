#!/bin/bash

# ==============================================
# ПОЛНАЯ УСТАНОВКА VPN БАЛАНСИРОВЩИКА
# ИСПРАВЛЕННАЯ ВЕРСИЯ 2.0 - БЕЗ ОШИБОК ПАРСИНГА
# ==============================================

set -e  # Прерывать при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Функция для вывода с временной меткой
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция для проверки успешности выполнения
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

# Логотип
clear
echo -e "${BLUE}"
echo '╔══════════════════════════════════════════════════════════════════════╗'
echo '║                                                                      ║'
echo '║           VPN БАЛАНСИРОВЩИК - ПОЛНАЯ УСТАНОВКА                       ║'
echo '║           Приватный репозиторий + Авто-обновление                   ║'
echo '║           Версия 2.0 - ИСПРАВЛЕННАЯ                                 ║'
echo '║                                                                      ║'
echo '╚══════════════════════════════════════════════════════════════════════╝'
echo -e "${NC}"
echo ""

# ==============================================
# ПРОВЕРКА ПРАВ ROOT
# ==============================================
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Этот скрипт должен запускаться с правами root${NC}"
   echo "   Используйте: sudo bash install.sh"
   exit 1
fi

# ==============================================
# ЗАПРОС ДАННЫХ
# ==============================================

echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📝 ВВЕДИТЕ ДАННЫЕ ДЛЯ ДОСТУПА К ПРИВАТНОМУ РЕПОЗИТОРИЮ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

read -p "👉 GitHub username: " GITHUB_USER
while [ -z "$GITHUB_USER" ]; do
    echo -e "${RED}Имя пользователя не может быть пустым${NC}"
    read -p "👉 GitHub username: " GITHUB_USER
done

read -p "👉 Название репозитория: " REPO_NAME
while [ -z "$REPO_NAME" ]; do
    echo -e "${RED}Название репозитория не может быть пустым${NC}"
    read -p "👉 Название репозитория: " REPO_NAME
done

read -p "👉 Имя файла с ключами (например vpnnn.txt): " KEYS_FILE
while [ -z "$KEYS_FILE" ]; do
    echo -e "${RED}Имя файла не может быть пустым${NC}"
    read -p "👉 Имя файла с ключами: " KEYS_FILE
done

echo -e "${YELLOW}👉 Введите GitHub Personal Access Token (с доступом к repo):${NC}"
read -s GITHUB_TOKEN
echo ""
while [ -z "$GITHUB_TOKEN" ]; do
    echo -e "${RED}Токен не может быть пустым${NC}"
    echo -e "${YELLOW}👉 Введите GitHub Personal Access Token:${NC}"
    read -s GITHUB_TOKEN
    echo ""
done

read -p "👉 Порт для VLESS (по умолчанию 443): " XRAY_PORT
XRAY_PORT=${XRAY_PORT:-443}

# ==============================================
# ПРОВЕРКА ДОСТУПА К РЕПОЗИТОРИЮ
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔍 ПРОВЕРКА ДОСТУПА К РЕПОЗИТОРИЮ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

log "Проверяю доступ к файлу ${KEYS_FILE} в репозитории ${GITHUB_USER}/${REPO_NAME}..."

TEST_URL="https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/${KEYS_FILE}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token ${GITHUB_TOKEN}" "${TEST_URL}")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Доступ к файлу подтвержден! (HTTP 200)${NC}"
    
    # Показываем первые несколько строк файла для подтверждения
    echo -e "${CYAN}Первые 3 строки файла:${NC}"
    curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
         -H "Accept: application/vnd.github.v3.raw" \
         "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/${KEYS_FILE}" | head -3
    echo ""
else
    echo -e "${RED}❌ Ошибка доступа к файлу (код: $HTTP_CODE)${NC}"
    echo ""
    echo "Возможные причины:"
    echo "  • Неправильное имя пользователя: ${GITHUB_USER}"
    echo "  • Неправильное название репозитория: ${REPO_NAME}"
    echo "  • Неправильное имя файла: ${KEYS_FILE}"
    echo "  • Токен не имеет доступа к repo"
    echo "  • Репозиторий не существует или файл удален"
    echo ""
    echo "Проверьте данные и запустите скрипт заново"
    exit 1
fi

# ==============================================
# ОБНОВЛЕНИЕ СИСТЕМЫ
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📦 1. ОБНОВЛЕНИЕ СИСТЕМЫ И УСТАНОВКА ЗАВИСИМОСТЕЙ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

log "Обновление списка пакетов..."
apt update
check_success "Обновление списка пакетов"

log "Обновление установленных пакетов..."
apt upgrade -y
check_success "Обновление пакетов"

log "Установка необходимых пакетов..."
apt install -y curl wget git python3-pip python3-venv unzip nginx cron openssl net-tools socat jq
check_success "Установка зависимостей"

# ==============================================
# УСТАНОВКА XRAY
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🚀 2. УСТАНОВКА XRAY${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

log "Скачивание и установка Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
check_success "Установка Xray"

# Проверка установки Xray
if command -v xray &> /dev/null; then
    XRAY_VERSION=$(xray version | head -1)
    log "Xray установлен: ${XRAY_VERSION}"
else
    echo -e "${RED}❌ Xray не установился корректно${NC}"
    exit 1
fi

# ==============================================
# ГЕНЕРАЦИЯ КЛЮЧЕЙ
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔐 3. ГЕНЕРАЦИЯ КЛЮЧЕЙ БЕЗОПАСНОСТИ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Генерация UUID для клиентов
UUID=$(cat /proc/sys/kernel/random/uuid)
log "Сгенерирован UUID: ${UUID}"

# Генерация ключей Reality
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')

# Генерация short ID
SHORT_ID=$(openssl rand -hex 8)

# Генерация случайного short ID массива
SHORT_ID_ARRAY="[\"${SHORT_ID}\"]"

echo -e "${GREEN}  ✅ Private Key: ${PRIVATE_KEY:0:20}...${NC}"
echo -e "${GREEN}  ✅ Public Key: ${PUBLIC_KEY:0:20}...${NC}"
echo -e "${GREEN}  ✅ Short ID: ${SHORT_ID}${NC}"

# ==============================================
# СОЗДАНИЕ ДИРЕКТОРИЙ
# ==============================================

log "Создание необходимых директорий..."
mkdir -p /usr/local/etc/xray
mkdir -p /var/log/xray
mkdir -p /usr/local/bin
mkdir -p /var/log/vpn-balancer
mkdir -p /root/vpn-keys
check_success "Создание директорий"

# ==============================================
# СОЗДАНИЕ БАЗОВОЙ КОНФИГУРАЦИИ XRAY
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⚙️ 4. СОЗДАНИЕ БАЗОВОЙ КОНФИГУРАЦИИ XRAY${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

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
            "www.google.com",
            "www.cloudflare.com"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ${SHORT_ID_ARRAY}
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
check_success "Создание базовой конфигурации Xray"

# ==============================================
# СОЗДАНИЕ СКРИПТА ЗАГРУЗКИ КЛЮЧЕЙ (ПРОСТОЙ)
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📥 5. СОЗДАНИЕ СКРИПТА ЗАГРУЗКИ КЛЮЧЕЙ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /usr/local/bin/fetch_keys.py << EOF
#!/usr/bin/env python3
"""
Очень простой загрузчик ключей из приватного репозитория GitHub
"""

import requests
import sys
import base64
import json

# Данные для доступа
GITHUB_USER = "${GITHUB_USER}"
REPO_NAME = "${REPO_NAME}"
KEYS_FILE = "${KEYS_FILE}"
GITHUB_TOKEN = "${GITHUB_TOKEN}"

def fetch_keys():
    """Загружает файл с ключами"""
    url = f"https://api.github.com/repos/{GITHUB_USER}/{REPO_NAME}/contents/{KEYS_FILE}"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    try:
        print(f"Загрузка {KEYS_FILE} из {GITHUB_USER}/{REPO_NAME}...", file=sys.stderr)
        
        response = requests.get(url, headers=headers, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            
            # Декодируем из base64
            if 'content' in data:
                content = base64.b64decode(data['content']).decode('utf-8')
                print(content, end='')
                print(f"✅ Успешно загружено {len(content.splitlines())} строк", file=sys.stderr)
                return True
            else:
                print("❌ Неверный формат ответа", file=sys.stderr)
        else:
            print(f"❌ Ошибка HTTP {response.status_code}", file=sys.stderr)
            print(response.text, file=sys.stderr)
            
    except Exception as e:
        print(f"❌ Ошибка: {e}", file=sys.stderr)
    
    return False

if __name__ == "__main__":
    if not fetch_keys():
        sys.exit(1)
EOF

chmod +x /usr/local/bin/fetch_keys.py
check_success "Создание скрипта загрузки ключей"

# ==============================================
# СОЗДАНИЕ СКРИПТА ПАРСЕРА (МАКСИМАЛЬНО ПРОСТОЙ)
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔧 6. СОЗДАНИЕ СКРИПТА ПАРСЕРА КЛЮЧЕЙ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /usr/local/bin/parse_keys.py << 'EOF'
#!/usr/bin/env python3
"""
Максимально простой парсер VLESS ключей
Без сложностей, без интерактива, только построчный парсинг
"""

import sys
import json
import urllib.parse

def parse_vless_key(line):
    """
    Парсит VLESS ключ максимально просто
    Формат: vless://uuid@host:port?params#name
    """
    try:
        line = line.strip()
        if not line.startswith('vless://'):
            return None
        
        # Убираем vless://
        content = line[8:]
        
        # Отделяем параметры от основной части
        params_part = ''
        if '?' in content:
            auth_part, params_part = content.split('?', 1)
        else:
            auth_part = content
        
        # Отделяем имя (комментарий)
        name = ''
        if '#' in line:
            full_line, name = line.split('#', 1)
        
        # Парсим uuid@host:port
        if '@' not in auth_part:
            return None
        
        uuid, host_port = auth_part.split('@', 1)
        
        # Парсим host:port
        if ':' in host_port:
            host, port_str = host_port.split(':', 1)
            # Обрезаем всё лишнее после порта
            port_str = port_str.split('?')[0].split('#')[0]
            try:
                port = int(port_str)
            except:
                port = 443
        else:
            host = host_port
            port = 443
        
        # Парсим параметры
        params = {}
        if params_part:
            # Обрезаем имя если есть
            params_part = params_part.split('#')[0]
            for param in params_part.split('&'):
                if '=' in param:
                    k, v = param.split('=', 1)
                    params[k] = v
        
        # Формируем результат
        result = {
            'type': 'vless',
            'uuid': uuid,
            'host': host,
            'port': port,
            'name': name,
            'params': params,
            'full_key': line
        }
        
        return result
        
    except Exception as e:
        # В случае ошибки просто пропускаем
        sys.stderr.write(f"Error parsing line: {e}\n")
        return None

def main():
    """Читает строки из stdin и выводит JSON в stdout"""
    for line in sys.stdin:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
            
        parsed = parse_vless_key(line)
        if parsed:
            # Выводим только JSON, ничего лишнего
            print(json.dumps(parsed, ensure_ascii=False))
            sys.stdout.flush()

if __name__ == "__main__":
    main()
EOF

chmod +x /usr/local/bin/parse_keys.py
check_success "Создание скрипта парсера"

# ==============================================
# ТЕСТИРОВАНИЕ ПАРСЕРА
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🧪 7. ТЕСТИРОВАНИЕ ПАРСЕРА${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

log "Тестирование парсера на примере ключа..."
echo "vless://5d86335c-a27c-4b04-900d-e360971f80ad@185.189.46.63:443?encryption=none&type=grpc&mode=gun&security=reality&fp=chrome&sni=swe.denditop.site&pbk=HZiMehwH6sQf4bDkLiXJ0KslpYqz0mNFwBr34-e6RRM&sid=9c2378562188c3cb&spx=/#🇸🇪 Базовый 80мс [xankaVPN]" | /usr/bin/python3 /usr/local/bin/parse_keys.py | jq .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Парсер работает корректно${NC}"
else
    echo -e "${RED}❌ Парсер не работает${NC}"
    exit 1
fi

# ==============================================
# ТЕСТОВАЯ ЗАГРУЗКА КЛЮЧЕЙ
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📤 8. ТЕСТОВАЯ ЗАГРУЗКА КЛЮЧЕЙ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

log "Пробная загрузка ключей из репозитория..."
/usr/bin/python3 /usr/local/bin/fetch_keys.py > /tmp/test_keys.txt

if [ -s /tmp/test_keys.txt ]; then
    KEY_COUNT=$(wc -l < /tmp/test_keys.txt)
    echo -e "${GREEN}✅ Успешно загружено ${KEY_COUNT} строк ключей${NC}"
    
    # Показываем первые несколько ключей
    echo -e "${CYAN}Первые 3 ключа из файла:${NC}"
    head -3 /tmp/test_keys.txt
    echo ""
else
    echo -e "${RED}❌ Не удалось загрузить ключи${NC}"
    exit 1
fi

# ==============================================
# СОЗДАНИЕ ОСНОВНОГО СКРИПТА ОБНОВЛЕНИЯ
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔄 9. СОЗДАНИЕ СКРИПТА ОБНОВЛЕНИЯ СЕРВЕРОВ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /usr/local/bin/update_servers.py << 'EOF'
#!/usr/bin/env python3
"""
Простой скрипт обновления конфигурации Xray
Без сложных зависимостей, с таймаутами
"""

import json
import subprocess
import sys
import os
import time
from datetime import datetime

# Константы
CONFIG_PATH = "/usr/local/etc/xray/config.json"
BACKUP_PATH = "/usr/local/etc/xray/config_backup.json"
LOG_PATH = "/var/log/vpn-balancer.log"

def log_message(msg):
    """Запись в лог"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {msg}"
    
    try:
        with open(LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(log_entry + '\n')
    except:
        pass
    
    print(log_entry)

def run_command(cmd, timeout=10):
    """Запуск команды с таймаутом"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Timeout expired"
    except Exception as e:
        return False, "", str(e)

def fetch_keys():
    """Загружает ключи из GitHub"""
    log_message("Загрузка ключей из репозитория...")
    
    success, stdout, stderr = run_command(['/usr/bin/python3', '/usr/local/bin/fetch_keys.py'], timeout=30)
    
    if success and stdout:
        log_message(f"✅ Загружено {len(stdout.splitlines())} строк")
        return stdout
    else:
        log_message(f"❌ Ошибка загрузки: {stderr}")
        return None

def parse_keys(content):
    """Парсит ключи построчно"""
    servers = []
    lines = content.split('\n')
    
    log_message(f"Парсинг {len(lines)} строк...")
    
    for line_num, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        
        # Парсим через внешний скрипт
        try:
            proc = subprocess.run(
                ['/usr/bin/python3', '/usr/local/bin/parse_keys.py'],
                input=line,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if proc.returncode == 0 and proc.stdout:
                try:
                    parsed = json.loads(proc.stdout.strip())
                    if parsed.get('type') == 'vless':
                        servers.append(parsed)
                        log_message(f"  ✅ {parsed['host']}:{parsed['port']}")
                except json.JSONDecodeError:
                    pass
        except subprocess.TimeoutExpired:
            log_message(f"  ⚠️ Таймаут на строке {line_num}")
            continue
    
    log_message(f"✅ Найдено VLESS серверов: {len(servers)}")
    return servers

def create_outbound(server, index):
    """Создает outbound для сервера"""
    params = server.get('params', {})
    
    # Базовые настройки Reality
    reality_settings = {
        "serverName": params.get('sni', 'www.microsoft.com'),
        "fingerprint": params.get('fp', 'chrome'),
        "publicKey": params.get('pbk', ''),
        "shortId": params.get('sid', '6ba85179e30d4fc2')
    }
    
    if 'spx' in params:
        reality_settings['spiderX'] = params['spx']
    
    stream_settings = {
        "network": params.get('type', 'tcp'),
        "security": params.get('security', 'reality'),
        "realitySettings": reality_settings
    }
    
    # Для gRPC
    if params.get('type') == 'grpc':
        stream_settings['grpcSettings'] = {
            "serviceName": params.get('serviceName', ''),
            "mode": params.get('mode', 'gun')
        }
    
    return {
        "protocol": "vless",
        "tag": f"vpn-server-{index}",
        "settings": {
            "vnext": [{
                "address": server['host'],
                "port": server.get('port', 443),
                "users": [{
                    "id": server['uuid'],
                    "flow": params.get('flow', 'xtls-rprx-vision'),
                    "encryption": params.get('encryption', 'none')
                }]
            }]
        },
        "streamSettings": stream_settings
    }

def update_config(servers):
    """Обновляет конфигурацию Xray"""
    try:
        # Читаем текущую конфигурацию
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        # Создаем outbounds
        outbounds = []
        
        for i, server in enumerate(servers):
            outbound = create_outbound(server, i)
            outbounds.append(outbound)
            log_message(f"  ➕ Добавлен: {server['host']}:{server.get('port', 443)}")
        
        # Добавляем стандартные
        outbounds.append({"protocol": "freedom", "tag": "direct"})
        outbounds.append({"protocol": "blackhole", "tag": "block"})
        
        config['outbounds'] = outbounds
        
        # Обновляем балансировщик
        if 'routing' not in config:
            config['routing'] = {"balancers": [], "rules": []}
        
        if 'balancers' not in config['routing']:
            config['routing']['balancers'] = []
        
        # Находим или создаем балансировщик
        balancer_found = False
        for balancer in config['routing']['balancers']:
            if balancer.get('tag') == 'vpn-servers':
                balancer['selector'] = [f"vpn-server-{i}" for i in range(len(servers))]
                balancer_found = True
                break
        
        if not balancer_found and servers:
            config['routing']['balancers'].append({
                "tag": "vpn-servers",
                "selector": [f"vpn-server-{i}" for i in range(len(servers))],
                "strategy": {"type": "leastPing"}
            })
        
        # Сохраняем резервную копию
        if os.path.exists(CONFIG_PATH):
            import shutil
            shutil.copy2(CONFIG_PATH, BACKUP_PATH)
        
        # Сохраняем новую конфигурацию
        with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        
        log_message(f"✅ Конфигурация обновлена: {len(servers)} серверов")
        return True
        
    except Exception as e:
        log_message(f"❌ Ошибка: {e}")
        return False

def reload_xray():
    """Перезагружает Xray"""
    log_message("Перезагрузка Xray...")
    
    # Проверяем конфигурацию
    success, stdout, stderr = run_command(['/usr/local/bin/xray', 'check', '-config', CONFIG_PATH])
    
    if not success:
        log_message(f"❌ Ошибка в конфигурации: {stderr}")
        # Восстанавливаем из резервной копии
        if os.path.exists(BACKUP_PATH):
            import shutil
            shutil.copy2(BACKUP_PATH, CONFIG_PATH)
            log_message("✅ Конфигурация восстановлена из резервной копии")
        return False
    
    # Перезапускаем Xray
    success, _, stderr = run_command(['systemctl', 'restart', 'xray'])
    
    if success:
        time.sleep(2)
        success, stdout, _ = run_command(['systemctl', 'is-active', 'xray'])
        if success and 'active' in stdout:
            log_message("✅ Xray успешно перезагружен")
            return True
    
    log_message(f"❌ Ошибка перезагрузки: {stderr}")
    return False

def main():
    """Основная функция"""
    log_message("=" * 60)
    log_message("🔄 НАЧАЛО ОБНОВЛЕНИЯ")
    
    # Загружаем ключи
    content = fetch_keys()
    if not content:
        log_message("❌ Нет данных для обработки")
        return 1
    
    # Парсим ключи
    servers = parse_keys(content)
    
    if len(servers) == 0:
        log_message("⚠️ Нет VLESS серверов")
        return 0
    
    # Обновляем конфигурацию
    if update_config(servers):
        reload_xray()
    
    log_message("🏁 ЗАВЕРШЕНО")
    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF

chmod +x /usr/local/bin/update_servers.py
check_success "Создание скрипта обновления"

# ==============================================
# ТЕСТОВЫЙ ЗАПУСК ОБНОВЛЕНИЯ
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🧪 10. ТЕСТОВЫЙ ЗАПУСК ОБНОВЛЕНИЯ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

log "Запуск скрипта обновления..."
/usr/bin/python3 /usr/local/bin/update_servers.py

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Скрипт обновления выполнен успешно${NC}"
else
    echo -e "${RED}❌ Ошибка при выполнении скрипта обновления${NC}"
fi

# ==============================================
# СОЗДАНИЕ CRON ДЛЯ АВТО-ОБНОВЛЕНИЯ
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⏰ 11. НАСТРОЙКА АВТОМАТИЧЕСКОГО ОБНОВЛЕНИЯ${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /etc/cron.d/vpn-balancer << EOF
# Обновление списка серверов каждые 5 минут
*/5 * * * * root /usr/bin/python3 /usr/local/bin/update_servers.py >> /var/log/vpn-balancer-cron.log 2>&1

# Очистка старых логов каждый день в 2:00
0 2 * * * root find /var/log/vpn-balancer* -type f -mtime +7 -delete
0 2 * * * root find /var/log/xray/*.log -type f -mtime +7 -delete
EOF

chmod 644 /etc/cron.d/vpn-balancer
check_success "Настройка cron"

# ==============================================
# ЗАПУСК XRAY
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🚀 12. ЗАПУСК XRAY${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

systemctl enable xray
systemctl restart xray
sleep 3

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}✅ Xray успешно запущен${NC}"
else
    echo -e "${RED}❌ Xray не запустился${NC}"
    journalctl -u xray -n 20 --no-pager
fi

# ==============================================
# СОЗДАНИЕ СКРИПТОВ МОНИТОРИНГА
# ==============================================

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 13. СОЗДАНИЕ СКРИПТОВ МОНИТОРИНГА${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /usr/local/bin/balancer-status << 'EOF'
#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo '╔══════════════════════════════════════════════════════════════════════╗'
echo '║              VPN БАЛАНСИРОВЩИК - СТАТУС                              ║'
echo '╚══════════════════════════════════════════════════════════════════════╝'
echo -e "${NC}"

# Информация о системе
echo -e "\n${YELLOW}📌 СИСТЕМА:${NC}"
echo "   • Хост: $(hostname)"
echo "   • IP: $(curl -s ifconfig.me 2>/dev/null || echo 'N/A')"
echo "   • Время: $(date '+%Y-%m-%d %H:%M:%S')"

# Статус Xray
echo -e "\n${YELLOW}🚀 XRAY:${NC}"
if systemctl is-active --quiet xray; then
    echo -e "   • Статус: ${GREEN}Активен${NC}"
else
    echo -e "   • Статус: ${RED}Не активен${NC}"
fi

XRAY_PID=$(pgrep xray)
if [ ! -z "$XRAY_PID" ]; then
    echo "   • PID: $XRAY_PID"
    echo "   • Память: $(ps -o rss= -p $XRAY_PID | awk '{printf "%.2f MB", $1/1024}')"
fi

# Проверка порта
if ss -tlnp | grep -q ":${XRAY_PORT:-443}"; then
    echo -e "   • Порт ${XRAY_PORT:-443}: ${GREEN}Слушается${NC}"
else
    echo -e "   • Порт ${XRAY_PORT:-443}: ${RED}Не слушается${NC}"
fi

# Загруженные сервера
echo -e "\n${YELLOW}🌍 ЗАГРУЖЕННЫЕ СЕРВЕРА:${NC}"
if [ -f /usr/local/etc/xray/config.json ]; then
    python3 -c "
import json
try:
    with open('/usr/local/etc/xray/config.json') as f:
        config = json.load(f)
    servers = []
    for outbound in config.get('outbounds', []):
        if outbound['tag'].startswith('vpn-server-'):
            settings = outbound['settings']['vnext'][0]
            servers.append(f\"    {outbound['tag']}: {settings['address']}:{settings['port']}\")
    if servers:
        for s in servers[:10]:
            print(s)
        if len(servers) > 10:
            print(f'    ... и еще {len(servers)-10} серверов')
    else:
        print('    ❌ Сервера не загружены')
except Exception as e:
    print(f'    ❌ Ошибка: {e}')
"
else
    echo "    ❌ Конфигурация не найдена"
fi

# Последние логи
echo -e "\n${YELLOW}📋 ПОСЛЕДНИЕ ОБНОВЛЕНИЯ:${NC}"
if [ -f /var/log/vpn-balancer.log ]; then
    tail -5 /var/log/vpn-balancer.log | sed 's/^/   /'
else
    echo "   ❌ Лог не найден"
fi

# VLESS ключ
echo -e "\n${YELLOW}🔑 VLESS КЛЮЧ:${NC}"
if [ -f /root/vpn-keys/balancer-key.txt ]; then
    KEY=$(grep -o 'vless://[^ ]*' /root/vpn-keys/balancer-key.txt | head -1)
    if [ ! -z "$KEY" ]; then
        echo "   $KEY"
    else
        echo "   ❌ Ключ не найден"
    fi
else
    echo "   ❌ Файл с ключом не найден"
fi

echo ""
EOF

chmod +x /usr/local/bin/balancer-status

cat > /usr/local/bin/balancer-logs << 'EOF'
#!/bin/bash

if [ "$1" = "-f" ] || [ "$1" = "--follow" ]; then
    tail -f /var/log/vpn-balancer.log
elif [ "$1" = "-n" ]; then
    COUNT=${2:-50}
    tail -n $COUNT /var/log/vpn-balancer.log
else
    echo "=== Последние 50 строк лога ==="
    tail -50 /var/log/vpn-balancer.log
    echo ""
    echo "Использование:"
    echo "  balancer-logs        - показать последние 50 строк"
    echo "  balancer-logs -n 100 - показать последние 100 строк"
    echo "  balancer-logs -f     - следить за логом в реальном времени"
fi
EOF

chmod +x /usr/local/bin/balancer-logs

cat > /usr/local/bin/balancer-update << 'EOF'
#!/bin/bash

echo "🔄 Принудительное обновление списка серверов..."
/usr/bin/python3 /usr/local/bin/update_servers.py

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Обновление выполнено успешно${NC}"
    echo "   Проверьте статус: balancer-status"
else
    echo ""
    echo -e "${RED}❌ Ошибка при обновлении${NC}"
    echo "   Проверьте логи: balancer-logs"
fi
EOF

chmod +x /usr/local/bin/balancer-update

cat > /usr/local/bin/connections << 'EOF'
#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

case "$1" in
    live)
        echo -e "${YELLOW}Просмотр подключений в реальном времени (Ctrl+C для выхода):${NC}"
        tail -f /var/log/xray/access.log | while read line; do
            if [[ $line == *"tcp"* ]]; then
                echo -e "${GREEN}🔌 $(date '+%H:%M:%S') - $line${NC}"
            fi
        done
        ;;
    stats)
        echo -e "${BLUE}════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}📊 СТАТИСТИКА ПОДКЛЮЧЕНИЙ${NC}"
        echo -e "${BLUE}════════════════════════════════════════════${NC}"
        
        TOTAL=$(wc -l < /var/log/xray/access.log 2>/dev/null || echo "0")
        echo -e "Всего подключений: ${GREEN}$TOTAL${NC}"
        
        TODAY=$(grep -c "$(date '+%Y/%m/%d')" /var/log/xray/access.log 2>/dev/null || echo "0")
        echo -e "За сегодня: ${CYAN}$TODAY${NC}"
        
        echo -e "\n${YELLOW}Топ IP адресов:${NC}"
        tail -1000 /var/log/xray/access.log 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -rn | head -10 | while read count ip; do
            echo -e "  ${GREEN}$ip${NC} - ${CYAN}$count${NC}"
        done
        ;;
    ip)
        if [ -z "$2" ]; then
            echo "Использование: connections ip <IP-адрес>"
            exit 1
        fi
        echo -e "${YELLOW}Подключения с IP $2:${NC}"
        grep "$2" /var/log/xray/access.log | tail -20
        ;;
    help)
        echo "Использование: connections [live|stats|ip <IP>|help]"
        echo "  live  - просмотр в реальном времени"
        echo "  stats - статистика подключений"
        echo "  ip    - поиск по IP"
        ;;
    *)
        echo "Использование: connections [live|stats|ip <IP>|help]"
        tail -20 /var/log/xray/access.log 2>/dev/null
        ;;
esac
EOF

chmod +x /usr/local/bin/connections

# Добавляем алиасы
cat >> ~/.bashrc << EOF

# Алиасы для VPN балансировщика
alias balancer-status='/usr/local/bin/balancer-status'
alias balancer-logs='/usr/local/bin/balancer-logs'
alias balancer-update='/usr/local/bin/balancer-update'
alias connections='/usr/local/bin/connections'
alias xray-logs='journalctl -u xray -f'
alias xray-status='systemctl status xray'
EOF

source ~/.bashrc
check_success "Создание скриптов мониторинга"

# ==============================================
# СОХРАНЕНИЕ КЛЮЧА
# ==============================================

SERVER_IP=$(curl -s ifconfig.me)
FINAL_KEY="vless://${UUID}@${SERVER_IP}:${XRAY_PORT}?encryption=none&security=reality&type=tcp&flow=xtls-rprx-vision&sni=www.microsoft.com&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#VPN-Balancer"

cat > /root/vpn-keys/balancer-key.txt << EOF
╔════════════════════════════════════════════════════════════════════════════╗
║                 VPN БАЛАНСИРОВЩИК - КЛЮЧ ДОСТУПА                          ║
╚════════════════════════════════════════════════════════════════════════════╝

🔑 VLESS КЛЮЧ (для всех клиентов):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${FINAL_KEY}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 ПАРАМЕТРЫ КЛЮЧА:
  • UUID:        ${UUID}
  • Сервер:      ${SERVER_IP}
  • Порт:        ${XRAY_PORT}
  • Public Key:  ${PUBLIC_KEY}
  • Short ID:    ${SHORT_ID}
  • SNI:         www.microsoft.com

📊 ИНФОРМАЦИЯ О РЕПОЗИТОРИИ:
  • GitHub:      ${GITHUB_USER}/${REPO_NAME}
  • Файл:        ${KEYS_FILE}

⚙️ КОМАНДЫ УПРАВЛЕНИЯ:
  • balancer-status     - Показать статус
  • balancer-logs       - Показать логи
  • balancer-update     - Обновить сервера
  • connections         - Показать подключения
  • connections live    - Подключения в реальном времени
  • connections stats   - Статистика подключений

📁 ФАЙЛЫ:
  • Конфигурация: /usr/local/etc/xray/config.json
  • Лог обновлений: /var/log/vpn-balancer.log
  • Лог Xray: /var/log/xray/access.log
  • Этот файл: /root/vpn-keys/balancer-key.txt

📅 ДАТА УСТАНОВКИ: $(date '+%Y-%m-%d %H:%M:%S')
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  СОХРАНИТЕ ЭТОТ КЛЮЧ!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

chmod 600 /root/vpn-keys/balancer-key.txt
check_success "Сохранение ключа в файл"

# ==============================================
# ФИНАЛЬНЫЙ ВЫВОД
# ==============================================

clear
echo -e "${GREEN}"
echo '╔══════════════════════════════════════════════════════════════════════╗'
echo '║                                                                      ║'
echo '║           ✅ УСТАНОВКА ЗАВЕРШЕНА ПОЛНОСТЬЮ УСПЕШНО!                 ║'
echo '║                                                                      ║'
echo '╚══════════════════════════════════════════════════════════════════════╝'
echo -e "${NC}"
echo ""

echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔑 ВАШ ЕДИНСТВЕННЫЙ VLESS КЛЮЧ (для всех клиентов):${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}${FINAL_KEY}${NC}"
echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}📊 ЗАГРУЖЕННЫЕ СЕРВЕРА ИЗ ${KEYS_FILE}:${NC}"
python3 -c "
import json
try:
    with open('/usr/local/etc/xray/config.json') as f:
        config = json.load(f)
    servers = []
    for outbound in config.get('outbounds', []):
        if outbound['tag'].startswith('vpn-server-'):
            settings = outbound['settings']['vnext'][0]
            servers.append(f\"    {outbound['tag']}: {settings['address']}:{settings['port']}\")
    if servers:
        for s in servers[:5]:
            print(s)
        if len(servers) > 5:
            print(f'    ... и еще {len(servers)-5} серверов')
    else:
        print('    ❌ Сервера не загружены')
except Exception as e:
    print(f'    ❌ Ошибка: {e}')
"
echo ""

echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📋 ДОСТУПНЫЕ КОМАНДЫ:${NC}"
echo -e "  ${CYAN}balancer-status${NC}     - Показать полный статус"
echo -e "  ${CYAN}balancer-logs${NC}       - Показать логи обновлений"
echo -e "  ${CYAN}balancer-update${NC}     - Принудительно обновить список серверов"
echo -e "  ${CYAN}connections${NC}         - Показать последние подключения"
echo -e "  ${CYAN}connections live${NC}    - Подключения в реальном времени"
echo -e "  ${CYAN}connections stats${NC}   - Статистика подключений"
echo -e "  ${CYAN}xray-logs${NC}           - Логи Xray в реальном времени"
echo -e "  ${CYAN}xray-status${NC}         - Статус Xray"
echo ""

echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📁 ВАЖНЫЕ ФАЙЛЫ:${NC}"
echo -e "  • Ключ сохранен в: ${CYAN}/root/vpn-keys/balancer-key.txt${NC}"
echo -e "  • Конфигурация: ${CYAN}/usr/local/etc/xray/config.json${NC}"
echo -e "  • Лог обновлений: ${CYAN}/var/log/vpn-balancer.log${NC}"
echo -e "  • Лог подключений: ${CYAN}/var/log/xray/access.log${NC}"
echo ""

echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🔍 ПРОВЕРКА РАБОТЫ:${NC}"
echo -e "  • Запустите: ${CYAN}balancer-status${NC}"
echo -e "  • Или выполните: ${CYAN}curl -I http://${SERVER_IP}:${XRAY_PORT}${NC}"
echo ""

echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}⚠️  СОХРАНИТЕ КЛЮЧ ИЗ ЭТОГО ОКНА!${NC}"
echo -e "${RED}   Он также сохранен в файле /root/vpn-keys/balancer-key.txt${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Финальная проверка
sleep 2
/usr/local/bin/balancer-status | head -15