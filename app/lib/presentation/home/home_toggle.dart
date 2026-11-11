import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../nav/nav_cubit.dart';
import '../theme/theme.dart';

/// The two faces of the first place: start a chat, or go back through the
/// ones you have. Sits in the header, like the Chat and Code switch in a chat app.
class HomeToggle extends StatelessWidget {
  const HomeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final d = context.select<NavCubit, Destination>((n) => n.state.destination);
    Widget segment(Key key, String label, IconData icon, bool on, VoidCallback onTap) => Expanded(
          child: Material(
            color: on ? c.raised : Colors.transparent,
            borderRadius: context.round(18),
            child: InkWell(
              key: key,
              borderRadius: context.round(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: on ? c.accent : c.muted),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(fontSize: 13.5, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? c.text : c.muted)),
                  ],
                ),
              ),
            ),
          ),
        );
    return Container(
      width: 244,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surface, borderRadius: context.round(21), border: Border.all(color: c.border)),
      child: Row(
        children: [
          segment(const Key('nav-home'), 'New', Icons.edit_square, d == Destination.home, () => nav.select(Destination.home)),
          segment(const Key('nav-chats'), 'Chats', Icons.forum_outlined, d == Destination.chats, () => nav.select(Destination.chats)),
        ],
      ),
    );
  }
}
