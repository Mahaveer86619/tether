import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';

/// The app's top-level places, in the order navigation shows them.
enum Destination { home, chats, devices, activity, files, routines, usage, settings }

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
  const NavState({this.destination = Destination.home, this.stack = const []});

  final Destination destination;

  /// Screens open on top of the destination, newest last.
  final List<NavEntry> stack;

  NavEntry? get top => stack.lastOrNull;

  /// The chat or session on screen, for highlighting it in lists.
  String get selectedChat => switch (top) { ChatEntry(:final chatId) => chatId, _ => '' };
  String get selectedSession => switch (top) { SessionEntry(:final sessionId) => sessionId, _ => '' };
  String get selectedNode => switch (top) { NodeEntry(:final node) => node, _ => '' };

  /// Nothing left to go back to: Back leaves the app.
  bool get atRoot => stack.isEmpty && destination == Destination.home;

  @override
  List<Object?> get props => [destination, stack];
}

/// The one place navigation state lives. Every layout renders from it and
/// every screen moves through it; screens keep no navigation of their own.
///
/// The rules, as on any phone: a destination is a place, not a step, so
/// switching between them leaves nothing to go back to. Screens opened on
/// top of a destination (a chat, a device) are steps, and Back pops them.
/// With nothing open, Back from any destination goes Home, and from Home
/// leaves the app.
class NavCubit extends Cubit<NavState> {
  NavCubit({required this._watchHub}) : super(const NavState());

  final WatchHub _watchHub;

  HubSnapshot get _hub => _watchHub.current;

  /// Switches to a destination, closing whatever was open on top.
  void select(Destination d) {
    if (d == state.destination && state.stack.isEmpty) return;
    emit(NavState(destination: d));
  }

  /// Opens a screen on top of the current one.
  void push(NavEntry e) {
    if (state.top == e) return;
    emit(NavState(destination: state.destination, stack: [...state.stack, e]));
  }

  /// Opens a screen in place of whatever was open, e.g. from the sidebar.
  void show(NavEntry e) {
    if (state.stack.length == 1 && state.top == e) return;
    emit(NavState(destination: state.destination, stack: [e]));
  }

  /// Swaps the top screen without a Back step, e.g. a new chat becoming
  /// the chat it started.
  void replaceTop(NavEntry e) {
    final stack = [...state.stack];
    if (stack.isNotEmpty) stack.removeLast();
    emit(NavState(destination: state.destination, stack: [...stack, e]));
  }

  /// Goes back one step; false when there's nowhere to go.
  bool back() {
    if (state.stack.isNotEmpty) {
      emit(NavState(destination: state.destination, stack: state.stack.sublist(0, state.stack.length - 1)));
      return true;
    }
    if (state.destination != Destination.home) {
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
