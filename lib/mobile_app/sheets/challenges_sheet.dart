import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/mobile_app/widgets/shared_widgets.dart';
import 'package:access_mobile/mobile_app/widgets/score_ring.dart';

void showChallengesSheet(BuildContext context) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => DraggableScrollableSheet(
      expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
      builder: (_, ctrl) => ListenableBuilder(
        listenable: appState,
        builder: (ctx, __) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Skill Challenges'),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: appState.challenges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = appState.challenges[i];
                return GestureDetector(
                  onTap: () => appState.toggleChallenge(i),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.completed ? kCyanDim : kSurfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.completed ? kCyan.withOpacity(0.4) : kBorder)),
                    child: Row(children: [
                      Container(width: 22, height: 22,
                        decoration: BoxDecoration(
                          gradient: c.completed ? const LinearGradient(
                            colors: [kCyan, kAccent]) : null,
                          color: c.completed ? null : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.completed ? kCyan : kBorder)),
                        child: c.completed
                          ? const Icon(Icons.check, color: Colors.white, size: 13) : null),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.title, style: TextStyle(
                          color: c.completed ? kCyan : kTextPrimary,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(c.description,
                          style: const TextStyle(color: kTextSecondary, fontSize: 11)),
                      ])),
                      Text('+${c.xp} XP', style: const TextStyle(color: kYellow,
                        fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    ),
  );
}
