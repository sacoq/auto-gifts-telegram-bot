import aiohttp
import asyncio
import logging

# Настройка логирования
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

# Конфигурация
BOT_TOKEN = ''  # Токен бота
YOUR_USER_ID = 812935135  # ID чата по умолчанию
REQUEST_DELAY = 1  # Задержка между запросами sendGift (секунды)
MAX_RETRIES = 3  # Максимум повторных попыток при ошибке
RARE_STAR_THRESHOLD = 101

async def check_bot_token():
    async with aiohttp.ClientSession() as session:
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/getMe"
        async with session.get(url) as response:
            data = await response.json()
            if not data.get('ok'):
                logger.error(f"Ошибка getMe: {data}")
                return False, f"Ошибка токена: {data.get('description', 'Неизвестная ошибка')}"
            return True, f"Бот активен: {data['result']['username']}"

async def get_my_star_balance():
    async with aiohttp.ClientSession() as session:
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/getMyStarBalance"
        async with session.get(url) as response:
            data = await response.json()
            if not data.get('ok'):
                logger.error(f"Ошибка getMyStarBalance: {data}")
                return None, f"Ошибка: {data.get('description', 'Неизвестная ошибка')}"
            return data['result']['amount'], None

#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####