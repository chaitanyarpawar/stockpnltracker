"""Production-safe NSE-only Yahoo Finance client.

Key rules:
1. Force NSE only: exchange == 'NSI' AND symbol.endswith('.NS')
2. Use regularMarketPrice field only (not previousClose, postMarketPrice, etc.)
3. Reject BSE (.BO) and US ADR listings
"""
from __future__ import annotations
import httpx
import yfinance as yf
from concurrent.futures import ThreadPoolExecutor
import asyncio

YAHOO_SEARCH_URL = "https://query1.finance.yahoo.com/v1/finance/search"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "application/json",
}

# Thread pool for running yfinance sync code
_executor = ThreadPoolExecutor(max_workers=4)


async def search_nse_symbol(name: str) -> str | None:
    """
    Search for NSE symbol only.
    
    Filters:
    - exchange == 'NSI' (NSE India)
    - quoteType == 'EQUITY'
    - symbol.endswith('.NS')
    
    Rejects: BSE (.BO), US ADR, other exchanges
    """
    try:
        params = {"q": name, "quotesCount": 10, "newsCount": 0}
        async with httpx.AsyncClient(timeout=10.0, headers=HEADERS) as client:
            resp = await client.get(YAHOO_SEARCH_URL, params=params)
            if resp.status_code != 200:
                return None
            data = resp.json()

        for item in data.get("quotes", []):
            # FORCE NSE ONLY
            if (
                item.get("exchange") == "NSI"
                and item.get("quoteType") == "EQUITY"
                and item.get("symbol", "").endswith(".NS")
            ):
                return item["symbol"]
        
        return None
    except Exception:
        return None


# Alias for backward compatibility
search_symbol = search_nse_symbol


def _fetch_ltp_sync(symbol: str) -> float | None:
    """Synchronous yfinance call to get regularMarketPrice."""
    try:
        ticker = yf.Ticker(symbol)
        info = ticker.fast_info
        # fast_info.last_price gives regularMarketPrice
        price = getattr(info, 'last_price', None)
        if price is not None:
            return float(price)
        
        # Fallback to history if fast_info fails
        hist = ticker.history(period="1d")
        if not hist.empty:
            return float(hist["Close"].iloc[-1])
        return None
    except Exception:
        return None


async def fetch_ltp(symbol: str) -> float | None:
    """
    Fetch LTP (Last Traded Price) using yfinance library.
    
    Uses regularMarketPrice via fast_info.last_price
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(_executor, _fetch_ltp_sync, symbol)


# Alias for backward compatibility
fetch_price = fetch_ltp
