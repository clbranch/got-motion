import 'package:flutter/material.dart';
import 'group_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Bottom navigation with 5 tabs: Home, Leaderboard, Profile, Group, Settings.
/// Default tab is Home.
class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  static const Color _background = Color(0xFF0B0B0F);

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onSeeAllLeaderboard: () => setState(() => _currentIndex = 1),
      ),
      const LeaderboardScreen(),
      const ProfileScreen(),
      const GroupScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: _background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  selected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  label: 'Leaderboard',
                  icon: Icons.leaderboard_outlined,
                  selectedIcon: Icons.leaderboard,
                  selected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  label: 'Profile',
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  selected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  label: 'Group',
                  icon: Icons.group_outlined,
                  selectedIcon: Icons.group,
                  selected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _NavItem(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  selected: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 24,
              color: selected ? _accent : Colors.white54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? _accent : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
