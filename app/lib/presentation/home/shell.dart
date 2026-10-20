import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../artifacts/files_page.dart';
import '../hub/hub_cubit.dart';
import '../new_session/new_session_sheet.dart';
import '../session/session_page.dart';
import '../settings/settings_cubit.dart';
import '../settings/settings_page.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../usage/usage_page.dart';
import 'activity_page.dart';
import 'devices_page.dart';
import 'home_page.dart';
import 'session_navigator.dart';
import 'sessions_page.dart';

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

enum _Page { home, sessions, devices, activity, files, node, session, settings, usage }

class _WideShell extends StatefulWidget {
  const _WideShell();

  @override
  State<_WideShell> createState() => _WideShellState();
}

class _WideShellState extends State<_WideShell> {
  _Page _page = _Page.home;
  String? _node, _session;

  /// Where Back returns to: earlier pages, newest last.
  final _history = <(_Page, String?, String?)>[];

  void _go(_Page page, {String? node, String? session}) {
    if (page == _page && node == _node && session == _session) return;
    setState(() {
      _history.add((_page, _node, _session));
      if (_history.length > 50) _history.removeAt(0);
      _page = page;
      _node = node;
      _session = session;
    });
  }

  void _back() {
    if (_history.isEmpty) return;
    final (page, node, session) = _history.removeLast();
    setState(() {
      _page = page;
      _node = node;
      _session = session;
    });
  }

  void _openSession(String id) => _go(_Page.session, session: id, node: context.read<HubCubit>().state.hub.sessions[id]?.node);

  void _openNode(String node) => _go(_Page.node, node: node);

  Future<void> _newSession() async {
    final id = await showNewSession(context, node: _node);
    if (id != null && mounted) _openSession(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (status, attention) = context.select<HubCubit, (ConnectionStatus, int)>((h) => (h.state.hub.status, attentionCount(h.state.hub)));
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
                  for (final (page, icon, label) in _destinations)
                    _NavItem(
                      icon: icon,
                      label: label,
                      badge: page == _Page.home ? attention : 0,
                      selected: _page == page || page == _Page.devices && _page == _Page.node,
                      onTap: () => _go(page),
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
                          isSelected: _page == _Page.settings,
                          onPressed: () => _go(_Page.settings),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: c.border),
          // Its own messenger so toasts centre on this pane, not the window.
          Expanded(
            // Mouse back button goes back; so does Esc, except in a session,
            // where Esc interrupts Claude.
            child: Listener(
              onPointerDown: (e) {
                if (e.buttons & kBackMouseButton != 0) _back();
              },
              child: CallbackShortcuts(
                bindings: {if (_page != _Page.session && _history.isNotEmpty) const SingleActivator(LogicalKeyboardKey.escape): _back},
                child: Focus(
                  autofocus: true,
                  child: ScaffoldMessenger(
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      body: SafeArea(child: _main()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _main() => switch (_page) {
        _Page.session => SessionScreen(key: ValueKey(_session), sessionId: _session!, onOpenSession: _openSession),
        _Page.node => _Titled(
            onBack: _back,
            title: _node!,
            action: FilledButton.icon(onPressed: _newSession, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New session here')),
            child: DevicePage(node: _node!, onSession: _openSession),
          ),
        _Page.settings => _Titled(title: 'Settings', onBack: _back, child: SettingsPage(onSaved: () => _go(_Page.home))),
        _Page.usage => _Titled(title: 'Usage', onBack: _back, child: UsagePage(onSession: _openSession)),
        _Page.sessions => _Titled(
            title: 'Sessions',
            onBack: _back,
            action: FilledButton.icon(onPressed: _newSession, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New session')),
            child: SessionsPage(onSession: _openSession),
          ),
        _Page.devices => _Titled(title: 'Devices', onBack: _back, child: DevicesPage(onNode: _openNode)),
        _Page.activity => _Titled(title: 'Activity', onBack: _back, child: ActivityPage(onSession: _openSession)),
        _Page.files => _Titled(title: 'Files', onBack: _back, child: FilesPage(onSession: _openSession)),
        _Page.home => _Titled(
            title: 'Home',
            child: HomePage(onSession: _openSession, onDevices: () => _go(_Page.devices), onAllSessions: () => _go(_Page.sessions)),
          ),
      };
}

const _destinations = [
  (_Page.home, Icons.home_outlined, 'Home'),
  (_Page.sessions, Icons.forum_outlined, 'Sessions'),
  (_Page.devices, Icons.devices_outlined, 'Devices'),
  (_Page.activity, Icons.history_rounded, 'Activity'),
  (_Page.files, Icons.folder_open_rounded, 'Files'),
  (_Page.usage, Icons.insights_outlined, 'Usage'),
];

class _Titled extends StatelessWidget {
  const _Titled({required this.title, required this.child, this.action, this.onBack});

  final String title;
  final Widget child;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(onBack == null ? 24 : 12, 14, 16, 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border))),
            child: Row(
              children: [
                if (onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(tooltip: 'Back (Esc)', icon: const Icon(Icons.arrow_back_rounded), onPressed: onBack),
                  ),
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

class _PhoneHome extends StatefulWidget {
  const _PhoneHome();

  static void openSession(BuildContext context, String id) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _PhoneSession(sessionId: id)));
  }

  @override
  State<_PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<_PhoneHome> {
  int _tab = 0;

  void _open(String id) => _PhoneHome.openSession(context, id);

  void _openNode(String node) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(node)),
        body: DevicePage(node: node, onSession: (id) => _PhoneHome.openSession(ctx, id)),
        floatingActionButton: _NewButton(node: node, onCreated: (id) => _PhoneHome.openSession(ctx, id)),
      ),
    ));
  }

  void _push(String title, Widget Function(BuildContext ctx) body) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (ctx) => Scaffold(appBar: AppBar(title: Text(title)), body: body(ctx))));
  }

  @override
  Widget build(BuildContext context) {
    final (status, attention) = context.select<HubCubit, (ConnectionStatus, int)>((h) => (h.state.hub.status, attentionCount(h.state.hub)));
    const titles = ['Tether', 'Sessions', 'Devices', 'Activity'];
    Widget badged(IconData icon) => Badge(isLabelVisible: attention > 0, label: Text('$attention'), child: Icon(icon));
    return Scaffold(
      appBar: AppBar(
        title: _tab == 0
            ? Row(
                children: [
                  Icon(Icons.hub_rounded, size: 20, color: context.colors.accent),
                  const SizedBox(width: 8),
                  const Text('Tether'),
                  const SizedBox(width: 12),
                  Flexible(child: ConnectionLine(status: status)),
                ],
              )
            : Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Files',
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: () => _push('Files', (ctx) => FilesPage(onSession: (id) => _PhoneHome.openSession(ctx, id))),
          ),
          IconButton(
            tooltip: 'Usage',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => _push('Usage', (ctx) => UsagePage(onSession: (id) => _PhoneHome.openSession(ctx, id))),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _push('Settings', (ctx) => SettingsPage(onSaved: () => Navigator.of(ctx).pop())),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          RefreshIndicator(
            onRefresh: () async => context.read<HubCubit>().retry(),
            child: HomePage(onSession: _open, onDevices: () => setState(() => _tab = 2), onAllSessions: () => setState(() => _tab = 1)),
          ),
          SessionsPage(onSession: _open),
          DevicesPage(onNode: _openNode),
          ActivityPage(onSession: _open),
        ],
      ),
      floatingActionButton: _tab == 1 ? _NewButton(onCreated: _open) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        height: 64,
        destinations: [
          NavigationDestination(icon: badged(Icons.home_outlined), selectedIcon: badged(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Sessions'),
          const NavigationDestination(icon: Icon(Icons.devices_outlined), selectedIcon: Icon(Icons.devices_rounded), label: 'Devices'),
          const NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Activity'),
        ],
      ),
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
