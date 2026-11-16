import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compile with:
/// `flutter test test/api_config_staging_port_test.dart --dart-define=API_PORT=3011`
void main() {
  test('ApiConfig.port honors API_PORT dart-define for staging runs', () {
    const compilePort = int.fromEnvironment('API_PORT', defaultValue: 3001);
    if (compilePort == 3011) {
      expect(ApiConfig.port, 3011);
      expect(ApiConfig.baseUrl, contains(':3011'));
    } else {
      expect(ApiConfig.port, ApiConfig.defaultPort);
      expect(ApiConfig.defaultPort, 3001);
    }
  });
}
