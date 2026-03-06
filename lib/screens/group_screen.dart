import 'package:flutter/material.dart';

/// Placeholder for Group tab.
class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  static const Color _background = Color(0xFF0B0B0F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text('Group', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Text(
          'Group',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 18),
        ),
      ),
    );
  }
}
