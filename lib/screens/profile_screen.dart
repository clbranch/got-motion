import 'package:flutter/material.dart';

/// Placeholder for Profile tab.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color _background = Color(0xFF0B0B0F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Text(
          'Profile',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 18),
        ),
      ),
    );
  }
}
