// Builds Android notification icons from the transparent app emblem.
//
//   ic_notification*.png       — white silhouette (status bar / small icon)
//   ic_notification_large.png  — full-color emblem (large icon on alerts)
//   ic_bg_service_small*.png   — same silhouette for foreground step service
//
// Run: dart run tool/generate_notification_icons.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _logoPath = 'assets/icon/app_icon_logo.png';
const _androidRes = 'android/app/src/main/res';

const _densities = <String, int>{
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

void main() {
  final logoFile = File(_logoPath);
  if (!logoFile.existsSync()) {
    stderr.writeln('Missing $_logoPath');
    exit(1);
  }

  final logo = img.decodeImage(logoFile.readAsBytesSync());
  if (logo == null) {
    stderr.writeln('Could not decode $_logoPath');
    exit(1);
  }

  final trimmed = _trimTransparent(logo);
  final silhouette = _whiteSilhouette(trimmed);

  for (final entry in _densities.entries) {
    final folder = '$_androidRes/drawable-${entry.key}';
    Directory(folder).createSync(recursive: true);
    final size = entry.value;
    final small = img.copyResize(
      silhouette,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    final smallPath = '$folder/ic_notification.png';
    File(smallPath).writeAsBytesSync(img.encodePng(small));
    stdout.writeln('Wrote $smallPath');

    final servicePath = '$folder/ic_bg_service_small.png';
    File(servicePath).writeAsBytesSync(img.encodePng(small));
    stdout.writeln('Wrote $servicePath');
  }

  Directory('$_androidRes/drawable-nodpi').createSync(recursive: true);
  const largeSize = 256;
  final maxSide = (largeSize * 0.88).round();
  final scale = math.min(maxSide / trimmed.width, maxSide / trimmed.height);
  final w = (trimmed.width * scale).round();
  final h = (trimmed.height * scale).round();
  final scaled = img.copyResize(
    trimmed,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );
  final largeCanvas = img.Image(width: largeSize, height: largeSize, numChannels: 4);
  img.fill(largeCanvas, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(
    largeCanvas,
    scaled,
    dstX: (largeSize - w) ~/ 2,
    dstY: (largeSize - h) ~/ 2,
  );
  final largePath = '$_androidRes/drawable-nodpi/ic_notification_large.png';
  File(largePath).writeAsBytesSync(img.encodePng(largeCanvas));
  stdout.writeln('Wrote $largePath');
}

img.Image _whiteSilhouette(img.Image src) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final a = src.getPixel(x, y).a;
      if (a < 16) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        out.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }
  return out;
}

img.Image _trimTransparent(img.Image src) {
  var minX = src.width;
  var minY = src.height;
  var maxX = 0;
  var maxY = 0;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a > 12) {
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }
  }
  if (maxX < minX || maxY < minY) return src;
  return img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}
