import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/entities.dart';
import '../theme/theme.dart';
import 'tailscale_cubit.dart';

/// Says what Tether is doing about Tailscale when the hub can't be reached:
/// starting it, waiting for a sign-in, or what the owner has to do. It is only
/// there while the hub is unreachable and Tailscale is the likely reason.
class TailscaleBanner extends StatelessWidget {
  const TailscaleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<TailscaleCubit>().state;
    if (!s.visible) return const SizedBox.shrink();
    final c = context.colors;
    final cubit = context.read<TailscaleCubit>();
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final (text, actions) = _content(context, s, cubit);
    return Material(
      key: const Key('tailscale-banner'),
      color: c.warning.withValues(alpha: 0.10),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (s.busy)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.warning))
                else
                  Icon(Icons.vpn_lock_rounded, size: 18, color: c.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(text, key: const Key('tailscale-text'), style: const TextStyle(fontSize: 13.5))),
                if (!narrow) ...actions,
              ],
            ),
            if (narrow && actions.isNotEmpty) Wrap(alignment: WrapAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }

  (String, List<Widget>) _content(BuildContext context, TailscaleViewState s, TailscaleCubit cubit) {
    final st = s.status;
    final open = TextButton(key: const Key('tailscale-open'), onPressed: cubit.openApp, child: const Text('Open Tailscale'));
    final retry = TextButton(key: const Key('tailscale-retry'), onPressed: s.busy ? null : cubit.retry, child: const Text('Try again'));
    if (st.state == TailscaleState.needsLogin) {
      return (
        'Tailscale needs you to sign in before it can reach your hub.',
        [
          if (st.loginUrl.isNotEmpty)
            FilledButton(key: const Key('tailscale-signin'), onPressed: () => launchUrl(Uri.parse(st.loginUrl), mode: LaunchMode.externalApplication), child: const Text('Sign in'))
          else
            open,
        ],
      );
    }
    if (st.state == TailscaleState.notInstalled) {
      return (
        "Your hub is on your tailnet, but Tailscale isn't installed on this device.",
        [TextButton(key: const Key('tailscale-get'), onPressed: () => launchUrl(Uri.parse('https://tailscale.com/download'), mode: LaunchMode.externalApplication), child: const Text('Get Tailscale'))],
      );
    }
    if (s.busy) {
      return (cubit.canStart ? 'Starting Tailscale so the hub can be reached…' : 'Checking Tailscale…', const []);
    }
    final message = st.message.isNotEmpty ? st.message : (cubit.canStart ? "Tailscale isn't running, so the hub can't be reached." : 'Tailscale is off, so the hub can\'t be reached.');
    return (message, [retry, open]);
  }
}
