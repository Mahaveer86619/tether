import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../core/version.dart';
import '../hub/hub_cubit.dart';
import '../notifications/notifications_section.dart';
import '../update/update_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import 'appearance_picker.dart';
import 'pairing_widgets.dart';
import 'codebases_section.dart';
import 'workspaces_section.dart';
import 'settings_cubit.dart';

/// Hub connection and appearance. Also the first-run screen.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onSaved, this.header});

  final VoidCallback? onSaved;

  /// Above the connect form on a first run.
  final Widget? header;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _url = TextEditingController(text: context.read<SettingsCubit>().state.connection.url);
  late final _token = TextEditingController(text: context.read<SettingsCubit>().state.connection.token);
  bool _showToken = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hub = context.select<HubCubit, ({ConnectionStatus status, String version, String? error})>((h) => (
          status: h.state.hub.status,
          version: h.state.hub.hubVersion,
          error: h.state.hub.lastError,
        ));
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) => a.failureId != b.failureId || a.savedId != b.savedId,
      listener: (context, s) {
        if (s.failure != null && s.failureId != 0) showFailure(context, s.failure!);
        _url.text = s.connection.url;
        if (s.savedId > 0) widget.onSaved?.call();
      },
      builder: (context, s) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!s.connection.isComplete) ...[
                    ?widget.header,
                    const PairForm(),
                    const SizedBox(height: 16),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: Text('Use the hub token instead', style: TextStyle(fontSize: 14, color: c.muted)),
                        children: [_hubForm(context, s, hub)],
                      ),
                    ),
                  ] else
                    _hubForm(context, s, hub),
                  if (s.connection.isComplete && hub.status == ConnectionStatus.connected) ...[
                    const SizedBox(height: 32),
                    const DevicesSection(),
                    const SizedBox(height: 16),
                    const NotificationsSection(),
                    const SizedBox(height: 32),
                    const WorkspacesSection(),
                    const SizedBox(height: 32),
                    const CodebasesSection(),
                  ],
                  const SizedBox(height: 32),
                  const Text('Appearance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {s.appearance.mode},
                    onSelectionChanged: (m) => context.read<SettingsCubit>().setThemeMode(m.first),
                  ),
                  const SizedBox(height: 20),
                  AppearancePicker(appearance: s.appearance),
                  const SizedBox(height: 32),
                  const _AboutSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hubForm(BuildContext context, SettingsState s, ({ConnectionStatus status, String version, String? error}) hub) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('The machine running tether-hub, reachable over Tailscale. The token is TETHER_TOKEN from that machine.',
            style: TextStyle(color: c.muted, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          key: const Key('hub-url'),
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: monoStyle(context, size: 13.5),
          decoration: const InputDecoration(labelText: 'Hub address', hintText: '100.x.y.z or ws://100.x.y.z:7420/ws'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('hub-token'),
          controller: _token,
          obscureText: !_showToken,
          autocorrect: false,
          enableSuggestions: false,
          style: monoStyle(context, size: 13.5),
          decoration: InputDecoration(
            labelText: 'Token',
            suffixIcon: IconButton(
              icon: Icon(_showToken ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _showToken = !_showToken),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Flexible(child: HubConnectionLine()),
                  if (hub.version.isNotEmpty)
                    Flexible(
                      child: Text('  · hub ${hub.version}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.faint)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('save-connection'),
              onPressed: s.saving ? null : () => context.read<SettingsCubit>().save(_url.text, _token.text),
              child: const Text('Save and connect'),
            ),
          ],
        ),
        if (hub.error != null && hub.status != ConnectionStatus.connected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(hub.error!, style: TextStyle(color: c.danger, fontSize: 12)),
          ),
      ],
    );
  }
}

/// This app's version and a way to look for a newer one.
class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final found = await context.read<UpdateCubit>().checkNow();
    if (!mounted) return;
    setState(() => _checking = false);
    showToast(
      context,
      switch (found) {
        true => 'A new version is ready: see the banner at the top',
        false => 'You are on the latest version',
        null => 'Could not reach the hub to ask',
      },
      icon: found == null ? Icons.error_outline_rounded : Icons.check_rounded,
      error: found == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hubVersion = context.select<HubCubit, String>((h) => h.state.hub.hubVersion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Tether $appVersion${hubVersion.isEmpty ? '' : '  ·  hub $hubVersion'}',
                style: monoStyle(context, size: 13, color: c.muted),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('check-updates'),
              onPressed: _checking ? null : _check,
              icon: _checking ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.system_update_alt_rounded, size: 18),
              label: const Text('Check for updates'),
            ),
          ],
        ),
      ],
    );
  }
}
