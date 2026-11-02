import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart' show parsePairingLink;
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'devices_cubit.dart';
import 'settings_cubit.dart';

/// First-run pairing: scan the QR code another device shows, or type the
/// hub address and code.
class PairForm extends StatefulWidget {
  const PairForm({super.key});

  @override
  State<PairForm> createState() => _PairFormState();
}

class _PairFormState extends State<PairForm> {
  final _url = TextEditingController();
  final _code = TextEditingController();
  String _fingerprint = '';

  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final link = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
    final parsed = link == null ? null : parsePairingLink(link);
    if (parsed == null || !mounted) return;
    _url.text = parsed.url;
    _code.text = parsed.code;
    _fingerprint = parsed.fingerprint;
    context.read<SettingsCubit>().pair(parsed.url, parsed.code, fingerprint: parsed.fingerprint);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final saving = context.select<SettingsCubit, bool>((s) => s.state.saving);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Connect this device', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          "Over Tailscale, enter the hub's machine name and connect. Otherwise, on a device that is already connected, open Settings and choose \"Add a device\", then scan its QR code or type the code.",
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('pair-url'),
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: monoStyle(context, size: 13.5),
          decoration: const InputDecoration(labelText: 'Hub address', hintText: 'minipc, 100.x.y.z or wss://host:port/ws'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('connect-tailnet'),
          onPressed: saving ? null : () => context.read<SettingsCubit>().connectOverTailnet(_url.text),
          icon: const Icon(Icons.lan_outlined, size: 18),
          label: const Text('Connect over Tailscale'),
        ),
        const SizedBox(height: 4),
        Text('Works when the hub trusts your own tailnet machines (tether-hub -trust-tailnet).',
            style: TextStyle(color: c.faint, fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: c.border)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('or pair with a code', style: TextStyle(color: c.faint, fontSize: 12))),
            Expanded(child: Divider(color: c.border)),
          ],
        ),
        const SizedBox(height: 16),
        if (Platform.isAndroid || Platform.isIOS) ...[
          OutlinedButton.icon(
            key: const Key('scan-qr'),
            onPressed: saving ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR code'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: const Key('pair-code'),
          controller: _code,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          style: monoStyle(context, size: 15),
          decoration: const InputDecoration(labelText: 'Pairing code', hintText: 'ABCDE-FGHJK'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            key: const Key('pair'),
            onPressed: saving ? null : () => context.read<SettingsCubit>().pair(_url.text, _code.text, fingerprint: _fingerprint),
            child: const Text('Pair'),
          ),
        ),
      ],
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan the pairing QR code')),
        body: MobileScanner(
          onDetect: (capture) {
            for (final b in capture.barcodes) {
              final v = b.rawValue;
              if (!_done && v != null && parsePairingLink(v) != null) {
                _done = true;
                Navigator.of(context).pop(v);
                return;
              }
            }
          },
        ),
      );
}

/// Paired devices, and "Add a device", which shows a QR code to scan.
class DevicesSection extends StatelessWidget {
  const DevicesSection({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<DevicesCubit>()..load(),
        child: const _DevicesBody(),
      );
}

class _DevicesBody extends StatelessWidget {
  const _DevicesBody();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<DevicesCubit>();
    final (selfId, clientIp) = context.select<HubCubit, (String, String)>((h) => (h.state.hub.deviceId, h.state.hub.clientIp));
    return BlocConsumer<DevicesCubit, DevicesState>(
      listenWhen: (a, b) => a.failureId != b.failureId || a.invite != b.invite && b.invite != null,
      listener: (context, s) async {
        if (s.invite != null) {
          await showDialog<void>(context: context, builder: (_) => _InviteDialog(invite: s.invite!));
          cubit.closeInvite();
        } else if (s.failure != null) {
          showFailure(context, s.failure!);
        }
      },
      builder: (context, s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              FilledButton.icon(
                key: const Key('add-device'),
                onPressed: cubit.invite,
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('Add a device'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Apps and agents paired with their own token. Revoking one disconnects it at once.',
              style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 10),
          if (s.loading && s.devices.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
          else if (s.devices.isEmpty)
            Text('None yet. Devices set up with the hub token don\'t show here.', style: TextStyle(color: c.faint, fontSize: 13))
          else
            for (final d in s.devices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(d.isNode ? Icons.dns_outlined : (d.platform == 'android' ? Icons.phone_android_rounded : Icons.computer_outlined),
                    color: c.muted),
                title: Row(
                  children: [
                    Flexible(child: Text(d.name, overflow: TextOverflow.ellipsis)),
                    if (d.id == selfId) ...[const SizedBox(width: 8), const Pill('this device')],
                  ],
                ),
                subtitle: Text(
                  [d.isNode ? 'agent' : 'app', if (d.platform.isNotEmpty) d.platform, if (d.lastSeen != null) 'seen ${ago(d.lastSeen)}'].join(' · '),
                  style: TextStyle(fontSize: 12, color: c.faint),
                ),
                trailing: d.id == selfId
                    ? TextButton(
                        key: const Key('disconnect-this-device'),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Disconnect this device?'),
                              content: const Text("Tether forgets the hub here and this device's pairing is revoked. Pair again with a new code to reconnect."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Disconnect'),
                                ),
                              ],
                            ),
                          );
                          if (ok ?? false) cubit.disconnectThisDevice();
                        },
                        child: Text('Disconnect', style: TextStyle(color: c.danger)),
                      )
                    : TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Revoke ${d.name}?'),
                        content: const Text('Its token stops working right away. It can pair again with a new code.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Revoke'),
                          ),
                        ],
                      ),
                    );
                    if (ok ?? false) cubit.revoke(d.id);
                  },
                  child: Text('Revoke', style: TextStyle(color: c.danger)),
                ),
              ),
          const SizedBox(height: 20),
          Text('On your tailnet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
          const SizedBox(height: 4),
          if (s.tailnetError != null)
            Text(s.tailnetError!, style: TextStyle(color: c.faint, fontSize: 13))
          else
            for (final d in s.tailnet) TailnetRow(device: d, isSelf: d.ips.contains(clientIp)),
        ],
      ),
    );
  }
}

/// A tailnet machine, and what of Tether runs on it.
class TailnetRow extends StatelessWidget {
  const TailnetRow({super.key, required this.device, this.isSelf = false});

  final TailnetDevice device;

  /// The machine this app is running on.
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = device;
    final icon = switch (d.os) {
      'android' || 'iOS' => Icons.phone_android_rounded,
      'linux' => Icons.dns_outlined,
      _ => Icons.laptop_windows_outlined,
    };
    final tags = [
      if (isSelf) ('this device', c.text),
      if (d.isHub) ('hub', c.accent),
      if (d.node.isNotEmpty) ('agent: ${d.node}', c.success),
      for (final a in d.clients) ('app: ${a.replaceAll(RegExp(r' \(\w+\)$'), '')}', c.info),
      if (!d.runsTether && !d.isHub) ('no Tether', c.faint),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: d.online ? c.muted : c.faint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(d.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: d.online ? c.text : c.muted))),
                    const SizedBox(width: 6),
                    OnlineDot(online: d.online),
                  ],
                ),
                Text(
                  [d.os, if (!d.online && d.lastSeen != null) 'seen ${ago(d.lastSeen)}'].where((x) => x.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: c.faint),
                ),
              ],
            ),
          ),
          Wrap(spacing: 4, children: [for (final (t, color) in tags) Pill(t, color: color)]),
        ],
      ),
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.invite});

  final PairingInvite invite;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inv = widget.invite;
    final left = inv.expires.difference(DateTime.now());
    final expired = left.isNegative;
    final agent = 'tether-agent pair -hub ${inv.hubUrl} -token-file <path>${inv.fingerprint.isEmpty ? '' : ' -fingerprint ${inv.fingerprint}'} ${inv.code}';
    return AlertDialog(
      title: const Text('Add a device'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('On the phone, open Tether and choose "Scan QR code".', style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 14),
            Center(
              child: Opacity(
                opacity: expired ? 0.2 : 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: QrImageView(data: inv.link, size: 220, backgroundColor: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(child: SelectableText(inv.code, style: monoStyle(context, size: 22).copyWith(letterSpacing: 2, fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),
            Center(
              child: Text(
                expired ? 'Expired. Close and try again.' : 'Works once · expires in ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: expired ? c.danger : c.faint),
              ),
            ),
            const SizedBox(height: 12),
            Text('Hub address: ${inv.hubUrl}', style: TextStyle(fontSize: 12, color: c.muted)),
            const SizedBox(height: 10),
            Text('For an agent on another machine:', style: TextStyle(fontSize: 12, color: c.muted)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
              child: Row(
                children: [
                  Expanded(child: SelectableText(agent, style: monoStyle(context, size: 11.5))),
                  IconButton(
                    tooltip: 'Copy',
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.content_copy_rounded),
                    onPressed: () => Clipboard.setData(ClipboardData(text: agent)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    );
  }
}
