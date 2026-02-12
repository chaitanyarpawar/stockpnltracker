"""Production-safe NSE-only Stock API.

Key features:
1. Forces NSE exchange only (rejects BSE, US ADR)
2. Uses regularMarketPrice field only
3. Minimal caching to avoid stale prices
"""
from __future__ import annotations
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from .models import SymbolResponse, PriceResponse
from .cache import TTLCache
from . import yahoo_client

app = FastAPI(title="NSE Stock API", version="3.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Symbol cache: 1 hour (symbols don't change)
symbol_cache = TTLCache(ttl_seconds=3600)
# Price cache: 0 seconds (always fetch fresh LTP)
# Set to 0 to avoid stale prices - this is critical!
price_cache = TTLCache(ttl_seconds=0)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "version": "3.0.0", "exchange": "NSE-ONLY"}


@app.get("/search-stock", response_model=SymbolResponse)
async def search_stock(name: str = Query(..., min_length=1)) -> SymbolResponse:
    """
    Resolve stock name to NSE symbol.
    
    FORCES NSE ONLY:
    - exchange == 'NSI'
    - quoteType == 'EQUITY'
    - symbol.endswith('.NS')
    
    REJECTS: BSE (.BO), US ADR, other exchanges
    """
    query = name.strip().lower()
    
    # Check cache first
    cached = symbol_cache.get(query)
    if cached:
        return SymbolResponse(symbol=cached)

    # Search NSE symbol via Yahoo (with NSE-only filter)
    symbol = await yahoo_client.search_nse_symbol(query)
    
    if not symbol:
        raise HTTPException(status_code=404, detail="NSE stock not found")
    
    symbol_cache.set(query, symbol)
    return SymbolResponse(symbol=symbol)


@app.get("/get-price", response_model=PriceResponse)
async def get_price(symbol: str = Query(..., min_length=1)) -> PriceResponse:
    """
    Get LTP (Last Traded Price) for a symbol.
    
    USES ONLY: regularMarketPrice field
    NEVER USES: previousClose, postMarketPrice, preMarketPrice
    """
    ticker = symbol.strip().upper()
    
    # Fetch fresh LTP (no caching to avoid stale prices)
    ltp = await yahoo_client.fetch_ltp(ticker)
    
    if ltp is None or ltp <= 0:
        raise HTTPException(status_code=404, detail="Price unavailable")
    
    return PriceResponse(symbol=ticker, price=ltp)


@app.get("/ltp")
async def get_ltp(name: str = Query(..., min_length=1)):
    """
    Combined endpoint: Resolve name → Get LTP in one call.
    
    Example: /ltp?name=tcs → {"symbol": "TCS.NS", "ltp": 3456.50, "exchange": "NSE"}
    """
    query = name.strip().lower()
    
    # Resolve symbol (NSE only)
    cached = symbol_cache.get(query)
    symbol = cached if cached else await yahoo_client.search_nse_symbol(query)
    
    if not symbol:
        raise HTTPException(status_code=404, detail="NSE stock not found")
    
    if not cached:
        symbol_cache.set(query, symbol)
    
    # Get LTP
    ltp = await yahoo_client.fetch_ltp(symbol)
    
    if ltp is None or ltp <= 0:
        raise HTTPException(status_code=404, detail="Price unavailable")
    
    return {
        "symbol": symbol,
        "ltp": ltp,
        "exchange": "NSE"
    }
