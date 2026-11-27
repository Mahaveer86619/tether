import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../settings/team_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';

/// Who owns each device, who it is shared with and who has booked time on it;
/// the owner shares or stops sharing their own. Grants and bookings come back
/// with the node's status, so the lists follow the hub.
class DeviceSharingSection extends StatelessWidget {
  const DeviceSharingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final me = hub.me;
    if (me == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => sl<TeamCubit>(),
      child: BlocListener<TeamCubit, TeamState>(
        listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
        listener: (context, s) => showFailure(context, s.failure!),
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('Owners and sharing'),
              for (final n in hub.sortedNodes)
                _NodeSharing(node: n, hub: hub, mine: n.owner.isEmpty || n.owner == me.id),
              if (hub.nodes.isEmpty) Text('No devices yet.', style: TextStyle(color: c.faint, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

String _slotLabel(DeviceSlot s) {
  String clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return '${s.start.day}/${s.start.month} ${clock(s.start)}–${clock(s.end)}';
}

class _NodeSharing extends StatelessWidget {
  const _NodeSharing({required this.node, required this.hub, required this.mine});

  final Node node;
  final HubSnapshot hub;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<TeamCubit>();
    final me = hub.me?.id;
    final sortedSlots = [...node.slots]..sort((a, b) => a.start.compareTo(b.start));
    return Padding(
      key: Key('sharing-${node.name}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(mine ? 'Yours' : "${hub.userName(node.owner)}'s, shared with you", style: TextStyle(color: c.muted, fontSize: 12.5)),
                if (node.grants.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final g in node.grants)
                        InputChip(
                          key: Key('grant-${node.name}-${g.user}'),
                          label: Text(
                            '${hub.userName(g.user)} · ${g.access == DeviceAccess.full ? 'full' : 'jobs only'} · ${g.windowLabel}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: mine ? () => cubit.unshare(node.name, g.user) : null,
                          deleteButtonTooltipMessage: 'Stop sharing',
                        ),
                    ]),
                  ),
                if (sortedSlots.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final s in sortedSlots)
                        InputChip(
                          key: Key('slot-${node.name}-${s.id}'),
                          label: Text('${hub.userName(s.user)} · ${_slotLabel(s)}', style: const TextStyle(fontSize: 12)),
                          onDeleted: s.user == me || mine ? () => cubit.cancelSlot(node.name, s.id) : null,
                          deleteButtonTooltipMessage: 'Cancel booking',
                        ),
                    ]),
                  ),
              ],
            ),
          ),
          Column(children: [
            if (mine)
              TextButton.icon(
                key: Key('share-${node.name}'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BlocProvider.value(
                    value: cubit,
                    child: ShareDeviceSheet(node: node.name, users: [for (final u in hub.users.values) if (u.id != hub.me?.id) u]),
                  ),
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            TextButton.icon(
              key: Key('book-${node.name}'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: BookSlotSheet(node: node.name, users: [for (final u in hub.users.values) u], me: me ?? ''),
                ),
              ),
              icon: const Icon(Icons.event_available_outlined, size: 18),
              label: const Text('Book'),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Pick a teammate, how much of the device they may use and when.
class ShareDeviceSheet extends StatefulWidget {
  const ShareDeviceSheet({super.key, required this.node, required this.users});

  final String node;
  final List<TeamUser> users;

  @override
  State<ShareDeviceSheet> createState() => _ShareDeviceSheetState();
}

class _ShareDeviceSheetState extends State<ShareDeviceSheet> {
  String? _user;
  DeviceAccess _access = DeviceAccess.jobs;
  int _startHour = 0;
  int _endHour = 0;
  final _days = TextEditingController();
  final _timezone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _days.dispose();
    _timezone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share ${widget.node}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (widget.users.isEmpty)
            Text('No one else is on this hub yet. Invite a teammate in Settings > Team.', style: TextStyle(color: c.muted))
          else ...[
            DropdownButtonFormField<String>(
              key: const Key('share-user'),
              initialValue: _user,
              decoration: const InputDecoration(labelText: 'With'),
              items: [for (final u in widget.users) DropdownMenuItem(value: u.id, child: Text(u.name))],
              onChanged: (v) => setState(() => _user = v),
            ),
            const SizedBox(height: 8),
            RadioGroup<DeviceAccess>(
              groupValue: _access,
              onChanged: (v) => setState(() => _access = v ?? _access),
              child: Column(children: [
                for (final a in DeviceAccess.values)
                  RadioListTile<DeviceAccess>(
                    key: Key('access-${a.wire}'),
                    value: a,
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.label),
                    subtitle: Text(a.blurb, style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const Key('share-start-hour'),
                  initialValue: _startHour,
                  decoration: const InputDecoration(labelText: 'From'),
                  items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00'))],
                  onChanged: (v) => setState(() => _startHour = v ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const Key('share-end-hour'),
                  initialValue: _endHour,
                  decoration: const InputDecoration(labelText: 'To'),
                  items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00'))],
                  onChanged: (v) => setState(() => _endHour = v ?? 0),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              key: const Key('share-days'),
              controller: _days,
              decoration: const InputDecoration(labelText: 'Days', hintText: 'mon,tue,wed,thu,fri (blank = every day)'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('share-timezone'),
              controller: _timezone,
              decoration: const InputDecoration(labelText: 'Time zone', hintText: 'e.g. America/New_York (blank = device time)'),
            ),
            if (_access == DeviceAccess.full)
              Container(
                key: const Key('share-warning'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.12), borderRadius: context.round(8)),
                child: Text(
                  'Their sessions run under your Claude Code login and spend your plan. Outside the hours you choose they are held back, and you can stop sharing at any time.',
                  style: TextStyle(fontSize: 12.5, color: c.text),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('share-confirm'),
                onPressed: _user == null || _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final ok = await context.read<TeamCubit>().share(
                              widget.node,
                              _user!,
                              _access,
                              startHour: _startHour,
                              endHour: _endHour,
                              days: _days.text.trim(),
                              timezone: _timezone.text.trim(),
                            );
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.pop(context);
                        } else {
                          setState(() => _busy = false);
                        }
                      },
                child: const Text('Share'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reserve a block of time on a device. The hub refuses overlapping bookings.
class BookSlotSheet extends StatefulWidget {
  const BookSlotSheet({super.key, required this.node, required this.users, required this.me});

  final String node;
  final List<TeamUser> users;
  final String me;

  @override
  State<BookSlotSheet> createState() => _BookSlotSheetState();
}

class _BookSlotSheetState extends State<BookSlotSheet> {
  late String _user;
  late DateTime _day;
  TimeOfDay _from = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 22, minute: 0);
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user = widget.me;
    _day = DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Book ${widget.node}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('slot-user'),
            initialValue: _user,
            decoration: const InputDecoration(labelText: 'For'),
            items: [for (final u in widget.users) DropdownMenuItem(value: u.id, child: Text(u.name))],
            onChanged: (v) => setState(() => _user = v ?? widget.me),
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('slot-day'),
            contentPadding: EdgeInsets.zero,
            title: Text('${_day.day}/${_day.month}/${_day.year}'),
            trailing: const Icon(Icons.calendar_today_outlined, size: 18),
            onTap: () async {
              final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _day);
              if (picked != null) setState(() => _day = picked);
            },
          ),
          Row(children: [
            Expanded(
              child: ListTile(
                key: const Key('slot-from'),
                contentPadding: EdgeInsets.zero,
                title: Text('From ${_from.format(context)}'),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _from);
                  if (picked != null) setState(() => _from = picked);
                },
              ),
            ),
            Expanded(
              child: ListTile(
                key: const Key('slot-to'),
                contentPadding: EdgeInsets.zero,
                title: Text('To ${_to.format(context)}'),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _to);
                  if (picked != null) setState(() => _to = picked);
                },
              ),
            ),
          ]),
          TextField(
            key: const Key('slot-notes'),
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes', hintText: 'What will run then?'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('slot-confirm'),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final ok = await context.read<TeamCubit>().bookSlot(
                            widget.node,
                            _user,
                            _at(_from),
                            _at(_to),
                            notes: _notes.text.trim(),
                          );
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _busy = false);
                      }
                    },
              child: Text('Book ${widget.node}'),
            ),
          ),
          if (_busy) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Booking…', style: TextStyle(color: c.muted, fontSize: 12))),
        ],
      ),
    );
  }
}
