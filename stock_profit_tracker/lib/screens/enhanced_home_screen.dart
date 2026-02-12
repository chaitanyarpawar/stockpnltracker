import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/stock_provider.dart';
import '../widgets/enhanced_stock_form.dart';
import '../widgets/stock_list_item.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

/// Enhanced Main Home Screen with Material 3 Design
///
/// Features:
/// - Modern Material 3 UI with Google Fonts
/// - Real-time portfolio dashboard
/// - Foreground service controls
/// - Yahoo Finance API integration
/// - Pull-to-refresh with enhanced feedback
/// - Notification and widget status indicators
/// - Advanced portfolio analytics
/// - Beautiful profit/loss visualizations
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

  // Track service status
  bool _showServiceControls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize provider and services
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<StockProvider>();
      await provider.initialize();
      provider.startPeriodicUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<StockProvider>();

    if (state == AppLifecycleState.resumed) {
      // App came to foreground - start updates
      provider.startPeriodicUpdates();
    } else if (state == AppLifecycleState.paused) {
      // App went to background - keep background service running
      // Updates continue via foreground service
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: _buildAppBar(context),
      body: Consumer<StockProvider>(
        builder: (context, provider, child) {
          // Show beautiful loading screen on initial load
          if (provider.isLoading && !provider.hasStocks) {
            return _buildLoadingScreen();
          }

          // Handle errors with enhanced feedback
          if (provider.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showErrorSnackBar(context, provider.errorMessage!);
            });
          }

          return RefreshIndicator.adaptive(
            onRefresh: () => provider.forceRefresh(),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Service Controls Panel (when enabled)
                if (_showServiceControls)
                  SliverToBoxAdapter(child: _buildServiceControls(provider)),

                // Enhanced Portfolio Dashboard
                if (provider.hasStocks)
                  SliverToBoxAdapter(child: _buildPortfolioDashboard(provider)),

                // Add Stock Section with Material 3 Design
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: StockForm(),
                  ),
                ),

                // Portfolio Analytics (when stocks exist)
                if (provider.hasStocks)
                  SliverToBoxAdapter(child: _buildPortfolioAnalytics(provider)),

                // Stock List with Enhanced Design
                if (provider.hasStocks)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.show_chart,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Stocks (${provider.stocks.length})',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Enhanced Stock List
                if (provider.hasStocks)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final stock = provider.stocks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: StockListItem(stock: stock),
                        );
                      }, childCount: provider.stocks.length),
                    ),
                  ),

                // Beautiful Empty State
                if (!provider.hasStocks)
                  SliverFillRemaining(child: _buildEmptyState()),

                // Bottom spacing
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build enhanced app bar with service indicators
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.trending_up,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stock Tracker',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Consumer<StockProvider>(
                builder: (context, provider, _) {
                  return Text(
                    provider.isUpdatingPeriodically
                        ? 'Live Updates'
                        : 'Manual Mode',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: provider.isUpdatingPeriodically
                          ? AppTheme.profitGreen
                          : AppTheme.neutralGray,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Live update indicator
        Consumer<StockProvider>(
          builder: (context, provider, _) {
            return Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: provider.isUpdatingPeriodically
                    ? AppTheme.profitGreen.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: provider.isUpdatingPeriodically
                      ? AppTheme.profitGreen
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: provider.isUpdatingPeriodically
                          ? AppTheme.profitGreen
                          : AppTheme.neutralGray,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.isUpdatingPeriodically ? 'LIVE' : 'MANUAL',
                    style: context.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: provider.isUpdatingPeriodically
                          ? AppTheme.profitGreen
                          : AppTheme.neutralGray,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Refresh button
        Consumer<StockProvider>(
          builder: (context, provider, _) {
            return IconButton(
              icon: provider.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryBlue,
                      ),
                    )
                  : Icon(Icons.refresh, color: AppTheme.primaryBlue),
              tooltip: 'Refresh Prices',
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      await provider.forceRefresh();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Prices refreshed'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
            );
          },
        ),

        // Service controls toggle
        IconButton(
          icon: Icon(_showServiceControls ? Icons.settings : Icons.tune),
          tooltip: 'Service Controls',
          onPressed: () {
            setState(() {
              _showServiceControls = !_showServiceControls;
            });
          },
        ),

        // Settings button
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),

        // Clear all button
        Consumer<StockProvider>(
          builder: (context, provider, _) {
            if (provider.hasStocks) {
              return IconButton(
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  color: AppTheme.lossRed,
                ),
                tooltip: 'Clear all stocks',
                onPressed: () => _showClearConfirmation(context),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  /// Build service controls panel
  Widget _buildServiceControls(StockProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Service Controls',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: provider.isUpdatingPeriodically
                    ? () => provider.stopPeriodicUpdates()
                    : () => provider.startPeriodicUpdates(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.isUpdatingPeriodically
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(provider.isUpdatingPeriodically ? 'Pause' : 'Resume'),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: provider.isForegroundServiceActive
                    ? () => provider.stopForegroundService()
                    : () => provider.startForegroundService(),
                style: FilledButton.styleFrom(
                  backgroundColor: provider.isForegroundServiceActive
                      ? AppTheme.lossRed.withValues(alpha: 0.1)
                      : AppTheme.profitGreen.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.isForegroundServiceActive
                          ? Icons.stop
                          : Icons.play_circle,
                      size: 16,
                      color: provider.isForegroundServiceActive
                          ? AppTheme.lossRed
                          : AppTheme.profitGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.isForegroundServiceActive
                          ? 'Stop BG'
                          : 'Start BG',
                      style: TextStyle(
                        color: provider.isForegroundServiceActive
                            ? AppTheme.lossRed
                            : AppTheme.profitGreen,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => provider.forceRefresh(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build enhanced portfolio dashboard
  Widget _buildPortfolioDashboard(StockProvider provider) {
    final isProfit = provider.isOverallProfit;
    final profitColor = AppTheme.getProfitLossColor(provider.totalProfitLoss);

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: isProfit ? AppTheme.profitGradient : AppTheme.lossGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: profitColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: profitColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isProfit ? Icons.trending_up : Icons.trending_down,
                    color: profitColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portfolio Value',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(provider.totalCurrentValue),
                        style: context.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildDashboardStat(
                    'Invested',
                    _currencyFormat.format(provider.totalInvestment),
                    AppTheme.neutralGray,
                    Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDashboardStat(
                    'P&L',
                    AppTheme.formatProfitLoss(provider.totalProfitLoss),
                    profitColor,
                    isProfit ? Icons.trending_up : Icons.trending_down,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDashboardStat(
                    'Return',
                    AppTheme.formatPercentage(
                      provider.totalProfitLossPercentage,
                    ),
                    profitColor,
                    Icons.percent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build dashboard stat item
  Widget _buildDashboardStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build portfolio analytics section
  Widget _buildPortfolioAnalytics(StockProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Portfolio Insights',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInsightItem(
                  'Best Stock',
                  provider.bestPerformingStock?.symbol ?? 'N/A',
                  AppTheme.profitGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInsightItem(
                  'Worst Stock',
                  provider.worstPerformingStock?.symbol ?? 'N/A',
                  AppTheme.lossRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build insight item
  Widget _buildInsightItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build loading screen
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),
          const SizedBox(height: 24),
          Text(
            'Initializing Stock Tracker...',
            style: context.textTheme.bodyLarge?.copyWith(
              color: AppTheme.neutralGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up real-time updates',
            style: context.textTheme.bodySmall?.copyWith(
              color: AppTheme.neutralGray,
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_up,
                  size: 48,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Start Your Investment Journey',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first stock to start tracking\nreal-time profits and losses',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.neutralGray,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  // Scroll to add stock form
                  Scrollable.ensureVisible(
                    context,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                icon: const Icon(Icons.add_circle),
                label: const Text('Add Your First Stock'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show error snack bar with enhanced styling
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.lossRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show confirmation dialog with Material 3 styling
  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber, color: AppTheme.lossRed),
        title: const Text('Clear All Portfolio Data'),
        content: const Text(
          'This will remove all stocks from your portfolio, clear the home widget, '
          'and reset all cached data. This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<StockProvider>().clearAllStocks();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Portfolio cleared - widget reset'),
                    ],
                  ),
                  backgroundColor: AppTheme.profitGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.lossRed),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
  }
}
