import 'package:flutter_test/flutter_test.dart';
import 'package:access_mobile/shared/utils/member_media_display_url.dart';

void main() {
  test('supabase-ref falls back to authenticated stream URL', () {
    final url = memberMediaDisplayUrl(
      fileUrl: 'supabase-ref:access-media/access-visioncheck/media/76/abc.jpg',
      mediaId: 270,
    );
    expect(url, contains('/api/media/270/stream'));
  });

  test('memberMediaImageHeaders adds bearer for stream URLs', () {
    final headers = memberMediaImageHeaders(
      'http://127.0.0.1:3001/api/media/5/stream',
      bearerToken: 'test-jwt',
    );
    expect(headers?['Authorization'], 'Bearer test-jwt');
  });

  test('memberMediaImageHeaders skips public https URLs', () {
    final headers = memberMediaImageHeaders(
      'https://cdn.example.com/photo.jpg',
      bearerToken: 'test-jwt',
    );
    expect(headers, isNull);
  });

  test('memberMediaHttpHeaders returns empty map when not needed', () {
    expect(
      memberMediaHttpHeaders('https://cdn.example.com/v.mp4', bearerToken: 'x'),
      isEmpty,
    );
  });

  test('memberMediaHttpHeaders includes bearer for stream URLs', () {
    final headers = memberMediaHttpHeaders(
      'http://127.0.0.1:3001/api/media/9/stream',
      bearerToken: 'tok',
    );
    expect(headers['Authorization'], 'Bearer tok');
  });
}
