import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/participation_quota_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late int savedToday;
  late int savedLimit;
  late bool savedConfirmed;

  setUp(() {
    savedToday = appState.evaluationsTodayCount;
    savedLimit = appState.dailyEvaluationLimit;
    savedConfirmed = appState.evaluationsTodayQuotaConfirmed;
  });

  tearDown(() {
    appState.applyParticipation(
      evaluationsToday: savedToday,
      dailyEvaluationLimit: savedLimit,
    );
    if (!savedConfirmed) {
      appState.invalidateEvaluationsTodayQuota();
    }
  });

  group('ParticipationRefreshGuard', () {
    test('ignores stale token after a newer refresh begins', () {
      final guard = ParticipationRefreshGuard();
      final first = guard.begin(73);
      final second = guard.begin(73);
      expect(guard.shouldApply(first, 73), isFalse);
      expect(guard.shouldApply(second, 73), isTrue);
      expect(guard.isLatestToken(first), isFalse);
      expect(guard.isLatestToken(second), isTrue);
    });

    test('does not apply previous member after account switch', () {
      final guard = ParticipationRefreshGuard();
      final token = guard.begin(73);
      expect(guard.shouldApply(token, 74), isFalse);
      expect(guard.shouldApply(token, 73), isTrue);
    });

    test('reset invalidates in-flight tokens', () {
      final guard = ParticipationRefreshGuard();
      final token = guard.begin(10);
      guard.reset();
      expect(guard.shouldApply(token, 10), isFalse);
    });
  });

  group('participationFieldsFromApi', () {
    test('maps evaluations_today and daily limit', () {
      final fields = participationFieldsFromApi({
        'evaluations_today': 5,
        'daily_evaluation_limit': 5,
        'evaluation_daily_timezone': 'Asia/Manila',
      });
      expect(fields['evaluations_today'], 5);
      expect(fields['daily_evaluation_limit'], 5);
      expect(fields['evaluation_daily_timezone'], 'Asia/Manila');
    });
  });

  group('AppState daily quota confirmation', () {
    test('applyParticipation confirms evaluations today count', () {
      appState.applyParticipation(evaluationsToday: 2, dailyEvaluationLimit: 5);
      expect(appState.evaluationsTodayCount, 2);
      expect(appState.evaluationsTodayQuotaConfirmed, isTrue);
      expect(appState.evaluationsRemainingToday, 3);
      expect(appState.evaluationsTodayAtLimitConfirmed, isFalse);
    });

    test('confirmed 5/5 blocks client gate', () {
      appState.applyParticipation(evaluationsToday: 5, dailyEvaluationLimit: 5);
      expect(appState.evaluationsTodayAtLimitConfirmed, isTrue);
    });

    test('invalidate clears confirmation without erasing limit', () {
      appState.applyParticipation(evaluationsToday: 2, dailyEvaluationLimit: 5);
      appState.invalidateEvaluationsTodayQuota();
      expect(appState.evaluationsTodayQuotaConfirmed, isFalse);
      expect(appState.evaluationsTodayAtLimitConfirmed, isFalse);
      expect(appState.evaluationsTodayCount, 2);
    });

    test('clearMemberProfile resets quota state', () {
      appState.applyParticipation(evaluationsToday: 5, dailyEvaluationLimit: 5);
      appState.clearMemberProfile();
      expect(appState.evaluationsTodayCount, 0);
      expect(appState.evaluationsTodayQuotaConfirmed, isFalse);
      appState.applyParticipation(
        evaluationsToday: savedToday,
        dailyEvaluationLimit: savedLimit,
      );
      if (!savedConfirmed) {
        appState.invalidateEvaluationsTodayQuota();
      }
    });
  });
}
