import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../services/service_registry.dart';
import '../services/notification_service.dart';

/// Enhanced Provider for managing stock portfolio state
///
/// Uses Provider pattern for state management with integrated services
/// Handles:
/// - Stock list management with real-time updates
/// - Adding/removing stocks with validation
/// - Periodic updates with notification & widget integration
/// - Loading/saving to local storage
/// - Portfolio calculations and analytics
/// - Foreground service management
/// - Price alerts and notifications
class StockProvider with ChangeNotifier {
  final ServiceRegistry _serviceRegistry = ServiceRegistry();

  // List of stocks in the portfolio
  List<Stock> _stocks = [];

  // Loading state
  bool _isLoading = false;

  // Error message
  String? _errorMessage;

  // Whether periodic updates are active
  bool _isUpdatingPeriodically = false;

  // Whether foreground service is running
  bool _isForegroundServiceActive = false;

  // Initialization state
  bool _isInitialized = false;

  // Getters
  List<Stock> get stocks => _stocks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUpdatingPeriodically => _isUpdatingPeriodically;
  bool get isForegroundServiceActive => _isForegroundServiceActive;
  bool get hasStocks => _stocks.isNotEmpty;
  bool get isInitialized => _isInitialized;

  /// Total investment across all stocks
  double get totalInvestment {
    return _stocks.fold(0.0, (sum, stock) => sum + stock.totalInvestment);
  }

  /// Current total market value of portfolio
  double get totalCurrentValue {
    return _stocks.fold(0.0, (sum, stock) => sum + stock.currentValue);
  }

  /// Total profit or loss amount
  double get totalProfitLoss {
    return _stocks.fold(0.0, (sum, stock) => sum + stock.profitLoss);
  }

  /// Total profit or loss percentage
  double get totalProfitLossPercentage {
    if (totalInvestment == 0) return 0.0;
    return (totalProfitLoss / totalInvestment) * 100;
  }

  /// Check if portfolio is in overall profit
  bool get isOverallProfit => totalProfitLoss >= 0;

  /// Get best performing stock
  Stock? get bestPerformingStock {
    if (_stocks.isEmpty) return null;
    return _stocks.reduce(
      (a, b) => a.profitLossPercentage > b.profitLossPercentage ? a : b,
    );
  }

  /// Get worst performing stock
  Stock? get worstPerformingStock {
    if (_stocks.isEmpty) return null;
    return _stocks.reduce(
      (a, b) => a.profitLossPercentage < b.profitLossPercentage ? a : b,
    );
  }

  /// Get portfolio summary for display
  Map<String, dynamic> get portfolioSummary => {
    'total_stocks': _stocks.length,
    'total_invested': totalInvestment,
    'total_current': totalCurrentValue,
    'total_pl': totalProfitLoss,
    'percentage': totalProfitLossPercentage,
    'is_profit': isOverallProfit,
    'best_stock': bestPerformingStock?.symbol,
    'worst_stock': worstPerformingStock?.symbol,
  };

  StockProvider() {
    // Services will be initialized via ServiceRegistry
    // All service initialization is deferred to prevent circular dependencies
  }

  /// Initialize provider and all integrated services via ServiceRegistry
  ///
  /// Call this when app starts
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      _clearError();

      // Initialize all services via registry to prevent circular dependencies
      await _serviceRegistry.initialize();

      // Set up the update callback for real-time updates
      _serviceRegistry.stockUpdateService.onStocksUpdated = (updatedStocks) {
        _stocks = updatedStocks;
        notifyListeners();
        debugPrint(
          '📊 Portfolio updated: ${_stocks.length} stocks, P/L: ₹${totalProfitLoss.toStringAsFixed(2)}',
        );
      };

      // Load existing stocks
      await loadStocks();

      // Auto-start foreground service for continuous widget updates
      await startForegroundService();

      _isInitialized = true;
      debugPrint('✅ StockProvider initialized successfully');
    } catch (e) {
      _setError('Failed to initialize: $e');
      debugPrint('❌ Error initializing StockProvider: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load stocks from local storage
  Future<void> loadStocks() async {
    try {
      _setLoading(true);
      _clearError();

      _stocks = await _serviceRegistry.stockUpdateService.loadStocks();

      debugPrint('📚 Loaded ${_stocks.length} stocks from storage');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load stocks: $e');
      debugPrint('❌ Error loading stocks: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new stock to the portfolio with enhanced validation
  ///
  /// [stock] - Stock object to add
  /// Returns true if successful
  Future<bool> addStock(Stock stock) async {
    try {
      _setLoading(true);
      _clearError();

      final normalizedNewSymbol = _serviceRegistry.stockUpdateService.apiService
          .normalizeSymbol(stock.symbol);

      // Check for duplicate symbol (with normalization).
      if (_stocks.any(
        (s) =>
            _serviceRegistry.stockUpdateService.apiService.normalizeSymbol(
              s.symbol,
            ) ==
            normalizedNewSymbol,
      )) {
        _setError('Stock ${stock.symbol} already exists in portfolio');
        return false;
      }

      // Validate symbol with real API
      final isValid = await _serviceRegistry.stockUpdateService
          .validateStockSymbol(stock.symbol);
      if (!isValid) {
        _setError('Invalid stock symbol: ${stock.symbol}');
        return false;
      }

      _stocks = await _serviceRegistry.stockUpdateService.addStock(stock);

      debugPrint('✅ Added stock: ${stock.symbol}');
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to add stock: $e');
      debugPrint('❌ Error adding stock: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove a stock from the portfolio
  ///
  /// [stockId] - ID of the stock to remove
  Future<void> removeStock(String stockId) async {
    try {
      _setLoading(true);
      _clearError();

      final stockToRemove = _stocks.firstWhere((s) => s.id == stockId);
      _stocks = await _serviceRegistry.stockUpdateService.removeStock(stockId);

      debugPrint('✅ Removed stock: ${stockToRemove.symbol}');
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove stock: $e');
      debugPrint('❌ Error removing stock: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Manually trigger comprehensive refresh
  ///
  /// Useful for pull-to-refresh functionality
  Future<void> refreshStockPrices() async {
    try {
      _clearError();

      debugPrint('🔄 Manual refresh triggered...');
      _stocks = await _serviceRegistry.stockUpdateService.updateAllPrices();

      debugPrint('✅ Refreshed ${_stocks.length} stock prices');
      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh prices: $e');
      debugPrint('❌ Error refreshing prices: $e');
    }
  }

  /// Force refresh all data and services
  Future<void> forceRefresh() async {
    try {
      _clearError();

      debugPrint('⚡ Force refresh initiated...');
      await _serviceRegistry.stockUpdateService.forceRefresh();
      await loadStocks(); // Reload to get latest data

      debugPrint('✅ Force refresh completed');
    } catch (e) {
      _setError('Failed to force refresh: $e');
      debugPrint('❌ Error in force refresh: $e');
    }
  }

  /// Start automatic periodic updates with enhanced features
  ///
  /// Integrates notifications, widgets, and background services
  /// Call this when app comes to foreground
  void startPeriodicUpdates() {
    if (_isUpdatingPeriodically) {
      debugPrint('📱 Periodic updates already running');
      return;
    }

    _serviceRegistry.stockUpdateService.startPeriodicUpdates();
    _isUpdatingPeriodically = true;
    notifyListeners();

    debugPrint('🚀 Started enhanced periodic stock updates');
  }

  /// Stop automatic periodic updates
  ///
  /// Call this when app goes to background or is paused
  void stopPeriodicUpdates() {
    if (!_isUpdatingPeriodically) {
      return;
    }

    _serviceRegistry.stockUpdateService.stopPeriodicUpdates();
    _isUpdatingPeriodically = false;
    notifyListeners();

    debugPrint('⏹️ Stopped periodic stock updates');
  }

  /// Start foreground service for background updates
  Future<bool> startForegroundService() async {
    try {
      if (_isForegroundServiceActive) {
        debugPrint('📱 Foreground service already running');
        return true;
      }

      final started = await StockForegroundService.start();
      if (started) {
        _isForegroundServiceActive = true;
        notifyListeners();
        debugPrint('🚀 Foreground service started successfully');
      } else {
        _setError('Failed to start foreground service');
        debugPrint('❌ Failed to start foreground service');
      }

      return started;
    } catch (e) {
      _setError('Error starting foreground service: $e');
      debugPrint('❌ Error starting foreground service: $e');
      return false;
    }
  }

  /// Stop foreground service
  Future<bool> stopForegroundService() async {
    try {
      final stopped = await StockForegroundService.stop();
      if (stopped) {
        _isForegroundServiceActive = false;
        notifyListeners();
        debugPrint('⏹️ Foreground service stopped');
      }

      return stopped;
    } catch (e) {
      debugPrint('❌ Error stopping foreground service: $e');
      return false;
    }
  }

  /// Clear all stocks from portfolio (delegates to comprehensive clear)
  Future<void> clearAllStocks() async {
    return clearAllData(); // Use the comprehensive clear method
  }

  /// Validate stock symbol with real API
  ///
  /// [symbol] - Stock ticker symbol
  /// Returns true if valid
  Future<bool> validateSymbol(String symbol) async {
    try {
      _clearError();
      return await _serviceRegistry.stockUpdateService.validateStockSymbol(
        symbol,
      );
    } catch (e) {
      _setError('Error validating symbol: $e');
      debugPrint('❌ Error validating symbol: $e');
      return false;
    }
  }

  /// Get detailed portfolio analytics
  Future<Map<String, dynamic>> getPortfolioAnalytics() async {
    try {
      final summary = await _serviceRegistry.stockUpdateService
          .getPortfolioSummary();
      final serviceStatus = _serviceRegistry.stockUpdateService
          .getServiceStatus();

      return {
        ...summary,
        'service_status': serviceStatus,
        'update_status': {
          'periodic_updates': _isUpdatingPeriodically,
          'foreground_service': _isForegroundServiceActive,
          'last_manual_refresh': DateTime.now().toIso8601String(),
        },
      };
    } catch (e) {
      debugPrint('❌ Error getting analytics: $e');
      return portfolioSummary;
    }
  }

  // Helper methods

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
    debugPrint('🚨 Provider error: $error');
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Clear all portfolio data and reset app state
  /// This removes all stocks, clears cache, and resets widget
  Future<void> clearAllData() async {
    try {
      _setLoading(true);
      _clearError();

      // Stop any ongoing updates
      stopPeriodicUpdates();

      // Clear the stocks list
      _stocks.clear();

      // Clear from storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stocks_data');

      // Clear cache in API service
      if (_isInitialized) {
        _serviceRegistry.stockUpdateService.apiService.clearCache();

        // Update all services with empty data (this will clear widget too)
        await _serviceRegistry.stockUpdateService.saveStocks([]);
      }

      debugPrint('✅ All portfolio data cleared - widget and storage reset');
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear data: $e');
      debugPrint('❌ Error clearing portfolio data: $e');
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    // Stop all services
    stopPeriodicUpdates();
    stopForegroundService();

    // Dispose update service
    _serviceRegistry.dispose();

    debugPrint('🧹 StockProvider disposed');
    super.dispose();
  }
}
