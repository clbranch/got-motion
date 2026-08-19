import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:got_motion/widgets/motion_logo.dart';

/// Renders the mark to PNGs under test/preview so the logo can be reviewed
/// without a device. Regenerates with: flutter test --update-goldens
void main() {
  testWidgets('motion logo badge', (tester) async {
    tester.view.physicalSize = const Size(420, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: Color(0xFF03070F),
          child: Center(child: MotionLogoBadge(size: 280)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MotionLogoBadge),
      matchesGoldenFile('preview/logo_badge.png'),
    );
  });

  testWidgets('motion logo mark', (tester) async {
    tester.view.physicalSize = const Size(420, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: Color(0xFF03070F),
          child: Center(child: MotionLogo(size: 280)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MotionLogo),
      matchesGoldenFile('preview/logo_mark.png'),
    );
  });
}
