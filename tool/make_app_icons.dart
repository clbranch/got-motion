import 'dart:io';

import 'package:image/image.dart' as img;

/// Builds the iOS app icon set from the rendered 1024px master.
///
/// Render the master first, then run this:
///   flutter test test/app_icon_render_test.dart --update-goldens
///   dart run tool/make_app_icons.dart
const _source = 'test/preview/app_icon_1024.png';
const _outputDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024];

void main() {
  final source = File(_source);
  if (!source.existsSync()) {
    stderr.writeln('Missing $_source — render the master first.');
    exit(1);
  }

  final master = img.decodePng(source.readAsBytesSync());
  if (master == null) {
    stderr.writeln('Could not decode $_source.');
    exit(1);
  }

  // App Store validation rejects icons carrying an alpha channel, and the
  // Flutter render is always RGBA, so flatten to three channels.
  final opaque = master.convert(numChannels: 3);

  for (final size in _sizes) {
    final resized = img.copyResize(
      opaque,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    File('$_outputDir/AppIcon-$size.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(resized));
  }

  stdout.writeln('Wrote ${_sizes.length} icons to $_outputDir');
}
