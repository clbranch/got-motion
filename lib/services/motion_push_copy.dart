import 'dart:math';

/// Motion-first push / in-app copy for Got Motion.
/// Keep alerts about motion — not generic “open the app” noise.
class MotionPushCopy {
  MotionPushCopy._();

  static final _random = Random();

  // ---------------------------------------------------------------------------
  // Morning / start the day
  // ---------------------------------------------------------------------------
  static const morningLines = <String>[
    'Wake up. Find your motion.',
    'Morning motion starts now.',
    'The day’s moving. Get in motion.',
    'No motion yet? Let’s change that.',
    'Your daily motion is waiting.',
    'Start small. Stay in motion.',
    'Today needs some motion from you.',
    'Got Motion? Go make some.',
    'Your first move is the whole point.',
    'Motion check: morning edition.',
  ];

  // ---------------------------------------------------------------------------
  // Gentle catch-up / competition
  // ---------------------------------------------------------------------------
  static const catchUpLines = <String>[
    'Everybody got motion but you.',
    'No motion detected. That can’t be you.',
    'They got motion. You got time.',
    'The motion party started without you.',
    'You can’t lead the motion from the sidelines.',
  ];

  // ---------------------------------------------------------------------------
  // Group: someone already moving (templates — fill with leaderboard-visible facts)
  // ---------------------------------------------------------------------------
  static String memberStepsEarly({required String name, required int steps}) =>
      '$name got motion early: ${_formatSteps(steps)} steps already.';

  static String memberInMotionYourTurn(String name) =>
      '$name is in motion. Your turn.';

  static String memberPutMotionOnBoard({
    required String name,
    required int steps,
  }) => '$name put motion on the board: ${_formatSteps(steps)} steps.';

  static String groupAlreadyInMotion(String groupName) =>
      '$groupName is already in motion.';

  static String motionAlreadyOnBoard(String groupName) =>
      'Motion is already on the board in $groupName.';

  static const groupActivityLines = <String>[
    'The crew got motion before noon.',
    'Someone in your group is making motion happen.',
    'The leaderboard is moving. Jump in.',
    'Your group’s motion is picking up.',
    'The crew is in motion. Don’t come in late.',
  ];

  /// Picks a morning line (stable for a given day if [seed] is provided).
  static String morning({int? seed}) => _pick(morningLines, seed);

  /// Picks a catch-up / competition line.
  static String catchUp({int? seed}) => _pick(catchUpLines, seed);

  /// Picks a generic group-activity line (no personal metrics).
  static String groupActivity({int? seed}) => _pick(groupActivityLines, seed);

  /// Builds a personalized “someone’s moving” line when we have name + steps.
  static String someoneMoving({
    required String name,
    required int steps,
    String? groupName,
    int? seed,
  }) {
    final options = <String>[
      memberStepsEarly(name: name, steps: steps),
      memberInMotionYourTurn(name),
      memberPutMotionOnBoard(name: name, steps: steps),
      if (groupName != null && groupName.isNotEmpty) ...[
        groupAlreadyInMotion(groupName),
        motionAlreadyOnBoard(groupName),
      ],
      ...groupActivityLines,
    ];
    return _pick(options, seed);
  }

  static String _pick(List<String> lines, int? seed) {
    if (lines.isEmpty) return 'Got Motion? Go make some.';
    final index = seed == null
        ? _random.nextInt(lines.length)
        : seed.abs() % lines.length;
    return lines[index];
  }

  static String _formatSteps(int steps) {
    final value = steps.abs();
    final chars = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      final fromEnd = chars.length - i;
      buffer.write(chars[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}
