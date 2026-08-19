import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:got_motion/screens/splash_screen.dart';

void main() {
  testWidgets('lays out without overflow on small and large phones', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    for (final size in const [Size(320, 568), Size(440, 956)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull, reason: 'overflowed at $size');
      expect(find.text('Got Motion'), findsOneWidget);
      expect(find.text('Stay in motion.'), findsOneWidget);
      expect(find.text('Getting things moving…'), findsOneWidget);
    }
  });

  testWidgets('gradient fills the entire screen', (tester) async {
    addTearDown(tester.view.reset);
    const size = Size(430, 932);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    final field = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .firstWhere(
          (box) =>
              box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).gradient == SplashScreen.field,
        );
    final render = tester.renderObject<RenderBox>(find.byWidget(field));
    expect(render.size.width, size.width);
    expect(render.size.height, size.height);
  });
}
