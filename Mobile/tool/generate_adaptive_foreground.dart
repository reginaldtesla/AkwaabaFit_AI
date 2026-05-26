// Optional: builds a proportionally scaled foreground (keeps full icon colours).
// Default launcher setup uses app_icon.png only — run this only if you re-enable
// adaptive_icon_foreground in pubspec.yaml.
//
// Run: dart run tool/generate_adaptive_foreground.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const srcPath = 'assets/icon/app_icon.png';
  const outPath = 'assets/icon/app_icon_foreground.png';
  const canvasSize = 1024;
  const safeFraction = 0.66;

  final src = img.decodeImage(File(srcPath).readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode $srcPath');
    exit(1);
  }

  final maxSide = (canvasSize * safeFraction).round();
  final scale = math.min(maxSide / src.width, maxSide / src.height);
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();

  final resized = img.copyResize(
    src,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: canvasSize, height: canvasSize);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(
    canvas,
    resized,
    dstX: (canvasSize - w) ~/ 2,
    dstY: (canvasSize - h) ~/ 2,
  );

  File(outPath).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('Wrote $outPath (${w}x$h centered, aspect ratio preserved)');
}
