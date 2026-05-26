// Builds BOTH app icon assets from the master source (never mix them in the UI).
//
//   app_icon_logo.png  — transparent emblem (splash, login, welcome, in-app)
//   app_icon.png       — opaque green launcher icon (home screen only)
//
// Run: dart run tool/build_app_icons.dart
// Then: dart run flutter_launcher_icons

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _masterPath = 'assets/icon/app_icon_source.png';
const _transparentOut = 'assets/icon/app_icon_logo.png';
const _launcherOut = 'assets/icon/app_icon.png';
const _launcherSize = 1024;
const _launcherArtworkFraction = 0.76;
const _transparentPadding = 24;
final _launcherGreen = img.ColorRgba8(26, 93, 26, 255); // #1A5D1A

void main() {
  final masterFile = File(_masterPath);
  if (!masterFile.existsSync()) {
    stderr.writeln('Missing $_masterPath — restore the original artwork there first.');
    exit(1);
  }

  final master = img.decodeImage(masterFile.readAsBytesSync());
  if (master == null) {
    stderr.writeln('Could not decode $_masterPath');
    exit(1);
  }

  final emblem = _extractEmblem(master);
  final trimmed = _trimTransparent(emblem);
  final transparentSide =
      math.max(trimmed.width, trimmed.height) + _transparentPadding * 2;
  final transparentCanvas =
      img.Image(width: transparentSide, height: transparentSide, numChannels: 4);
  img.fill(transparentCanvas, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(
    transparentCanvas,
    trimmed,
    dstX: (transparentSide - trimmed.width) ~/ 2,
    dstY: (transparentSide - trimmed.height) ~/ 2,
  );
  File(_transparentOut).writeAsBytesSync(img.encodePng(transparentCanvas));
  stdout.writeln(
    'Wrote $_transparentOut (${transparentCanvas.width}x${transparentCanvas.height})',
  );

  final maxSide = (_launcherSize * _launcherArtworkFraction).round();
  final scale = math.min(
    maxSide / transparentCanvas.width,
    maxSide / transparentCanvas.height,
  );
  final w = (transparentCanvas.width * scale).round();
  final h = (transparentCanvas.height * scale).round();
  final scaledEmblem = img.copyResize(
    transparentCanvas,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );

  final launcher = img.Image(width: _launcherSize, height: _launcherSize);
  img.fill(launcher, color: _launcherGreen);
  _blendEmblemOnto(
    launcher,
    scaledEmblem,
    dstX: (_launcherSize - w) ~/ 2,
    dstY: (_launcherSize - h) ~/ 2,
  );
  File(_launcherOut).writeAsBytesSync(img.encodePng(launcher));
  stdout.writeln(
    'Wrote $_launcherOut (${_launcherSize}x$_launcherSize, artwork ${w}x$h)',
  );
}

img.Image _extractEmblem(img.Image source) {
  final out = img.Image(width: source.width, height: source.height, numChannels: 4);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      if (_isBackground(r, g, b)) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        out.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }
  return out;
}

void _blendEmblemOnto(
  img.Image canvas,
  img.Image emblem, {
  required int dstX,
  required int dstY,
}) {
  for (var y = 0; y < emblem.height; y++) {
    for (var x = 0; x < emblem.width; x++) {
      final a = emblem.getPixel(x, y).a / 255.0;
      if (a < 0.04) continue;
      final cx = dstX + x;
      final cy = dstY + y;
      if (cx < 0 || cy < 0 || cx >= canvas.width || cy >= canvas.height) {
        continue;
      }
      final ep = emblem.getPixel(x, y);
      final bp = canvas.getPixel(cx, cy);
      final r = (ep.r * a + bp.r * (1 - a)).round().clamp(0, 255);
      final g = (ep.g * a + bp.g * (1 - a)).round().clamp(0, 255);
      final b = (ep.b * a + bp.b * (1 - a)).round().clamp(0, 255);
      canvas.setPixelRgba(cx, cy, r, g, b, 255);
    }
  }
}

bool _isBackground(int r, int g, int b) {
  if (_isGreenBackground(r, g, b)) return true;
  if (r < 45 && g < 45 && b < 45) return true;
  return false;
}

bool _isGreenBackground(int r, int g, int b) {
  if (g < 65 || g < r || g < b) return false;
  if (r > 95 || b > 95) return false;
  final dr = (r - 26).abs();
  final dg = (g - 90).abs();
  final db = (b - 26).abs();
  return dr + dg + db < 85;
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
