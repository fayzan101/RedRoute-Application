import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/enhanced_location_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  
  const SettingsScreen({super.key, this.onBackPressed});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else {
              // Fallback: navigate back
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Dark Mode Section
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: Consumer<ThemeService>(
                    builder: (context, themeService, child) => Icon(
                      themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: themeService.isDarkMode ? Colors.amber : Colors.blue,
                    ),
                  ),
                  title: const Text('Dark Mode'),
                  subtitle: Consumer<ThemeService>(
                    builder: (context, themeService, child) => Text(
                      themeService.isDarkMode ? 'Enabled' : 'Disabled',
                    ),
                  ),
                  trailing: Consumer<ThemeService>(
                    builder: (context, themeService, child) => Switch(
                      value: themeService.isDarkMode,
                      onChanged: (value) {
                        themeService.toggleTheme();
                      },
                      activeColor: const Color(0xFFE53E3E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Location Services Section
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.green),
                  title: const Text('Location Services'),
                  subtitle: const Text('Manage location permissions'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showLocationSettings();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.blue),
                  title: const Text('Refresh Location'),
                  subtitle: const Text('Update your current location'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _refreshLocation();
                  },
                ),
              ],
            ),
          ),
          

          
          // About Section
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blue),
                  title: const Text('About'),
                  subtitle: const Text('App version and information'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showAboutDialog();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.green),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Get help and contact support'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showHelpSupport();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: Colors.purple),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('Read our privacy policy'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showPrivacyPolicy();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location permissions are required for:'),
            SizedBox(height: 8),
            Text('• Finding your current location'),
            Text('• Calculating nearest bus stops'),
            Text('• Providing accurate journey times'),
            SizedBox(height: 16),
            Text('Please enable location services in your device settings.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _refreshLocation() async {
    final locationService = context.read<EnhancedLocationService>();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing location...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    await locationService.initializeLocation();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locationService.error != null 
              ? 'Location refresh failed' 
              : 'Location updated successfully',
          ),
          backgroundColor: locationService.error != null ? Colors.red : Colors.green,
        ),
      );
    }
  }





  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'RedRoute',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.directions_bus, size: 48),
      children: const [
        Text('Karachi Bus Navigation App'),
        SizedBox(height: 8),
        Text('Find the best BRT routes in Karachi with real-time information and smart journey planning.'),
        SizedBox(height: 16),
        Text('Features:'),
        Text('• Real-time BRT route information'),
        Text('• Smart journey planning'),
        Text('• Multiple transport options'),
        Text('• Dark mode support'),
        SizedBox(height: 16),
        Text('© 2024 RedRoute. All rights reserved.'),
      ],
    );
  }

  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Here are your options:'),
            SizedBox(height: 16),
            Text('📧 Email: support@redroute.com'),
            Text('📱 Phone: +92-XXX-XXXXXXX'),
            Text('💬 Chat: Available in app'),
            SizedBox(height: 16),
            Text('Common Issues:'),
            Text('• Location not working'),
            Text('• Routes not loading'),
            Text('• App crashes'),
            SizedBox(height: 16),
            Text('We typically respond within 24 hours.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Privacy Matters'),
              SizedBox(height: 16),
              Text('We collect and use your data to:'),
              Text('• Provide location-based services'),
              Text('• Calculate optimal routes'),
              Text('• Improve app performance'),
              SizedBox(height: 16),
              Text('We do NOT:'),
              Text('• Sell your personal data'),
              Text('• Share location with third parties'),
              Text('• Track you outside the app'),
              SizedBox(height: 16),
              Text('Full privacy policy available at:'),
              Text('redroute.com/privacy'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 