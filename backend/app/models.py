from pydantic import BaseModel


class SymbolResponse(BaseModel):
    symbol: str


class PriceResponse(BaseModel):
    symbol: str
    price: float
