import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Avatars are displayed at thumbnail sizes, and storage buckets cap uploads at
/// a few megabytes. Photo library images — especially PNG screenshots, which
/// image_picker cannot re-compress — routinely blow past that, so every avatar
/// is re-encoded to a small JPEG before it leaves the device.
class AvatarImage {
  const AvatarImage._();

  static const int _maxEdge = 512;
  static const int _quality = 85;
  static const String contentType = 'image/jpeg';
  static const String extension = '.jpg';

  static Future<Uint8List> prepare(File file) async {
    return _compress(file, maxEdge: _maxEdge);
  }

  /// Workout proof photos — larger than avatars, still capped for upload.
  static Future<Uint8List> prepareProof(File file) async {
    return _compress(file, maxEdge: 1280);
  }

  static Future<Uint8List> _compress(File file, {required int maxEdge}) async {
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: maxEdge,
        minHeight: maxEdge,
        quality: _quality,
        format: CompressFormat.jpeg,
      );
      if (compressed != null && compressed.isNotEmpty) return compressed;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AvatarImage] compress failed, using original: $e');
      }
    }
    return file.readAsBytes();
  }
}
