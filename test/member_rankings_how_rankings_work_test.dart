import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('howRankingsDetailedRules covers required topics without banned copy', () {
    for (final policy in ['v1', 'v2', 'V2', ' unknown ']) {
      final rules = MemberXpConfig.howRankingsDetailedRules(policy);
      final titles = rules.map((r) => r.title).toList();
      expect(titles, containsAll([
        'XP earning',
        'Media Integrity review',
        'Skill Tier requirements',
        'Monthly vs All-Time XP',
        'What does not earn XP',
      ]));
      final joined = rules.map((r) => '${r.title}\n${r.body}').join('\n');
      expect(joined.toLowerCase(), isNot(contains('3/day')));
      expect(joined.toLowerCase(), isNot(contains('ai penalty')));
      expect(joined.toLowerCase(), isNot(contains('ai confirmed penalty')));
      expect(joined, contains('submission chain'));
      expect(joined, contains('award timestamp'));
      expect(joined, contains('Event documentation'));
      expect(joined, contains('assignment'));
      expect(joined, contains('grandfathering'));
      expect(joined, contains('admin override'));
    }
  });

  test('skillTierRequirementsForPolicy switches on active version', () {
    final v1 = MemberXpConfig.skillTierRequirementsForPolicy('v1');
    final v2 = MemberXpConfig.skillTierRequirementsForPolicy('v2');
    expect(v1, contains('3 evaluations'));
    expect(v1, contains('6 evaluations'));
    expect(v1, contains('10 evaluations'));
    expect(v1, isNot(contains('distinct upload days')));
    expect(v2, contains('2 distinct upload days'));
    expect(v2, contains('12 evaluations'));
    expect(v2, contains('24 distinct upload days'));
    expect(MemberXpConfig.skillTierRequirementsForPolicy(''), equals(v1));
  });
}
