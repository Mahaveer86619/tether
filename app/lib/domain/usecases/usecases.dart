import 'package:flutter/material.dart' show ThemeMode;

import '../../core/error/failures.dart';
import '../../core/result.dart';
import '../entities/entities.dart';
import '../repositories/repositories.dart';

// Use cases are the only way the presentation layer touches repositories.
// Input rules live here so every screen applies them the same way.

class WatchHub {
  const WatchHub(this._hub);
  final HubRepository _hub;
  Stream<HubSnapshot> call() => _hub.watchHub();
}

class WatchTimeline {
  const WatchTimeline(this._hub);
  final HubRepository _hub;
  Stream<TimelineSnapshot> call(String sessionId) => _hub.watchTimeline(sessionId);
}

class RetryConnection {
  const RetryConnection(this._hub);
  final HubRepository _hub;
  void call() => _hub.retryNow();
}

class CreateSession {
  const CreateSession(this._hub);
  final HubRepository _hub;

  Future<Result<String>> call(NewSessionRequest r) async {
    if (r.node.isEmpty) return const Err(ValidationFailure('Pick a device to run the session on.'));
    final prompt = r.prompt.trim();
    if (prompt.isEmpty) return const Err(ValidationFailure('Write a prompt to start with.'));
    final node = _hub.current.nodes[r.node];
    if (node != null && !node.online) return const Err(NodeOfflineFailure());
    return _hub.createSession(NewSessionRequest(
      node: r.node,
      prompt: prompt,
      cwd: r.cwd.trim(),
      model: r.model,
      permissionMode: r.permissionMode,
    ));
  }
}

class SendMessage {
  const SendMessage(this._hub);
  final HubRepository _hub;

  /// Sends [text] to the session, or with [fork] to a new fork of it.
  /// Returns the id of the session that got the message.
  Future<Result<String>> call(String sessionId, String text, {bool fork = false}) async {
    final t = text.trim();
    if (t.isEmpty) return const Err(ValidationFailure('Message is empty.'));
    final session = _hub.current.sessions[sessionId];
    if (session == null) return Err(NotFoundFailure('session $sessionId'));
    if (!fork && !session.acceptsInput) return const Err(TerminalActiveFailure());
    return _hub.sendMessage(sessionId, t, fork: fork);
  }
}

class InterruptSession {
  const InterruptSession(this._hub);
  final HubRepository _hub;
  Future<Result<void>> call(String sessionId) => _hub.interrupt(sessionId);
}

class EndSession {
  const EndSession(this._hub);
  final HubRepository _hub;

  Future<Result<void>> call(String sessionId) async {
    final s = _hub.current.sessions[sessionId];
    if (s != null && s.host == SessionHost.terminal) {
      return const Err(ValidationFailure('This session is open in your terminal. Interrupt it, or close it there.'));
    }
    return _hub.endSession(sessionId);
  }
}

class DecideApproval {
  const DecideApproval(this._hub);
  final HubRepository _hub;
  Future<Result<void>> call(String approvalId, {required bool allow}) => _hub.decideApproval(approvalId, allow: allow);
}

class LoadConnection {
  const LoadConnection(this._settings);
  final SettingsRepository _settings;
  Future<Result<HubConnection>> call() => _settings.loadConnection();
}

class SaveConnection {
  const SaveConnection(this._settings, this._hub);
  final SettingsRepository _settings;
  final HubRepository _hub;

  Future<Result<HubConnection>> call(String url, String token) async {
    final normalized = normalizeHubUrl(url);
    if (normalized == null) return const Err(ValidationFailure('Enter the hub address, e.g. 100.64.0.1 or ws://100.64.0.1:7420/ws.'));
    if (token.trim().isEmpty) return const Err(ValidationFailure('Enter the hub token.'));
    final conn = HubConnection(url: normalized, token: token.trim());
    final saved = await _settings.saveConnection(conn);
    return saved.fold(Err.new, (_) {
      _hub.connect(conn);
      return Ok(conn);
    });
  }
}

class ThemeSettings {
  const ThemeSettings(this._settings);
  final SettingsRepository _settings;
  Future<ThemeMode> load() => _settings.loadThemeMode();
  Future<Result<void>> save(ThemeMode mode) => _settings.saveThemeMode(mode);
}

/// Accepts "100.64.0.1", "100.64.0.1:7420", "http://…" or a full ws:// URL;
/// returns null when it can't be a hub address.
String? normalizeHubUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'ws://$s';
  final u = Uri.tryParse(s);
  if (u == null || u.host.isEmpty) return null;
  final scheme = switch (u.scheme) { 'http' || 'ws' => 'ws', 'https' || 'wss' => 'wss', _ => null };
  if (scheme == null) return null;
  // Uri hides a default port (":443" on https), so read what was typed.
  final typed = RegExp(r'^[a-z]+://[^/]*:(\d+)').firstMatch(s);
  return Uri(
    scheme: scheme,
    host: u.host,
    port: typed != null ? int.parse(typed.group(1)!) : (scheme == 'wss' ? 443 : 7420),
    path: u.path.isEmpty || u.path == '/' ? '/ws' : u.path,
  ).toString();
}
