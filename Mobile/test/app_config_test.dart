import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/config/app_config.dart';

void main() {
  test('API base URL is configured', () {
    expect(AppConfig.apiBaseUrl, isNotEmpty);
    expect(AppConfig.apiBaseUrl.endsWith('/api'), isTrue);
  });
}
