import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ResolvedStock {
  final String symbol;
  final String name;
  final double price;

  const ResolvedStock({
    required this.symbol,
    required this.name,
    required this.price,
  });
}

/// Get the appropriate backend URL based on platform
String _getDefaultBackendUrl() {
  // Check for environment override first
  const envUrl = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
  if (envUrl.isNotEmpty) return envUrl;

  // For web, localhost works
  if (kIsWeb) return 'http://localhost:8000';

  // For Android (both emulator and physical device)
  // Use your PC's local network IP address
  // Change this IP to match your PC's local IP if different
  try {
    if (Platform.isAndroid) {
      return 'http://192.168.1.13:8000';
    }
  } catch (e) {
    // Platform check failed, fallback to localhost
  }

  // Default for other platforms
  return 'http://localhost:8000';
}

class StockApiService {
  StockApiService({http.Client? client, String? backendBaseUrl})
    : _client = client ?? http.Client(),
      _backendBaseUrl = backendBaseUrl ?? _getDefaultBackendUrl();

  final http.Client _client;
  final String _backendBaseUrl;
  final Map<String, double> _priceCache = {};
  final math.Random _random = math.Random();
  static const Duration _timeout = Duration(seconds: 30);

  static const Set<String> _knownIndianTickers = {
    'TCS',
    'INFY',
    'RELIANCE',
    'HDFCBANK',
    'ICICIBANK',
    'ITC',
    'BHARTIARTL',
    'KOTAKBANK',
    'LT',
    'SBIN',
    'WIPRO',
    'MARUTI',
    'HINDUNILVR',
    'ASIANPAINT',
    'TITAN',
    'ASTRAL',
    'LAURUSLABS',
  };

  static const Set<String> _knownUsTickers = {
    'AAPL',
    'GOOGL',
    'MSFT',
    'AMZN',
    'TSLA',
    'META',
    'NVDA',
    'NFLX',
    'INTC',
    'AMD',
    'ORCL',
    'CRM',
  };

  static const Map<String, String> _inputAliases = {
    'TCS': 'TCS.NS',
    'TATA CONSULTANCY SERVICES': 'TCS.NS',
    'INFY': 'INFY.NS',
    'INFOSYS': 'INFY.NS',
    'RELIANCE': 'RELIANCE.NS',
    'RELIANCE INDUSTRIES': 'RELIANCE.NS',
    'HDFC BANK': 'HDFCBANK.NS',
    'HDFCBANK': 'HDFCBANK.NS',
    'ICICI BANK': 'ICICIBANK.NS',
    'ICICIBANK': 'ICICIBANK.NS',
    'ITC': 'ITC.NS',
    'ITC LIMITED': 'ITC.NS',
    'BHARTI AIRTEL': 'BHARTIARTL.NS',
    'BHARTIARTL': 'BHARTIARTL.NS',
    'KOTAK BANK': 'KOTAKBANK.NS',
    'KOTAKBANK': 'KOTAKBANK.NS',
    'LARSEN TOUBRO': 'LT.NS',
    'L&T': 'LT.NS',
    'LT': 'LT.NS',
    'STATE BANK OF INDIA': 'SBIN.NS',
    'SBIN': 'SBIN.NS',
    'ASTRAL': 'ASTRAL.NS',
    'ASTRAL LIMITED': 'ASTRAL.NS',
    'ASTRAL LTD': 'ASTRAL.NS',
    'LAURUS LABS': 'LAURUSLABS.NS',
    'LAURUS LABS LIMITED': 'LAURUSLABS.NS',
    'LAURUS LABS LTD': 'LAURUSLABS.NS',
    'LAURUSLABS': 'LAURUSLABS.NS',
    'AAPL': 'AAPL',
    'APPLE': 'AAPL',
    'GOOGL': 'GOOGL',
    'GOOGLE': 'GOOGL',
    'MSFT': 'MSFT',
    'MICROSOFT': 'MSFT',
    'AMZN': 'AMZN',
    'AMAZON': 'AMZN',
    'TSLA': 'TSLA',
    'TESLA': 'TSLA',
    'META': 'META',
    'NVDA': 'NVDA',
    'NVIDIA': 'NVDA',
    'NFLX': 'NFLX',
    'NETFLIX': 'NFLX',
  };

  /// Normalize stored ticker symbols so users can type "itc" instead of
  /// "ITC.NS".
  String normalizeSymbol(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return cleaned;

    final upper = cleaned.toUpperCase();
    final alias = _inputAliases[_normalizeLookupKey(upper)];
    if (alias != null) return alias;

    if (upper.contains('.')) return upper;
    if (_knownIndianTickers.contains(upper)) return '$upper.NS';
    if (_knownUsTickers.contains(upper)) return upper;
    return upper;
  }

  /// Resolve arbitrary input (name or symbol) via backend and fetch latest price.
  Future<ResolvedStock?> resolveStock(String input) async {
    final query = input.trim();
    if (query.isEmpty) return null;

    try {
      final symbol = await _resolveSymbolRemote(query);
      if (symbol == null) return null;
      final price = await _getPriceRemote(symbol);
      if (price == null) return null;
      return ResolvedStock(
        symbol: symbol,
        name: getStockName(symbol),
        price: price,
      );
    } catch (e) {
      debugPrint('resolveStock failed for "$query": $e');
      final normalized = normalizeSymbol(query);
      final fallback = _getFallbackPrice(normalized);
      if (fallback <= 0) return null;
      return ResolvedStock(
        symbol: normalized,
        name: getStockName(normalized),
        price: fallback,
      );
    }
  }

  /// Fetch current market price for a symbol.
  Future<double> fetchCurrentPrice(String symbol) async {
    final normalized = normalizeSymbol(symbol);
    try {
      final price = await _getPriceRemote(normalized);
      if (price != null && price > 0) {
        _priceCache[normalized] = price;
        return price;
      }
    } catch (e) {
      debugPrint('fetchCurrentPrice failed for $normalized: $e');
    }
    return _getFallbackPrice(normalized);
  }

  /// Fetch prices for many stocks (sequential backend calls keeps API simple).
  Future<Map<String, double>> fetchMultiplePrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};

    final uniqueSymbols = symbols
        .map(normalizeSymbol)
        .where(_isValidSymbolFormat)
        .toSet()
        .toList();

    if (uniqueSymbols.isEmpty) {
      return _getFallbackPricesForAll(symbols);
    }

    final Map<String, double> prices = {};
    for (final symbol in uniqueSymbols) {
      try {
        final price = await _getPriceRemote(symbol);
        if (price != null && price > 0) {
          prices[symbol] = price;
          _priceCache[symbol] = price;
          continue;
        }
      } catch (e) {
        debugPrint('fetchMultiplePrices failed for $symbol: $e');
      }

      final fallback = _getFallbackPrice(symbol);
      if (fallback > 0) {
        prices[symbol] = fallback;
      }
    }

    return prices;
  }

  String getStockName(String symbol) {
    final names = {
      'TCS.NS': 'Tata Consultancy Services',
      'INFY.NS': 'Infosys Limited',
      'RELIANCE.NS': 'Reliance Industries',
      'HDFCBANK.NS': 'HDFC Bank Limited',
      'ICICIBANK.NS': 'ICICI Bank Limited',
      'ITC.NS': 'ITC Limited',
      'BHARTIARTL.NS': 'Bharti Airtel Limited',
      'KOTAKBANK.NS': 'Kotak Mahindra Bank',
      'LT.NS': 'Larsen & Toubro',
      'SBIN.NS': 'State Bank of India',
      'ASTRAL.NS': 'Astral Limited',
      'LAURUSLABS.NS': 'Laurus Labs Limited',
      'AAPL': 'Apple Inc.',
      'GOOGL': 'Alphabet Inc.',
      'MSFT': 'Microsoft Corporation',
      'AMZN': 'Amazon.com Inc.',
      'TSLA': 'Tesla Inc.',
      'META': 'Meta Platforms Inc.',
      'NVDA': 'NVIDIA Corporation',
      'NFLX': 'Netflix Inc.',
    };

    final normalized = normalizeSymbol(symbol);
    return names[normalized] ?? _formatSymbolName(normalized);
  }

  Future<bool> validateSymbol(String symbol) async {
    final resolved = await _resolveSymbolRemote(symbol);
    if (resolved == null) return false;
    final price = await _getPriceRemote(resolved);
    return price != null && price > 0;
  }

  void clearCache() => _priceCache.clear();

  Map<String, double> _getFallbackPricesForAll(List<String> symbols) {
    final out = <String, double>{};
    for (final symbol in symbols) {
      final normalized = normalizeSymbol(symbol);
      final fallback = _getFallbackPrice(normalized);
      if (fallback > 0) {
        out[normalized] = fallback;
      }
    }
    return out;
  }

  double _getFallbackPrice(String symbol) {
    final normalized = normalizeSymbol(symbol);

    if (_priceCache.containsKey(normalized)) {
      final cached = _priceCache[normalized]!;
      final variation = ((_random.nextDouble() * 2) - 1) * 0.005;
      return cached * (1 + variation);
    }

    final defaultPrices = {
      // Updated Feb 2026 - these are fallbacks only
      'TCS.NS': 2909.0,
      'INFY.NS': 1820.0,
      'RELIANCE.NS': 1468.0,
      'HDFCBANK.NS': 1850.0,
      'ICICIBANK.NS': 1280.0,
      'ITC.NS': 480.0,
      'BHARTIARTL.NS': 1650.0,
      'KOTAKBANK.NS': 1950.0,
      'LT.NS': 3600.0,
      'SBIN.NS': 780.0,
      'WIPRO.NS': 295.0,
      'MARUTI.NS': 12500.0,
      'HINDUNILVR.NS': 2850.0,
      'ASIANPAINT.NS': 2450.0,
      'TITAN.NS': 3400.0,
      'ASTRAL.NS': 1592.0,
      'LAURUSLABS.NS': 1013.0,
      'AAPL': 245.0,
      'GOOGL': 185.0,
      'MSFT': 420.0,
      'AMZN': 230.0,
      'TSLA': 380.0,
      'META': 620.0,
      'NVDA': 140.0,
      'NFLX': 980.0,
      'INTC': 22.0,
      'AMD': 125.0,
      'ORCL': 175.0,
      'CRM': 340.0,
    };

    final base = defaultPrices[normalized];
    if (base != null) {
      _priceCache[normalized] = base;
      return base;
    }
    return 0.0;
  }

  bool _isValidSymbolFormat(String symbol) {
    if (symbol.trim().isEmpty) return false;
    final clean = symbol.trim().toUpperCase();
    return RegExp(r'^[A-Z0-9.-]+$').hasMatch(clean) && clean.isNotEmpty;
  }

  String _normalizeLookupKey(String input) {
    return input
        .toUpperCase()
        .replaceAll('&', ' ')
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatSymbolName(String symbol) {
    final cleanSymbol = symbol.replaceAll(RegExp(r'\.[A-Z]+$'), '');
    return '${cleanSymbol.toUpperCase()} Limited';
  }

  Future<String?> _resolveSymbolRemote(String query) async {
    final uri = Uri.parse(
      '$_backendBaseUrl/search-stock',
    ).replace(queryParameters: {'name': query});
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final symbol = data['symbol'] as String?;
    return symbol?.toUpperCase();
  }

  Future<double?> _getPriceRemote(String symbol) async {
    final uri = Uri.parse(
      '$_backendBaseUrl/get-price',
    ).replace(queryParameters: {'symbol': symbol});
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final price = data['price'];
    if (price is num) {
      return price.toDouble();
    }
    return null;
  }
}
