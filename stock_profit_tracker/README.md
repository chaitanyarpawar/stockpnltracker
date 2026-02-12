# Stock Profit Tracker - Flutter Android App

A production-ready Flutter application for tracking stock portfolio profit/loss in real-time with Android home screen widget support and background updates.

## 🚀 Project Setup Command

```bash
flutter create --org com.stocktracker --project-name stock_profit_tracker --platforms android stock_profit_tracker
```

**Command Breakdown:**
- `--org com.stocktracker`: Sets the organization identifier
- `--project-name stock_profit_tracker`: Sets the project name
- `--platforms android`: Creates Android-only project (optimized for size)
- `stock_profit_tracker`: Project directory name

## 📋 Project Configuration

### Flutter SDK
- **Version:** Latest stable (3.35.7+ recommended)
- **Dart Version:** 3.9.2+
- **Target Platform:** Android only
- **Null Safety:** Enabled

### Android Configuration
- **Minimum SDK:** 21 (Android 5.0 Lollipop)
- **Compile SDK:** Latest (from Flutter SDK)
- **Package Name:** com.stocktracker.stock_profit_tracker

## 📦 Dependencies

All dependencies are configured in `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.2.0                        # API calls for stock data
  shared_preferences: ^2.2.2          # Local data persistence
  provider: ^6.1.1                    # State management
  flutter_foreground_task: ^8.1.0     # Background service
  home_widget: ^0.5.0                 # Android home screen widget
  intl: ^0.19.0                       # Number/date formatting
```

### Installing Dependencies

```bash
cd stock_profit_tracker
flutter pub get
```

## 📁 Project Structure

```
lib/
├── main.dart                           # App entry point & configuration
├── models/
│   └── stock.dart                      # Stock data model with P/L calculations
├── services/
│   ├── stock_api_service.dart          # API service (mock data for now)
│   └── stock_update_service.dart       # Update service & local storage
├── providers/
│   └── stock_provider.dart             # State management with Provider
├── screens/
│   └── home_screen.dart                # Main app screen
└── widgets/
    ├── stock_form.dart                 # Add stock form widget
    └── stock_list_item.dart            # Stock list item widget

android/
├── app/
│   ├── build.gradle.kts                # Android build config (minSdk: 21)
│   └── src/main/
│       ├── AndroidManifest.xml         # Permissions & components
│       └── res/
│           ├── xml/
│           │   └── home_widget_info.xml    # Widget configuration
│           ├── layout/
│           │   └── home_widget_layout.xml  # Widget UI layout
│           └── values/
│               └── strings.xml             # String resources
```

## ⚙️ Android Configuration Details

### Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

### Foreground Service Configuration
- **Service Type:** dataSync
- **Update Interval:** 5 seconds
- **Notification Channel:** stock_tracker_channel
- **Priority:** LOW (to avoid annoying users)

### Home Screen Widget
- **Size:** 180dp × 110dp (minimum)
- **Update Mode:** On-demand (via app updates)
- **Resize:** Horizontal/Vertical
- **Layout:** LinearLayout with TextViews

## 🎯 Key Features Implemented

### 1. Stock Model (`models/stock.dart`)
- Complete stock data representation
- Automatic P/L calculations
- JSON serialization/deserialization
- Immutable with `copyWith` method

### 2. API Service (`services/stock_api_service.dart`)
- **Current State:** Mock data with realistic fluctuations
- **Mock Features:**
  - Random price fluctuations (±5%)
  - Simulated network delay
  - Pre-defined stock prices (AAPL, GOOGL, etc.)
- **Production Ready:** 
  - Commented real API implementation
  - Error handling structure
  - Batch price fetching support

**To Use Real API:**
1. Uncomment real API code in `fetchCurrentPrice()`
2. Add your API key to `_apiKey` constant
3. Update `_baseUrl` with actual API endpoint
4. Remove mock methods

### 3. Update Service (`services/stock_update_service.dart`)
- Local storage using SharedPreferences
- Periodic updates (5-second interval)
- Home widget data synchronization
- CRUD operations for stocks

### 4. State Management (`providers/stock_provider.dart`)
- Provider pattern implementation
- Reactive state updates
- Portfolio calculations (total P/L, percentages)
- Automatic listener notifications
- Lifecycle management

### 5. Home Screen (`screens/home_screen.dart`)
- **Layout:**
  - Portfolio summary card (total value, P/L, return %)
  - Expandable add stock form
  - Scrollable stock list
  - Empty state UI
- **Features:**
  - Pull-to-refresh
  - Live update indicator
  - Clear all stocks option
  - App lifecycle handling (pause/resume updates)

### 6. Stock Form (`widgets/stock_form.dart`)
- **Input Fields:**
  - Stock Symbol (uppercase, letters only)
  - Quantity (integers only)
  - Buy Price (decimal numbers)
- **Validation:**
  - Required field checks
  - Format validation
  - Symbol verification via API
  - Duplicate prevention
- **UX Features:**
  - Expandable/collapsible
  - Loading state
  - Success/error messages
  - Auto-clear on success

### 7. Stock List Item (`widgets/stock_list_item.dart`)
- **Display:**
  - Symbol & company name
  - Buy price & current price
  - Quantity & total values
  - P/L amount & percentage
  - Color-coded profit/loss (green/red)
- **Interactions:**
  - Tap to view detailed info
  - Swipe-to-delete with confirmation
  - Dismissible with background indicator

## 🔄 Periodic Updates

### Foreground Updates (Active)
- **When:** App is in foreground
- **How:** Timer in `StockUpdateService`
- **Interval:** 5 seconds
- **Trigger:** Automatic via `StockProvider.startPeriodicUpdates()`

### Background Updates (Planned)
- **Service:** FlutterForegroundTask
- **Handler:** `StockUpdateTaskHandler` in `main.dart`
- **Status:** Configured but not fully implemented
- **TODO:** Complete background update logic

## 📱 Running the App

### Debug Mode
```bash
cd stock_profit_tracker
flutter run
```

### Release Mode
```bash
flutter run --release
```

### Build APK
```bash
flutter build apk --release
```

### Install on Device
```bash
flutter install
```

## 🧪 Testing the App

### Adding Stocks
1. Tap "Add Stock" to expand form
2. Enter symbol (e.g., AAPL, GOOGL, MSFT)
3. Enter quantity (e.g., 10)
4. Enter buy price (e.g., 180.50)
5. Tap "Add Stock" button
6. Stock appears in list with auto-calculated P/L

### Mock Stock Symbols Available
- **AAPL** - Apple Inc. (~₹180)
- **GOOGL** - Alphabet Inc. (~₹140)
- **MSFT** - Microsoft Corporation (~₹380)
- **AMZN** - Amazon.com Inc. (~₹170)
- **TSLA** - Tesla Inc. (~₹250)
- **META** - Meta Platforms Inc. (~₹480)
- **NVDA** - NVIDIA Corporation (~₹880)

### Observing Updates
- Watch the "Live" indicator in app bar
- Prices update every 5 seconds with small fluctuations
- P/L values recalculate automatically

### Pull-to-Refresh
- Drag down on stock list to force immediate update

## 🏗️ Architecture & Design Patterns

### Design Patterns Used
1. **Provider Pattern** - State management
2. **Repository Pattern** - Data access (StockUpdateService)
3. **Service Layer** - Business logic separation
4. **Model-View-ViewModel** - Clean architecture
5. **Singleton** - API service instances

### Code Organization Principles
- **Separation of Concerns** - Models, services, UI separated
- **Single Responsibility** - Each class has one clear purpose
- **Dependency Injection** - Provider-based DI
- **Composition** - Widget composition over inheritance

### Error Handling
- Try-catch blocks in all async operations
- User-friendly error messages via SnackBar
- Fallback to cached data on API errors
- Debug logging for troubleshooting

## 🔮 Next Steps for Production

### 1. Replace Mock API
```dart
// In stock_api_service.dart
// Uncomment real API implementation
// Add API key from provider (Alpha Vantage, Yahoo Finance, etc.)
```

### 2. Implement Background Service
```dart
// In main.dart StockUpdateTaskHandler
// Complete onRepeatEvent implementation
// Add SharedPreferences updates
// Update home widget from background
```

### 3. Add Advanced Features
- [ ] Stock charts/graphs
- [ ] Price alerts/notifications
- [ ] Historical data tracking
- [ ] Multiple portfolios
- [ ] Export to CSV
- [ ] Dark mode support

### 4. Optimize Performance
- [ ] Implement pagination for large lists
- [ ] Add caching layer for API calls
- [ ] Debounce API requests
- [ ] Optimize widget rebuilds

### 5. Enhance UI/UX
- [ ] Add animations
- [ ] Implement skeleton loaders
- [ ] Add haptic feedback
- [ ] Improve accessibility

### 6. Testing
- [ ] Write unit tests for models
- [ ] Widget tests for UI components
- [ ] Integration tests for flows
- [ ] Test on multiple devices

## 📚 Key Technologies & Concepts

### Flutter Concepts Used
- StatefulWidget & StatelessWidget
- Provider for state management
- FutureBuilder alternatives (manual state)
- Custom widgets
- Form validation
- Dismissible widgets
- RefreshIndicator
- AppLifecycleState handling
- Platform channels (ready for use)

### Dart Features Used
- Null safety
- Async/await
- Futures & Streams (ready)
- Extension methods (can be added)
- Getters & computed properties
- Factory constructors
- Named parameters

### Android Integration
- AndroidManifest configuration
- Gradle configuration (Kotlin DSL)
- XML layouts for widgets
- Resource management
- Permissions handling
- Foreground services

## 💡 Important Notes

### Mock Data
The app currently uses **mock stock prices** with random fluctuations. This is intentional for testing without API costs. Replace the mock implementation when ready for production.

### Update Frequency
5-second updates are aggressive and will:
- Drain battery in background
- Consume API quota quickly
- Increase network usage

Consider:
- 30-60 second intervals for production
- User-configurable update frequency
- Pause updates when battery is low

### Platform Channel
The foreground task is configured but the actual background update logic needs completion. The current implementation handles updates in the foreground via the Provider.

### API Costs
Most stock APIs have rate limits and costs:
- **Alpha Vantage:** Free tier - 5 requests/min, 500 requests/day
- **Yahoo Finance:** 500 requests/month free
- **IEX Cloud:** Varies by plan

Choose based on your update frequency and user base.

## 🎨 Customization Guide

### Changing Theme Colors
Edit `main.dart` ThemeData:
```dart
primarySwatch: Colors.blue,  // Change to Colors.green, etc.
```

### Adjusting Update Interval
Edit `services/stock_update_service.dart`:
```dart
static const Duration updateInterval = Duration(seconds: 30);
```

### Modifying Widget Layout
Edit Android widget files:
- `res/layout/home_widget_layout.xml` - UI layout
- `res/xml/home_widget_info.xml` - Widget configuration

## 🐛 Troubleshooting

### "Failed to update packages" during flutter create
- Try with `--offline` flag
- Check internet connection
- Update Flutter: `flutter upgrade`

### Dependencies not resolving
```bash
flutter pub cache repair
flutter pub get
```

### Android build errors
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Hot reload not working
- Use hot restart instead: `Ctrl+Shift+F5` or `R` in terminal
- For major changes, stop and restart app

## 📞 Support & Resources

### Official Documentation
- [Flutter Docs](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [Home Widget Plugin](https://pub.dev/packages/home_widget)

### Stock Market APIs
- [Alpha Vantage](https://www.alphavantage.co/)
- [IEX Cloud](https://iexcloud.io/)
- [Yahoo Finance API](https://finnhub.io/)

---

**Created:** February 2026  
**Flutter Version:** 3.35.7  
**Dart Version:** 3.9.2  
**Platform:** Android  
**License:** MIT (adjust as needed)
