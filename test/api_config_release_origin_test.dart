import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const production = 'https://accessvisioncheck.duckdns.org';

  test('normalizeApiOrigin keeps the production origin and strips one /api', () {
    expect(ApiConfig.normalizeApiOrigin(production, httpsOnly: true), production);
    expect(
      ApiConfig.normalizeApiOrigin('$production/api', httpsOnly: true),
      production,
    );
    expect(
      ApiConfig.normalizeApiOrigin('$production/api/', httpsOnly: true),
      production,
    );
  });

  test('normalizeApiOrigin rejects unsafe schemes, credentials, and extra paths', () {
    expect(ApiConfig.normalizeApiOrigin('http://accessvisioncheck.duckdns.org', httpsOnly: true), isNull);
    expect(ApiConfig.normalizeApiOrigin('ftp://accessvisioncheck.duckdns.org', httpsOnly: true), isNull);
    expect(ApiConfig.normalizeApiOrigin('javascript:alert(1)', httpsOnly: true), isNull);
    expect(ApiConfig.normalizeApiOrigin('https://user:pass@accessvisioncheck.duckdns.org', httpsOnly: true), isNull);
    expect(ApiConfig.normalizeApiOrigin('$production/auth/login', httpsOnly: true), isNull);
    expect(ApiConfig.normalizeApiOrigin('$production/api/auth', httpsOnly: true), isNull);
    expect(ApiConfig.normalizeApiOrigin('$production?next=/admin', httpsOnly: true), isNull);
    expect(ApiConfig.normalizeApiOrigin('https://', httpsOnly: true), isNull);
    expect(ApiConfig.normalizeApiOrigin('   ', httpsOnly: true), isNull);
  });

  test('debug normalize still accepts emulator and LAN http origins', () {
    expect(
      ApiConfig.normalizeApiOrigin('http://10.0.2.2:3001'),
      'http://10.0.2.2:3001',
    );
    expect(
      ApiConfig.normalizeApiOrigin('192.168.1.42:3001'),
      'http://192.168.1.42:3001',
    );
  });
}
