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
        'My Skill Level requirements',
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
      expect(joined, contains('Quality Skill Classification'));
      expect(joined, contains('Photo and Video'));
    }
  });

  test('skillTierRequirementsForPolicy uses Quality Skill Classification', () {
    final v1 = MemberXpConfig.skillTierRequirementsForPolicy('v1');
    final v2 = MemberXpConfig.skillTierRequirementsForPolicy('v2');
    expect(v1, contains('Quality Skill Classification'));
    expect(v1, contains('Developing'));
    expect(v1, contains('Proficient'));
    expect(v1, contains('4.50–5.00'));
    expect(v1, isNot(contains('distinct upload days')));
    expect(v1, isNot(contains('Intermediate')));
    expect(v2, equals(v1));
    expect(MemberXpConfig.skillTierRequirementsForPolicy(''), equals(v1));
  });
}
