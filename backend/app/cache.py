from __future__ import annotations
import time
from collections import OrderedDict
from typing import Any


class TTLCache:
    """Minimal TTL cache to shield Yahoo from repeated hits."""

    def __init__(self, ttl_seconds: int = 30, max_items: int = 256):
        self.ttl = ttl_seconds
        self.max_items = max_items
        self._store: OrderedDict[str, tuple[Any, float]] = OrderedDict()

    def get(self, key: str) -> Any | None:
        item = self._store.get(key)
        if not item:
            return None
        value, ts = item
        if time.time() - ts > self.ttl:
            self._store.pop(key, None)
            return None
        return value

    def set(self, key: str, value: Any) -> None:
        if len(self._store) >= self.max_items:
            self._store.popitem(last=False)
        self._store[key] = (value, time.time())
