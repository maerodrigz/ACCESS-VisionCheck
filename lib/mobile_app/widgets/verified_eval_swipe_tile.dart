import 'package:flutter/material.dart';

import 'package:access_mobile/shared/themes/theme.dart';

/// Horizontal swipe-to-reveal Delete for Verified evaluation cards.
///
/// Does not auto-delete. Parent owns which tile is open (one at a time).
class VerifiedEvalSwipeTile extends StatefulWidget {
  const VerifiedEvalSwipeTile({
    super.key,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onDeletePressed,
    required this.child,
    this.actionExtent = 76,
  });

  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onDeletePressed;
  final Widget child;
  final double actionExtent;

  @override
  State<VerifiedEvalSwipeTile> createState() => VerifiedEvalSwipeTileState();
}

@visibleForTesting
class VerifiedEvalSwipeTileState extends State<VerifiedEvalSwipeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragExtent = 0;

  double get revealProgress =>
      (widget.actionExtent <= 0) ? 0 : (_dragExtent / widget.actionExtent).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.isOpen ? 1 : 0,
    );
    _dragExtent = widget.isOpen ? widget.actionExtent : 0;
    _controller.addListener(() {
      setState(() {
        _dragExtent = _controller.value * widget.actionExtent;
      });
    });
  }

  @override
  void didUpdateWidget(covariant VerifiedEvalSwipeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      if (widget.isOpen) {
        _animateTo(widget.actionExtent, notify: false);
      } else {
        _animateTo(0, notify: false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double extent, {required bool notify}) {
    final target = extent.clamp(0.0, widget.actionExtent);
    _controller.stop();
    _controller.value = widget.actionExtent == 0
        ? 0
        : (_dragExtent / widget.actionExtent).clamp(0.0, 1.0);
    _controller
        .animateTo(
          widget.actionExtent == 0 ? 0 : target / widget.actionExtent,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
      if (!mounted) return;
      final open = _dragExtent >= widget.actionExtent * 0.5;
      if (notify && open != widget.isOpen) {
        widget.onOpenChanged(open);
      }
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final next = (_dragExtent - details.delta.dx).clamp(0.0, widget.actionExtent);
    setState(() => _dragExtent = next);
  }

  void _onDragEnd(DragEndDetails details) {
    final vx = details.primaryVelocity ?? 0;
    final shouldOpen = vx < -200
        ? true
        : vx > 200
            ? false
            : _dragExtent >= widget.actionExtent * 0.45;
    final target = shouldOpen ? widget.actionExtent : 0.0;
    final wasOpen = widget.isOpen;
    _animateTo(target, notify: false);
    if (shouldOpen != wasOpen) {
      widget.onOpenChanged(shouldOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: kRed,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: widget.actionExtent,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('verified_eval_swipe_delete'),
                      onTap: widget.onDeletePressed,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_outline_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(height: 2),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            // deferToChild so the revealed Delete strip receives taps once the
            // card is translated left (opaque would swallow those hits).
            behavior: HitTestBehavior.deferToChild,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: Transform.translate(
              offset: Offset(-_dragExtent, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
