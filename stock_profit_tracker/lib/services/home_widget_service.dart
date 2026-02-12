import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../theme/app_theme.dart';

/// Home Widget Service for Android Stock Tracker Widget
///
/// Features:
/// - Android home screen widget showing top 3 stocks
/// - Real-time P/L updates
/// - Tap to open app functionality
/// - Automatic updates when app is running
/// - Elegant Material 3 design matching app theme
class HomeWidgetService {
  static const String _widgetName = 'StockTrackerWidget';
  static const String _androidProviderName = 'StockTrackerWidgetProvider';

  // Singleton pattern to prevent circular dependencies
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  /// Initialize the home widget
  Future<void> initialize() async {
    if (!_isWidgetSupported) {
      debugPrint('ℹ️ Home widget not supported on this platform');
      return;
    }
    try {
      await HomeWidget.setAppGroupId('group.stock_tracker_widget');
      debugPrint('✅ Home widget initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize home widget: $e');
    }
  }

  /// Update the home widget with current portfolio data (ENHANCED)
  /// Shows top 3 stocks with highest profit/loss values, with price validation
  Future<void> updateWidget([List<Stock>? stocks]) async {
    if (!_isWidgetSupported) {
      return;
    }
    try {
      // Use provided stocks or load from storage if none provided
      List<Stock> currentStocks = stocks ?? [];

      if (stocks == null) {
        // Only load from storage if no stocks provided (for backward compatibility)
        // Note: This should be avoided to prevent circular dependency
        debugPrint(
          '⚠️ Loading stocks from storage in HomeWidgetService - consider passing stocks directly',
        );
        return; // Skip update to prevent circular dependency
      }

      if (currentStocks.isEmpty) {
        await _showEmptyWidget();
        return;
      }

      // Filter out stocks with invalid prices (0.0 or negative)
      final validStocks = currentStocks.where((stock) {
        if (stock.currentPrice <= 0.0 || stock.buyPrice <= 0.0) {
          debugPrint(
            '⚠️ Skipping ${stock.symbol} in widget: Invalid price data (Current: ${stock.currentPrice}, Purchase: ${stock.buyPrice})',
          );
          return false;
        }
        return true;
      }).toList();

      if (validStocks.isEmpty) {
        debugPrint('⚠️ No stocks with valid prices for widget display');
        await _showEmptyWidget();
        return;
      }

      debugPrint(
        '📊 Widget update: ${validStocks.length}/${currentStocks.length} stocks have valid prices',
      );

      // Sort stocks by absolute profit/loss value (highest first)
      validStocks.sort(
        (a, b) => b.profitLoss.abs().compareTo(a.profitLoss.abs()),
      );

      // Get widget size preference and adjust stock count accordingly
      final prefs = await SharedPreferences.getInstance();
      final widgetSize = prefs.getString('widget_size') ?? '4x2';
      final maxStocks = _getMaxStocksForSize(widgetSize);

      // Take appropriate number of stocks based on widget size
      final topStocks = validStocks.take(maxStocks).toList();

      debugPrint(
        '📊 Widget ($widgetSize): Showing ${topStocks.length}/${validStocks.length} stocks',
      );

      // Calculate portfolio totals (only from valid stocks)
      final totalInvested = validStocks.fold<double>(
        0,
        (sum, stock) => sum + stock.totalInvestment,
      );
      final totalPL = validStocks.fold<double>(
        0,
        (sum, stock) => sum + stock.profitLoss,
      );
      final totalPercentage = totalInvested > 0
          ? (totalPL / totalInvested) * 100
          : 0.0;

      debugPrint(
        '📈 Widget Portfolio Summary: ${validStocks.length} stocks, ₹${totalInvested.toStringAsFixed(2)} invested, ₹${totalPL.toStringAsFixed(2)} P/L (${totalPercentage.toStringAsFixed(2)}%)',
      );

      // Prepare widget data with validation
      final widgetData = {
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'total_stocks': validStocks.length,
        'total_invested': totalInvested,
        'total_pl': totalPL,
        'total_percentage': totalPercentage,
        'stocks': topStocks.asMap().map(
          (index, stock) => MapEntry(index.toString(), {
            'symbol': stock.symbol,
            'company_name': _getShortCompanyName(stock.symbol),
            'current_price': stock.currentPrice,
            'profit_loss': stock.profitLoss,
            'percentage': stock.profitLossPercentage,
            'quantity': stock.quantity,
            'purchase_price': stock.buyPrice,
            'total_investment': stock.totalInvestment,
            'current_value': stock.currentValue,
          }),
        ),
      };

      // Save each piece of data individually for the widget
      await HomeWidget.saveWidgetData('widget_data', jsonEncode(widgetData));

      // Save update timestamp for countdown timer
      final now = DateTime.now();
      await HomeWidget.saveWidgetData(
        'last_updated',
        now.millisecondsSinceEpoch.toString(),
      );
      await HomeWidget.saveWidgetData(
        'widget_update_time',
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      );
      await HomeWidget.saveWidgetData(
        'total_pl',
        AppTheme.formatProfitLoss(totalPL),
      );
      await HomeWidget.saveWidgetData(
        'widget_total_pl',
        AppTheme.formatProfitLoss(totalPL),
      );
      await HomeWidget.saveWidgetData(
        'total_percentage',
        AppTheme.formatPercentage(totalPercentage),
      );
      await HomeWidget.saveWidgetData(
        'widget_total_percentage',
        AppTheme.formatPercentage(totalPercentage),
      );
      await HomeWidget.saveWidgetData(
        'widget_last_updated',
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      );
      await HomeWidget.saveWidgetData(
        'stock_count',
        validStocks.length.toString(),
      );
      await HomeWidget.saveWidgetData(
        'widget_stock_count',
        '${validStocks.length} stocks',
      );

      // Save individual stock data (for easier access in widget)
      for (int i = 0; i < topStocks.length && i < 3; i++) {
        final stock = topStocks[i];
        final shortName = _getShortCompanyName(stock.symbol);
        final ltpText = '₹${stock.currentPrice.toStringAsFixed(2)}';
        final plValue = stock.profitLoss;
        final plText = plValue >= 0
            ? '+₹${plValue.toStringAsFixed(2)}'
            : '-₹${plValue.abs().toStringAsFixed(2)}';

        await HomeWidget.saveWidgetData('stock_${i}_symbol', stock.symbol);
        await HomeWidget.saveWidgetData(
          'widget_stock_${i}_symbol',
          stock.symbol,
        );
        await HomeWidget.saveWidgetData('stock_${i}_name', shortName);
        await HomeWidget.saveWidgetData('widget_stock_${i}_name', shortName);

        // Save LTP (current price)
        await HomeWidget.saveWidgetData('stock_${i}_ltp', ltpText);
        await HomeWidget.saveWidgetData('widget_stock_${i}_ltp', ltpText);

        // Save P/L (profit/loss)
        await HomeWidget.saveWidgetData('stock_${i}_pl', plText);
        await HomeWidget.saveWidgetData('widget_stock_${i}_pl', plText);

        // Legacy fields for backward compatibility
        await HomeWidget.saveWidgetData('stock_${i}_price', ltpText);
        await HomeWidget.saveWidgetData('widget_stock_${i}_price', ltpText);
        await HomeWidget.saveWidgetData(
          'stock_${i}_percentage',
          AppTheme.formatPercentage(stock.profitLossPercentage),
        );
        await HomeWidget.saveWidgetData(
          'stock_${i}_is_profit',
          (stock.profitLoss >= 0).toString(),
        );
      }

      // Clear unused slots so stale values do not remain in widget rows.
      for (int i = topStocks.length; i < 3; i++) {
        await HomeWidget.saveWidgetData('stock_${i}_symbol', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_symbol', '');
        await HomeWidget.saveWidgetData('stock_${i}_name', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_name', '');
        await HomeWidget.saveWidgetData('stock_${i}_ltp', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_ltp', '');
        await HomeWidget.saveWidgetData('stock_${i}_pl', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_pl', '');
        await HomeWidget.saveWidgetData('stock_${i}_price', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_price', '');
        await HomeWidget.saveWidgetData('stock_${i}_percentage', '');
        await HomeWidget.saveWidgetData('stock_${i}_is_profit', 'false');
      }

      // Update the widget
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _androidProviderName,
      );

      debugPrint('✅ Home widget updated with ${topStocks.length} stocks');
    } catch (e) {
      debugPrint('❌ Failed to update home widget: $e');
    }
  }

  /// Show empty widget when no stocks are available
  Future<void> _showEmptyWidget() async {
    if (!_isWidgetSupported) {
      return;
    }
    try {
      await HomeWidget.saveWidgetData(
        'widget_data',
        jsonEncode({
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'total_stocks': 0,
          'is_empty': true,
        }),
      );

      await HomeWidget.saveWidgetData(
        'last_updated',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await HomeWidget.saveWidgetData('total_pl', '₹0.00');
      await HomeWidget.saveWidgetData('widget_total_pl', '₹0.00');
      await HomeWidget.saveWidgetData('total_percentage', '0.00%');
      await HomeWidget.saveWidgetData('widget_total_percentage', '0.00%');
      await HomeWidget.saveWidgetData('widget_last_updated', '0.00%');
      await HomeWidget.saveWidgetData('stock_count', '0');
      await HomeWidget.saveWidgetData('widget_stock_count', '0 stocks');
      await HomeWidget.saveWidgetData('is_empty', 'true');

      for (int i = 0; i < 3; i++) {
        await HomeWidget.saveWidgetData('stock_${i}_symbol', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_symbol', '');
        await HomeWidget.saveWidgetData('stock_${i}_name', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_name', '');
        await HomeWidget.saveWidgetData('stock_${i}_pl', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_pl', '');
        await HomeWidget.saveWidgetData('stock_${i}_price', '');
        await HomeWidget.saveWidgetData('widget_stock_${i}_price', '');
      }

      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _androidProviderName,
      );

      debugPrint('✅ Empty home widget displayed');
    } catch (e) {
      debugPrint('❌ Failed to show empty widget: $e');
    }
  }

  /// Get shortened company name for widget display
  String _getShortCompanyName(String symbol) {
    final shortNames = {
      // Indian stocks (shortened for widget)
      'TCS.NS': 'TCS',
      'INFY.NS': 'Infosys',
      'RELIANCE.NS': 'Reliance',
      'HDFCBANK.NS': 'HDFC Bank',
      'ICICIBANK.NS': 'ICICI Bank',
      'ITC.NS': 'ITC',
      'BHARTIARTL.NS': 'Bharti',
      'KOTAKBANK.NS': 'Kotak',
      'LT.NS': 'L&T',
      'SBIN.NS': 'SBI',

      // US stocks (shortened for widget)
      'AAPL': 'Apple',
      'GOOGL': 'Google',
      'MSFT': 'Microsoft',
      'AMZN': 'Amazon',
      'TSLA': 'Tesla',
      'META': 'Meta',
      'NVDA': 'NVIDIA',
      'NFLX': 'Netflix',
    };

    return shortNames[symbol.toUpperCase()] ??
        symbol.replaceAll(RegExp(r'\.[A-Z]+$'), '').toUpperCase();
  }

  /// Set up widget tap actions
  Future<void> registerInteractivity() async {
    if (!_isWidgetSupported) {
      return;
    }
    try {
      // Register callback for widget taps
      HomeWidget.widgetClicked.listen((uri) {
        debugPrint('Widget tapped with URI: $uri');
        // This will bring the app to foreground
        // The app will handle the specific action based on URI
      });

      debugPrint('✅ Widget interactivity registered');
    } catch (e) {
      debugPrint('❌ Failed to register widget interactivity: $e');
    }
  }

  /// Schedule periodic widget updates
  /// This should be called when the foreground service starts
  void startPeriodicUpdates() {
    // Widget updates are handled by the foreground service
    // This method is a placeholder for future scheduling logic
    debugPrint('📱 Widget periodic updates started');
  }

  /// Stop periodic widget updates
  void stopPeriodicUpdates() {
    debugPrint('📱 Widget periodic updates stopped');
  }

  /// Get widget configuration info
  Map<String, dynamic> getWidgetInfo() {
    return {
      'widget_name': _widgetName,
      'provider_name': _androidProviderName,
      'supported_sizes': ['2x2', '3x2', '4x2'],
      'auto_update': true,
      'tap_to_open': true,
    };
  }

  /// Helper method to check if widget is pinned to home screen
  Future<bool> isWidgetPinned() async {
    try {
      // This is a placeholder - the home_widget package doesn't provide
      // a direct way to check if widget is actually pinned
      // In practice, you can check SharedPreferences or app state
      return true; // Assume widget is available
    } catch (e) {
      debugPrint('Error checking widget status: $e');
      return false;
    }
  }

  /// Force refresh widget data
  /// Note: Actual price updates should be triggered from StockUpdateService
  /// to avoid circular dependencies
  Future<void> forceRefresh([List<Stock>? stocks]) async {
    debugPrint('🔄 Force refreshing home widget...');
    if (stocks != null) {
      await updateWidget(stocks);
    } else {
      debugPrint(
        '⚠️ No stocks provided for force refresh - skipping update to avoid circular dependency',
      );
    }
  }

  /// Get last widget update time
  Future<DateTime?> getLastUpdateTime() async {
    if (!_isWidgetSupported) {
      return null;
    }
    try {
      final timestampStr =
          await HomeWidget.getWidgetData('last_updated') as String?;
      if (timestampStr != null) {
        final timestamp = int.tryParse(timestampStr);
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting widget update time: $e');
      return null;
    }
  }

  /// Clear all widget data
  Future<void> clearWidget() async {
    if (!_isWidgetSupported) {
      return;
    }
    try {
      // Clear all stored widget data
      await HomeWidget.saveWidgetData('widget_data', '{}');
      await HomeWidget.saveWidgetData('is_empty', 'true');

      // Update widget to show cleared state
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _androidProviderName,
      );

      debugPrint('✅ Widget data cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear widget: $e');
    }
  }

  /// Get maximum stocks to display based on widget size preference
  /// Adjusts layout density for different widget configurations
  int _getMaxStocksForSize(String widgetSize) {
    switch (widgetSize) {
      case '3x2':
        return 2; // Compact - fewer stocks, larger text
      case '4x2':
        return 3; // Standard - balanced
      case '4x3':
        return 4; // Large - more stocks can fit
      default:
        return 3; // Default to standard
    }
  }

  /// Get widget layout preference from user settings
  /// Returns the layout identifier for conditional rendering
  Future<String> getWidgetLayoutPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('widget_size') ?? '4x2';
  }

  /// Update widget layout preference in settings
  Future<void> setWidgetLayoutPreference(String layoutSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_size', layoutSize);
    debugPrint('📱 Widget layout preference updated to: $layoutSize');
  }

  bool get _isWidgetSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

/// Widget configuration constants for Android implementation
class WidgetConfig {
  static const String packageName = 'com.example.stock_profit_tracker';
  static const String widgetClassName = 'StockTrackerWidgetProvider';

  // Widget dimensions (in DP)
  static const int minWidth = 180;
  static const int minHeight = 110;
  static const int defaultWidth = 220;
  static const int defaultHeight = 140;

  // Update intervals
  static const int updateIntervalMinutes = 5;
  static const int fastUpdateIntervalSeconds = 5;

  // Widget styling
  static const String backgroundColor = '#FAFBFE'; // Light theme background
  static const String backgroundColorDark = '#121212'; // Dark theme background
  static const String textColor = '#1C1B1F';
  static const String textColorDark = '#E6E1E5';
  static const String profitColor = '#00C853';
  static const String lossColor = '#D32F2F';
}
