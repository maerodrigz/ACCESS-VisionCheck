import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig LAN dev sync', () {
    test('isSameIpv4Subnet24 matches /24 prefix', () {
      expect(ApiConfig.isSameIpv4Subnet24('192.168.8.98', '192.168.8.97'), isTrue);
      expect(ApiConfig.isSameIpv4Subnet24('192.168.8.97', '192.168.1.97'), isFalse);
    });

    test('suggestedPhoneBackendUrl prefers current home Wi-Fi host', () {
      expect(
        ApiConfig.suggestedPhoneBackendUrl,
        'http://192.168.8.97:3001',
      );
    });
  });
}
