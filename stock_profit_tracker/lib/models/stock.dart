/// Stock model class representing a single stock holding
/// 
/// This model stores:
/// - Basic stock info (symbol, name)
/// - Purchase details (buy price, quantity)
/// - Current market price (CMP)
/// - Calculated profit/loss values
class Stock {
  final String id;
  final String symbol; // Stock ticker symbol (e.g., "AAPL", "GOOGL")
  final String name; // Company name
  final double buyPrice; // Price at which stock was purchased
  final int quantity; // Number of shares
  final double currentPrice; // Current Market Price (CMP)
  final DateTime purchaseDate; // Date of purchase

  Stock({
    required this.id,
    required this.symbol,
    required this.name,
    required this.buyPrice,
    required this.quantity,
    required this.currentPrice,
    required this.purchaseDate,
  });

  /// Calculate total investment amount
  double get totalInvestment => buyPrice * quantity;

  /// Calculate current market value
  double get currentValue => currentPrice * quantity;

  /// Calculate profit or loss amount
  double get profitLoss => currentValue - totalInvestment;

  /// Calculate profit or loss percentage
  double get profitLossPercentage {
    if (totalInvestment == 0) return 0;
    return (profitLoss / totalInvestment) * 100;
  }

  /// Check if stock is in profit
  bool get isProfit => profitLoss >= 0;

  /// Convert Stock object to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'buyPrice': buyPrice,
      'quantity': quantity,
      'currentPrice': currentPrice,
      'purchaseDate': purchaseDate.toIso8601String(),
    };
  }

  /// Create Stock object from JSON
  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      buyPrice: (json['buyPrice'] as num).toDouble(),
      quantity: json['quantity'] as int,
      currentPrice: (json['currentPrice'] as num).toDouble(),
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
    );
  }

  /// Create a copy of Stock with updated values
  Stock copyWith({
    String? id,
    String? symbol,
    String? name,
    double? buyPrice,
    int? quantity,
    double? currentPrice,
    DateTime? purchaseDate,
  }) {
    return Stock(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      buyPrice: buyPrice ?? this.buyPrice,
      quantity: quantity ?? this.quantity,
      currentPrice: currentPrice ?? this.currentPrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
    );
  }

  @override
  String toString() {
    return 'Stock(symbol: $symbol, name: $name, P&L: ${profitLoss.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Stock && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
