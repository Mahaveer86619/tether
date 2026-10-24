import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../artifacts/files_page.dart';
import '../chats/chat_page.dart';
import '../chats/chats_cubit.dart';
import '../chats/chats_page.dart';
import '../chats/new_chat_page.dart';
import '../hub/hub_cubit.dart';
import '../nav/nav_cubit.dart';
import '../new_session/new_session_sheet.dart';
import '../session/session_page.dart';
import '../settings/settings_cubit.dart';
import '../settings/settings_page.dart';
import '../theme/theme.dart';
import '../update/update_banner.dart';
import '../update/update_cubit.dart';
import '../usage/usage_page.dart';
import '../widgets/common.dart';
import 'activity_page.dart';
import 'devices_page.dart';
import 'monitor_page.dart';
import 'session_navigator.dart';
import 'sessions_page.dart';

/// Below this the app is a phone: one pane and a bottom bar.
const double phoneBreakpoint = 600;

/// From here the sidebar shows labels and recent chats; between the two it
/// is an icon rail.
const double sidebarBreakpoint = 1000;

/// Picks the layout for the window size, and shows app-wide failures and
/// notices. Every layout renders from [NavCubit].
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    // Decided by saved settings, not hub state, so a configured app never
    // flashes the setup screen while the first snapshot is on its way.
    final configured = context.select<SettingsCubit, bool>((c) => c.state.connection.isComplete);
    final forced = context.select<UpdateCubit, bool>((c) => c.state.forced && c.state.release != null);
    if (forced) return const ForcedUpdatePage();
    return MultiBlocListener(
      listeners: [
        BlocListener<HubCubit, HubState>(
          listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
          listener: (context, s) => showFailure(context, s.failure!),
        ),
        BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null || a.noticeId != b.noticeId && b.notice != null,
          listener: (context, s) => s.failure != null && s.notice == null ? showFailure(context, s.failure!) : showToast(context, s.notice!),
        ),
      ],
      child: !configured
          ? Scaffold(appBar: AppBar(title: const Text('Connect to your hub')), body: const SettingsPage())
          : LayoutBuilder(
              builder: (context, box) => box.maxWidth < phoneBreakpoint ? const _PhoneShell() : _WideShell(compact: box.maxWidth < sidebarBreakpoint),
            ),
    );
  }
}

/// A destination's look in navigation.
typedef _Dest = ({Destination d, IconData icon, IconData selected, String label});

const List<_Dest> _destinations = [
  (d: Destination.chats, icon: Icons.chat_bubble_outline_rounded, selected: Icons.chat_bubble_rounded, label: 'Chats'),
  (d: Destination.monitor, icon: Icons.monitor_heart_outlined, selected: Icons.monitor_heart_rounded, label: 'Monitor'),
  (d: Destination.sessions, icon: Icons.forum_outlined, selected: Icons.forum_rounded, label: 'Sessions'),
  (d: Destination.devices, icon: Icons.devices_outlined, selected: Icons.devices_rounded, label: 'Devices'),
  (d: Destination.activity, icon: Icons.history_rounded, selected: Icons.history_rounded, label: 'Activity'),
  (d: Destination.files, icon: Icons.folder_open_outlined, selected: Icons.folder_open_rounded, label: 'Files'),
  (d: Destination.usage, icon: Icons.insights_outlined, selected: Icons.insights_rounded, label: 'Usage'),
];

/// The phone's bottom bar; the rest sit in the header's menu.
const _phoneBar = [Destination.chats, Destination.monitor, Destination.sessions, Destination.devices];

String _title(Destination d) => switch (d) {
      Destination.settings => 'Settings',
      _ => _destinations.firstWhere((x) => x.d == d).label,
    };

/// The page for a destination with nothing open on top.
Widget _destinationPage(BuildContext context, Destination d) {
  final nav = context.read<NavCubit>();
  return switch (d) {
    Destination.chats => const ChatsPage(),
    Destination.monitor => MonitorPage(
        onSession: nav.openSession,
        onDevices: () => nav.select(Destination.devices),
        onAllSessions: () => nav.select(Destination.sessions),
      ),
    Destination.sessions => SessionsPage(onSession: nav.openSession),
    Destination.devices => DevicesPage(onNode: nav.openNode),
    Destination.activity => ActivityPage(onSession: nav.openSession),
    Destination.files => FilesPage(onSession: nav.openSession),
    Destination.usage => UsagePage(onSession: nav.openSession),
    Destination.settings => SettingsPage(onSaved: () => nav.select(Destination.chats)),
  };
}

/// What a destination's header offers, if anything.
Widget? _destinationAction(BuildContext context, Destination d) {
  final nav = context.read<NavCubit>();
  return switch (d) {
    Destination.chats => FilledButton.icon(onPressed: () => nav.newChat(), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New chat')),
    Destination.sessions => OutlinedButton.icon(
        onPressed: () => newSession(context),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('New session'),
      ),
    _ => null,
  };
}

/// The full new-session form, for when a chat isn't what's wanted.
Future<void> newSession(BuildContext context, {String? node}) async {
  final nav = context.read<NavCubit>();
  final id = await showNewSession(context, node: node);
  if (id != null) nav.push(SessionEntry(id));
}

// ---- tablet and desktop ----

class _WideShell extends StatelessWidget {
  const _WideShell({required this.compact});

  /// An icon rail rather than the full sidebar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final s = context.watch<NavCubit>().state;
    return Scaffold(
      body: Row(
        children: [
          compact ? const _Rail() : const _Sidebar(),
          VerticalDivider(width: 1, color: c.border),
          // Its own messenger so toasts centre on this pane, not the window.
          Expanded(
            // Mouse back button goes back; so does Esc, except in a session,
            // where Esc interrupts Claude.
            child: Listener(
              onPointerDown: (e) {
                if (e.buttons & kBackMouseButton != 0) nav.back();
              },
              child: CallbackShortcuts(
                bindings: {
                  if (s.top is! SessionEntry && s.top is! ChatEntry && !s.atRoot) const SingleActivator(LogicalKeyboardKey.escape): () => nav.back(),
                },
                child: Focus(
                  autofocus: true,
                  child: ScaffoldMessenger(
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      body: SafeArea(child: Column(children: [const UpdateBanner(), Expanded(child: _WidePane(state: s))])),
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
}

class _WidePane extends StatelessWidget {
  const _WidePane({required this.state});

  final NavState state;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavCubit>();
    final back = state.history.isEmpty && state.stack.isEmpty ? null : nav.back;
    return switch (state.top) {
      ChatEntry(:final chatId) => ChatPage(key: ValueKey('chat-$chatId'), chatId: chatId),
      SessionEntry(:final sessionId) => SessionScreen(key: ValueKey(sessionId), sessionId: sessionId, onOpenSession: (id) => nav.push(SessionEntry(id))),
      NewChatEntry(:final node) => NewChatPage(key: ValueKey('new-$node'), node: node),
      NodeEntry(:final node) => _Titled(
          onBack: back,
          title: node,
          action: FilledButton.icon(onPressed: () => nav.newChat(node: node), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New chat here')),
          child: DevicePage(node: node, onSession: nav.openSession),
        ),
      null => _Titled(
          title: _title(state.destination),
          onBack: back,
          action: _destinationAction(context, state.destination),
          child: _destinationPage(context, state.destination),
        ),
    };
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar();

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  // Which list fills the sidebar's lower half: recent chats or projects.
  bool _projects = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final s = context.watch<NavCubit>().state;
    final (status, attention) = context.select<HubCubit, (ConnectionStatus, int)>((h) => (h.state.hub.status, attentionCount(h.state.hub)));
    return Container(
      width: 280,
      color: c.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.hub_rounded, size: 20, color: c.accent),
                  const SizedBox(width: 8),
                  const Text('Tether', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: FilledButton.icon(
                key: const Key('new-chat'),
                onPressed: () => nav.newChat(replace: true),
                icon: const Icon(Icons.edit_square, size: 17),
                label: const Text('New chat'),
                style: FilledButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
              ),
            ),
            for (final d in _destinations)
              _NavItem(
                key: Key('nav-${d.d.name}'),
                icon: d.icon,
                selectedIcon: d.selected,
                label: d.label,
                badge: d.d == Destination.monitor ? attention : 0,
                selected: s.top == null && s.destination == d.d || d.d == Destination.devices && s.top is NodeEntry,
                onTap: () => nav.select(d.d),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 4),
              child: Row(
                children: [
                  _ListTab(label: 'Recents', selected: !_projects, onTap: () => setState(() => _projects = false)),
                  const SizedBox(width: 4),
                  _ListTab(label: 'Projects', selected: _projects, onTap: () => setState(() => _projects = true)),
                ],
              ),
            ),
            Expanded(
              child: _projects
                  ? SessionNavigator(
                      selectedSession: s.selectedSession.isEmpty ? null : s.selectedSession,
                      selectedNode: s.selectedNode.isEmpty ? null : s.selectedNode,
                      onSession: (id) => nav.openSession(id, replace: true),
                      onNode: nav.openNode,
                    )
                  : const RecentChats(),
            ),
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  const Expanded(child: HubConnectionLine()),
                  IconButton(
                    tooltip: 'Settings',
                    icon: Icon(s.destination == Destination.settings && s.top == null ? Icons.settings_rounded : Icons.settings_outlined, size: 20),
                    color: s.destination == Destination.settings && s.top == null ? c.accent : null,
                    onPressed: () => nav.select(Destination.settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sidebar squeezed to icons, for tablets and narrow windows.
class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final s = context.watch<NavCubit>().state;
    final (status, attention) = context.select<HubCubit, (ConnectionStatus, int)>((h) => (h.state.hub.status, attentionCount(h.state.hub)));
    return Container(
      width: 84,
      color: c.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            Icon(Icons.hub_rounded, size: 22, color: c.accent),
            const SizedBox(height: 12),
            IconButton.filled(
              key: const Key('new-chat'),
              tooltip: 'New chat',
              onPressed: () => nav.newChat(replace: true),
              icon: const Icon(Icons.edit_square, size: 20),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final d in _destinations)
                      _RailItem(
                        key: Key('nav-${d.d.name}'),
                        icon: d.icon,
                        selectedIcon: d.selected,
                        label: d.label,
                        badge: d.d == Destination.monitor ? attention : 0,
                        selected: s.top == null && s.destination == d.d || d.d == Destination.devices && s.top is NodeEntry,
                        onTap: () => nav.select(d.d),
                      ),
                  ],
                ),
              ),
            ),
            Tooltip(message: switch (status) { ConnectionStatus.connected => 'Connected', _ => 'Not connected' }, child: OnlineDot(online: status == ConnectionStatus.connected)),
            IconButton(
              tooltip: 'Settings',
              icon: Icon(s.destination == Destination.settings && s.top == null ? Icons.settings_rounded : Icons.settings_outlined, size: 20),
              color: s.destination == Destination.settings && s.top == null ? c.accent : null,
              onPressed: () => nav.select(Destination.settings),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

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
            padding: EdgeInsets.fromLTRB(onBack == null ? 24 : 12, 12, 16, 12),
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

/// A sidebar destination: icon and label, filled and tinted when current.
class _NavItem extends StatefulWidget {
  const _NavItem({super.key, required this.icon, required this.selectedIcon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  final IconData icon, selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = widget.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: on ? c.accent.withValues(alpha: 0.12) : (_hover ? c.raised : Colors.transparent),
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: widget.onTap,
            child: SizedBox(
              height: 38,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(on ? widget.selectedIcon : widget.icon, size: 19, color: on ? c.accent : c.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.label,
                        style: TextStyle(fontSize: 13.5, color: on ? c.text : c.text.withValues(alpha: 0.85), fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
                  ),
                  if (widget.badge > 0) Pill('${widget.badge}', color: c.warning),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({super.key, required this.icon, required this.selectedIcon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  final IconData icon, selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 30,
                decoration: BoxDecoration(color: selected ? c.accent.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                child: Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  child: Icon(selected ? selectedIcon : icon, size: 20, color: selected ? c.accent : c.muted),
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11, color: selected ? c.text : c.muted, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListTab extends StatelessWidget {
  const _ListTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(label.toUpperCase(),
            style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: selected ? c.text : c.faint)),
      ),
    );
  }
}

// ---- phone ----

/// One pane: the destination with a bottom bar, and anything opened on top
/// of it as pages, all from [NavCubit]. System back goes through it too.
class _PhoneShell extends StatelessWidget {
  const _PhoneShell();

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavCubit>();
    final s = context.watch<NavCubit>().state;
    return PopScope(
      canPop: s.atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.back();
      },
      child: Navigator(
        pages: [
          const MaterialPage(key: ValueKey('root'), child: _PhoneRoot()),
          for (final (i, e) in s.stack.indexed) MaterialPage(key: _pageKey(i, e), child: _PhonePage(entry: e)),
        ],
        onDidRemovePage: (page) {
          // Only a pop the user made (Back, or a back arrow) moves the
          // state; pages removed because the state changed are already gone.
          final current = [for (final (i, e) in nav.state.stack.indexed) _pageKey(i, e)];
          if (current.contains(page.key)) nav.back();
        },
      ),
    );
  }
}

ValueKey<String> _pageKey(int i, NavEntry e) => ValueKey('$i:${e.runtimeType}:${e.props.join(',')}');

class _PhoneRoot extends StatelessWidget {
  const _PhoneRoot();

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavCubit>();
    final d = context.select<NavCubit, Destination>((n) => n.state.destination);
    final (status, attention) = context.select<HubCubit, (ConnectionStatus, int)>((h) => (h.state.hub.status, attentionCount(h.state.hub)));
    final onBar = _phoneBar.contains(d);
    Widget badged(IconData icon) => Badge(isLabelVisible: attention > 0, label: Text('$attention'), child: Icon(icon));
    return Scaffold(
      appBar: AppBar(
        leading: onBar ? null : BackButton(onPressed: nav.back),
        title: d == Destination.chats
            ? Row(
                children: [
                  Icon(Icons.hub_rounded, size: 20, color: context.colors.accent),
                  const SizedBox(width: 8),
                  const Text('Tether'),
                  const SizedBox(width: 12),
                  const Flexible(child: HubConnectionLine()),
                ],
              )
            : Text(_title(d)),
        actions: [
          if (d == Destination.sessions) IconButton(tooltip: 'New session', icon: const Icon(Icons.add_rounded), onPressed: () => newSession(context)),
          PopupMenuButton<Destination>(
            key: const Key('more-destinations'),
            tooltip: 'More',
            onSelected: nav.select,
            itemBuilder: (_) => [
              for (final x in _destinations.where((x) => !_phoneBar.contains(x.d)))
                PopupMenuItem(value: x.d, child: Row(children: [Icon(x.icon, size: 18), const SizedBox(width: 12), Text(x.label)])),
              const PopupMenuItem(
                value: Destination.settings,
                child: Row(children: [Icon(Icons.settings_outlined, size: 18), SizedBox(width: 12), Text('Settings')]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(
            child: d == Destination.monitor
                ? RefreshIndicator(onRefresh: () async => context.read<HubCubit>().retry(), child: _destinationPage(context, d))
                : _destinationPage(context, d),
          ),
        ],
      ),
      floatingActionButton: d == Destination.chats
          ? FloatingActionButton.extended(
              key: const Key('new-chat'),
              onPressed: () => nav.newChat(),
              icon: const Icon(Icons.edit_square),
              label: const Text('New chat'),
            )
          : null,
      bottomNavigationBar: onBar
          ? NavigationBar(
              selectedIndex: _phoneBar.indexOf(d),
              onDestinationSelected: (i) => nav.select(_phoneBar[i]),
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final x in _destinations.where((x) => _phoneBar.contains(x.d)))
                  NavigationDestination(
                    key: Key('nav-${x.d.name}'),
                    icon: x.d == Destination.monitor ? badged(x.icon) : Icon(x.icon),
                    selectedIcon: x.d == Destination.monitor ? badged(x.selected) : Icon(x.selected),
                    label: x.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _PhonePage extends StatelessWidget {
  const _PhonePage({required this.entry});

  final NavEntry entry;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavCubit>();
    return switch (entry) {
      ChatEntry(:final chatId) => Scaffold(body: SafeArea(child: ChatPage(chatId: chatId, leading: const BackButton()))),
      SessionEntry(:final sessionId) => Scaffold(
          body: SafeArea(child: SessionScreen(sessionId: sessionId, leading: const BackButton(), onOpenSession: (id) => nav.replaceTop(SessionEntry(id)))),
        ),
      NewChatEntry(:final node) => Scaffold(
          appBar: AppBar(title: const Text('New chat')),
          body: SafeArea(child: NewChatPage(node: node)),
        ),
      NodeEntry(:final node) => Scaffold(
          appBar: AppBar(title: Text(node)),
          body: DevicePage(node: node, onSession: nav.openSession),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => nav.newChat(node: node),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New chat here'),
          ),
        ),
    };
  }
}
