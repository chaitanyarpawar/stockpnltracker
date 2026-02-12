import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_form.dart';
import '../widgets/stock_list_item.dart';

/// Main home screen of the Stock Profit Tracker app
///
/// Features:
/// - Portfolio summary card showing total P&L
/// - Add stock button/form
/// - List of all stocks with individual P&L
/// - Pull-to-refresh functionality
/// - Periodic auto-updates indicator
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  );
  final NumberFormat _percentFormat = NumberFormat.decimalPattern()
    ..maximumFractionDigits = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize provider and start updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StockProvider>();
      provider.initialize();
      provider.startPeriodicUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop updates when screen is disposed
    context.read<StockProvider>().stopPeriodicUpdates();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    final provider = context.read<StockProvider>();

    if (state == AppLifecycleState.resumed) {
      // App came to foreground - start updates
      provider.startPeriodicUpdates();
    } else if (state == AppLifecycleState.paused) {
      // App went to background - stop updates to save battery
      provider.stopPeriodicUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Profit Tracker'),
        elevation: 2,
        actions: [
          // Update indicator
          Consumer<StockProvider>(
            builder: (context, provider, child) {
              if (provider.isUpdatingPeriodically) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Live', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Clear all button
          Consumer<StockProvider>(
            builder: (context, provider, child) {
              if (provider.hasStocks) {
                return IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Clear all stocks',
                  onPressed: () => _showClearConfirmation(context),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, child) {
          // Show loading indicator on initial load
          if (provider.isLoading && !provider.hasStocks) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show error message if any
          if (provider.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            });
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshStockPrices(),
            child: CustomScrollView(
              slivers: [
                // Portfolio Summary Card
                if (provider.hasStocks)
                  SliverToBoxAdapter(child: _buildPortfolioSummary(provider)),

                // Add Stock Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: StockForm(),
                  ),
                ),

                // Stock List Header
                if (provider.hasStocks)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Your Stocks (${provider.stocks.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                // Stock List
                if (provider.hasStocks)
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final stock = provider.stocks[index];
                      return StockListItem(stock: stock);
                    }, childCount: provider.stocks.length),
                  ),

                // Empty state
                if (!provider.hasStocks)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 72,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No stocks added yet',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first stock above to start tracking',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build portfolio summary card
  Widget _buildPortfolioSummary(StockProvider provider) {
    final isProfit = provider.isOverallProfit;
    final profitColor = isProfit ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Portfolio Value',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(provider.totalCurrentValue),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[400]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'Investment',
                _currencyFormat.format(provider.totalInvestment),
                Colors.grey[700]!,
              ),
              _buildSummaryItem(
                'P&L',
                '${isProfit ? '+' : ''}${_currencyFormat.format(provider.totalProfitLoss)}',
                profitColor,
              ),
              _buildSummaryItem(
                'Return',
                '${isProfit ? '+' : ''}${_percentFormat.format(provider.totalProfitLossPercentage)}%',
                profitColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual summary item
  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Show confirmation dialog before clearing all stocks
  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Stocks'),
        content: const Text(
          'Are you sure you want to remove all stocks from your portfolio? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<StockProvider>().clearAllStocks();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All stocks cleared')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
