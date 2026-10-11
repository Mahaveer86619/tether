import 'package:flutter/material.dart' show ThemeMode;

import '../../core/result.dart';
import '../entities/entities.dart';

/// Access to the hub: live state, timelines and commands.
abstract interface class HubRepository {
  /// Points the repository at a hub and (re)connects.
  void connect(HubConnection connection);

  void retryNow();

  /// Emits the current snapshot immediately, then every change.
  Stream<HubSnapshot> watchHub();

  HubSnapshot get current;

  /// Emits the session's timeline immediately, then every change, until the
  /// subscription is cancelled.
  Stream<TimelineSnapshot> watchTimeline(String sessionId);

  /// Returns the new session's id.
  Future<Result<String>> createSession(NewSessionRequest request);

  /// Returns the session that received the message: the same one, or the
  /// new fork when [fork] is set.
  Future<Result<String>> sendMessage(String sessionId, String text, {bool fork = false});

  /// Stops Claude's current turn; the session stays open.
  Future<Result<void>> interrupt(String sessionId);

  /// Ends a session the agent hosts (tmux or headless).
  Future<Result<void>> endSession(String sessionId);

  /// Marks a session done (or not) on the hub, for every client.
  Future<Result<void>> setArchived(String sessionId, {required bool archived});

  Future<Result<void>> decideApproval(String approvalId, {required bool allow, String message = ''});

  Future<void> dispose();
}

abstract interface class SettingsRepository {
  Future<Result<HubConnection>> loadConnection();
  Future<Result<void>> saveConnection(HubConnection connection);
  Future<ThemeMode> loadThemeMode();
  Future<Result<void>> saveThemeMode(ThemeMode mode);
}
