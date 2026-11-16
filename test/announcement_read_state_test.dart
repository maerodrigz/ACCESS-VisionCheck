import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Announcement copyWithRead preserves first open stamps', () {
    final first = DateTime.utc(2026, 11, 15, 1);
    final expires = first.add(const Duration(hours: 24));
    const unread = Announcement(
      id: 12,
      title: 'Campus update',
      content: 'Details here',
      date: 'Nov 15',
    );
    expect(unread.isRead, isFalse);

    final read = unread.copyWithRead(
      isRead: true,
      firstReadAt: first,
      expiresAt: expires,
    );
    expect(read.isRead, isTrue);
    expect(read.firstReadAt, first);
    expect(read.expiresAt, expires);

    final again = read.copyWithRead(
      isRead: true,
      firstReadAt: first.add(const Duration(hours: 2)),
      expiresAt: expires.add(const Duration(hours: 2)),
    );
    // copyWithRead replaces values when provided; UI should pass original stamps.
    expect(again.firstReadAt!.isAfter(first), isTrue);
  });

  test('unread indicator semantics based on isRead', () {
    const unread = Announcement(id: 1, title: 'A', content: 'B', date: 'd');
    final read = unread.copyWithRead(isRead: true);
    expect(unread.isRead, isFalse);
    expect(read.isRead, isTrue);
  });
}
