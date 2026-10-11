import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../new_session/new_session_cubit.dart';
import '../new_session/new_session_sheet.dart';
import '../session/session_page.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'session_navigator.dart';

/// The dashboard: start something, what needs you, and where you left off.
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.onSession, required this.onNode});

  final ValueChanged<String> onSession;
  final ValueChanged<String> onNode;

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;

    if (!hub.connected && hub.sessions.isEmpty) {
      final connecting = hub.status == ConnectionStatus.connecting;
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: connecting ? 'Connecting to the hub…' : 'Not connected',
        body: hub.lastError ?? hub.endpoint,
        action: connecting ? null : OutlinedButton(onPressed: context.read<HubCubit>().retry, child: const Text('Retry now')),
      );
    }

    final approvals = hub.sortedApprovals;
    final active = hub.liveSessions;
    final projects = hub.projects().take(8).toList();
    final nodes = hub.sortedNodes;
    final side = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 16.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(side, 8, side, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hub.connected) ...[const SizedBox(height: 8), QuickStart(onCreated: onSession)],
                if (approvals.isNotEmpty) ...[
                  SectionLabel('Needs you', trailing: Pill('${approvals.length}', color: c.warning)),
                  for (final a in approvals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ApprovalCard(approval: a, sessionTitle: hub.sessions[a.session]?.displayTitle),
                    ),
                ],
                if (active.isNotEmpty) ...[
                  SectionLabel('Active now', trailing: Text('${active.length}', style: TextStyle(color: c.faint, fontSize: 12))),
                  _Grid(children: [for (final s in active) _ActiveCard(session: s, onTap: () => onSession(s.id))]),
                ],
                const SectionLabel('Pick up where you left off'),
                if (projects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sessions you start, or open on your devices, show up here by project.',
                        style: TextStyle(color: c.muted, fontSize: 13)),
                  )
                else
                  _Grid(children: [for (final p in projects) _ProjectCard(project: p, onSession: onSession)]),
                const SectionLabel('Devices'),
                _Grid(children: [for (final n in nodes) _DeviceCard(node: n, sessions: hub.sessionsOf(n.name).length, onTap: () => onNode(n.name))]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A prompt box that starts a session straight away, on the device and in
/// the folder used most recently; "more options" opens the full form.
class QuickStart extends StatelessWidget {
  const QuickStart({super.key, required this.onCreated});

  final ValueChanged<String> onCreated;

  @override
  Widget build(BuildContext context) {
    final hub = context.read<HubCubit>().state.hub;
    final online = context.select<HubCubit, String>((c) => c.state.hub.sortedNodes.where((n) => n.online).map((n) => n.name).join(','));
    return BlocProvider(
      key: ValueKey(online),
      create: (_) => sl<NewSessionCubit>(param1: hub, param2: hub.projects().firstOrNull?.node),
      child: _QuickStartBox(onCreated: onCreated),
    );
  }
}

class _QuickStartBox extends StatefulWidget {
  const _QuickStartBox({required this.onCreated});

  final ValueChanged<String> onCreated;

  @override
  State<_QuickStartBox> createState() => _QuickStartBoxState();
}

class _QuickStartBoxState extends State<_QuickStartBox> {
  final _prompt = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prompt.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<NewSessionCubit>();
    return BlocConsumer<NewSessionCubit, NewSessionState>(
      listenWhen: (a, b) => a.failureId != b.failureId || a.createdId != b.createdId,
      listener: (context, s) {
        if (s.createdId != null) {
          _prompt.clear();
          widget.onCreated(s.createdId!);
        } else if (s.failure != null) {
          showFailure(context, s.failure!);
        }
      },
      builder: (context, s) {
        final canStart = s.node != null && !s.submitting && _prompt.text.trim().isNotEmpty;
        void start() {
          if (canStart) cubit.submit(_prompt.text);
        }

        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CallbackShortcuts(
                bindings: {if (isDesktop) const SingleActivator(LogicalKeyboardKey.enter): start},
                child: TextField(
                  key: const Key('quick-start'),
                  controller: _prompt,
                  minLines: 1,
                  maxLines: 5,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'What should Claude work on?',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              Row(
                children: [
                  if (s.nodes.isEmpty)
                    Text('No devices online', style: TextStyle(color: c.danger, fontSize: 12.5))
                  else
                    _ChipMenu(
                      icon: osIcon(s.nodes.firstWhere((n) => n.name == s.node, orElse: () => s.nodes.first).os),
                      label: s.node ?? '',
                      tooltip: 'Device',
                      options: {for (final n in s.nodes) n.name: n.name},
                      onSelected: cubit.selectNode,
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: s.nodes.isEmpty
                          ? const SizedBox.shrink()
                          : _ChipMenu(
                              icon: Icons.folder_outlined,
                              label: s.cwd.isEmpty ? 'Home folder' : baseName(s.cwd),
                              tooltip: s.cwd.isEmpty ? 'Folder' : s.cwd,
                              options: {for (final f in s.folders.take(10)) f: baseName(f), '': 'Home folder'},
                              onSelected: cubit.setCwd,
                            ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More options',
                    icon: Icon(Icons.tune_rounded, size: 20, color: c.muted),
                    onPressed: () async {
                      final id = await showNewSession(context, node: s.node, cwd: s.cwd, prompt: _prompt.text);
                      if (id != null) {
                        _prompt.clear();
                        widget.onCreated(id);
                      }
                    },
                  ),
                  IconButton.filled(
                    key: const Key('quick-start-send'),
                    tooltip: 'Start session',
                    onPressed: canStart ? start : null,
                    style: IconButton.styleFrom(
                      backgroundColor: c.accent,
                      disabledBackgroundColor: c.raised,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: s.submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_upward_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChipMenu extends StatelessWidget {
  const _ChipMenu({required this.icon, required this.label, required this.tooltip, required this.options, required this.onSelected});

  final IconData icon;
  final String label, tooltip;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (_) => [for (final e in options.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: c.muted),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.text))),
            Icon(Icons.expand_more_rounded, size: 16, color: c.faint),
          ],
        ),
      ),
    );
  }
}

/// A folder you worked in recently: tap to continue its latest session.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onSession});

  final Project project;
  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = project;
    final latest = p.latest;
    return CardShell(
      onTap: () => onSession(latest.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 17, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.cwd.isEmpty ? 'Home folder' : baseName(p.cwd), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              if (p.liveCount > 0) ...[Pill('${p.liveCount} live', color: c.accent), const SizedBox(width: 6)],
              Pill(p.node),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              StateDot(state: latest.state, size: 7),
              const SizedBox(width: 8),
              Expanded(
                child: Text(latest.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.text)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p.sessions.length} ${p.sessions.length == 1 ? 'session' : 'sessions'} · ${ago(p.updated)}',
                  style: TextStyle(fontSize: 12, color: c.faint),
                ),
              ),
              Text('Continue', style: TextStyle(fontSize: 12, color: c.accent, fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_right_rounded, size: 16, color: c.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 640 ? 2 : 1;
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    return CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StateDot(state: s.state),
              const SizedBox(width: 8),
              Text(stateLabel(s.state), style: TextStyle(fontSize: 12, color: stateColor(context, s.state))),
              const Spacer(),
              if (hostLabel(s.host).isNotEmpty) Pill(hostLabel(s.host)),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text([s.node, if (s.cwd.isNotEmpty) baseName(s.cwd), ago(s.updated)].join(' · '), style: TextStyle(fontSize: 12, color: c.muted)),
          if (s.todos.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: s.todosDone / s.todos.length, minHeight: 4, backgroundColor: c.raised, color: c.accent),
            ),
            const SizedBox(height: 6),
            Text(s.currentTodo?.label ?? '${s.todosDone} of ${s.todos.length} done',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.node, required this.sessions, required this.onTap});

  final Node node;
  final int sessions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CardShell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(10)),
            child: Icon(osIcon(node.os), color: c.muted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(node.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    OnlineDot(online: node.online),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    node.online ? 'Online' : 'Offline${node.lastSeen != null ? ' · ${ago(node.lastSeen)}' : ''}',
                    if (node.claudeVersion.isNotEmpty) 'Claude Code ${node.claudeVersion}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${node.runningSessions}', style: TextStyle(fontWeight: FontWeight.w600, color: node.runningSessions > 0 ? c.accent : c.faint)),
              Text('live · $sessions total', style: TextStyle(fontSize: 11, color: c.faint)),
            ],
          ),
        ],
      ),
    );
  }
}

class CardShell extends StatelessWidget {
  const CardShell({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.border), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: child)),
    );
  }
}

/// One device and all of its sessions.
class DevicePage extends StatelessWidget {
  const DevicePage({super.key, required this.node, required this.onSession});

  final String node;
  final ValueChanged<String> onSession;

  @override
  Widget build(BuildContext context) {
    final hub = context.select<HubCubit, HubSnapshot>((c) => c.state.hub);
    final c = context.colors;
    final status = hub.nodes[node];
    final sessions = hub.sessionsOf(node);
    final live = sessions.where((s) => s.isLive).toList();
    final rest = sessions.where((s) => !s.isLive).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      [
                        status.online ? 'Online' : 'Offline',
                        status.os,
                        if (status.hostname.isNotEmpty) status.hostname,
                        if (status.claudeVersion.isNotEmpty) 'Claude Code ${status.claudeVersion}',
                        if (status.agentVersion.isNotEmpty) 'agent ${status.agentVersion}',
                      ].join(' · '),
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ),
                SectionLabel('Live', trailing: Text('${live.length}', style: TextStyle(color: c.faint, fontSize: 12))),
                if (live.isEmpty) Text('No live sessions on this device.', style: TextStyle(color: c.muted, fontSize: 13)),
                for (final s in live) SessionTile(session: s, selected: false, dense: false, onTap: () => onSession(s.id)),
                SectionLabel('History', trailing: Text('${rest.length}', style: TextStyle(color: c.faint, fontSize: 12))),
                for (final s in rest) SessionTile(session: s, selected: false, dense: false, onTap: () => onSession(s.id)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
