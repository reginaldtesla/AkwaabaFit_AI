import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  for (final p in ['assets/icon/app_icon.png', 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png']) {
    final i = img.decodeImage(File(p).readAsBytesSync());
    print('$p: ${i?.width}x${i?.height}');
  }
}
