import 'package:flutter/material.dart';

import '../models/weekly_group_award.dart';
import '../services/weekly_award_copy.dart';

/// Finalized weekly leaders — revealed Mondays for the prior Mon–Sun block.
class WeeklyGroupAwardsCard extends StatelessWidget {
  const WeeklyGroupAwardsCard({
    super.key,
    required this.awards,
    this.currentUserId,
  });

  final WeeklyGroupAwards awards;
  final String? currentUserId;

  static const _card = Color(0xFF11151B);
  static const _border = Color(0xFF242B36);
  static const _gold = Color(0xFFFFB547);

  @override
  Widget build(BuildContext context) {
    if (awards.winners.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 8),
            const Text(
              'No group activity last week. Sync your motion and check back Monday.',
              style: TextStyle(color: Color(0xFF8F99AA), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: awards.userLeadsAny(currentUserId ?? '')
              ? _gold.withValues(alpha: 0.45)
              : _border,
        ),
        gradient: awards.userLeadsAny(currentUserId ?? '')
            ? LinearGradient(
                colors: [
                  _gold.withValues(alpha: 0.08),
                  _card,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          if (currentUserId != null && awards.userLeadsAny(currentUserId!)) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.emoji_events_rounded, size: 16, color: _gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    WeeklyAwardCopy.cardBannerForUser(
                      awards.winsForUser(currentUserId!),
                    ),
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: WeeklyAwardCategory.values.map((category) {
              final winner = awards.winnerFor(category);
              return _AwardTile(
                category: category,
                winner: winner,
                isYou: winner?.userId == currentUserId,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Last week\'s leaders',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        awards.weekLabel,
        style: const TextStyle(color: Color(0xFF8F99AA), fontSize: 12),
      ),
    ],
  );
}

class _AwardTile extends StatelessWidget {
  const _AwardTile({
    required this.category,
    required this.winner,
    required this.isYou,
  });

  final WeeklyAwardCategory category;
  final WeeklyAwardWinner? winner;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final accent = switch (category) {
      WeeklyAwardCategory.steps => const Color(0xFF218FFF),
      WeeklyAwardCategory.calories => const Color(0xFFFF8A1E),
      WeeklyAwardCategory.exercise => const Color(0xFF9A73FF),
      WeeklyAwardCategory.miles => const Color(0xFF16D6A0),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1016),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isYou ? accent.withValues(alpha: 0.55) : const Color(0xFF1E2632),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            winner?.displayName ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isYou ? Colors.white : const Color(0xFFE8EDF5),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            WeeklyAwardCopy.tileLine(
              category: category,
              winnerName: winner?.displayName,
              isYou: isYou,
              value: winner?.value ?? 0,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isYou ? accent.withValues(alpha: 0.92) : const Color(0xFF8F99AA),
              fontSize: 10,
              height: 1.3,
              fontWeight: isYou ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small badge chips for member rows.
class WeeklyAwardBadge extends StatelessWidget {
  const WeeklyAwardBadge({super.key, required this.category});

  final WeeklyAwardCategory category;

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      WeeklyAwardCategory.steps => const Color(0xFF218FFF),
      WeeklyAwardCategory.calories => const Color(0xFFFF8A1E),
      WeeklyAwardCategory.exercise => const Color(0xFF9A73FF),
      WeeklyAwardCategory.miles => const Color(0xFF16D6A0),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        category.emoji,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
