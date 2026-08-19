import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Rebuilds the 1024 icon master. Pass a source photo to re-key the ribbon;
/// otherwise reuses `assets/branding/motion_mark.png`.
void main(List<String> args) {
  late img.Image mark;
  if (args.isNotEmpty) {
    final sourceFile = File(args.first);
    if (!sourceFile.existsSync()) {
      stderr.writeln('Missing ${args.first}');
      exit(1);
    }
    final source = img.decodeImage(sourceFile.readAsBytesSync());
    if (source == null) {
      stderr.writeln('Could not decode ${args.first}');
      exit(1);
    }
    final keyed = _keyBlack(source);
    final cropped = _cropToContent(keyed, padding: 48);
    mark = img.copyResize(
      cropped,
      width: 1024,
      interpolation: img.Interpolation.cubic,
    );
    Directory('assets/branding').createSync(recursive: true);
    File(
      'assets/branding/motion_mark.png',
    ).writeAsBytesSync(img.encodePng(mark));
  } else {
    final existing = File('assets/branding/motion_mark.png');
    if (!existing.existsSync()) {
      stderr.writeln(
        'Usage: dart run tool/import_motion_mark.dart [source]\n'
        'Missing assets/branding/motion_mark.png — pass a source image.',
      );
      exit(1);
    }
    final decoded = img.decodePng(existing.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('Could not decode assets/branding/motion_mark.png');
      exit(1);
    }
    mark = decoded;
  }

  final icon = _paintIconField(1024);

  // Leave ~18% margin so iOS rounding does not clip the ribbon.
  final inset = 184;
  final placed = img.copyResize(
    mark,
    width: 1024 - inset * 2,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    icon,
    placed,
    dstX: (1024 - placed.width) ~/ 2,
    dstY: (1024 - placed.height) ~/ 2,
  );

  Directory('test/preview').createSync(recursive: true);
  final square = icon.convert(numChannels: 3);
  File(
    'test/preview/app_icon_1024.png',
  ).writeAsBytesSync(img.encodePng(square));
  File(
    'test/preview/app_icon_rounded.png',
  ).writeAsBytesSync(img.encodePng(_iosSquirclePreview(icon)));

  stdout.writeln(
    'Wrote icon master ${square.width}x${square.height} '
    'and a rounded preview.',
  );
}

/// Near-black pixels become transparent; mid-tones get a soft alpha so the
/// ribbon's anti-aliased edges stay clean on a dark field.
img.Image _keyBlack(img.Image source) {
  final out = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final luma = (0.2126 * r + 0.7152 * g + 0.0722 * b);
      final chroma = math.max(math.max(r, g), b) - math.min(math.min(r, g), b);
      // Pure black field vs. the dark-blue folds in the ribbon.
      if (luma < 18 && chroma < 12) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      var alpha = 255;
      if (luma < 42 && chroma < 28) {
        alpha = ((luma - 18) / 24 * 255).round().clamp(0, 255);
      }
      out.setPixelRgba(x, y, r, g, b, alpha);
    }
  }
  return out;
}

img.Image _cropToContent(img.Image source, {required int padding}) {
  var minX = source.width;
  var minY = source.height;
  var maxX = 0;
  var maxY = 0;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (source.getPixel(x, y).a < 8) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX <= minX || maxY <= minY) return source;

  final left = math.max(0, minX - padding);
  final top = math.max(0, minY - padding);
  final right = math.min(source.width - 1, maxX + padding);
  final bottom = math.min(source.height - 1, maxY + padding);
  return img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

/// CSS `linear-gradient(145deg, #1E5AA6 0%, #0B2A57 48%, #06152B 100%)`
/// plus a faint inner highlight and a navy bloom behind the M.
img.Image _paintIconField(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  const c0 = (0x1E, 0x5A, 0xA6);
  const c1 = (0x0B, 0x2A, 0x57);
  const c2 = (0x06, 0x15, 0x2B);

  // CSS 0° is up; 145° runs upper-left → lower-right, slightly more vertical.
  final rad = 145 * math.pi / 180;
  final dirX = math.sin(rad);
  final dirY = -math.cos(rad);

  var minP = double.infinity;
  var maxP = -double.infinity;
  for (final corner in [
    (0.0, 0.0),
    (size - 1.0, 0.0),
    (0.0, size - 1.0),
    (size - 1.0, size - 1.0),
  ]) {
    final p = corner.$1 * dirX + corner.$2 * dirY;
    if (p < minP) minP = p;
    if (p > maxP) maxP = p;
  }
  final span = maxP - minP;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = ((x * dirX + y * dirY) - minP) / span;
      final (r, g, b) = t <= 0.48
          ? _mix(c0, c1, t / 0.48)
          : _mix(c1, c2, ((t - 0.48) / 0.52).clamp(0.0, 1.0));
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // Very subtle inner highlight in the upper-left — a light catch, not a rim.
  _addRadialGlow(
    image,
    cx: size * 0.18,
    cy: size * 0.14,
    radius: size * 0.52,
    color: (0x8E, 0xC4, 0xF0),
    alpha: 0.11,
    falloffPower: 2.1,
  );

  // Faint navy glow behind the M. Stays in-family with the field — no cyan.
  _addRadialGlow(
    image,
    cx: size * 0.50,
    cy: size * 0.46,
    radius: size * 0.46,
    color: (0x1E, 0x5A, 0xA6),
    alpha: 0.22,
    falloffPower: 1.8,
  );
  return image;
}

(int, int, int) _mix((int, int, int) a, (int, int, int) b, double t) {
  final u = t.clamp(0.0, 1.0);
  return (
    (a.$1 + (b.$1 - a.$1) * u).round(),
    (a.$2 + (b.$2 - a.$2) * u).round(),
    (a.$3 + (b.$3 - a.$3) * u).round(),
  );
}

void _addRadialGlow(
  img.Image image, {
  required double cx,
  required double cy,
  required double radius,
  required (int, int, int) color,
  required double alpha,
  double falloffPower = 1.6,
}) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final falloff = 1 - math.sqrt(dx * dx + dy * dy) / radius;
      if (falloff <= 0) continue;
      final a = math.pow(falloff, falloffPower) * alpha;
      final base = image.getPixel(x, y);
      image.setPixelRgba(
        x,
        y,
        (base.r + (color.$1 - base.r) * a).round().clamp(0, 255),
        (base.g + (color.$2 - base.g) * a).round().clamp(0, 255),
        (base.b + (color.$3 - base.b) * a).round().clamp(0, 255),
        255,
      );
    }
  }
}

/// Preview-only iOS squircle. App Store assets stay a full opaque square —
/// the OS applies this mask on the home screen.
img.Image _iosSquirclePreview(img.Image source) {
  const n = 5.0;
  final size = source.width;
  final out = img.Image(width: size, height: size, numChannels: 4);
  final cx = (size - 1) / 2;
  final cy = (size - 1) / 2;
  final rx = cx;
  final ry = cy;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final nx = ((x - cx) / rx).abs();
      final ny = ((y - cy) / ry).abs();
      final d = math.pow(nx, n) + math.pow(ny, n);
      if (d > 1.04) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      final p = source.getPixel(x, y);
      var alpha = 255;
      if (d > 0.96) {
        alpha = ((1.04 - d) / 0.08 * 255).round().clamp(0, 255);
      }
      out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), alpha);
    }
  }
  return out;
}
