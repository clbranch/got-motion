import 'package:flutter/material.dart';

/// Placeholder for Settings tab.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color _background = Color(0xFF0B0B0F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Text(
          'Settings',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 18),
        ),
      ),
    );
  }
}
