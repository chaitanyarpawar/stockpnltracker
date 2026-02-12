import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Settings screen for Stock Tracker app
///
/// Features:
/// - Enable/disable P&L notification in status bar
/// - Widget size preferences
/// - Update frequency settings
/// - Data management options
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showNotificationBar = true;
  bool _persistentNotification = false;
  bool _soundEnabled = false;
  String _updateFrequency = '5'; // seconds
  String _widgetSize = '4x2'; // Default widget size

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Load settings from shared preferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showNotificationBar = prefs.getBool('notification_bar_enabled') ?? true;
      _persistentNotification =
          prefs.getBool('persistent_notification') ?? false;
      _soundEnabled = prefs.getBool('notification_sound') ?? false;
      _updateFrequency = prefs.getString('update_frequency') ?? '5';
      _widgetSize = prefs.getString('widget_size') ?? '4x2';
    });
  }

  /// Save settings to shared preferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('notification_bar_enabled', _showNotificationBar),
      prefs.setBool('persistent_notification', _persistentNotification),
      prefs.setBool('notification_sound', _soundEnabled),
      prefs.setString('update_frequency', _updateFrequency),
      prefs.setString('widget_size', _widgetSize),
    ]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Settings saved successfully'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notification Settings
          _buildSectionHeader('Notification Settings'),
          _buildSettingsCard([
            SwitchListTile(
              title: const Text('Show P&L in Notification Bar'),
              subtitle: const Text(
                'Display real-time profit/loss in status bar',
              ),
              value: _showNotificationBar,
              onChanged: (value) {
                setState(() => _showNotificationBar = value);
                _saveSettings();
              },
              activeThumbColor: AppTheme.profitGreen,
            ),
            if (_showNotificationBar) ...[
              SwitchListTile(
                title: const Text('Keep Notification Persistent'),
                subtitle: const Text(
                  'Notification stays visible and cannot be dismissed',
                ),
                value: _persistentNotification,
                onChanged: (value) {
                  setState(() => _persistentNotification = value);
                  _saveSettings();
                },
                activeThumbColor: AppTheme.profitGreen,
              ),
              SwitchListTile(
                title: const Text('Notification Sound'),
                subtitle: const Text('Play sound for significant P&L changes'),
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() => _soundEnabled = value);
                  _saveSettings();
                },
                activeThumbColor: AppTheme.profitGreen,
              ),
            ],
          ]),

          const SizedBox(height: 24),

          // Widget Settings
          _buildSectionHeader('Widget Settings'),
          _buildSettingsCard([
            ListTile(
              title: const Text('Preferred Widget Size'),
              subtitle: Text('Current: $_widgetSize'),
              trailing: DropdownButton<String>(
                value: _widgetSize,
                items: const [
                  DropdownMenuItem(value: '3x2', child: Text('Compact (3x2)')),
                  DropdownMenuItem(value: '4x2', child: Text('Standard (4x2)')),
                  DropdownMenuItem(value: '4x3', child: Text('Large (4x3)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _widgetSize = value);
                    _saveSettings();
                  }
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Update Settings
          _buildSectionHeader('Update Settings'),
          _buildSettingsCard([
            ListTile(
              title: const Text('Update Frequency'),
              subtitle: Text('Every $_updateFrequency seconds'),
              trailing: DropdownButton<String>(
                value: _updateFrequency,
                items: const [
                  DropdownMenuItem(value: '5', child: Text('5 sec')),
                  DropdownMenuItem(value: '10', child: Text('10 sec')),
                  DropdownMenuItem(value: '30', child: Text('30 sec')),
                  DropdownMenuItem(value: '60', child: Text('1 min')),
                  DropdownMenuItem(value: '300', child: Text('5 min')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _updateFrequency = value);
                    _saveSettings();
                  }
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          _buildSettingsCard([
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Version'),
              subtitle: const Text('1.0.0'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAboutDialog(),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showHelpDialog(),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.primaryBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children
            .map(
              (child) => child is ListTile || child is SwitchListTile
                  ? child
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: child,
                    ),
            )
            .toList(),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stock Profit Tracker'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text(
              'Track your stock portfolio profit/loss in real-time with live price updates, home screen widget, and notifications.',
            ),
            SizedBox(height: 16),
            Text('Features:'),
            Text('• Real-time price updates'),
            Text('• Home screen widget'),
            Text('• P&L notifications'),
            Text('• Portfolio analytics'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Tips'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Widget Setup:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Long press on home screen → Widgets → Stock Tracker'),
            Text('• Choose between Compact (3x2) or Standard (4x2) sizes'),
            SizedBox(height: 12),
            Text(
              'Stock Symbols:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Indian stocks: Use .NS suffix (e.g., TCS.NS, RELIANCE.NS)'),
            Text('• US stocks: Use ticker only (e.g., AAPL, GOOGL)'),
            SizedBox(height: 12),
            Text(
              'Notifications:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Enable to see P&L in status bar'),
            Text('• Persistent notifications cannot be dismissed'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
