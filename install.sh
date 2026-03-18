#!/bin/bash

# ==============================================
# ПОЛНАЯ УСТАНОВКА VPN БАЛАНСИРОВЩИКА
# ИСПРАВЛЕННАЯ ВЕРСИЯ - МАРТ 2026
# ==============================================

set -e  # Прерывать при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
echo '╔══════════════════════════════════════════════════════════════════╗'
echo '║                                                                  ║'
echo '║           VPN БАЛАНСИРОВЩИК - ПОЛНАЯ УСТАНОВКА                   ║'
echo '║           Приватный репозиторий + Авто-обновление               ║'
echo '║           Версия 2.0 - Исправленная                             ║'
echo '║                                                                  ║'
echo '╚══════════════════════════════════════════════════════════════════╝'
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

echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📝 Введите данные для доступа к ПРИВАТНОМУ репозиторию:${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
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
read -s "GITHUB_TOKEN"
while [ -z "$GITHUB_TOKEN" ]; do
    echo -e "${RED}Токен не может быть пустым${NC}"
    echo -e "${YELLOW}👉 Введите GitHub Personal Access Token:${NC}"
    read -s "GITHUB_TOKEN"
done
echo ""

read -p "👉 Порт для VLESS (по умолчанию 443): " XRAY_PORT
XRAY_PORT=${XRAY_PORT:-443}

# ==============================================
# ПРОВЕРКА ДОСТУПА К РЕПОЗИТОРИЮ
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔍 ПРОВЕРКА ДОСТУПА К РЕПОЗИТОРИЮ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

log "Проверяю доступ к файлу ${KEYS_FILE} в репозитории ${GITHUB_USER}/${REPO_NAME}..."

TEST_URL="https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/${KEYS_FILE}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token ${GITHUB_TOKEN}" "${TEST_URL}")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Доступ к файлу подтвержден! (HTTP 200)${NC}"
    
    # Показываем первые несколько строк файла для подтверждения
    echo -e "${CYAN}Первые несколько строк файла:${NC}"
    curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
         -H "Accept: application/vnd.github.v3.raw" \
         "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/${KEYS_FILE}" | head -5
    echo ""
else
    echo -e "${RED}❌ Ошибка доступа к файлу (код: $HTTP_CODE)${NC}"
    echo ""
    echo "Возможные причины:"
    echo "  ❌ Неправильное имя пользователя: ${GITHUB_USER}"
    echo "  ❌ Неправильное название репозитория: ${REPO_NAME}"
    echo "  ❌ Неправильное имя файла: ${KEYS_FILE}"
    echo "  ❌ Токен не имеет доступа к repo"
    echo "  ❌ Репозиторий не существует или файл удален"
    echo ""
    echo "Проверьте данные и запустите скрипт заново"
    exit 1
fi

# ==============================================
# ОБНОВЛЕНИЕ СИСТЕМЫ
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📦 1. ОБНОВЛЕНИЕ СИСТЕМЫ И УСТАНОВКА ЗАВИСИМОСТЕЙ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

log "Обновление списка пакетов..."
apt update
check_success "Обновление списка пакетов"

log "Обновление установленных пакетов..."
apt upgrade -y
check_success "Обновление пакетов"

log "Установка необходимых пакетов..."
apt install -y curl wget git python3-pip python3-venv unzip nginx cron openssl net-tools socat
check_success "Установка зависимостей"

# ==============================================
# УСТАНОВКА XRAY
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🚀 2. УСТАНОВКА XRAY${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
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
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔐 3. ГЕНЕРАЦИЯ КЛЮЧЕЙ БЕЗОПАСНОСТИ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
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

echo -e "${GREEN}  ✅ Сгенерирован UUID: ${UUID}${NC}"
echo -e "${GREEN}  ✅ Сгенерирован Private Key: ${PRIVATE_KEY}${NC}"
echo -e "${GREEN}  ✅ Сгенерирован Public Key: ${PUBLIC_KEY}${NC}"
echo -e "${GREEN}  ✅ Сгенерирован Short ID: ${SHORT_ID}${NC}"

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
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⚙️ 4. СОЗДАНИЕ БАЗОВОЙ КОНФИГУРАЦИИ XRAY${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
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
# СОЗДАНИЕ СКРИПТА ПАРСЕРА
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔧 5. СОЗДАНИЕ СКРИПТА ПАРСЕРА КЛЮЧЕЙ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /usr/local/bin/parse_keys.py << 'PYEOF'
#!/usr/bin/env python3
"""
Парсер VPN ключей из файла vpnnn.txt
Сохраняет все параметры без сокращений
"""

import base64
import json
import re
import urllib.parse
import sys
from typing import Dict, Optional, Any

def parse_vless_key(key_str: str) -> Optional[Dict[str, Any]]:
    """
    Парсит VLESS ключ БЕЗ СОКРАЩЕНИЙ, сохраняя все параметры
    Формат: vless://uuid@host:port?params#name
    """
    try:
        if not key_str.startswith('vless://'):
            return None
        
        # Сохраняем оригинальный ключ полностью
        original_key = key_str.strip()
        
        # Извлекаем имя из комментария если есть
        name = ''
        comment = ''
        if '#' in original_key:
            base_key, comment = original_key.split('#', 1)
            name = urllib.parse.unquote(comment)
        else:
            base_key = original_key
        
        # Убираем vless://
        content = base_key[8:]
        
        # Разделяем на основную часть и параметры
        params = {}
        auth_part = content
        
        if '?' in content:
            auth_part, params_str = content.split('?', 1)
            # Парсим параметры
            for param in params_str.split('&'):
                if '=' in param:
                    k, v = param.split('=', 1)
                    params[k] = v
        
        # Парсим uuid@host:port
        if '@' not in auth_part:
            return None
        
        uuid, host_port = auth_part.split('@', 1)
        
        # Парсим host:port
        if ':' in host_port:
            host, port_str = host_port.split(':', 1)
            try:
                port = int(port_str)
            except ValueError:
                port = 443
        else:
            host = host_port
            port = 443
        
        # Извлекаем дополнительные параметры из комментария если нужно
        # Некоторые ключи хранят параметры в комментарии
        if comment and not params:
            # Пытаемся найти параметры в комментарии
            for part in comment.split():
                if '=' in part:
                    k, v = part.split('=', 1)
                    params[k] = v
        
        result = {
            'type': 'vless',
            'uuid': uuid,
            'host': host,
            'port': port,
            'name': name,
            'comment': comment,
            'params': params,
            'full_key': original_key,
            'protocol': 'vless'
        }
        
        return result
        
    except Exception as e:
        print(f"Error parsing VLESS key: {e}", file=sys.stderr)
        return None

def parse_ss_key(key_str: str) -> Optional[Dict[str, Any]]:
    """
    Парсит Shadowsocks ключ
    Формат: ss://method:password@host:port#name
    """
    try:
        if not key_str.startswith('ss://'):
            return None
        
        original_key = key_str.strip()
        
        # Извлекаем имя из комментария
        name = ''
        if '#' in original_key:
            base_key, name = original_key.split('#', 1)
            name = urllib.parse.unquote(name)
        else:
            base_key = original_key
        
        content = base_key[5:]
        
        # Пробуем разные форматы SS ключей
        host = None
        port = None
        
        # Формат с @
        if '@' in content:
            method_pass, host_port = content.split('@', 1)
            if ':' in method_pass:
                method, password = method_pass.split(':', 1)
            else:
                # Возможно base64
                try:
                    decoded = base64.b64decode(method_pass).decode('utf-8')
                    if ':' in decoded:
                        method, password = decoded.split(':', 1)
                    else:
                        method, password = 'chacha20-ietf-poly1305', method_pass
                except:
                    method, password = 'chacha20-ietf-poly1305', method_pass
            
            if ':' in host_port:
                host, port_str = host_port.split(':', 1)
                port = int(port_str)
        
        # Формат с base64
        elif not content.startswith('ss://'):
            try:
                decoded = base64.b64decode(content).decode('utf-8')
                if '@' in decoded:
                    method_pass, host_port = decoded.split('@', 1)
                    if ':' in method_pass:
                        method, password = method_pass.split(':', 1)
                    if ':' in host_port:
                        host, port_str = host_port.split(':', 1)
                        port = int(port_str)
            except:
                pass
        
        if host and port:
            return {
                'type': 'ss',
                'method': method,
                'password': password,
                'host': host,
                'port': port,
                'name': name,
                'full_key': original_key,
                'protocol': 'ss'
            }
        
        # Если не удалось распарсить, возвращаем базовую информацию
        return {
            'type': 'ss',
            'full_key': original_key,
            'name': name,
            'protocol': 'ss'
        }
        
    except Exception as e:
        print(f"Error parsing SS key: {e}", file=sys.stderr)
        return None

def parse_any_key(key_str: str) -> Optional[Dict[str, Any]]:
    """
    Парсит любой ключ (VLESS, SS, и т.д.)
    """
    key_str = key_str.strip()
    
    if not key_str or key_str.startswith('#'):
        return None
    
    if key_str.startswith('vless://'):
        return parse_vless_key(key_str)
    elif key_str.startswith('ss://'):
        return parse_ss_key(key_str)
    elif key_str.startswith('trojan://'):
        # Для Trojan ключей
        return {
            'type': 'trojan',
            'full_key': key_str,
            'protocol': 'trojan'
        }
    else:
        # Для неизвестных ключей
        return {
            'type': 'unknown',
            'full_key': key_str,
            'protocol': 'unknown'
        }

def extract_host_from_key(key_dict: Dict) -> Optional[str]:
    """Извлекает хост из распарсенного ключа"""
    if 'host' in key_dict:
        return key_dict['host']
    
    # Пытаемся извлечь из full_key
    full_key = key_dict.get('full_key', '')
    if '@' in full_key:
        try:
            host_part = full_key.split('@')[1]
            if ':' in host_part:
                return host_part.split(':')[0]
            elif '?' in host_part:
                return host_part.split('?')[0]
            else:
                return host_part
        except:
            pass
    
    return None

def main():
    """Основная функция для тестирования"""
    import sys
    
    print("VPN Key Parser v2.0")
    print("=" * 50)
    
    if not sys.stdin.isatty():
        # Читаем из stdin
        for line in sys.stdin:
            line = line.strip()
            if line:
                parsed = parse_any_key(line)
                if parsed:
                    print(json.dumps(parsed, ensure_ascii=False, indent=2))
    else:
        # Интерактивный режим
        print("Введите ключи (по одному в строке, Ctrl+D для завершения):")
        for line in sys.stdin:
            line = line.strip()
            if line:
                parsed = parse_any_key(line)
                if parsed:
                    print(json.dumps(parsed, ensure_ascii=False, indent=2))
                else:
                    print(f"Не удалось распарсить: {line}")

if __name__ == "__main__":
    main()
PYEOF

chmod +x /usr/local/bin/parse_keys.py
check_success "Создание скрипта парсера"

# ==============================================
# СОЗДАНИЕ СКРИПТА ЗАГРУЗКИ КЛЮЧЕЙ
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📥 6. СОЗДАНИЕ СКРИПТА ЗАГРУЗКИ КЛЮЧЕЙ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /usr/local/bin/fetch_keys.py << PYEOF
#!/usr/bin/env python3
"""
Скрипт для загрузки ключей из приватного репозитория GitHub
Использует Personal Access Token для аутентификации
"""

import requests
import json
import sys
import os
import base64
from urllib.parse import urlparse
from typing import Optional

# Данные для доступа к репозиторию (заполняются при установке)
GITHUB_USER = "${GITHUB_USER}"
REPO_NAME = "${REPO_NAME}"
KEYS_FILE = "${KEYS_FILE}"
GITHUB_TOKEN = "${GITHUB_TOKEN}"

def fetch_private_file() -> Optional[str]:
    """
    Загружает файл из приватного репозитория GitHub
    
    Returns:
        Содержимое файла или None в случае ошибки
    """
    # GitHub API URL для получения содержимого файла
    url = f"https://api.github.com/repos/{GITHUB_USER}/{REPO_NAME}/contents/{KEYS_FILE}"
    
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3.raw"  # Получаем сырое содержимое
    }
    
    try:
        print(f"Загрузка файла: {KEYS_FILE} из {GITHUB_USER}/{REPO_NAME}", file=sys.stderr)
        
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        
        # Проверяем тип ответа
        content_type = response.headers.get('Content-Type', '')
        
        if 'application/json' in content_type:
            # Если получили JSON, значит файл закодирован в base64
            data = response.json()
            if 'content' in data:
                # Декодируем из base64
                content = base64.b64decode(data['content']).decode('utf-8')
                print(f"Файл загружен (base64), размер: {len(content)} символов", file=sys.stderr)
                return content
        else:
            # Получили сырое содержимое
            content = response.text
            print(f"Файл загружен (raw), размер: {len(content)} символов", file=sys.stderr)
            return content
            
    except requests.exceptions.HTTPError as e:
        if response.status_code == 404:
            print(f"Ошибка: Файл {KEYS_FILE} не найден в репозитории", file=sys.stderr)
        elif response.status_code == 401:
            print("Ошибка: Неверный токен или нет доступа", file=sys.stderr)
        elif response.status_code == 403:
            print("Ошибка: Доступ запрещен (возможно, превышен лимит запросов)", file=sys.stderr)
        else:
            print(f"HTTP ошибка {response.status_code}: {e}", file=sys.stderr)
            
    except requests.exceptions.ConnectionError:
        print("Ошибка: Нет соединения с GitHub", file=sys.stderr)
        
    except requests.exceptions.Timeout:
        print("Ошибка: Таймаут при соединении с GitHub", file=sys.stderr)
        
    except Exception as e:
        print(f"Неожиданная ошибка: {e}", file=sys.stderr)
    
    return None

def test_connection() -> bool:
    """Тестирует соединение с GitHub API"""
    try:
        url = "https://api.github.com"
        response = requests.get(url, timeout=10)
        return response.status_code == 200
    except:
        return False

def main():
    """Основная функция"""
    # Проверяем соединение с GitHub
    if not test_connection():
        print("Ошибка: Нет доступа к GitHub API", file=sys.stderr)
        return 1
    
    content = fetch_private_file()
    
    if content:
        # Выводим содержимое в stdout для использования в других скриптах
        print(content, end='')
        return 0
    else:
        print("Не удалось загрузить файл", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
PYEOF

chmod +x /usr/local/bin/fetch_keys.py
check_success "Создание скрипта загрузки ключей"

# ==============================================
# ТЕСТОВАЯ ЗАГРУЗКА КЛЮЧЕЙ
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔍 7. ТЕСТОВАЯ ЗАГРУЗКА КЛЮЧЕЙ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
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
    echo "Проверьте:"
    echo "  - Правильность токена"
    echo "  - Существование файла ${KEYS_FILE}"
    echo "  - Доступ к репозиторию"
    exit 1
fi

# ==============================================
# СОЗДАНИЕ ОСНОВНОГО СКРИПТА ОБНОВЛЕНИЯ
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔄 8. СОЗДАНИЕ СКРИПТА ОБНОВЛЕНИЯ СЕРВЕРОВ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /usr/local/bin/update_servers.py << 'PYEOF'
#!/usr/bin/env python3
"""
Основной скрипт обновления конфигурации Xray
Загружает ключи из GitHub и обновляет список серверов для балансировки
"""

import json
import subprocess
import sys
import os
import time
import re
from datetime import datetime
from typing import List, Dict, Any, Optional
import traceback

# Константы
CONFIG_PATH = "/usr/local/etc/xray/config.json"
BACKUP_PATH = "/usr/local/etc/xray/config_backup.json"
LOG_PATH = "/var/log/vpn-balancer.log"
PARSE_SCRIPT = "/usr/local/bin/parse_keys.py"
FETCH_SCRIPT = "/usr/local/bin/fetch_keys.py"

def log_message(msg: str):
    """
    Записывает сообщение в лог-файл и выводит в консоль
    
    Args:
        msg: Сообщение для записи
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {msg}"
    
    # Запись в файл
    try:
        with open(LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(log_entry + '\n')
    except Exception as e:
        print(f"Ошибка записи в лог: {e}")
    
    # Вывод в консоль
    print(log_entry)

def run_script(script_path: str, args: List[str] = None) -> Optional[str]:
    """
    Запускает внешний Python скрипт и возвращает его вывод
    
    Args:
        script_path: Путь к скрипту
        args: Аргументы командной строки
        
    Returns:
        Вывод скрипта или None в случае ошибки
    """
    try:
        cmd = [sys.executable, script_path]
        if args:
            cmd.extend(args)
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            return result.stdout
        else:
            log_message(f"Ошибка выполнения {script_path}: {result.stderr}")
            return None
            
    except subprocess.TimeoutExpired:
        log_message(f"Таймаут при выполнении {script_path}")
        return None
    except Exception as e:
        log_message(f"Ошибка запуска {script_path}: {e}")
        return None

def fetch_servers_from_github() -> Optional[str]:
    """
    Загружает содержимое файла с ключами из GitHub
    
    Returns:
        Содержимое файла или None
    """
    log_message("Загрузка ключей из приватного репозитория GitHub...")
    
    content = run_script(FETCH_SCRIPT)
    
    if content:
        log_message(f"✅ Загружено {len(content.splitlines())} строк")
        return content
    else:
        log_message("❌ Не удалось загрузить ключи из GitHub")
        return None

def parse_keys_from_content(content: str) -> List[Dict[str, Any]]:
    """
    Парсит ключи из текстового содержимого
    
    Args:
        content: Текстовое содержимое файла с ключами
        
    Returns:
        Список распарсенных ключей
    """
    servers = []
    vless_servers = []
    
    lines = content.splitlines()
    
    for line_num, line in enumerate(lines, 1):
        line = line.strip()
        
        # Пропускаем пустые строки и комментарии
        if not line or line.startswith('#'):
            continue
        
        # Парсим ключ с помощью внешнего скрипта
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', delete=False) as f:
            f.write(line)
            tmp_file = f.name
        
        try:
            parsed_json = run_script(PARSE_SCRIPT, [tmp_file])
            if parsed_json:
                try:
                    parsed = json.loads(parsed_json.strip())
                    servers.append(parsed)
                    
                    # Отдельно собираем VLESS серверы
                    if parsed.get('type') == 'vless' or line.startswith('vless://'):
                        vless_servers.append(parsed)
                except json.JSONDecodeError:
                    pass
        finally:
            os.unlink(tmp_file)
    
    log_message(f"✅ Всего ключей: {len(servers)}")
    log_message(f"✅ VLESS ключей: {len(vless_servers)}")
    
    return vless_servers

def create_outbound_for_server(server: Dict[str, Any], index: int) -> Dict[str, Any]:
    """
    Создает outbound конфигурацию для сервера
    
    Args:
        server: Распарсенный сервер
        index: Индекс сервера для тега
        
    Returns:
        Конфигурация outbound для Xray
    """
    # Базовые настройки
    streamSettings = {
        "network": "tcp",
        "security": "reality"
    }
    
    # Настройки Reality
    realitySettings = {
        "serverName": "www.microsoft.com",
        "fingerprint": "chrome",
        "publicKey": "",
        "shortId": "6ba85179e30d4fc2"
    }
    
    # Если есть параметры в ключе, используем их
    params = server.get('params', {})
    
    if 'sni' in params:
        realitySettings['serverName'] = params['sni']
    if 'fp' in params:
        realitySettings['fingerprint'] = params['fp']
    if 'pbk' in params:
        realitySettings['publicKey'] = params['pbk']
    if 'sid' in params:
        realitySettings['shortId'] = params['sid']
    if 'spx' in params:
        realitySettings['spiderX'] = params['spx']
    
    streamSettings['realitySettings'] = realitySettings
    
    # Настройки gRPC если есть
    if params.get('type') == 'grpc':
        streamSettings['network'] = 'grpc'
        streamSettings['grpcSettings'] = {
            "serviceName": params.get('serviceName', ''),
            "mode": params.get('mode', 'gun')
        }
    
    # Определяем flow
    flow = params.get('flow', 'xtls-rprx-vision')
    
    outbound = {
        "protocol": "vless",
        "tag": f"vpn-server-{index}",
        "settings": {
            "vnext": [
                {
                    "address": server['host'],
                    "port": server.get('port', 443),
                    "users": [
                        {
                            "id": server['uuid'],
                            "flow": flow,
                            "encryption": params.get('encryption', 'none')
                        }
                    ]
                }
            ]
        },
        "streamSettings": streamSettings
    }
    
    return outbound

def update_xray_config(servers: List[Dict[str, Any]]) -> bool:
    """
    Обновляет конфигурацию Xray с новыми серверами
    
    Args:
        servers: Список серверов для добавления
        
    Returns:
        True в случае успеха, False при ошибке
    """
    try:
        log_message("Обновление конфигурации Xray...")
        
        # Читаем текущую конфигурацию
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        # Создаем outbounds для каждого сервера
        outbounds = []
        
        for i, server in enumerate(servers):
            outbound = create_outbound_for_server(server, i)
            outbounds.append(outbound)
            log_message(f"  Добавлен сервер {i+1}: {server['host']}:{server.get('port', 443)}")
        
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
        if 'routing' not in config:
            config['routing'] = {
                "balancers": [],
                "rules": []
            }
        
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
                "strategy": {
                    "type": "leastPing"
                }
            })
        
        # Создаем резервную копию
        if os.path.exists(CONFIG_PATH):
            import shutil
            shutil.copy2(CONFIG_PATH, BACKUP_PATH)
            log_message(f"Создана резервная копия: {BACKUP_PATH}")
        
        # Сохраняем новую конфигурацию
        with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        
        log_message(f"✅ Конфигурация обновлена: {len(servers)} серверов добавлено")
        return True
        
    except Exception as e:
        log_message(f"❌ Ошибка обновления конфигурации: {e}")
        traceback.print_exc()
        return False

def reload_xray() -> bool:
    """
    Перезагружает Xray с новой конфигурацией
    
    Returns:
        True в случае успеха, False при ошибке
    """
    try:
        log_message("Перезагрузка Xray...")
        
        # Проверяем конфигурацию
        check_result = subprocess.run(
            ['/usr/local/bin/xray', 'check', '-config', CONFIG_PATH],
            capture_output=True, text=True
        )
        
        if check_result.returncode != 0:
            log_message(f"❌ Ошибка в конфигурации: {check_result.stderr}")
            
            # Восстанавливаем из резервной копии если есть
            if os.path.exists(BACKUP_PATH):
                log_message("Восстановление из резервной копии...")
                import shutil
                shutil.copy2(BACKUP_PATH, CONFIG_PATH)
                log_message("✅ Конфигурация восстановлена")
            return False
        
        # Перезапускаем Xray
        restart_result = subprocess.run(
            ['systemctl', 'restart', 'xray'],
            capture_output=True, text=True
        )
        
        if restart_result.returncode != 0:
            log_message(f"❌ Ошибка перезапуска Xray: {restart_result.stderr}")
            return False
        
        # Даем время на запуск
        time.sleep(3)
        
        # Проверяем статус
        status_result = subprocess.run(
            ['systemctl', 'is-active', 'xray'],
            capture_output=True, text=True
        )
        
        if status_result.stdout.strip() == 'active':
            log_message("✅ Xray успешно перезагружен и работает")
            return True
        else:
            log_message(f"❌ Xray не активен: {status_result.stdout}")
            return False
        
    except Exception as e:
        log_message(f"❌ Ошибка перезагрузки Xray: {e}")
        return False

def main():
    """Основная функция"""
    log_message("=" * 60)
    log_message("🔄 НАЧАЛО ОБНОВЛЕНИЯ СЕРВЕРОВ")
    
    # Загружаем ключи из GitHub
    content = fetch_servers_from_github()
    
    if not content:
        log_message("❌ Не удалось загрузить ключи")
        return 1
    
    # Парсим ключи
    servers = parse_keys_from_content(content)
    
    if len(servers) == 0:
        log_message("⚠️ Нет VLESS серверов для добавления")
        return 0
    
    # Обновляем конфигурацию
    if update_xray_config(servers):
        # Перезагружаем Xray
        if reload_xray():
            log_message("✅ Обновление завершено успешно")
        else:
            log_message("⚠️ Конфигурация обновлена, но Xray не перезагружен")
    else:
        log_message("❌ Ошибка обновления конфигурации")
        return 1
    
    log_message("🏁 ЗАВЕРШЕНО")
    return 0

if __name__ == "__main__":
    sys.exit(main())
PYEOF

chmod +x /usr/local/bin/update_servers.py
check_success "Создание скрипта обновления"

# ==============================================
# ТЕСТОВЫЙ ЗАПУСК ОБНОВЛЕНИЯ
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🧪 9. ТЕСТОВЫЙ ЗАПУСК ОБНОВЛЕНИЯ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

log "Запуск скрипта обновления..."
/usr/bin/python3 /usr/local/bin/update_servers.py

# ==============================================
# СОЗДАНИЕ CRON ДЛЯ АВТО-ОБНОВЛЕНИЯ
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⏰ 10. НАСТРОЙКА АВТОМАТИЧЕСКОГО ОБНОВЛЕНИЯ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /etc/cron.d/vpn-balancer << EOF
# Обновление списка серверов каждые 5 минут
*/5 * * * * root /usr/bin/python3 /usr/local/bin/update_servers.py >> /var/log/vpn-balancer-cron.log 2>&1

# Очистка старых логов каждый день в 2:00
0 2 * * * root find /var/log/vpn-balancer* -type f -mtime +7 -delete
EOF

chmod 644 /etc/cron.d/vpn-balancer
check_success "Настройка cron"

# ==============================================
# СОЗДАНИЕ SYSTEMD ТАЙМЕРА
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⏲️ 11. СОЗДАНИЕ SYSTEMD ТАЙМЕРА${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /etc/systemd/system/vpn-balancer.service << EOF
[Unit]
Description=VPN Balancer Auto-Updater
Description=Обновление списка серверов VPN балансировщика
After=network.target xray.service
Wants=xray.service

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/local/bin/update_servers.py
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/vpn-balancer.timer << EOF
[Unit]
Description=Timer for VPN Balancer Auto-Updater
Description=Таймер для автоматического обновления серверов VPN
Requires=vpn-balancer.service

[Timer]
OnCalendar=*:0/5
Persistent=true
RandomizedDelaySec=10

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable vpn-balancer.timer
systemctl start vpn-balancer.timer
systemctl enable xray
systemctl restart xray

check_success "Настройка systemd таймера"

# ==============================================
# СОЗДАНИЕ СКРИПТА МОНИТОРИНГА
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 12. СОЗДАНИЕ СКРИПТА МОНИТОРИНГА${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

cat > /usr/local/bin/balancer-status << 'EOF'
#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo '╔══════════════════════════════════════════════════════════════════╗'
echo '║              VPN БАЛАНСИРОВЩИК - СТАТУС СИСТЕМЫ                  ║'
echo '╚══════════════════════════════════════════════════════════════════╝'
echo -e "${NC}"
echo ""

# Функция для получения информации о системе
get_system_info() {
    echo -e "${YELLOW}📌 ИНФОРМАЦИЯ О СИСТЕМЕ:${NC}"
    echo "   • Хост: $(hostname)"
    echo "   • IP: $(curl -s ifconfig.me)"
    echo "   • Время: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "   • Uptime: $(uptime -p)"
    echo "   • Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
}

# Функция для проверки статуса Xray
check_xray_status() {
    echo -e "${YELLOW}🚀 СТАТУС XRAY:${NC}"
    
    if systemctl is-active --quiet xray; then
        echo -e "   • Статус: ${GREEN}Активен${NC}"
    else
        echo -e "   • Статус: ${RED}Не активен${NC}"
    fi
    
    XRAY_VERSION=$(xray version 2>/dev/null | head -1)
    echo "   • Версия: $XRAY_VERSION"
    
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
    echo ""
}

# Функция для проверки статуса обновлений
check_update_status() {
    echo -e "${YELLOW}🔄 СТАТУС АВТО-ОБНОВЛЕНИЯ:${NC}"
    
    if systemctl is-active --quiet vpn-balancer.timer; then
        echo -e "   • Таймер: ${GREEN}Активен${NC}"
        TIMER_STATUS=$(systemctl status vpn-balancer.timer --no-pager | grep "Trigger:" | head -1)
        echo "   • $TIMER_STATUS"
    else
        echo -e "   • Таймер: ${RED}Не активен${NC}"
    fi
    
    if [ -f /etc/cron.d/vpn-balancer ]; then
        echo -e "   • Cron: ${GREEN}Настроен${NC}"
    else
        echo -e "   • Cron: ${RED}Не настроен${NC}"
    fi
    echo ""
}

# Функция для просмотра последних логов
check_logs() {
    echo -e "${YELLOW}📋 ПОСЛЕДНИЕ ОБНОВЛЕНИЯ:${NC}"
    
    if [ -f /var/log/vpn-balancer.log ]; then
        echo "   Последние 5 записей:"
        tail -5 /var/log/vpn-balancer.log | sed 's/^/   /'
    else
        echo "   ❌ Лог-файл не найден"
    fi
    echo ""
}

# Функция для отображения загруженных серверов
show_servers() {
    echo -e "${YELLOW}🌍 ЗАГРУЖЕННЫЕ СЕРВЕРА (VLESS):${NC}"
    
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
            servers.append({
                'tag': outbound['tag'],
                'address': settings['address'],
                'port': settings['port']
            })
    
    if servers:
        print('   {:<5} {:<30} {:<10}'.format('№', 'ХОСТ', 'ПОРТ'))
        print('   ' + '-' * 50)
        for i, s in enumerate(servers, 1):
            print('   {:<5} {:<30} {:<10}'.format(i, s['address'], s['port']))
    else:
        print('   ❌ Нет загруженных серверов')
        
except Exception as e:
    print(f'   ❌ Ошибка: {e}')
"
    else:
        echo "   ❌ Конфигурация не найдена"
    fi
    echo ""
}

# Функция для отображения статистики трафика
show_traffic_stats() {
    echo -e "${YELLOW}📈 СТАТИСТИКА ТРАФИКА:${NC}"
    
    if [ -f /var/log/xray/access.log ]; then
        TOTAL_CONNS=$(wc -l < /var/log/xray/access.log 2>/dev/null || echo "0")
        echo "   • Всего подключений: $TOTAL_CONNS"
        
        # Топ серверов по трафику
        echo "   • Топ серверов:"
        tail -100 /var/log/xray/access.log 2>/dev/null | grep "proxy" | awk '{print $5}' | sort | uniq -c | sort -rn | head -5 | while read count server; do
            echo "      $count - $server"
        done
    else
        echo "   • Нет данных о трафике"
    fi
    echo ""
}

# Функция для отображения VLESS ключа
show_vless_key() {
    echo -e "${YELLOW}🔑 ВАШ VLESS КЛЮЧ (для клиентов):${NC}"
    
    if [ -f /usr/local/etc/xray/config.json ]; then
        UUID=$(grep -o '"id": "[^"]*"' /usr/local/etc/xray/config.json | head -1 | cut -d'"' -f4)
        PORT=$(grep -o '"port": [0-9]*' /usr/local/etc/xray/config.json | head -1 | awk '{print $2}')
        PBK=$(grep -o '"publicKey": "[^"]*"' /usr/local/etc/xray/config.json | head -1 | cut -d'"' -f4)
        SID=$(grep -o '"shortIds": \["[^"]*"' /usr/local/etc/xray/config.json | head -1 | cut -d'"' -f4)
        SERVER_IP=$(curl -s ifconfig.me)
        
        if [ -z "$PBK" ]; then
            PBK="your-public-key"
        fi
        if [ -z "$SID" ]; then
            SID="your-short-id"
        fi
        if [ -z "$PORT" ]; then
            PORT="443"
        fi
        
        KEY="vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&security=reality&type=tcp&flow=xtls-rprx-vision&sni=www.microsoft.com&pbk=${PBK}&sid=${SID}#VPN-Balancer"
        
        echo "   $KEY"
        echo ""
        echo "   📝 Параметры ключа:"
        echo "      • UUID: $UUID"
        echo "      • Сервер: $SERVER_IP:$PORT"
        echo "      • Public Key: $PBK"
        echo "      • Short ID: $SID"
    else
        echo "   ❌ Конфигурация не найдена"
    fi
    echo ""
}

# Функция для проверки доступности
check_connectivity() {
    echo -e "${YELLOW}🔍 ПРОВЕРКА ДОСТУПНОСТИ:${NC}"
    
    SERVER_IP=$(curl -s ifconfig.me)
    PORT=$(grep -o '"port": [0-9]*' /usr/local/etc/xray/config.json 2>/dev/null | head -1 | awk '{print $2}')
    PORT=${PORT:-443}
    
    echo "   • Проверка порта $PORT:"
    
    # Проверка через netcat
    if nc -zv -w 2 $SERVER_IP $PORT 2>&1 | grep -q "succeeded"; then
        echo -e "      ${GREEN}✓ Порт открыт (netcat)${NC}"
    else
        echo -e "      ${RED}✗ Порт не отвечает (netcat)${NC}"
    fi
    
    # Проверка через curl
    HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 2 http://$SERVER_IP:$PORT)
    if [ "$HTTP_CODE" != "000" ]; then
        echo -e "      ${GREEN}✓ HTTP ответ: $HTTP_CODE${NC}"
    else
        echo -e "      ${RED}✗ Нет HTTP ответа${NC}"
    fi
    
    echo ""
}

# Основная функция
main() {
    get_system_info
    check_xray_status
    check_update_status
    check_logs
    show_servers
    show_traffic_stats
    show_vless_key
    check_connectivity
    
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Для просмотра логов в реальном времени:${NC}"
    echo "  tail -f /var/log/vpn-balancer.log"
    echo "  journalctl -u xray -f"
    echo ""
    echo -e "${CYAN}Для принудительного обновления:${NC}"
    echo "  /usr/local/bin/update_servers.py"
    echo ""
}

main
EOF

chmod +x /usr/local/bin/balancer-status

cat > /usr/local/bin/balancer-logs << 'EOF'
#!/bin/bash

if [ "$1" = "-f" ]; then
    tail -f /var/log/vpn-balancer.log
else
    echo "=== Последние 50 строк лога ==="
    tail -50 /var/log/vpn-balancer.log
    echo ""
    echo "Для просмотра в реальном времени используйте: balancer-logs -f"
fi
EOF

chmod +x /usr/local/bin/balancer-logs

cat > /usr/local/bin/balancer-update << 'EOF'
#!/bin/bash
echo "🔄 Принудительное обновление списка серверов..."
/usr/bin/python3 /usr/local/bin/update_servers.py
echo ""
echo "✅ Готово! Проверьте статус: balancer-status"
EOF

chmod +x /usr/local/bin/balancer-update

# Добавляем алиасы в .bashrc
cat >> ~/.bashrc << 'EOF'

# Алиасы для VPN балансировщика
alias balancer-status='/usr/local/bin/balancer-status'
alias balancer-logs='/usr/local/bin/balancer-logs'
alias balancer-update='/usr/local/bin/balancer-update'
alias balancer-config='cat /usr/local/etc/xray/config.json'
alias balancer-restart='systemctl restart xray && systemctl status xray'
EOF

source ~/.bashrc

check_success "Создание скриптов мониторинга"

# ==============================================
# ФИНАЛЬНАЯ ПРОВЕРКА
# ==============================================

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}✅ 13. ФИНАЛЬНАЯ ПРОВЕРКА${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

log "Проверка работы Xray..."
systemctl restart xray
sleep 3

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}✅ Xray успешно запущен${NC}"
else
    echo -e "${RED}❌ Xray не запустился${NC}"
    journalctl -u xray -n 20 --no-pager
fi

# ==============================================
# СОХРАНЕНИЕ КЛЮЧА В ФАЙЛ
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
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • UUID:        ${UUID}
  • Сервер:      ${SERVER_IP}
  • Порт:        ${XRAY_PORT}
  • Протокол:    VLESS + Reality
  • SNI:         www.microsoft.com
  • Flow:        xtls-rprx-vision
  • Public Key:  ${PUBLIC_KEY}
  • Short ID:    ${SHORT_ID}
  • Fingerprint: chrome

📊 ИНФОРМАЦИЯ О РЕПОЗИТОРИИ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • GitHub:      ${GITHUB_USER}/${REPO_NAME}
  • Файл:        ${KEYS_FILE}
  • Токен:       ${GITHUB_TOKEN:0:10}... (первые 10 символов)

⚙️ КОМАНДЫ УПРАВЛЕНИЯ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • balancer-status     - Показать статус балансировщика
  • balancer-logs       - Показать логи обновлений
  • balancer-update     - Принудительно обновить список серверов
  • balancer-config     - Показать конфигурацию
  • balancer-restart    - Перезапустить Xray

📁 РАСПОЛОЖЕНИЕ ФАЙЛОВ:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • Конфигурация:       /usr/local/etc/xray/config.json
  • Лог обновлений:     /var/log/vpn-balancer.log
  • Лог Xray:           /var/log/xray/access.log
  • Скрипты:            /usr/local/bin/
  • Этот файл:          /root/vpn-keys/balancer-key.txt

📅 ДАТА УСТАНОВКИ: $(date '+%Y-%m-%d %H:%M:%S')
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  СОХРАНИТЕ ЭТОТ КЛЮЧ! ОН БОЛЬШЕ НЕ ПОКАЖЕТСЯ!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

chmod 600 /root/vpn-keys/balancer-key.txt

# ==============================================
# ФИНАЛЬНЫЙ ВЫВОД
# ==============================================

clear
echo -e "${GREEN}"
echo '╔════════════════════════════════════════════════════════════════════════════╗'
echo '║                                                                            ║'
echo '║           ✅ УСТАНОВКА ЗАВЕРШЕНА ПОЛНОСТЬЮ УСПЕШНО!                       ║'
echo '║                                                                            ║'
echo '╚════════════════════════════════════════════════════════════════════════════╝'
echo -e "${NC}"
echo ""

echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔑 ВАШ ЕДИНСТВЕННЫЙ VLESS КЛЮЧ (для всех клиентов):${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}${FINAL_KEY}${NC}"
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════${NC}"
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
        for s in servers[:5]:  # Показываем первые 5
            print(s)
        if len(servers) > 5:
            print(f'    ... и еще {len(servers)-5} серверов')
    else:
        print('    ❌ Сервера не загружены')
except Exception as e:
    print(f'    ❌ Ошибка: {e}')
"
echo ""

echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📋 ДОСТУПНЫЕ КОМАНДЫ:${NC}"
echo -e "${CYAN}  balancer-status${NC}     - Показать полный статус балансировщика"
echo -e "${CYAN}  balancer-logs${NC}       - Показать логи обновлений"
echo -e "${CYAN}  balancer-update${NC}     - Принудительно обновить список серверов"
echo -e "${CYAN}  balancer-config${NC}     - Показать конфигурацию Xray"
echo -e "${CYAN}  balancer-restart${NC}    - Перезапустить Xray"
echo ""

echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📁 ВАЖНЫЕ ФАЙЛЫ:${NC}"
echo -e "  • Ключ сохранен в: ${CYAN}/root/vpn-keys/balancer-key.txt${NC}"
echo -e "  • Конфигурация: ${CYAN}/usr/local/etc/xray/config.json${NC}"
echo -e "  • Лог обновлений: ${CYAN}/var/log/vpn-balancer.log${NC}"
echo ""

echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🔍 ПРОВЕРКА РАБОТЫ:${NC}"
echo -e "  • Запустите ${CYAN}balancer-status${NC} для полной диагностики"
echo -e "  • Или выполните: ${CYAN}curl -I http://${SERVER_IP}:${XRAY_PORT}${NC}"
echo ""

echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}⚠️  ВАЖНО: Сохраните ключ из этого окна!${NC}"
echo -e "${RED}   Он также сохранен в файле /root/vpn-keys/balancer-key.txt${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Проверка статуса в конце
/usr/local/bin/balancer-status | head -20