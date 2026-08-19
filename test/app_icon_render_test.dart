import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:got_motion/widgets/motion_logo.dart';

/// Visual check that the icon lockup — dark-blue gradient field + ribbon M —
/// still composes. The opaque 1024 master shipped to iOS is produced by
/// `dart run tool/import_motion_mark.dart` then `dart run tool/make_app_icons.dart`.
void main() {
  testWidgets('app icon lockup', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 512,
          height: 512,
          child: MotionLogoBadge(size: 512),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MotionLogoBadge),
      matchesGoldenFile('preview/app_icon_lockup.png'),
    );
  });
}
