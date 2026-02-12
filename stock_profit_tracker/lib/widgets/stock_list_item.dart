import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/stock.dart';
import '../providers/stock_provider.dart';

/// List item widget displaying individual stock information
///
/// Shows:
/// - Stock symbol and name
/// - Buy price and current price
/// - Quantity and total values
/// - Profit/Loss amount and percentage
/// - Swipe to delete functionality
class StockListItem extends StatelessWidget {
  final Stock stock;

  const StockListItem({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
    );
    final NumberFormat percentFormat = NumberFormat.decimalPattern()
      ..maximumFractionDigits = 2;

    final isProfit = stock.isProfit;
    final profitColor = isProfit ? Colors.green : Colors.red;

    return Dismissible(
      key: Key(stock.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) => _showDeleteConfirmation(context),
      onDismissed: (direction) {
        context.read<StockProvider>().removeStock(stock.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${stock.symbol} removed from portfolio'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Undo functionality: Re-add the deleted stock
                context.read<StockProvider>().addStock(stock);
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: profitColor.withValues(alpha: 0.3), width: 1),
        ),
        child: InkWell(
          onTap: () => _showStockDetails(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Symbol and P&L
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Stock Symbol and Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.symbol,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stock.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Profit/Loss
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isProfit ? '+' : ''}${currencyFormat.format(stock.profitLoss)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: profitColor,
                          ),
                        ),
                        Text(
                          '${isProfit ? '+' : ''}${percentFormat.format(stock.profitLossPercentage)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: profitColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Details Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        'Qty',
                        stock.quantity.toString(),
                        Icons.numbers,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        'Buy',
                        currencyFormat.format(stock.buyPrice),
                        Icons.shopping_cart,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        'CMP',
                        currencyFormat.format(stock.currentPrice),
                        Icons.show_chart,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Total Values
                Row(
                  children: [
                    Expanded(
                      child: _buildTotalItem(
                        'Invested',
                        currencyFormat.format(stock.totalInvestment),
                        Colors.grey[700]!,
                      ),
                    ),
                    Expanded(
                      child: _buildTotalItem(
                        'Current',
                        currencyFormat.format(stock.currentValue),
                        profitColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a detail item (Qty, Buy, CMP)
  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  /// Build a total value item
  Widget _buildTotalItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Show delete confirmation dialog
  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Stock'),
        content: Text(
          'Are you sure you want to remove ${stock.symbol} from your portfolio?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Show detailed stock information dialog
  void _showStockDetails(BuildContext context) {
    final DateFormat dateFormat = DateFormat('MMM dd, yyyy');
    final NumberFormat currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stock.symbol),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Company', stock.name),
              const Divider(),
              _buildInfoRow(
                'Purchase Date',
                dateFormat.format(stock.purchaseDate),
              ),
              _buildInfoRow('Quantity', '${stock.quantity} shares'),
              const Divider(),
              _buildInfoRow('Buy Price', currencyFormat.format(stock.buyPrice)),
              _buildInfoRow(
                'Current Price',
                currencyFormat.format(stock.currentPrice),
              ),
              const Divider(),
              _buildInfoRow(
                'Total Investment',
                currencyFormat.format(stock.totalInvestment),
              ),
              _buildInfoRow(
                'Current Value',
                currencyFormat.format(stock.currentValue),
              ),
              const Divider(),
              _buildInfoRow(
                'Profit/Loss',
                '${stock.isProfit ? '+' : ''}${currencyFormat.format(stock.profitLoss)}',
                stock.isProfit ? Colors.green : Colors.red,
              ),
              _buildInfoRow(
                'Return %',
                '${stock.isProfit ? '+' : ''}${stock.profitLossPercentage.toStringAsFixed(2)}%',
                stock.isProfit ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build an information row for the details dialog
  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
