import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Pull a page down from its top to refresh it, as on a phone.
class PullRefresh extends StatelessWidget {
  const PullRefresh({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RefreshIndicator(color: c.accent, backgroundColor: c.surface, strokeWidth: 2.5, onRefresh: onRefresh, child: child);
  }
}

/// The same for a list that is upside down, like a chat, whose "top" is the
/// end of the list: pulling the oldest message down past its edge refreshes,
/// and a small spinner shows while it works.
class EdgeRefresh extends StatefulWidget {
  const EdgeRefresh({super.key, required this.onRefresh, required this.child, this.distance = 80});

  final Future<void> Function() onRefresh;
  final Widget child;

  /// How far past the edge counts as a pull.
  final double distance;

  @override
  State<EdgeRefresh> createState() => _EdgeRefreshState();
}

class _EdgeRefreshState extends State<EdgeRefresh> {
  bool _refreshing = false;
  double _pull = 0;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final m = n.metrics;
    if (n is ScrollStartNotification) {
      _pull = 0;
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      // Only while a finger is down: the spring-back after release passes through zero.
      _pull = m.pixels > m.maxScrollExtent ? m.pixels - m.maxScrollExtent : 0;
    } else if (n is ScrollEndNotification) {
      final pulled = _pull;
      _pull = 0;
      if (pulled >= widget.distance && !_refreshing) _refresh();
    }
    return false;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _refreshing ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)),
                  child: _refreshing ? CircularProgressIndicator(strokeWidth: 2.5, color: c.accent) : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
