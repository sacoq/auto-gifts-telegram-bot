import asyncio
import logging
import aiosqlite
import uuid
import aiohttp
from aiogram import Bot, Dispatcher, types, F
from aiogram.types import LabeledPrice
from aiogram.enums import ParseMode
from aiogram.utils.keyboard import InlineKeyboardBuilder
from aiogram.client.default import DefaultBotProperties
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.context import FSMContext
from aiogram.filters import StateFilter

class Form(StatesGroup):
    waiting_for_limit = State()
    waiting_for_topup = State()

API_TOKEN = "" # ТОКЕН БОТА
PAYMENT_PROVIDER_TOKEN = "" # ТУТ НИЧЕГО НЕ ПИСАТЬ
RARE_STAR_THRESHOLD = 101
REQUEST_DELAY = 1
MAX_RETRIES = 3
ADMIN_ID = 812935135 # АЙДИ АДМИНА

dp = Dispatcher()
bot = Bot(token=API_TOKEN, default=DefaultBotProperties(parse_mode=ParseMode.HTML))

async def get_my_star_balance():
    async with aiohttp.ClientSession() as session:
        url = f"https://api.telegram.org/bot{API_TOKEN}/getMyStarBalance"
        async with session.get(url) as response:
            data = await response.json()
            return (data["result"]["amount"], None) if data.get("ok") else (None, data.get("description"))

async def get_available_gifts():
    async with aiohttp.ClientSession() as session:
        url = f"https://api.telegram.org/bot{API_TOKEN}/getAvailableGifts"
        async with session.get(url) as response:
            data = await response.json()
            return (data["result"]["gifts"], None) if data.get("ok") else (None, data.get("description"))

#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
#### ДЛЯ ПОКУПКИ ПОЛНОГО СКРИПТА ПИСАТЬ t.me/sacoq ####
