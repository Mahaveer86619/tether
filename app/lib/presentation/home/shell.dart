import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../artifacts/files_page.dart';
import '../chats/chat_page.dart';
import '../chats/chats_cubit.dart';
import '../chats/chats_page.dart';
import '../chats/new_chat_page.dart';
import '../hub/hub_cubit.dart';
import '../onboarding/find_hubs_card.dart';
import '../nav/nav_cubit.dart';
import '../session/session_page.dart';
import '../settings/settings_cubit.dart';
import '../settings/settings_page.dart';
import '../theme/theme.dart';
import '../tailscale/tailscale_banner.dart';
import '../update/update_banner.dart';
import '../update/update_cubit.dart';
import '../routines/routines_page.dart';
import '../usage/usage_page.dart';
import '../widgets/common.dart';
import 'activity_page.dart';
import 'devices_page.dart';
import 'home_toggle.dart';
import 'sidebar.dart';

/// Below this the app is a phone: one pane, and the sidebar is a drawer.
const double phoneBreakpoint = 600;

/// From here the sidebar is open to begin with; below it, a tablet or a
/// narrow window starts with it folded away.
const double sidebarBreakpoint = 1000;

const double _sidebarWidth = 280;

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
          ? const Scaffold(body: SafeArea(child: SettingsPage(header: FindHubsCard())))
          : LayoutBuilder(
              builder: (context, box) => box.maxWidth < phoneBreakpoint ? const _PhoneShell() : _WideShell(startOpen: box.maxWidth >= sidebarBreakpoint),
            ),
    );
  }
}

String _title(Destination d) => switch (d) {
      Destination.home => 'New chat',
      Destination.chats => 'Chats',
      Destination.devices => 'Devices',
      Destination.activity => 'History',
      Destination.files => 'Files',
      Destination.routines => 'Routines',
      Destination.usage => 'Usage',
      Destination.settings => 'Settings',
    };

/// The header's centre for a place: the New and Chats switch on the first
/// two, the name on the rest.
bool _hasToggle(Destination d) => d == Destination.home || d == Destination.chats;

/// The page for a destination with nothing open on top.
Widget _destinationPage(BuildContext context, Destination d) {
  final nav = context.read<NavCubit>();
  return switch (d) {
    Destination.chats => const ChatsPage(),
    Destination.home => const NewChatPage(),
    Destination.devices => DevicesPage(onNode: nav.openNode),
    Destination.activity => ActivityPage(onSession: nav.openSession),
    Destination.files => FilesPage(onSession: nav.openSession),
    Destination.routines => const RoutinesPage(),
    Destination.usage => UsagePage(onSession: nav.openSession),
    Destination.settings => SettingsPage(onSaved: () => nav.select(Destination.home)),
  };
}

/// What a destination's header offers, if anything.
Widget? _destinationAction(BuildContext context, Destination d) {
  return null;
}

// ---- tablet and desktop ----

class _WideShell extends StatefulWidget {
  const _WideShell({required this.startOpen});

  final bool startOpen;

  @override
  State<_WideShell> createState() => _WideShellState();
}

class _WideShellState extends State<_WideShell> {
  late bool _open = widget.startOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final s = context.watch<NavCubit>().state;
    return Scaffold(
      body: Row(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            child: _open
                ? SizedBox(width: _sidebarWidth, child: SidebarBody(onCollapse: () => setState(() => _open = false)))
                : _FoldedSidebar(onOpen: () => setState(() => _open = true)),
          ),
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
                      body: SafeArea(child: Column(children: [const TailscaleBanner(), const UpdateBanner(), Expanded(child: _WidePane(state: s))])),
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

/// What is left of the sidebar when it is folded away: a way to open it,
/// start a chat and reach Settings.
class _FoldedSidebar extends StatelessWidget {
  const _FoldedSidebar({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.read<NavCubit>();
    final onSettings = context.select<NavCubit, bool>((n) => n.state.destination == Destination.settings && n.state.top == null);
    return Container(
      width: 56,
      color: c.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            IconButton(key: const Key('open-sidebar'), tooltip: 'Show the sidebar', icon: const Icon(Icons.menu_rounded), onPressed: onOpen),
            const SizedBox(height: 4),
            IconButton.filled(key: const Key('new-chat'), tooltip: 'New chat', onPressed: () => nav.select(Destination.home), icon: const Icon(Icons.edit_square, size: 19)),
            const Spacer(),
            IconButton(
              key: const Key('nav-settings'),
              tooltip: 'Settings',
              icon: Icon(onSettings ? Icons.settings_rounded : Icons.settings_outlined, size: 20),
              color: onSettings ? c.accent : null,
              onPressed: () => nav.select(Destination.settings),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
    final back = state.atRoot ? null : nav.back;
    return _Fade(id: state.top == null ? state.destination.name : '${state.top.runtimeType}:${state.top!.props.join(',')}', child: _pane(context, nav, back));
  }

  Widget _pane(BuildContext context, NavCubit nav, VoidCallback? back) {
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
          heading: _hasToggle(state.destination) ? const HomeToggle() : null,
          action: _destinationAction(context, state.destination),
          child: _destinationPage(context, state.destination),
        ),
    };
  }
}

/// Cross-fades to what is shown when the place or the open screen changes,
/// so moving about is a dissolve and not a cut.
class _Fade extends StatelessWidget {
  const _Fade({required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: ValueKey(id), child: child),
      );
}

class _Titled extends StatelessWidget {
  const _Titled({required this.title, required this.child, this.action, this.onBack, this.heading});

  final String title;

  /// Stands in for the title, e.g. the New and Chats switch.
  final Widget? heading;
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
                Expanded(child: heading != null ? Align(alignment: Alignment.centerLeft, child: heading) : Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                ?action,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      );
}

// ---- phone ----

/// One pane: the destination, with the sidebar as a drawer, and anything
/// opened on top of it as pages, all from [NavCubit]. System back goes
/// through it too.
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
    final toggle = _hasToggle(d);
    return Scaffold(
      drawer: Drawer(
        width: 304,
        child: Builder(builder: (context) => SidebarBody(onNavigate: () => Scaffold.of(context).closeDrawer())),
      ),
      appBar: AppBar(
        centerTitle: true,
        leading: toggle
            ? Builder(builder: (context) => IconButton(key: const Key('open-sidebar'), tooltip: 'Menu', icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(context).openDrawer()))
            : BackButton(onPressed: nav.back),
        title: toggle ? const HomeToggle() : Text(_title(d)),
      ),
      body: Column(
        children: [
          const TailscaleBanner(),
          const UpdateBanner(),
          Expanded(
            child: _Fade(id: d, child: _destinationPage(context, d)),
          ),
        ],
      ),
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
