import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/stock_update_service.dart';
import '../models/stock.dart';
import '../theme/app_theme.dart';

/// Comprehensive notification service for stock tracker
///
/// Features:
/// - Persistent foreground notification with real-time P/L
/// - Price alert notifications
/// - Portfolio summary notifications
/// - Background service status indicators
/// - Tap to open app functionality
class NotificationService {
  static const String _channelId = 'stock_tracker_channel';
  static const String _channelName = 'Stock Tracker Updates';
  static const String _channelDescription =
      'Real-time stock price and P/L updates';
  static const int _notificationId = 1000;
  static const int _alertNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  // StockUpdateService used indirectly via foreground task

  bool _isInitialized = false;

  /// Initialize the notification service
  /// Call this once at app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const initSettings = InitializationSettings(android: androidSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _createNotificationChannel();
      _isInitialized = true;

      debugPrint('✅ Notification service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize notification service: $e');
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low, // Low importance for persistent updates
      enableVibration: false,
      playSound: false,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Handle notification tap - open the app
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');

    // Bring app to foreground
    SystemNavigator.pop();
  }

  /// Show enhanced persistent notification with P&L prominently in status bar
  /// Title shows total P&L, content shows portfolio details
  Future<void> showPortfolioNotification(List<Stock> stocks) async {
    if (!_isInitialized || stocks.isEmpty) return;

    try {
      // Check if notifications are enabled in settings
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('notification_bar_enabled') ?? true;
      final isPersistent = prefs.getBool('persistent_notification') ?? false;
      final soundEnabled = prefs.getBool('notification_sound') ?? false;

      if (!isEnabled) {
        // Clear any existing notification if disabled
        await _notifications.cancel(_notificationId);
        return;
      }

      final summary = _calculatePortfolioSummary(stocks);

      // FORMAT: Status bar shows "₹+125 (+2.5%)" for immediate P&L visibility
      final percentageStr = summary.totalInvested > 0
          ? ' (${AppTheme.formatPercentage(summary.totalPL / summary.totalInvested * 100)})'
          : '';

      final title =
          '${AppTheme.formatProfitLoss(summary.totalPL)}$percentageStr';

      // Body shows portfolio breakdown
      String body;
      if (stocks.length == 1) {
        final stock = stocks.first;
        body =
            '${stock.symbol}: ₹${stock.currentPrice.toStringAsFixed(2)} • ${AppTheme.formatProfitLoss(stock.profitLoss)}';
      } else if (stocks.length <= 3) {
        // Show top performer and basic stats
        final topStock = stocks.reduce(
          (a, b) => a.profitLoss.abs() > b.profitLoss.abs() ? a : b,
        );
        body =
            '${stocks.length} stocks • Top: ${topStock.symbol} ${AppTheme.formatProfitLoss(topStock.profitLoss)} • Total: ₹${summary.totalInvested.toStringAsFixed(0)}';
      } else {
        body =
            '${stocks.length} stocks • Invested: ₹${summary.totalInvested.toStringAsFixed(0)} • Tap for details';
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: isPersistent ? Priority.max : Priority.low,
        ongoing: isPersistent, // Persistent based on user setting
        autoCancel: !isPersistent, // Cannot be dismissed if persistent
        enableVibration: false,
        playSound: soundEnabled,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        usesChronometer: false,
        icon: '@mipmap/ic_launcher',
        color: summary.totalPL >= 0
            ? const Color(0xFF00C853)
            : const Color(0xFFF44336), // Green for profit, red for loss
        showProgress: false,
        ticker:
            'Portfolio P/L: ${AppTheme.formatProfitLoss(summary.totalPL)}', // Shows in status bar
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        _notificationId,
        title,
        body,
        notificationDetails,
        payload: 'portfolio_update',
      );

      debugPrint('✅ Portfolio notification updated');
    } catch (e) {
      debugPrint('❌ Failed to show portfolio notification: $e');
    }
  }

  /// Show price alert notification when significant changes occur
  /// This is a separate notification that can be dismissed
  Future<void> showPriceAlert({
    required String symbol,
    required double oldPrice,
    required double newPrice,
    required double percentage,
  }) async {
    if (!_isInitialized) return;

    try {
      final isGain = percentage > 0;
      final direction = isGain ? '📈' : '📉';
      final title = '$direction $symbol Alert';
      final body =
          '${AppTheme.formatPercentage(percentage)} • ₹$oldPrice → ₹${newPrice.toStringAsFixed(2)}';

      const androidDetails = AndroidNotificationDetails(
        'stock_alerts',
        'Stock Price Alerts',
        channelDescription: 'Notifications for significant stock price changes',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        _alertNotificationId + symbol.hashCode,
        title,
        body,
        notificationDetails,
        payload: 'price_alert:$symbol',
      );

      debugPrint('✅ Price alert sent for $symbol');
    } catch (e) {
      debugPrint('❌ Failed to show price alert: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('✅ All notifications cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear notifications: $e');
    }
  }

  /// Clear specific notification
  Future<void> clearNotification(int id) async {
    try {
      await _notifications.cancel(id);
      debugPrint('✅ Notification $id cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear notification $id: $e');
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }

  /// Request notification permissions (Android 13+)
  Future<bool> requestNotificationPermissions() async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Calculate portfolio summary for notification display
  _PortfolioSummary _calculatePortfolioSummary(List<Stock> stocks) {
    double totalInvested = 0;
    double totalPL = 0;

    for (final stock in stocks) {
      totalInvested += stock.totalInvestment;
      totalPL += stock.profitLoss;
    }

    return _PortfolioSummary(totalInvested: totalInvested, totalPL: totalPL);
  }

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
  }
}

/// Helper class for portfolio summary calculations
class _PortfolioSummary {
  final double totalInvested;
  final double totalPL;

  _PortfolioSummary({required this.totalInvested, required this.totalPL});
}

/// Foreground service for continuous stock updates
///
/// This service runs in the background and updates stock prices every 5 seconds
/// It also maintains the persistent notification with real-time P/L data
class StockForegroundService {
  static NotificationService? _notificationService;

  /// Start the foreground service
  static Future<bool> start() async {
    try {
      // Initialize notification service if not already done
      _notificationService ??= NotificationService();
      await _notificationService!.initialize();

      // Configure foreground task with basic settings
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'stock_foreground_task',
          channelName: 'Stock Background Updates',
          channelDescription: 'Keeps stock prices updated in background',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(
            5000,
          ), // Update every 5 seconds
        ),
      );

      // Start the foreground task
      await FlutterForegroundTask.startService(
        notificationTitle: 'Stock Tracker Active',
        notificationText: 'Updating prices every 5 seconds...',
        callback: _startCallback,
      );

      debugPrint('✅ Foreground service started successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting foreground service: $e');
      return false;
    }
  }

  /// Stop the foreground service
  static Future<bool> stop() async {
    try {
      await FlutterForegroundTask.stopService();

      debugPrint('✅ Foreground service stopped successfully');
      await _notificationService?.clearAllNotifications();

      return true;
    } catch (e) {
      debugPrint('❌ Error stopping foreground service: $e');
      return false;
    }
  }

  /// Check if foreground service is running
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  /// Callback function for foreground task
  @pragma('vm:entry-point')
  static void _startCallback() {
    FlutterForegroundTask.setTaskHandler(_StockTaskHandler());
  }
}

/// Task handler for the foreground service
/// This runs every 5 seconds and updates stock prices
class _StockTaskHandler extends TaskHandler {
  int _updateCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('📱 Stock foreground task started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _updateCount++;
    debugPrint('🔄 Stock update #$_updateCount at ${timestamp.toLocal()}');

    // Update stock prices in background
    _performBackgroundUpdate();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('🛑 Stock foreground task destroyed at $timestamp');
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('Notification button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    debugPrint('📱 Notification pressed - launching app');
    FlutterForegroundTask.launchApp('/');
  }

  /// Perform background stock price update
  Future<void> _performBackgroundUpdate() async {
    try {
      // Create a stock update service instance
      final stockService = StockUpdateService();

      // Load current stocks
      final stocks = await stockService.loadStocks();

      if (stocks.isNotEmpty) {
        // Update prices
        await stockService.updateAllPrices();

        // Update notification
        if (StockForegroundService._notificationService != null) {
          final updatedStocks = await stockService.loadStocks();
          await StockForegroundService._notificationService!
              .showPortfolioNotification(updatedStocks);
        }

        // Update foreground task notification
        FlutterForegroundTask.updateService(
          notificationTitle: 'Stock Tracker Active',
          notificationText:
              'Updated ${stocks.length} stocks at ${DateTime.now().toLocal().toString().split(' ')[1].substring(0, 5)}',
        );
      }
    } catch (e) {
      debugPrint('❌ Background update failed: $e');
    }
  }
}
