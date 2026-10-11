import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

class FeedbackFormSkeleton extends StatelessWidget {
  const FeedbackFormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        10,
        kMemberDashboardPagePadding,
        56,
      ),
      children: [
        _bar(width: double.infinity, height: 14),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(width: 120, height: 16),
              const SizedBox(height: 14),
              _bar(width: double.infinity, height: 44),
              const SizedBox(height: 10),
              _bar(width: double.infinity, height: 44),
              const SizedBox(height: 18),
              _bar(width: 100, height: 14),
              const SizedBox(height: 10),
              Row(
                children: List.generate(
                  5,
                  (_) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kSurfaceAlt,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _bar(width: double.infinity, height: 88),
              const SizedBox(height: 18),
              _bar(width: double.infinity, height: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class RescheduleCalendarSkeleton extends StatelessWidget {
  const RescheduleCalendarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              _box(36, 36, radius: 10),
              Expanded(child: Center(child: _box(140, 16, radius: 8))),
              _box(36, 36, radius: 10),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              7,
              (_) => Expanded(
                child: Center(child: _box(24, 12, radius: 6)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: List.generate(
                  7,
                  (_) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _box(double.infinity, 46, radius: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(double width, double height, {double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class RequestListSkeleton extends StatelessWidget {
  const RequestListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        10,
        kMemberDashboardPagePadding,
        56,
      ),
      children: [
        _bar(width: 140, height: 22),
        const SizedBox(height: 6),
        _bar(width: 260, height: 14),
        const SizedBox(height: 14),
        Container(
          height: 64,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: List.generate(
              5,
              (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: kSurfaceAlt,
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 3; i++) ...[
          _requestCardSkeleton(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _requestCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kSurfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(width: double.infinity, height: 16),
                const SizedBox(height: 10),
                _bar(width: 160, height: 12),
                const SizedBox(height: 6),
                _bar(width: 140, height: 12),
                const SizedBox(height: 6),
                _bar(width: 120, height: 12),
                const SizedBox(height: 10),
                _bar(width: 72, height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
