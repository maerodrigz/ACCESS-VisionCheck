import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects isolated QA backend URLs on port 3003', () {
    expect(ApiConfig.isIsolatedQaBackendUrl('http://127.0.0.1:3003'), isTrue);
    expect(ApiConfig.isIsolatedQaBackendUrl('http://10.0.2.2:3003'), isTrue);
    expect(ApiConfig.isIsolatedQaBackendUrl('http://127.0.0.1:3001'), isFalse);
    expect(ApiConfig.isIsolatedQaBackendUrl('http://192.168.8.97:3001'), isFalse);
  });

  test('detects local original USB backend', () {
    expect(ApiConfig.isLocalOriginalUsbBackendUrl('http://127.0.0.1:3001'), isTrue);
    expect(ApiConfig.isLocalOriginalUsbBackendUrl('http://127.0.0.1:3003'), isFalse);
  });
}
