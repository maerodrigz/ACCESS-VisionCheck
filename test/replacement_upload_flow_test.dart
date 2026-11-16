import 'package:access_mobile/mobile_app/widgets/submission_chain_history_panel.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/submission_chain_history.dart';
import 'package:access_mobile/shared/utils/replacement_upload_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

void main() {
  group('Evaluation replacement eligibility', () {
    test('canSubmitLinkedReplacement when reupload requested and no active replacement', () {
      final ev = Evaluation(
        id: 'MED-10',
        title: 'Practice',
        score: 0,
        composition: 'N/A',
        lighting: 'N/A',
        feedback: '',
        date: 'Today',
        reviewStatus: 'reupload_requested',
        adminRemarks: 'Please upload a clearer photo with better lighting.',
        awaitingReplacementMediaId: 10,
      );
      expect(ev.canSubmitLinkedReplacement, isTrue);
      expect(ev.replacementTargetMediaId, 10);
    });

    test('blocks when active replacement exists', () {
      final ev = Evaluation(
        id: 'MED-10',
        title: 'Practice',
        score: 0,
        composition: 'N/A',
        lighting: 'N/A',
        feedback: '',
        date: 'Today',
        reviewStatus: 'reupload_requested',
        activeReplacementMediaId: 99,
        awaitingReplacementMediaId: 10,
      );
      expect(ev.canSubmitLinkedReplacement, isFalse);
    });
  });

  group('replacementUploadErrorMessage', () {
    test('maps disabled flag', () {
      const e = ApiException('x', statusCode: 400, code: 'replacement_upload_disabled');
      expect(replacementUploadErrorMessage(e), contains('not enabled'));
    });

    test('maps duplicate active replacement', () {
      const e = ApiException('x', statusCode: 409, code: 'replacement_already_active');
      expect(replacementUploadErrorMessage(e), contains('already being processed'));
    });
  });

  group('SubmissionChainHistoryPanel', () {
    testWidgets('shows original and replacement rows', (tester) async {
      const history = SubmissionChainHistory(
        chainId: 1,
        rootMediaId: 10,
        media: [
          SubmissionChainMediaItem(
            mediaId: 10,
            fileName: 'root.jpg',
            reviewStatus: 'reupload_requested',
          ),
          SubmissionChainMediaItem(
            mediaId: 11,
            fileName: 'rep.jpg',
            reviewStatus: 'pending_review',
            replacesMediaId: 10,
            replacementLifecycle: 'active',
          ),
        ],
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SubmissionChainHistoryPanel(history: history)),
        ),
      );
      expect(find.text('Submission history'), findsOneWidget);
      expect(find.text('root.jpg'), findsOneWidget);
      expect(find.text('rep.jpg'), findsOneWidget);
      expect(find.text('Original submission'), findsOneWidget);
    });
  });

  group('MemberReviewStatus', () {
    test('detects reupload requested', () {
      expect(MemberReviewStatus.isReuploadRequested('reupload_requested'), isTrue);
    });
  });
}
