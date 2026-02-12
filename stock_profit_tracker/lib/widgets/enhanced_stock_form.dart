import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../providers/stock_provider.dart';
import '../services/stock_api_service.dart';
import '../theme/app_theme.dart';

/// Enhanced Material 3 Form Widget for Adding New Stocks
///
/// Features:
/// - Beautiful Material 3 design with Google Fonts
/// - Real-time symbol validation with Yahoo Finance API
/// - Smart symbol suggestions (Indian & US stocks)
/// - Live price preview before adding
/// - Improved user experience with better feedback
/// - Auto-complete for popular symbols
/// - Enhanced error handling and validation
class StockForm extends StatefulWidget {
  const StockForm({super.key});

  @override
  State<StockForm> createState() => _StockFormState();
}

class _StockFormState extends State<StockForm> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();

  final StockApiService _apiService = StockApiService();

  bool _isExpanded = true;
  bool _isSubmitting = false;
  bool _isValidatingSymbol = false;
  double? _currentPrice;
  String? _companyName;
  String? _resolvedSymbol;
  String? _symbolError;

  // Animation controllers
  late AnimationController _expandController;
  late AnimationController _shimmerController;
  late Animation<double> _expandAnimation;

  // Popular stock symbols for suggestions
  final List<Map<String, String>> _popularStocks = [
    {'symbol': 'TCS', 'name': 'Tata Consultancy Services'},
    {'symbol': 'INFY', 'name': 'Infosys Limited'},
    {'symbol': 'RELIANCE', 'name': 'Reliance Industries'},
    {'symbol': 'HDFCBANK', 'name': 'HDFC Bank'},
    {'symbol': 'AAPL', 'name': 'Apple Inc.'},
    {'symbol': 'GOOGL', 'name': 'Alphabet Inc.'},
    {'symbol': 'MSFT', 'name': 'Microsoft Corporation'},
    {'symbol': 'TSLA', 'name': 'Tesla Inc.'},
  ];

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    _expandController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.02),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Static Header (no expansion)
              _buildStaticHeader(),

              // Form Content (always visible)
              _buildFormContent(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build static form header (no expansion)
  Widget _buildStaticHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          // Static Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_chart, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),

          // Title and Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Stock',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Enter stock details to track P/L',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutralGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build enhanced form header (legacy - kept for compatibility)
  Widget _buildFormHeader() {
    return _buildStaticHeader();
  }

  /// Build enhanced form content
  Widget _buildFormContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Enhanced Stock Symbol Field with suggestions
            _buildSymbolField(),
            const SizedBox(height: 20),

            // Price Preview Card (when symbol is valid)
            if (_currentPrice != null && _companyName != null)
              _buildPricePreviewCard(),

            if (_currentPrice != null && _companyName != null)
              const SizedBox(height: 20),

            // Quantity and Buy Price Row
            Row(
              children: [
                Expanded(child: _buildQuantityField()),
                const SizedBox(width: 16),
                Expanded(child: _buildBuyPriceField()),
              ],
            ),

            const SizedBox(height: 24),

            // Enhanced Submit Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  /// Build enhanced symbol field with autocomplete
  Widget _buildSymbolField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _symbolController,
          decoration: InputDecoration(
            labelText: 'Stock Name or Symbol',
            hintText: 'e.g., ITC, ITC Limited, AAPL',
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.search, color: AppTheme.primaryBlue, size: 20),
            ),
            suffixIcon: _isValidatingSymbol
                ? Container(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  )
                : _currentPrice != null
                ? Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.check_circle,
                      color: AppTheme.profitGreen,
                      size: 20,
                    ),
                  )
                : null,
            errorText: _symbolError,
            helperText: 'Type company name or ticker. .NS is auto-handled.',
            helperStyle: context.textTheme.bodySmall?.copyWith(
              color: AppTheme.neutralGray,
            ),
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9 .&'-]")),
            LengthLimitingTextInputFormatter(40),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a stock symbol';
            }
            if (_symbolError != null) {
              return _symbolError;
            }
            return null;
          },
          onChanged: _onSymbolChanged,
        ),
      ],
    );
  }

  /// Build stock suggestions chips
  Widget _buildStockSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Stocks:',
          style: context.textTheme.bodySmall?.copyWith(
            color: AppTheme.neutralGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _popularStocks.take(6).map((stock) {
            return ActionChip(
              label: Text(
                stock['name']!,
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              side: BorderSide(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              ),
              onPressed: () {
                _symbolController.text = stock['name']!;
                _onSymbolChanged(stock['name']!);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Build price preview card
  Widget _buildPricePreviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.profitGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.profitGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: AppTheme.profitGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _companyName ?? 'Company Name',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.profitGreen,
                  ),
                ),
              ),
              if (_resolvedSymbol != null)
                Text(
                  _resolvedSymbol!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutralGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Current Price: ',
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppTheme.neutralGray,
                ),
              ),
              Text(
                '₹${_currentPrice!.toStringAsFixed(2)}',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.profitGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build quantity field
  Widget _buildQuantityField() {
    return TextFormField(
      controller: _quantityController,
      decoration: const InputDecoration(
        labelText: 'Quantity',
        hintText: 'Shares',
        prefixIcon: Icon(Icons.confirmation_number_outlined),
        helperText: 'Number of shares',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        final quantity = int.tryParse(value);
        if (quantity == null || quantity <= 0) {
          return 'Must be > 0';
        }
        return null;
      },
    );
  }

  /// Build buy price field
  Widget _buildBuyPriceField() {
    return TextFormField(
      controller: _buyPriceController,
      decoration: const InputDecoration(
        labelText: 'Buy Price',
        hintText: '₹0.00',
        prefixIcon: Icon(Icons.currency_rupee),
        helperText: 'Price per share',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        final price = double.tryParse(value);
        if (price == null || price <= 0) {
          return 'Must be > 0';
        }
        return null;
      },
    );
  }

  /// Build enhanced submit button
  Widget _buildSubmitButton() {
    final canSubmit =
        _currentPrice != null &&
        _companyName != null &&
        _symbolError == null &&
        !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: canSubmit ? _handleSubmit : null,
        style: FilledButton.styleFrom(
          backgroundColor: canSubmit
              ? AppTheme.primaryBlue
              : AppTheme.neutralGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Adding Stock...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add to Portfolio',
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Toggle form expansion
  void _toggleForm() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  /// Handle symbol change with debouncing
  void _onSymbolChanged(String value) {
    setState(() {
      _symbolError = null;
      _currentPrice = null;
      _companyName = null;
      _resolvedSymbol = null;
    });

    if (value.trim().length >= 2) {
      // Debounce symbol validation
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_symbolController.text.trim().toUpperCase() ==
            value.trim().toUpperCase()) {
          _validateSymbol(value.trim());
        }
      });
    }
  }

  /// Validate symbol and fetch price
  Future<void> _validateSymbol(String query) async {
    setState(() {
      _isValidatingSymbol = true;
      _symbolError = null;
    });

    try {
      final resolved = await _apiService.resolveStock(query);

      if (!mounted) return;

      if (resolved != null && resolved.price > 0) {
        if (mounted) {
          setState(() {
            _currentPrice = resolved.price;
            _companyName = resolved.name;
            _resolvedSymbol = resolved.symbol;
            _symbolError = null;
          });
        }
      } else {
        setState(() {
          _symbolError = 'Invalid or unavailable symbol';
          _currentPrice = null;
          _companyName = null;
          _resolvedSymbol = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _symbolError = 'Error validating symbol';
          _currentPrice = null;
          _companyName = null;
          _resolvedSymbol = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingSymbol = false;
        });
      }
    }
  }

  /// Handle form submission
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentPrice == null ||
        _companyName == null ||
        _resolvedSymbol == null) {
      _showError('Please wait for symbol validation to complete');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final symbol = _resolvedSymbol!;
      final quantity = int.parse(_quantityController.text.trim());
      final buyPrice = double.parse(_buyPriceController.text.trim());

      // Create stock object
      final stock = Stock(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: symbol,
        name: _companyName!,
        buyPrice: buyPrice,
        quantity: quantity,
        currentPrice: _currentPrice!,
        purchaseDate: DateTime.now(),
      );

      if (!mounted) return;

      // Add to provider
      final provider = context.read<StockProvider>();
      final success = await provider.addStock(stock);

      if (!mounted) return;

      if (success) {
        // Clear form and reset state
        _symbolController.clear();
        _quantityController.clear();
        _buyPriceController.clear();
        _currentPrice = null;
        _companyName = null;
        _resolvedSymbol = null;
        _symbolError = null;

        // Form stays open for adding more stocks

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('$symbol added to portfolio successfully!'),
              ],
            ),
            backgroundColor: AppTheme.profitGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to add stock: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Show enhanced error message
  void _showError(String message) {
    if (!mounted) return;

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
}
