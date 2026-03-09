import 'package:flutter/material.dart';

class SettingsConnectedDevicesScreen extends StatelessWidget {
  const SettingsConnectedDevicesScreen({super.key});

  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text('Connected Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDeviceRow('Apple Health', 'Connected', true),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  _buildDeviceRow('Garmin', 'Coming soon', false),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  _buildDeviceRow('Oura', 'Coming soon', false),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  _buildDeviceRow('Whoop', 'Coming soon', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceRow(String name, String status, bool isConnected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle_rounded : Icons.watch_rounded,
                color: isConnected ? _accent : Colors.white.withValues(alpha: 0.3),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isConnected ? Colors.white.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              color: isConnected ? _accent : Colors.white.withValues(alpha: 0.4),
              fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
