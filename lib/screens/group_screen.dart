import 'package:flutter/material.dart';

/// V1 Group shell: group selector, current group card, members, invite, challenge placeholder.
class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _pillBg = Color(0xFF1A1A24);
  static const Color _pillBorder = Color(0xFF2A2A36);
  static const double _pagePadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildGroupControlRow(),
            const SizedBox(height: 18),
            _buildCurrentGroupCard(),
            const SizedBox(height: 20),
            _buildMembersSection(),
            const SizedBox(height: 14),
            _buildInviteButton(),
            const SizedBox(height: 20),
            _buildGroupStatsPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Group',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _buildGroupControlRow() {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // TODO: open group switcher / list of groups
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _pillBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _pillBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Rich-Men',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            // TODO: create new group
          },
          icon: Icon(Icons.add_rounded, size: 20, color: _accent),
          label: const Text(
            'New Group',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6),
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentGroupCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current group',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.groups_rounded, color: _accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rich-Men',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '8 members',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Group description placeholder. Connect with your crew and compete on daily steps.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Members',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _MemberRowPlaceholder(name: 'You', rank: 1, isYou: true),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              _MemberRowPlaceholder(name: 'Member 2', rank: 2),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              _MemberRowPlaceholder(name: 'Member 3', rank: 3),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              _MemberRowPlaceholder(name: 'Member 4', rank: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInviteButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text('Invite members'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: BorderSide(color: _accent.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildGroupStatsPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group stats / Challenge',
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
              Icon(Icons.emoji_events_rounded, size: 24, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 10),
              Text(
                'Challenges and group stats coming soon',
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
}

class _MemberRowPlaceholder extends StatelessWidget {
  const _MemberRowPlaceholder({
    required this.name,
    required this.rank,
    this.isYou = false,
  });

  final String name;
  final int rank;
  final bool isYou;

  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isYou ? _accent : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isYou ? FontWeight.w600 : FontWeight.w500,
                color: isYou ? Colors.white : Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          Text(
            '— steps',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
