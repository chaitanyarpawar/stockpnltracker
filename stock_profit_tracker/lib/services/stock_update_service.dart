import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import 'stock_api_service.dart';
import 'notification_service.dart';
import 'home_widget_service.dart';

/// Enhanced Service for handling stock data updates and persistence
///
/// Responsibilities:
/// - Periodic updates of stock prices (every 5 seconds)
/// - Local storage using SharedPreferences
/// - Integration with notification service
/// - Integration with home widget service
/// - Background task coordination
/// - Price alert detection
class StockUpdateService {
  // Singleton pattern to prevent circular dependencies
  static final StockUpdateService _instance = StockUpdateService._internal();
  factory StockUpdateService() => _instance;
  StockUpdateService._internal();

  final StockApiService _apiService = StockApiService();

  // Services set by ServiceRegistry to prevent circular dependencies
  NotificationService? _notificationService;
  HomeWidgetService? _homeWidgetService;

  /// Public getter for API service
  StockApiService get apiService => _apiService;

  // Flag to track if services were properly injected by ServiceRegistry
  bool _servicesInitialized = false;

  /// Setter methods for ServiceRegistry to inject dependencies
  set notificationService(NotificationService service) =>
      _notificationService = service;
  set homeWidgetService(HomeWidgetService service) =>
      _homeWidgetService = service;
  set servicesInitialized(bool initialized) =>
      _servicesInitialized = initialized;

  // SharedPreferences key for storing stocks
  static const String _stocksKey = 'saved_stocks';
  static const String _lastPricesKey =
      'last_prices'; // For price alert comparison

  // Update interval (5 seconds)
  static const Duration updateInterval = Duration(seconds: 5);

  // Timer for periodic updates
  Timer? _updateTimer;

  // Callback for notifying listeners of updates
  Function(List<Stock>)? onStocksUpdated;

  // Price alert thresholds
  static const double priceAlertThreshold = 5.0; // 5% change triggers alert

  // Service initialization state
  final bool _isInitialized = false;

  /// Load saved stocks from local storage
  ///
  /// Returns list of Stock objects from SharedPreferences
  /// Returns empty list if no stocks are saved
  Future<List<Stock>> loadStocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stocksJson = prefs.getString(_stocksKey);

      if (stocksJson == null || stocksJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(stocksJson);
      return decoded.map((json) => Stock.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading stocks: $e');
      return [];
    }
  }

  /// Save stocks to local storage and update all services
  ///
  /// [stocks] - List of Stock objects to persist
  Future<void> saveStocks(List<Stock> stocks) async {
    // Services will be initialized by ServiceRegistry

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = stocks
          .map((stock) => stock.toJson())
          .toList();
      final String encoded = jsonEncode(jsonList);
      await prefs.setString(_stocksKey, encoded);

      // Update all integrated services
      await _updateAllServices(stocks);

      debugPrint('✅ Stocks saved and services updated');
    } catch (e) {
      debugPrint('Error saving stocks: $e');
    }
  }

  /// Update all integrated services with latest stock data
  Future<void> _updateAllServices(List<Stock> stocks) async {
    try {
      // Only update services if they're initialized
      if (_servicesInitialized &&
          _homeWidgetService != null &&
          _notificationService != null) {
        // Update home widget with stocks data
        await _homeWidgetService!.updateWidget(stocks);

        // Update persistent notification
        await _notificationService!.showPortfolioNotification(stocks);
      }

      debugPrint('✅ All services updated with latest stock data');
    } catch (e) {
      debugPrint('❌ Error updating services: $e');
    }
  }

  /// Add a new stock to the portfolio
  ///
  /// [stock] - Stock object to add
  /// Returns updated list of all stocks
  Future<List<Stock>> addStock(Stock stock) async {
    final stocks = await loadStocks();
    final normalizedNewSymbol = _apiService.normalizeSymbol(stock.symbol);

    // Check for duplicates
    final isDuplicate = stocks.any(
      (s) => _apiService.normalizeSymbol(s.symbol) == normalizedNewSymbol,
    );
    if (isDuplicate) {
      throw Exception('Stock ${stock.symbol} already exists in portfolio');
    }

    stocks.add(
      stock.copyWith(
        symbol: normalizedNewSymbol,
        name: _apiService.getStockName(normalizedNewSymbol),
      ),
    );
    await saveStocks(stocks);

    debugPrint('✅ Added stock: ${stock.symbol}');
    return stocks;
  }

  /// Remove a stock from the portfolio
  ///
  /// [stockId] - ID of the stock to remove
  /// Returns updated list of remaining stocks
  Future<List<Stock>> removeStock(String stockId) async {
    final stocks = await loadStocks();
    final removedStock = stocks.firstWhere((s) => s.id == stockId);
    stocks.removeWhere((stock) => stock.id == stockId);
    await saveStocks(stocks);

    debugPrint('✅ Removed stock: ${removedStock.symbol}');
    return stocks;
  }

  /// Update stock prices for all stocks with price alerts
  ///
  /// Fetches latest prices from API and updates stock objects
  /// Checks for significant price changes and sends alerts
  /// Returns updated list of stocks
  Future<List<Stock>> updateAllPrices() async {
    try {
      final stocks = await loadStocks();

      if (stocks.isEmpty) {
        return stocks;
      }

      // Load previous prices for comparison
      final lastPrices = await _getLastPrices();

      // Normalize stored symbols to canonical trading symbols.
      // Example: ITC -> ITC.NS
      final requestSymbolByStockId = <String, String>{};
      for (final stock in stocks) {
        requestSymbolByStockId[stock.id] = _apiService.normalizeSymbol(
          stock.symbol,
        );
      }

      // Get all unique symbols
      final symbols = requestSymbolByStockId.values.toSet().toList();

      // Fetch current prices using batch API
      final prices = await _apiService.fetchMultiplePrices(symbols);

      debugPrint(
        '📊 Fetched prices for ${prices.length}/${symbols.length} symbols',
      );

      // Update each stock with new price and check for alerts
      final updatedStocks = <Stock>[];

      for (final stock in stocks) {
        final requestSymbol =
            requestSymbolByStockId[stock.id] ?? stock.symbol;
        double newPrice = stock.currentPrice; // Keep current price as default
        final fetchedPrice = prices[requestSymbol] ?? prices[stock.symbol];

        // Only use fetched price if it's valid (> 0)
        if (fetchedPrice != null && fetchedPrice > 0.0) {
          newPrice = fetchedPrice;
        } else if (fetchedPrice != null) {
          debugPrint(
            '⚠️ Invalid price for ${stock.symbol}: $fetchedPrice - keeping previous price',
          );
        }

        final oldPrice =
            lastPrices[requestSymbol] ??
            lastPrices[stock.symbol] ??
            stock.currentPrice;

        // Create updated stock
        final updatedStock = stock.copyWith(
          symbol: requestSymbol,
          name: _apiService.getStockName(requestSymbol),
          currentPrice: newPrice,
        );
        updatedStocks.add(updatedStock);

        // Check for price alerts (significant changes) only if price actually updated
        if (newPrice != stock.currentPrice) {
          await _checkPriceAlert(requestSymbol, oldPrice, newPrice);
        }
      }

      // Save current prices for next comparison
      await _saveLastPrices(prices);

      // Save updated stocks (this will update all services)
      await saveStocks(updatedStocks);

      return updatedStocks;
    } catch (e) {
      debugPrint('❌ Error updating stock prices: $e');
      return await loadStocks(); // Return existing stocks on error
    }
  }

  /// Check for significant price changes and send alerts
  Future<void> _checkPriceAlert(
    String symbol,
    double oldPrice,
    double newPrice,
  ) async {
    if (oldPrice <= 0) return; // Skip if no valid old price

    final percentage = ((newPrice - oldPrice) / oldPrice) * 100;

    // Send alert if change is greater than threshold
    if (percentage.abs() >= priceAlertThreshold) {
      await _notificationService?.showPriceAlert(
        symbol: symbol,
        oldPrice: oldPrice,
        newPrice: newPrice,
        percentage: percentage,
      );

      debugPrint(
        '🚨 Price alert sent for $symbol: ${percentage.toStringAsFixed(2)}%',
      );
    }
  }

  /// Get last saved prices for comparison
  Future<Map<String, double>> _getLastPrices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? pricesJson = prefs.getString(_lastPricesKey);

      if (pricesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(pricesJson);
        return decoded.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      }

      return {};
    } catch (e) {
      debugPrint('Error loading last prices: $e');
      return {};
    }
  }

  /// Save current prices for next comparison
  Future<void> _saveLastPrices(Map<String, double> prices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(prices);
      await prefs.setString(_lastPricesKey, encoded);
    } catch (e) {
      debugPrint('Error saving last prices: $e');
    }
  }

  /// Start periodic stock price updates with enhanced features
  ///
  /// Updates stock prices every 5 seconds
  /// Integrates with notification and widget services
  /// Calls [onStocksUpdated] callback after each update
  void startPeriodicUpdates() {
    // Cancel existing timer if any
    stopPeriodicUpdates();

    debugPrint(
      '🔄 Starting enhanced periodic stock updates (every ${updateInterval.inSeconds}s)',
    );

    // Create timer for periodic updates
    _updateTimer = Timer.periodic(updateInterval, (timer) async {
      try {
        debugPrint('📈 Updating stock prices...');
        final updatedStocks = await updateAllPrices();

        // Notify listeners
        onStocksUpdated?.call(updatedStocks);

        debugPrint(
          '✅ Periodic update completed for ${updatedStocks.length} stocks',
        );
      } catch (e) {
        debugPrint('❌ Error in periodic update: $e');
      }
    });

    // Start widget periodic updates
    _homeWidgetService?.startPeriodicUpdates();
  }

  /// Stop periodic updates and clean up
  void stopPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _homeWidgetService?.stopPeriodicUpdates();
    debugPrint('⏹️ Stopped periodic stock updates');
  }

  /// Clear all saved stocks and reset services
  ///
  /// Removes all stocks from local storage and clears widget/notifications
  Future<void> clearAllStocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stocksKey);
      await prefs.remove(_lastPricesKey);

      // Clear all services
      await _homeWidgetService?.clearWidget();
      await _notificationService?.clearAllNotifications();

      debugPrint('✅ All stocks and data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing stocks: $e');
    }
  }

  /// Validate a stock symbol before adding
  ///
  /// [symbol] - Stock ticker symbol to validate
  /// Returns true if symbol is valid and can be added
  Future<bool> validateStockSymbol(String symbol) async {
    return await _apiService.validateSymbol(symbol);
  }

  /// Force refresh all stock data and services
  Future<void> forceRefresh() async {
    // Services will be initialized by ServiceRegistry

    debugPrint('🔄 Force refreshing all stock data...');

    try {
      // Update all prices
      final stocks = await updateAllPrices();

      // Force update widget
      await _homeWidgetService?.forceRefresh(stocks);

      debugPrint('✅ Force refresh completed');
    } catch (e) {
      debugPrint('❌ Error in force refresh: $e');
    }
  }

  /// Get portfolio summary statistics
  Future<Map<String, dynamic>> getPortfolioSummary() async {
    final stocks = await loadStocks();

    double totalInvested = 0;
    double totalCurrent = 0;
    double totalPL = 0;

    for (final stock in stocks) {
      totalInvested += stock.totalInvestment;
      totalCurrent += stock.currentValue;
      totalPL += stock.profitLoss;
    }

    final percentage = totalInvested > 0
        ? (totalPL / totalInvested) * 100
        : 0.0;

    return {
      'total_stocks': stocks.length,
      'total_invested': totalInvested,
      'total_current': totalCurrent,
      'total_pl': totalPL,
      'percentage': percentage,
      'is_profit': totalPL >= 0,
    };
  }

  /// Get service status information
  Map<String, dynamic> getServiceStatus() {
    return {
      'is_initialized': _isInitialized,
      'periodic_updates_active': _updateTimer?.isActive ?? false,
      'update_interval_seconds': updateInterval.inSeconds,
      'price_alert_threshold': priceAlertThreshold,
      'services': {
        'api_service': 'active',
        'notification_service': _isInitialized ? 'active' : 'inactive',
        'home_widget_service': _isInitialized ? 'active' : 'inactive',
      },
    };
  }

  /// Dispose resources and clean up
  void dispose() {
    stopPeriodicUpdates();
    _notificationService?.dispose();
    debugPrint('🧹 StockUpdateService disposed');
  }
}
