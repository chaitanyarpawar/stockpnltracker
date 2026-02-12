// This is a basic Flutter widget test for the Stock Profit Tracker app.
//
// Note: Main app test is disabled due to home_widget package compatibility issues.
// Testing individual components instead.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_profit_tracker/models/stock.dart';
import 'package:stock_profit_tracker/providers/stock_provider.dart';

void main() {
  group('Stock Model Tests', () {
    test('Stock model calculates profit/loss correctly', () {
      final stock = Stock(
        id: '1',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        buyPrice: 100.0,
        quantity: 10,
        currentPrice: 110.0,
        purchaseDate: DateTime.now(),
      );

      expect(stock.totalInvestment, 1000.0);
      expect(stock.currentValue, 1100.0);
      expect(stock.profitLoss, 100.0);
      expect(stock.profitLossPercentage, 10.0);
      expect(stock.isProfit, true);
    });

    test('Stock model handles loss correctly', () {
      final stock = Stock(
        id: '1',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        buyPrice: 100.0,
        quantity: 10,
        currentPrice: 90.0,
        purchaseDate: DateTime.now(),
      );

      expect(stock.profitLoss, -100.0);
      expect(stock.profitLossPercentage, -10.0);
      expect(stock.isProfit, false);
    });
  });

  group('StockProvider Tests', () {
    test('StockProvider initializes correctly', () {
      final provider = StockProvider();

      expect(provider.stocks, isEmpty);
      expect(provider.totalInvestment, 0.0);
      expect(provider.totalCurrentValue, 0.0);
      expect(provider.totalProfitLoss, 0.0);
      expect(provider.hasStocks, false);
    });
  });
}
