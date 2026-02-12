import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Background callback for widget refresh button
/// This runs in a separate isolate when user taps refresh on widget
/// 
/// IMPORTANT: This must be a TOP-LEVEL function (not inside a class)
/// and must be annotated with @pragma('vm:entry-point')
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  debugPrint('🔄 Widget background callback triggered: $uri');
  
  if (uri == null) return;
  
  // Check if this is a refresh action
  if (uri.host == 'refresh' || uri.toString().contains('REFRESH')) {
    await _refreshWidgetData();
  }
}

/// Fetch fresh prices and update widget
Future<void> _refreshWidgetData() async {
  try {
    debugPrint('📡 Fetching fresh stock prices in background...');
    
    // Load stocks from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final stocksJson = prefs.getString('saved_stocks');
    
    if (stocksJson == null || stocksJson.isEmpty) {
      debugPrint('⚠️ No stocks saved to refresh');
      return;
    }
    
    final List<dynamic> stocksList = jsonDecode(stocksJson);
    if (stocksList.isEmpty) {
      debugPrint('⚠️ Empty stocks list');
      return;
    }
    
    debugPrint('📊 Found ${stocksList.length} stocks to refresh');
    
    // Fetch fresh prices for each stock
    final updatedStocks = <Map<String, dynamic>>[];
    for (final stockData in stocksList) {
      final symbol = stockData['symbol'] as String;
      try {
        final freshPrice = await _fetchPriceFromBackend(symbol);
        if (freshPrice != null && freshPrice > 0) {
          stockData['currentPrice'] = freshPrice;
          debugPrint('✅ $symbol: ₹$freshPrice');
        }
      } catch (e) {
        debugPrint('❌ Failed to fetch $symbol: $e');
      }
      updatedStocks.add(Map<String, dynamic>.from(stockData));
    }
    
    // Save updated stocks back to SharedPreferences
    await prefs.setString('saved_stocks', jsonEncode(updatedStocks));
    
    // Update widget data
    await _updateWidgetDisplay(updatedStocks);
    
    debugPrint('✅ Widget refresh complete');
  } catch (e) {
    debugPrint('❌ Background refresh failed: $e');
  }
}

/// Fetch price from backend API
Future<double?> _fetchPriceFromBackend(String symbol) async {
  // Use the same backend URL as the main app
  // For background work, we need to use the network IP, not localhost
  const backendUrl = 'http://192.168.1.13:8000';
  
  final url = Uri.parse('$backendUrl/ltp').replace(
    queryParameters: {'name': symbol},
  );
  
  try {
    final response = await http.get(url).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Timeout'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final price = data['price'];
      if (price is num) {
        return price.toDouble();
      }
    }
  } catch (e) {
    debugPrint('API call failed for $symbol: $e');
  }
  return null;
}

/// Update widget SharedPreferences with fresh data
Future<void> _updateWidgetDisplay(List<Map<String, dynamic>> stocks) async {
  // Sort by absolute P/L
  stocks.sort((a, b) {
    final aQuantity = (a['quantity'] as num?)?.toDouble() ?? 0;
    final aBuyPrice = (a['buyPrice'] as num?)?.toDouble() ?? 0;
    final aCurrentPrice = (a['currentPrice'] as num?)?.toDouble() ?? 0;
    final aPL = (aCurrentPrice - aBuyPrice) * aQuantity;
    
    final bQuantity = (b['quantity'] as num?)?.toDouble() ?? 0;
    final bBuyPrice = (b['buyPrice'] as num?)?.toDouble() ?? 0;
    final bCurrentPrice = (b['currentPrice'] as num?)?.toDouble() ?? 0;
    final bPL = (bCurrentPrice - bBuyPrice) * bQuantity;
    
    return bPL.abs().compareTo(aPL.abs());
  });
  
  // Take top 3 stocks
  final topStocks = stocks.take(3).toList();
  
  // Calculate totals
  double totalPL = 0;
  double totalInvested = 0;
  for (final stock in stocks) {
    final quantity = (stock['quantity'] as num?)?.toDouble() ?? 0;
    final buyPrice = (stock['buyPrice'] as num?)?.toDouble() ?? 0;
    final currentPrice = (stock['currentPrice'] as num?)?.toDouble() ?? 0;
    final pl = (currentPrice - buyPrice) * quantity;
    totalPL += pl;
    totalInvested += buyPrice * quantity;
  }
  
  final totalPercentage = totalInvested > 0 ? (totalPL / totalInvested) * 100 : 0.0;
  
  // Format values
  final plSign = totalPL >= 0 ? '+' : '';
  final totalPLFormatted = '$plSign₹${totalPL.toStringAsFixed(2)}';
  final totalPercentageFormatted = '$plSign${totalPercentage.toStringAsFixed(2)}%';
  
  // Update timestamp
  final now = DateTime.now();
  final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  
  // Save to HomeWidget
  await HomeWidget.saveWidgetData('widget_total_pl', totalPLFormatted);
  await HomeWidget.saveWidgetData('widget_total_percentage', totalPercentageFormatted);
  await HomeWidget.saveWidgetData('widget_stock_count', '${stocks.length} stocks');
  await HomeWidget.saveWidgetData('widget_update_time', timeString);
  await HomeWidget.saveWidgetData('widget_last_updated', 'Updated: $timeString');
  
  // Save individual stock data
  for (int i = 0; i < 3; i++) {
    if (i < topStocks.length) {
      final stock = topStocks[i];
      final symbol = stock['symbol'] as String? ?? '';
      final quantity = (stock['quantity'] as num?)?.toDouble() ?? 0;
      final buyPrice = (stock['buyPrice'] as num?)?.toDouble() ?? 0;
      final currentPrice = (stock['currentPrice'] as num?)?.toDouble() ?? 0;
      final pl = (currentPrice - buyPrice) * quantity;
      final sign = pl >= 0 ? '+' : '';
      
      // Get short name
      final shortName = _getShortName(symbol);
      
      await HomeWidget.saveWidgetData('widget_stock_${i}_symbol', symbol);
      await HomeWidget.saveWidgetData('widget_stock_${i}_name', shortName);
      await HomeWidget.saveWidgetData('widget_stock_${i}_ltp', '₹${currentPrice.toStringAsFixed(2)}');
      await HomeWidget.saveWidgetData('widget_stock_${i}_pl', '$sign₹${pl.toStringAsFixed(2)}');
    } else {
      // Clear unused rows
      await HomeWidget.saveWidgetData('widget_stock_${i}_symbol', '');
      await HomeWidget.saveWidgetData('widget_stock_${i}_name', '');
      await HomeWidget.saveWidgetData('widget_stock_${i}_ltp', '');
      await HomeWidget.saveWidgetData('widget_stock_${i}_pl', '');
    }
  }
  
  // Trigger widget update
  await HomeWidget.updateWidget(
    name: 'StockTrackerWidgetProvider',
    androidName: 'StockTrackerWidgetProvider',
  );
  await HomeWidget.updateWidget(
    name: 'StockTrackerCompactWidgetProvider',
    androidName: 'StockTrackerCompactWidgetProvider',
  );
}

/// Get short company name from symbol
String _getShortName(String symbol) {
  final cleanSymbol = symbol.replaceAll('.NS', '').replaceAll('.BO', '');
  
  const nameMap = {
    'TCS': 'TCS',
    'INFY': 'Infosys',
    'RELIANCE': 'Reliance',
    'HDFCBANK': 'HDFC Bank',
    'ICICIBANK': 'ICICI Bank',
    'ITC': 'ITC',
    'BHARTIARTL': 'Bharti Airtel',
    'KOTAKBANK': 'Kotak Bank',
    'LT': 'L&T',
    'SBIN': 'SBI',
    'WIPRO': 'Wipro',
    'MARUTI': 'Maruti',
    'HINDUNILVR': 'HUL',
    'ASIANPAINT': 'Asian Paint',
    'TITAN': 'Titan',
    'ASTRAL': 'Astral',
    'LAURUSLABS': 'Laurus Labs',
  };
  
  return nameMap[cleanSymbol] ?? cleanSymbol;
}
