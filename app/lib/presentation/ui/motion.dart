import 'package:flutter/material.dart';

/// How long a row takes to come in.
const kFadeDuration = Duration(milliseconds: 320);

/// The empty space left under the last item of a page, so it never sits
/// against the bottom edge: 15% of the screen's height, and at least [least].
double bottomRoom(BuildContext context, {double least = 40}) {
  final room = MediaQuery.sizeOf(context).height * 0.15;
  return room > least ? room : least;
}

/// Fades a row in, lifting it a little, the first time it is built. Lists build
/// their rows as they are scrolled to, so what is new to the screen arrives
/// gently instead of appearing at once.
///
/// Give it the list's [shown] set and the row's [id]: a row already in the set
/// has come in before and appears as it is (a list builds a row again when you
/// scroll back to it, and that should not play twice). [delay] staggers the
/// first rows of a list.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child, this.shown, this.id, this.delay = Duration.zero});

  final Widget child;
  final Set<Object>? shown;
  final Object? id;
  final Duration delay;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: kFadeDuration);
  late final CurvedAnimation _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final seen = widget.id != null && (widget.shown?.contains(widget.id) ?? false);
    if (widget.id != null) widget.shown?.add(widget.id!);
    if (seen) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        // A fixed offset: a relative one makes tall rows jump.
        builder: (context, child) => Opacity(
          opacity: _curve.value,
          child: Transform.translate(offset: Offset(0, 12 * (1 - _curve.value)), child: child),
        ),
        child: widget.child,
      );
}

/// The row delay for the n-th row a list builds first, so a page of rows
/// settles in one after another and not all in the same instant.
Duration stagger(int index) => Duration(milliseconds: 35 * (index < 8 ? index : 8));
