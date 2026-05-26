// Bowl emblem only — transparent background for in-app screens.
// Run: dart run tool/generate_transparent_logo.dart

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const srcPath = 'assets/icon/app_icon.png';
  const outPath = 'assets/icon/app_icon_logo.png';

  final source = img.decodeImage(File(srcPath).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode $srcPath');
    exit(1);
  }

  final out = img.Image(width: source.width, height: source.height);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      if (_isGreenBackground(r, g, b) || _isDarkBackground(r, g, b)) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        out.setPixelRgba(x, y, r, g, b, p.a.toInt());
      }
    }
  }

  File(outPath).writeAsBytesSync(img.encodePng(out));
  stdout.writeln('Wrote $outPath');
}

bool _isGreenBackground(int r, int g, int b) {
  if (g < 65 || g < r || g < b) return false;
  if (r > 95 || b > 95) return false;
  final dr = (r - 26).abs();
  final dg = (g - 90).abs();
  final db = (b - 26).abs();
  return dr + dg + db < 85;
}

bool _isDarkBackground(int r, int g, int b) {
  return r < 28 && g < 28 && b < 28;
}
