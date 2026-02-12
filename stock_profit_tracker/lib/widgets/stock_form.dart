import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../providers/stock_provider.dart';
import '../services/stock_api_service.dart';

/// Form widget for adding new stocks to the portfolio
///
/// Fields:
/// - Stock Symbol (e.g., AAPL, GOOGL)
/// - Quantity (number of shares)
/// - Buy Price (price per share at purchase)
///
/// Features:
/// - Input validation
/// - Symbol validation
/// - Auto-fetches current price
/// - Calculates expected P&L
class StockForm extends StatefulWidget {
  const StockForm({super.key});

  @override
  State<StockForm> createState() => _StockFormState();
}

class _StockFormState extends State<StockForm> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();

  final StockApiService _apiService = StockApiService();

  bool _isExpanded = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isExpanded ? 'Add New Stock' : 'Add Stock',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),

            // Form (shown when expanded)
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Stock Name or Symbol Field
                    TextFormField(
                      controller: _symbolController,
                      decoration: InputDecoration(
                        labelText: 'Stock Name or Symbol',
                        hintText: 'e.g., ITC, ITC Limited, AAPL',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'Type company name or ticker',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r"[A-Za-z0-9 .&'-]"),
                        ),
                        LengthLimitingTextInputFormatter(40),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a stock symbol';
                        }
                        if (value.trim().isEmpty) {
                          return 'Symbol cannot be empty';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Quantity Field
                    TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'Number of shares',
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'Enter number of shares',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter quantity';
                        }
                        final quantity = int.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Quantity must be greater than 0';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Buy Price Field
                    TextFormField(
                      controller: _buyPriceController,
                      decoration: InputDecoration(
                        labelText: 'Buy Price',
                        hintText: 'Price per share',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'Enter purchase price per share',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter buy price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Price must be greater than 0';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Add Stock',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Handle form submission
  Future<void> _handleSubmit() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final rawInput = _symbolController.text.trim();
      final quantity = int.parse(_quantityController.text.trim());
      final buyPrice = double.parse(_buyPriceController.text.trim());

      final resolved = await _apiService.resolveStock(rawInput);
      if (resolved == null || resolved.price <= 0) {
        _showError('Invalid stock input: $rawInput');
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final symbol = resolved.symbol;
      final currentPrice = resolved.price;
      final stockName = resolved.name;

      // Create stock object
      final stock = Stock(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: symbol,
        name: stockName,
        buyPrice: buyPrice,
        quantity: quantity,
        currentPrice: currentPrice,
        purchaseDate: DateTime.now(),
      );

      // Add to provider - check if widget is still mounted
      if (!mounted) return;

      final provider = context.read<StockProvider>();
      final success = await provider.addStock(stock);

      if (!mounted) return; // Check again after async operation

      if (success) {
        // Clear form
        _symbolController.clear();
        _quantityController.clear();
        _buyPriceController.clear();

        // Collapse form
        setState(() {
          _isExpanded = false;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added $symbol to portfolio'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  /// Show error message
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
