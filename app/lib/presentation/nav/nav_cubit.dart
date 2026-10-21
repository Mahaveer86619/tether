import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

/// The app's top-level places, in the order navigation shows them.
enum Destination { chats, monitor, sessions, devices, activity, files, usage, settings }

/// A screen opened on top of a destination.
sealed class NavEntry extends Equatable {
  const NavEntry();
}

/// The composer for a new chat.
class NewChatEntry extends NavEntry {
  const NewChatEntry({this.node = ''});

  /// A device to start on, when opened from its page.
  final String node;

  @override
  List<Object?> get props => [node];
}

class ChatEntry extends NavEntry {
  const ChatEntry(this.chatId);
  final String chatId;

  @override
  List<Object?> get props => [chatId];
}

class SessionEntry extends NavEntry {
  const SessionEntry(this.sessionId);
  final String sessionId;

  @override
  List<Object?> get props => [sessionId];
}

class NodeEntry extends NavEntry {
  const NodeEntry(this.node);
  final String node;

  @override
  List<Object?> get props => [node];
}

class NavState extends Equatable {
  const NavState({this.destination = Destination.chats, this.stack = const [], this.history = const []});

  final Destination destination;

  /// Screens open on top of the destination, newest last.
  final List<NavEntry> stack;

  /// Where Back goes: earlier states, newest last.
  final List<NavState> history;

  NavEntry? get top => stack.lastOrNull;

  /// The chat or session on screen, for highlighting it in lists.
  String get selectedChat => switch (top) { ChatEntry(:final chatId) => chatId, _ => '' };
  String get selectedSession => switch (top) { SessionEntry(:final sessionId) => sessionId, _ => '' };
  String get selectedNode => switch (top) { NodeEntry(:final node) => node, _ => '' };

  /// Nothing left to go back to: Back leaves the app.
  bool get atRoot => history.isEmpty && stack.isEmpty && destination == Destination.chats;

  NavState _without() => NavState(destination: destination, stack: stack);

  @override
  List<Object?> get props => [destination, stack, history];
}

/// The one place navigation state lives. Every layout renders from it and
/// every screen moves through it; screens keep no navigation of their own.
class NavCubit extends Cubit<NavState> {
  NavCubit({required this._watchHub}) : super(const NavState());

  final WatchHub _watchHub;
  static const _maxHistory = 50;

  HubSnapshot get _hub => _watchHub.current;

  void _go(NavState next) {
    if (next.destination == state.destination && _sameStack(next.stack, state.stack)) return;
    final history = [...state.history, state._without()];
    if (history.length > _maxHistory) history.removeAt(0);
    emit(NavState(destination: next.destination, stack: next.stack, history: history));
  }

  static bool _sameStack(List<NavEntry> a, List<NavEntry> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  /// Switches to a destination, closing whatever was open on top.
  void select(Destination d) => _go(NavState(destination: d));

  /// Opens a screen on top of the current one.
  void push(NavEntry e) {
    if (state.top == e) return;
    _go(NavState(destination: state.destination, stack: [...state.stack, e]));
  }

  /// Opens a screen in place of whatever was open, e.g. from the sidebar.
  void show(NavEntry e) {
    if (state.stack.length == 1 && state.top == e) return;
    _go(NavState(destination: state.destination, stack: [e]));
  }

  /// Swaps the top screen without a Back step, e.g. a new chat becoming
  /// the chat it started.
  void replaceTop(NavEntry e) {
    final stack = [...state.stack];
    if (stack.isNotEmpty) stack.removeLast();
    emit(NavState(destination: state.destination, stack: [...stack, e], history: state.history));
  }

  /// Goes back one step; false when there's nowhere to go.
  bool back() {
    if (state.history.isNotEmpty) {
      final history = [...state.history];
      final prev = history.removeLast();
      emit(NavState(destination: prev.destination, stack: prev.stack, history: history));
      return true;
    }
    if (state.stack.isNotEmpty) {
      emit(NavState(destination: state.destination, stack: state.stack.sublist(0, state.stack.length - 1)));
      return true;
    }
    if (state.destination != Destination.chats) {
      emit(const NavState());
      return true;
    }
    return false;
  }

  void newChat({String node = '', bool replace = false}) => replace ? show(NewChatEntry(node: node)) : push(NewChatEntry(node: node));

  void openChat(String id, {bool replace = false}) => replace ? show(ChatEntry(id)) : push(ChatEntry(id));

  /// Opens a session as its chat when it's that chat's active session, so
  /// the user stays in the conversation; any other session opens on its own.
  void openSession(String id, {bool replace = false}) {
    final chat = _hub.chatOf(id);
    final NavEntry e = chat != null && chat.activeSession == id ? ChatEntry(chat.id) : SessionEntry(id);
    replace ? show(e) : push(e);
  }

  void openNode(String node) => push(NodeEntry(node));
}
