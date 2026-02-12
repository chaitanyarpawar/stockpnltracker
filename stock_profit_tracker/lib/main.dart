import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:home_widget/home_widget.dart';
import 'providers/stock_provider.dart';
import 'screens/enhanced_home_screen.dart';
import 'theme/app_theme.dart';
import 'services/widget_background_service.dart';

/// Main entry point of the Stock Profit Tracker application
///
/// This app tracks stock portfolio profit/loss in real-time with:
/// - Live price updates every 5 seconds
/// - Android home screen widget
/// - Foreground service for background updates
/// - Local data persistence
/// - Clean Material Design UI
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (portrait only for better UX)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize foreground task configuration
  // Note: Currently using foreground updates via Provider
  // Future enhancement: Complete background service integration
  _initializeForegroundTask();

  // Register widget background callback for refresh button
  // This allows the widget to fetch fresh data without opening the app
  await _initializeWidgetCallback();

  runApp(const StockProfitTrackerApp());
}

/// Initialize HomeWidget background callback
/// This enables the widget refresh button to fetch fresh prices
Future<void> _initializeWidgetCallback() async {
  try {
    // Register the background callback for widget interactions
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    debugPrint('✅ Widget background callback registered');
  } catch (e) {
    debugPrint('❌ Failed to register widget callback: $e');
  }
}

/// Initialize foreground task for background stock updates
///
/// This allows the app to continue updating stock prices
/// even when running in the background
///
/// NOTE: Currently disabled - needs API version-specific implementation
/// The app uses foreground updates via Provider instead
void _initializeForegroundTask() {
  // Future enhancement: Implement based on flutter_foreground_task version
  // Current version (8.17.0) has different API than expected
  // For now, updates happen in foreground via StockProvider
  debugPrint(
    'Foreground task initialization skipped - using foreground updates',
  );
}

/// Root widget of the application
class StockProfitTrackerApp extends StatelessWidget {
  const StockProfitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Stock Provider for state management
        ChangeNotifierProvider(create: (_) => StockProvider()),
      ],
      child: MaterialApp(
        title: 'Stock Profit Tracker',
        debugShowCheckedModeBanner: false,

        // Modern Material 3 Theme Configuration
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,

        // Home Screen
        home: const HomeScreen(),
      ),
    );
  }
}

/// Foreground Task Handler
///
/// This handler is called every 5 seconds when the foreground service is active
/// It updates stock prices in the background
///
/// NOTE: This is a basic implementation. For production:
/// - Move this to a separate file
/// - Implement proper error handling
/// - Add battery optimization considerations
/// - Handle network connectivity changes
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StockUpdateTaskHandler());
}

/// Task handler for background stock updates
class StockUpdateTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Stock update task started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This is called every 5 seconds
    // In production, this would:
    // 1. Fetch latest stock prices
    // 2. Update SharedPreferences
    // 3. Update home widget
    // 4. Send notification if needed

    debugPrint('Background stock update triggered at $timestamp');

    // Background update logic placeholder
    // In production, this would:
    // 1. Use StockUpdateService to fetch latest prices
    // 2. Update SharedPreferences with new stock data
    // 3. Trigger home widget update
    // 4. Send notification if significant P/L changes occur
    // Currently, updates happen in foreground through StockProvider
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('Stock update task destroyed at $timestamp');
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('Notification button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    // Called when notification is pressed
    // Open the app
    FlutterForegroundTask.launchApp('/');
  }
}
