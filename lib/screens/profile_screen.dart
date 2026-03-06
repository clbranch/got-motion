import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../models/today_metrics.dart';

/// V1 Profile shell: header, avatar, display name, today summary, weekly & stats placeholders.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 16.0;

  TodayMetrics? _today;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = await HealthService.getTodayMetrics();
    if (!mounted) return;
    setState(() {
      _today = today;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : RefreshIndicator(
                onRefresh: _load,
                color: _accent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 24),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildAvatarAndName(),
                    const SizedBox(height: 24),
                    _buildTodaySummary(),
                    const SizedBox(height: 18),
                    _buildWeeklyPlaceholder(),
                    const SizedBox(height: 18),
                    _buildPersonalStatsPlaceholder(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Profile',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _buildAvatarAndName() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: _cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
          ),
          child: Icon(Icons.person_rounded, size: 44, color: Colors.white.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 12),
        Text(
          'Display Name',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@username',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTodaySummary() {
    final t = _today ?? TodayMetrics.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _SummaryItem(label: 'Steps', value: _formatInt(t.steps)),
              _SummaryItem(label: 'Miles', value: t.distanceMiles.toStringAsFixed(1)),
              _SummaryItem(label: 'Active Cal', value: _formatInt(t.activeEnergyCalories.round())),
              _SummaryItem(label: 'Exercise min', value: _formatInt(t.exerciseMinutes.round())),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, size: 24, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 10),
              Text(
                'Weekly summary coming soon',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalStatsPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal stats',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _PlaceholderRow(label: 'Average steps', value: '—'),
              const SizedBox(height: 12),
              _PlaceholderRow(label: 'Best day', value: '—'),
              const SizedBox(height: 12),
              _PlaceholderRow(label: 'Streak', value: '—'),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatInt(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final firstLen = s.length % 3;
    if (firstLen > 0) {
      buf.write(s.substring(0, firstLen));
      if (firstLen < s.length) buf.write(',');
    }
    for (var i = firstLen; i < s.length; i += 3) {
      buf.write(s.substring(i, i + 3));
      if (i + 3 < s.length) buf.write(',');
    }
    return buf.toString();
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
