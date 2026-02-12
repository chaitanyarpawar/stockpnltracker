# Stock Proxy Backend

FastAPI service that proxies Yahoo Finance so the Flutter app can fetch stock symbols and prices without running into CORS issues.

## Endpoints

- `GET /health` – uptime check
- `GET /search-stock?name=<query>` – resolves a user-friendly name to the first NSE ticker (suffix `.NS`). Returns JSON `{ "symbol": "ASTRAL.NS" }`.
- `GET /get-price?symbol=<ticker>` – returns `{ "symbol": "ASTRAL.NS", "price": 1945.50 }` using Yahoo quote endpoint.

## Run locally

```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

By default the Flutter app points at `http://localhost:8000`. Update the base URL in `lib/services/stock_api_service.dart` if you host elsewhere.
