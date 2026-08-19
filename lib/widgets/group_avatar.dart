import 'package:flutter/material.dart';

import '../services/selected_group_service.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.name,
    this.size = 42,
    this.radius = 8,
    this.showEditBadge = false,
    this.loading = false,
  });

  final String? name;
  final double size;
  final double radius;
  final bool showEditBadge;
  final bool loading;

  static String initials(String? value) {
    final parts = (value ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '--';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length > 2 ? 2 : word.length).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: selectedGroupService,
      builder: (context, _) {
        final url = selectedGroupService.imageUrlFor(name);
        final mark = initials(name);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  color: const Color(0xFF14233B),
                  child: url != null
                      ? Image.network(
                          url,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _Initials(mark: mark, size: size),
                        )
                      : _Initials(mark: mark, size: size),
                ),
              ),
              if (loading)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x99000000),
                    child: Center(
                      child: SizedBox(
                        width: size * 0.38,
                        height: size * 0.38,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showEditBadge && !loading)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF168BFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.mark, required this.size});

  final String mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          mark,
          style: TextStyle(
            color: const Color(0xFF5BA9FF),
            fontSize: size * 0.32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
