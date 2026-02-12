"""
Production-safe NSE India client.

Uses NSE's public quote endpoint which is more reliable than Yahoo for Indian stocks.
Includes retry logic, proper headers, and rate-limit handling.
"""
from __future__ import annotations
import asyncio
import httpx
from typing import Any

NSE_BASE_URL = "https://www.nseindia.com"
NSE_QUOTE_URL = f"{NSE_BASE_URL}/api/quote-equity"
NSE_SEARCH_URL = f"{NSE_BASE_URL}/api/search/autocomplete"

# NSE requires browser-like headers and a session cookie
DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Referer": "https://www.nseindia.com/",
    "Connection": "keep-alive",
}

# Reusable client with cookies (NSE needs session)
_client: httpx.AsyncClient | None = None


async def _get_client() -> httpx.AsyncClient:
    """Get or create a persistent client with NSE session cookie."""
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(
            timeout=15.0,
            headers=DEFAULT_HEADERS,
            follow_redirects=True,
        )
        # Warm up session by hitting homepage (gets cookies)
        try:
            await _client.get(NSE_BASE_URL, timeout=10.0)
        except Exception:
            pass  # Continue anyway, quote endpoint might still work
    return _client


async def search_nse_symbol(query: str) -> str | None:
    """
    Search NSE for a symbol by company name.
    Returns the NSE symbol (without .NS suffix) or None.
    """
    client = await _get_client()
    try:
        params = {"q": query.strip().upper()}
        resp = await client.get(NSE_SEARCH_URL, params=params)
        if resp.status_code != 200:
            return None
        data = resp.json()
        
        # NSE returns: {"symbols": [{"symbol": "TCS", "symbol_info": "..."}]}
        symbols = data.get("symbols", [])
        for item in symbols:
            symbol = item.get("symbol", "").upper()
            if symbol:
                return symbol
        return None
    except Exception:
        return None


async def fetch_nse_price(symbol: str) -> dict[str, Any] | None:
    """
    Fetch live quote from NSE for a given symbol.
    
    Args:
        symbol: NSE symbol WITHOUT .NS suffix (e.g., "TCS", "RELIANCE")
    
    Returns:
        Dict with price data or None if failed.
    """
    # Strip .NS suffix if present
    clean_symbol = symbol.upper().replace(".NS", "").replace(".BO", "")
    
    client = await _get_client()
    
    for attempt in range(3):  # Retry logic
        try:
            params = {"symbol": clean_symbol}
            resp = await client.get(NSE_QUOTE_URL, params=params)
            
            if resp.status_code == 401:
                # Session expired, refresh
                global _client
                if _client:
                    await _client.aclose()
                _client = None
                client = await _get_client()
                continue
            
            if resp.status_code != 200:
                return None
            
            data = resp.json()
            price_info = data.get("priceInfo", {})
            
            return {
                "symbol": f"{clean_symbol}.NS",
                "price": price_info.get("lastPrice"),
                "open": price_info.get("open"),
                "high": price_info.get("intraDayHighLow", {}).get("max"),
                "low": price_info.get("intraDayHighLow", {}).get("min"),
                "prev_close": price_info.get("previousClose"),
                "change": price_info.get("change"),
                "change_pct": price_info.get("pChange"),
                "volume": data.get("preOpenMarket", {}).get("totalTradedVolume"),
            }
        except Exception as e:
            if attempt < 2:
                await asyncio.sleep(0.5 * (attempt + 1))
                continue
            return None
    
    return None


async def get_price_only(symbol: str) -> float | None:
    """Simple helper that returns just the LTP."""
    result = await fetch_nse_price(symbol)
    if result and result.get("price"):
        return float(result["price"])
    return None


# Symbol mapping for common names
COMMON_NAMES_TO_SYMBOL = {
    "tcs": "TCS",
    "tata consultancy": "TCS",
    "tata consultancy services": "TCS",
    "infosys": "INFY",
    "infy": "INFY",
    "reliance": "RELIANCE",
    "reliance industries": "RELIANCE",
    "hdfc bank": "HDFCBANK",
    "hdfcbank": "HDFCBANK",
    "icici bank": "ICICIBANK",
    "icicibank": "ICICIBANK",
    "itc": "ITC",
    "itc limited": "ITC",
    "sbi": "SBIN",
    "state bank": "SBIN",
    "state bank of india": "SBIN",
    "kotak": "KOTAKBANK",
    "kotak bank": "KOTAKBANK",
    "bharti airtel": "BHARTIARTL",
    "airtel": "BHARTIARTL",
    "larsen": "LT",
    "l&t": "LT",
    "larsen toubro": "LT",
    "astral": "ASTRAL",
    "astral limited": "ASTRAL",
    "laurus labs": "LAURUSLABS",
    "lauruslabs": "LAURUSLABS",
    "wipro": "WIPRO",
    "maruti": "MARUTI",
    "maruti suzuki": "MARUTI",
    "asian paints": "ASIANPAINT",
    "asianpaint": "ASIANPAINT",
    "titan": "TITAN",
    "hindustan unilever": "HINDUNILVR",
    "hul": "HINDUNILVR",
}


def resolve_symbol_locally(query: str) -> str | None:
    """Try to resolve common names without API call."""
    normalized = query.strip().lower()
    return COMMON_NAMES_TO_SYMBOL.get(normalized)
