import 'package:flutter/foundation.dart';
import '../services/stock_update_service.dart';
import '../services/notification_service.dart';
import '../services/home_widget_service.dart';

/// Service Registry to manage service dependencies and prevent circular dependencies
///
/// This acts as a central registry for all services, ensuring they are initialized
/// in the correct order and preventing circular dependency issues.
class ServiceRegistry {
  static final ServiceRegistry _instance = ServiceRegistry._internal();
  factory ServiceRegistry() => _instance;
  ServiceRegistry._internal();

  // Service instances
  StockUpdateService? _stockUpdateService;
  NotificationService? _notificationService;
  HomeWidgetService? _homeWidgetService;

  bool _isInitialized = false;

  /// Initialize all services in the correct order to prevent circular dependencies
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize services in dependency order
      // 1. First initialize services with no dependencies
      _notificationService = NotificationService();
      await _notificationService!.initialize();

      _homeWidgetService = HomeWidgetService();
      await _homeWidgetService!.initialize();
      await _homeWidgetService!.registerInteractivity();

      // 2. Then initialize services that depend on others
      _stockUpdateService = StockUpdateService();
      // Set up dependencies - these are now safe as services are already created
      _stockUpdateService!.notificationService = _notificationService!;
      _stockUpdateService!.homeWidgetService = _homeWidgetService!;
      _stockUpdateService!.servicesInitialized = true;

      _isInitialized = true;
      debugPrint('✅ ServiceRegistry: All services initialized successfully');
    } catch (e) {
      debugPrint('❌ ServiceRegistry initialization failed: $e');
      rethrow;
    }
  }

  /// Get the stock update service (must be initialized first)
  StockUpdateService get stockUpdateService {
    if (_stockUpdateService == null) {
      throw StateError(
        'ServiceRegistry not initialized. Call initialize() first.',
      );
    }
    return _stockUpdateService!;
  }

  /// Get the notification service (must be initialized first)
  NotificationService get notificationService {
    if (_notificationService == null) {
      throw StateError(
        'ServiceRegistry not initialized. Call initialize() first.',
      );
    }
    return _notificationService!;
  }

  /// Get the home widget service (must be initialized first)
  HomeWidgetService get homeWidgetService {
    if (_homeWidgetService == null) {
      throw StateError(
        'ServiceRegistry not initialized. Call initialize() first.',
      );
    }
    return _homeWidgetService!;
  }

  /// Check if the registry is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose all services
  void dispose() {
    _stockUpdateService?.dispose();
    _stockUpdateService = null;
    _notificationService = null;
    _homeWidgetService = null;
    _isInitialized = false;
    debugPrint('🔄 ServiceRegistry: All services disposed');
  }
}
