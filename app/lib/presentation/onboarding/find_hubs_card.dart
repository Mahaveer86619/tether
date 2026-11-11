import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart' show hubNameOf;
import '../../injection.dart';
import '../settings/settings_cubit.dart';
import '../theme/theme.dart';
import '../ui/tokens.dart';
import '../widgets/common.dart';
import 'onboarding_cubit.dart';

/// The first thing a new install shows: the hubs it used before and the Tether
/// hubs found among the devices on the tailnet, to pick from. Under it sit the
/// other ways in (a code, a QR code, a token).
class FindHubsCard extends StatelessWidget {
  const FindHubsCard({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<OnboardingCubit>()..start(),
        child: const _Card(),
      );
}

class _Card extends StatefulWidget {
  const _Card();

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      builder: (context, s) {
        final cubit = context.read<OnboardingCubit>();
        final ts = s.tailscale;
        final saving = context.select<SettingsCubit, bool>((x) => x.state.saving);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.hub_rounded, size: 26, color: c.accent),
                const SizedBox(width: Gap.md),
                const Expanded(child: Text('Connect to your hub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              cubit.canSearch
                  ? 'Tether looks for your hub among the devices on your Tailscale network. Most of them do not run Tether, so only the ones that answer are listed.'
                  : "A phone's Tailscale app does not say who else is on the network. Scan the QR code from a device that is already connected, or enter the hub's Tailscale name or address below.",
              style: TextStyle(color: c.muted, fontSize: 13.5),
            ),
            const SizedBox(height: Gap.lg),
            if (s.hubs.isNotEmpty) ...[
              Text('HUBS', style: Type.label(context)),
              const SizedBox(height: Gap.sm),
              for (final h in s.hubs)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: _HubTile(hub: h, busy: s.connecting == h.url, onTap: s.connecting.isNotEmpty ? null : () => cubit.choose(h)),
                ),
              if (s.needsCodeFor.isNotEmpty) ...[
                const SizedBox(height: Gap.xs),
                Text('Enter the pairing code for ${hubNameOf(s.needsCodeFor)}. On a device that is connected, open Settings and choose "Add a device".',
                    style: TextStyle(color: c.muted, fontSize: 13)),
                const SizedBox(height: Gap.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('found-code'),
                        controller: _code,
                        autofocus: true,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.characters,
                        style: monoStyle(context, size: 14),
                        decoration: const InputDecoration(labelText: 'Pairing code', hintText: 'ABCDE-FGHJK'),
                        onSubmitted: (_) => _pair(context, s.needsCodeFor),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    FilledButton(
                      key: const Key('found-pair'),
                      onPressed: saving ? null : () => _pair(context, s.needsCodeFor),
                      child: const Text('Pair'),
                    ),
                  ],
                ),
              ],
            ],
            if (cubit.canSearch) ..._tailnet(context, s, ts),
            const SizedBox(height: Gap.xl),
            Text('OR', style: Type.label(context)),
            const SizedBox(height: Gap.sm),
          ],
        );
      },
    );
  }

  void _pair(BuildContext context, String url) {
    if (_code.text.trim().isEmpty) return;
    context.read<SettingsCubit>().pair(url, _code.text);
  }

  List<Widget> _tailnet(BuildContext context, OnboardingState s, TailscaleStatus? ts) {
    final c = context.colors;
    final cubit = context.read<OnboardingCubit>();
    Widget row(Widget lead, String text, [Widget? action]) => Padding(
          padding: const EdgeInsets.only(top: Gap.sm),
          child: Row(
            children: [
              lead,
              const SizedBox(width: Gap.md),
              Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: c.muted))),
              if (action != null) ...[const SizedBox(width: Gap.sm), action],
            ],
          ),
        );
    const spinner = SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    if (ts == null) return [row(spinner, 'Checking Tailscale…')];
    if (s.starting) return [row(spinner, ts.message.isEmpty ? 'Starting Tailscale…' : ts.message)];
    switch (ts.state) {
      case TailscaleState.running:
        if (s.scanning) return [row(spinner, 'Looking for Tether on your devices…')];
        return [
          row(
            Icon(s.hubs.any((h) => h.reachable) ? Icons.check_circle_outline_rounded : Icons.search_off_rounded, size: 18, color: c.faint),
            s.hubs.any((h) => h.reachable)
                ? 'Tap a hub to connect.'
                : 'No Tether hub answered on the devices that are online. Check that the hub machine is on, or use a code below.',
            TextButton(key: const Key('scan-tailnet'), onPressed: cubit.scan, child: const Text('Search again')),
          ),
        ];
      case TailscaleState.needsLogin:
        return [
          row(
            Icon(Icons.login_rounded, size: 18, color: c.warning),
            ts.message.isEmpty ? 'Tailscale needs you to sign in.' : ts.message,
            ts.loginUrl.isEmpty
                ? TextButton(onPressed: cubit.openTailscale, child: const Text('Open Tailscale'))
                : FilledButton(key: const Key('onboarding-signin'), onPressed: () => launchUrl(Uri.parse(ts.loginUrl), mode: LaunchMode.externalApplication), child: const Text('Sign in')),
          ),
        ];
      case TailscaleState.notInstalled:
        return [
          row(
            Icon(Icons.download_rounded, size: 18, color: c.warning),
            'Tailscale is not installed on this device.',
            FilledButton(key: const Key('onboarding-get'), onPressed: () => launchUrl(Uri.parse('https://tailscale.com/download'), mode: LaunchMode.externalApplication), child: const Text('Get Tailscale')),
          ),
        ];
      case TailscaleState.unsupported:
        return const [];
      default:
        return [
          row(
            Icon(Icons.power_settings_new_rounded, size: 18, color: c.warning),
            ts.message.isEmpty ? 'Tailscale is off.' : ts.message,
            FilledButton(key: const Key('onboarding-tailscale-on'), onPressed: cubit.turnOnTailscale, child: const Text('Turn on')),
          ),
        ];
    }
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.hub, required this.busy, required this.onTap});

  final FoundHub hub;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = hub;
    final host = hubNameOf(h.url);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: context.round(10)),
      child: InkWell(
        key: Key('hub-${h.url}'),
        borderRadius: context.round(10),
        onTap: h.reachable || h.known ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Icon(Icons.dns_outlined, color: h.reachable ? c.accent : c.faint),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(h.name, overflow: TextOverflow.ellipsis, style: Type.title(context).copyWith(fontSize: 14.5))),
                        if (h.known) ...[const SizedBox(width: Gap.sm), const Pill('used before')],
                        if (h.version.isNotEmpty) ...[const SizedBox(width: Gap.xs), Pill(h.version)],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !h.reachable ? '$host · not answering now' : (h.trusted ? '$host · connects directly' : '$host · needs a pairing code'),
                      style: Type.meta(context, color: h.reachable ? c.muted : c.faint, size: 11.5),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.arrow_forward_rounded, size: 18, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}
