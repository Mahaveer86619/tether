import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../hub/hub_cubit.dart';
import '../new_session/new_session_sheet.dart';
import '../session/session_page.dart';
import '../settings/settings_cubit.dart';
import '../settings/settings_page.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import 'overview_page.dart';
import 'session_navigator.dart';

const double _wideBreakpoint = 840;

/// Picks the two-pane desktop layout or the stacked phone layout, and shows
/// app-wide failures.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    // Decided by saved settings, not hub state, so a configured app never
    // flashes the setup screen while the first snapshot is on its way.
    final configured = context.select<SettingsCubit, bool>((c) => c.state.connection.isComplete);
    return BlocListener<HubCubit, HubState>(
      listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
      listener: (context, s) => showFailure(context, s.failure!),
      child: !configured
          ? Scaffold(appBar: AppBar(title: const Text('Connect to your hub')), body: const SettingsPage())
          : LayoutBuilder(builder: (context, box) => box.maxWidth >= _wideBreakpoint ? const _WideShell() : const _PhoneHome()),
    );
  }
}

// ---- desktop / tablet ----

enum _Page { overview, node, session, settings }

class _WideShell extends StatefulWidget {
  const _WideShell();

  @override
  State<_WideShell> createState() => _WideShellState();
}

class _WideShellState extends State<_WideShell> {
  _Page _page = _Page.overview;
  String? _node, _session;

  void _openSession(String id) => setState(() {
        _page = _Page.session;
        _session = id;
        _node = context.read<HubCubit>().state.hub.sessions[id]?.node;
      });

  void _openNode(String node) => setState(() {
        _page = _Page.node;
        _node = node;
        _session = null;
      });

  Future<void> _newSession() async {
    final id = await showNewSession(context, node: _node);
    if (id != null && mounted) _openSession(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (status, approvals) = context.select<HubCubit, (ConnectionStatus, int)>((h) => (h.state.hub.status, h.state.hub.approvals.length));
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 290,
            color: c.sidebar,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                    child: Row(
                      children: [
                        Icon(Icons.hub_rounded, size: 20, color: c.accent),
                        const SizedBox(width: 8),
                        const Text('Tether', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: OutlinedButton.icon(
                      key: const Key('new-session'),
                      onPressed: status == ConnectionStatus.connected ? _newSession : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New session'),
                      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, backgroundColor: c.surface),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.space_dashboard_outlined,
                    label: 'Overview',
                    badge: approvals,
                    selected: _page == _Page.overview,
                    onTap: () => setState(() => _page = _Page.overview),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SessionNavigator(
                      selectedSession: _page == _Page.session ? _session : null,
                      selectedNode: _page == _Page.node ? _node : null,
                      onSession: _openSession,
                      onNode: _openNode,
                    ),
                  ),
                  Divider(color: c.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                    child: Row(
                      children: [
                        Expanded(child: ConnectionLine(status: status)),
                        IconButton(
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          onPressed: () => setState(() => _page = _Page.settings),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: c.border),
          Expanded(child: SafeArea(child: _main())),
        ],
      ),
    );
  }

  Widget _main() => switch (_page) {
        _Page.session => SessionScreen(key: ValueKey(_session), sessionId: _session!, onOpenSession: _openSession),
        _Page.node => _Titled(
            title: _node!,
            action: FilledButton.icon(onPressed: _newSession, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New session here')),
            child: DevicePage(node: _node!, onSession: _openSession),
          ),
        _Page.settings => _Titled(title: 'Settings', child: SettingsPage(onSaved: () => setState(() => _page = _Page.overview))),
        _Page.overview => _Titled(title: 'Overview', child: OverviewPage(onSession: _openSession, onNode: _openNode)),
      };
}

class _Titled extends StatelessWidget {
  const _Titled({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border))),
            child: Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                ?action,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? c.raised : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 18, color: c.muted),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: selected ? FontWeight.w600 : null))),
                if (badge > 0) Pill('$badge', color: c.warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- phone ----

class _PhoneHome extends StatelessWidget {
  const _PhoneHome();

  static void openSession(BuildContext context, String id) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _PhoneSession(sessionId: id)));
  }

  void _openNode(BuildContext context, String node) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(node)),
        body: DevicePage(node: node, onSession: (id) => openSession(ctx, id)),
        floatingActionButton: _NewButton(node: node, onCreated: (id) => openSession(ctx, id)),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select<HubCubit, ConnectionStatus>((c) => c.state.hub.status);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.hub_rounded, size: 20, color: context.colors.accent),
            const SizedBox(width: 8),
            const Text('Tether'),
            const SizedBox(width: 12),
            Flexible(child: ConnectionLine(status: status)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (ctx) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: SettingsPage(onSaved: () => Navigator.of(ctx).pop())),
            )),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => context.read<HubCubit>().retry(),
        child: OverviewPage(showDeviceSessions: true, onSession: (id) => openSession(context, id), onNode: (n) => _openNode(context, n)),
      ),
      floatingActionButton: status == ConnectionStatus.connected ? _NewButton(onCreated: (id) => openSession(context, id)) : null,
    );
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton({required this.onCreated, this.node});

  final ValueChanged<String> onCreated;
  final String? node;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () async {
          final id = await showNewSession(context, node: node);
          if (id != null) onCreated(id);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New session'),
      );
}

class _PhoneSession extends StatelessWidget {
  const _PhoneSession({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SessionScreen(
            sessionId: sessionId,
            leading: const BackButton(),
            // A fork opens in place of this screen.
            onOpenSession: (id) => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => _PhoneSession(sessionId: id))),
          ),
        ),
      );
}
