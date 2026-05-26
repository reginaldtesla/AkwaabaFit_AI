// Makes app_icon.png a perfect square so Android launcher icons are not stretched.
// Backs up the original to app_icon_source.png on first run.
//
// Run: dart run tool/square_app_icon.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const srcPath = 'assets/icon/app_icon.png';
  const backupPath = 'assets/icon/app_icon_source.png';
  const outPath = 'assets/icon/app_icon.png';
  const size = 1024;
  final bg = img.ColorRgba8(26, 93, 26, 255); // #1A5D1A

  final file = File(srcPath);
  if (!file.existsSync()) {
    stderr.writeln('Missing $srcPath');
    exit(1);
  }

  if (!File(backupPath).existsSync()) {
    File(backupPath).writeAsBytesSync(file.readAsBytesSync());
    stdout.writeln('Backed up original to $backupPath');
  }

  final source = img.decodeImage(file.readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode icon');
    exit(1);
  }

  if (source.width == source.height) {
    stdout.writeln('Icon already square (${source.width}x${source.height})');
    return;
  }

  // Fit entire artwork inside the square without changing proportions.
  final scale = math.min(size / source.width, size / source.height);
  final w = (source.width * scale).round();
  final h = (source.height * scale).round();
  final resized = img.copyResize(
    source,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: size, height: size);
  img.fill(canvas, color: bg);
  img.compositeImage(
    canvas,
    resized,
    dstX: (size - w) ~/ 2,
    dstY: (size - h) ~/ 2,
  );

  File(outPath).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln(
    'Wrote square $outPath (${size}x$size, artwork ${w}x$h centered)',
  );
}
