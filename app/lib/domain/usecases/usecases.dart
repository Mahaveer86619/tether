
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
    if (r.node.isEmpty && !r.scratch) return const Err(ValidationFailure('Pick a device to run the session on.'));
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
      createCwd: r.createCwd,
      scratch: r.scratch,
      attachments: r.attachments,
    ));
  }
}

class SetSessionGlobal {
  const SetSessionGlobal(this._hub);
  final HubRepository _hub;
  Future<Result<void>> call(String sessionId, {required bool global}) => _hub.setGlobal(sessionId, global: global);
}

class ContinueOnHub {
  const ContinueOnHub(this._hub);
  final HubRepository _hub;

  Future<Result<String>> call(String sessionId, String text) async {
    if (text.trim().isEmpty) return const Err(ValidationFailure('Write the first message for the hub to continue with.'));
    return _hub.continueOnHub(sessionId, text.trim());
  }
}

/// The artifact store: upload, fetch, share, delete.
class Artifacts {
  const Artifacts(this._hub);
  final HubRepository _hub;

  Future<Result<List<int>>> bytes(String id) => _hub.artifactBytes(id);
  Future<Result<String>> link(String id) => _hub.artifactLink(id);
  Future<Result<void>> delete(String id) => _hub.deleteArtifact(id);
  Future<Result<List<HostedPage>>> pages({String session = ''}) => _hub.pages(session: session);
}

/// Downloads to this device and uploads from it, with progress.
class Transfers {
  const Transfers(this._transfers);
  final TransferRepository _transfers;

  Stream<Map<String, Transfer>> watch() => _transfers.watch();
  Map<String, Transfer> get current => _transfers.current;
  Future<Result<void>> download(Artifact a) => _transfers.download(a);
  Future<Result<void>> pause(String id) => _transfers.pause(id);
  Future<Result<void>> resume(String id) => _transfers.resume(id);
  Future<Result<void>> cancel(String id) => _transfers.cancel(id);
  void dismiss(String id) => _transfers.dismiss(id);

  /// Uploads a file; with a [session] it's attached to it, and put in the
  /// session's folder right away unless it's going with a message.
  Future<Result<Artifact>> upload(LocalFile file, {String session = '', String note = '', bool forMessage = false}) =>
      _transfers.upload(file, session: session, note: note.trim(), deliver: session.isNotEmpty && !forMessage);
}

class SendMessage {
  const SendMessage(this._hub);
  final HubRepository _hub;

  /// Sends [text] to the session, or with [fork] to a new fork of it.
  /// Returns the id of the session that got the message.
  Future<Result<String>> call(String sessionId, String text, {bool fork = false, List<String> attachments = const [], String clientId = ''}) async {
    if (check(sessionId, text, fork: fork, attachments: attachments) case final f?) return Err(f);
    return _hub.sendMessage(sessionId, wording(text), fork: fork, attachments: attachments, clientId: clientId);
  }

  /// Why the message can't go, before anything is sent.
  Failure? check(String sessionId, String text, {bool fork = false, List<String> attachments = const []}) {
    if (text.trim().isEmpty && attachments.isEmpty) return const ValidationFailure('Message is empty.');
    final session = _hub.current.sessions[sessionId];
    if (session == null) return NotFoundFailure('session $sessionId');
    if (!fork && !session.acceptsInput) return const TerminalActiveFailure();
    return null;
  }

  /// The text as sent: files alone still need a sentence.
  static String wording(String text) => text.trim().isEmpty ? 'Have a look at the attached files.' : text.trim();
}

/// Messages from this device on their way into a session, kept on the
/// device until the timeline shows them (see [OutboxEntry]).
class Outbox {
  const Outbox(this._settings);
  final SettingsRepository _settings;

  /// A send the app was in the middle of when it closed may or may not have
  /// gone: it's offered for a retry, which the hub sends at most once.
  Future<List<OutboxEntry>> load(String session) async => [
        for (final e in await _settings.loadOutbox(session))
          e.state == OutboxState.sending ? e.copyWith(state: OutboxState.failed, error: 'The app closed while sending it.') : e,
      ];

  Future<void> save(String session, List<OutboxEntry> entries) => _settings.saveOutbox(session, entries);

  /// The entries the timeline doesn't show yet. A message counts as shown
  /// once a user item carries its client id or, from a hub that doesn't
  /// stamp ids, has its text among the latest messages.
  static List<OutboxEntry> pending(List<OutboxEntry> entries, List<TimelineItem> items) {
    final users = [
      for (final i in items)
        if (i.whichKind() == TimelineItem_Kind.user && !i.user.queued) i,
    ];
    final recent = users.length > 10 ? users.sublist(users.length - 10) : users;
    final claimed = <String>{};
    bool shown(OutboxEntry e) {
      if (e.state != OutboxState.sent) return false;
      for (final u in users) {
        if (u.user.clientId == e.id) return true;
      }
      for (final u in recent) {
        if (u.user.clientId.isEmpty && !claimed.contains(u.itemId) && sameMessage(SendMessage.wording(e.text), u.user.text)) {
          claimed.add(u.itemId);
          return true;
        }
      }
      return false;
    }

    return [for (final e in entries) if (!shown(e)) e];
  }

  /// Whether the hub already shows the entry as queued, so it needn't be
  /// shown twice.
  static bool queuedOnHub(OutboxEntry e, List<TimelineItem> items) => items.any((i) =>
      i.whichKind() == TimelineItem_Kind.user &&
      i.user.queued &&
      (i.user.clientId == e.id || sameMessage(SendMessage.wording(e.text), i.user.text)));

  /// The same message as sent and as the transcript has it: the agent adds
  /// the list of attached files, and Windows line endings.
  static bool sameMessage(String sent, String got) {
    String norm(String s) => s.replaceAll('\r\n', '\n').trim();
    final a = norm(sent), b = norm(got);
    return a == b || b.startsWith('$a\n\nAttached files');
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

class SetSessionArchived {
  const SetSessionArchived(this._hub);
  final HubRepository _hub;
  Future<Result<void>> call(String sessionId, {required bool archived}) => _hub.setArchived(sessionId, archived: archived);
}

class DecideApproval {
  const DecideApproval(this._hub);
  final HubRepository _hub;
  Future<Result<void>> call(String approvalId, {required bool allow, String message = '', Map<String, String> answers = const {}, int option = 0}) =>
      _hub.decideApproval(approvalId, allow: allow, message: message, answers: answers, option: option);
}

/// A session's terminal: its screen and key presses, for dialogs Tether
/// can't turn into a card.
class TerminalControl {
  const TerminalControl(this._hub);
  final HubRepository _hub;

  Future<Result<ScreenSnapshot>> screen(String sessionId) => _hub.screen(sessionId);

  Future<Result<void>> press(String sessionId, List<String> keys, {String text = ''}) {
    if (keys.isEmpty && text.isEmpty) return Future.value(const Err(ValidationFailure('Nothing to send.')));
    return _hub.sendKeys(sessionId, keys, text: text);
  }
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

  Future<Result<HubConnection>> call(String url, String token, {String fingerprint = ''}) async {
    final normalized = normalizeHubUrl(url);
    if (normalized == null) return const Err(ValidationFailure('Enter the hub address, e.g. 100.64.0.1 or ws://100.64.0.1:7420/ws.'));
    if (token.trim().isEmpty) return const Err(ValidationFailure('Enter the hub token.'));
    final conn = HubConnection(url: normalized, token: token.trim(), fingerprint: fingerprint);
    final saved = await _settings.saveConnection(conn);
    return saved.fold(Err.new, (_) {
      _hub.connect(conn);
      return Ok(conn);
    });
  }
}

/// Connects without a token, for a hub that trusts its owner's tailnet
/// machines (`-trust-tailnet`).
class ConnectOverTailnet {
  const ConnectOverTailnet(this._settings, this._hub);
  final SettingsRepository _settings;
  final HubRepository _hub;

  Future<Result<HubConnection>> call(String url) async {
    final normalized = normalizeHubUrl(url);
    if (normalized == null) return const Err(ValidationFailure('Enter the Tailscale name or address of the hub, e.g. minipc or 100.64.0.1.'));
    final conn = HubConnection(url: normalized, token: '', viaTailnet: true);
    final saved = await _settings.saveConnection(conn);
    return saved.fold(Err.new, (_) {
      _hub.connect(conn);
      return Ok(conn);
    });
  }
}

/// Pairs this device with a hub using a one-time code, then connects with
/// the device token it gets back.
class PairThisDevice {
  const PairThisDevice(this._save, this._hub, {required this.name, required this.platform});
  final SaveConnection _save;
  final HubRepository _hub;
  final String name, platform;

  Future<Result<HubConnection>> call(String url, String code, {String fingerprint = ''}) async {
    final normalized = normalizeHubUrl(url);
    if (normalized == null) return const Err(ValidationFailure('Enter the hub address, e.g. 100.64.0.1 or ws://100.64.0.1:7420/ws.'));
    if (code.trim().isEmpty) return const Err(ValidationFailure('Enter the pairing code.'));
    final token = await _hub.pair(url: normalized, code: code.trim(), fingerprint: fingerprint, name: name, platform: platform);
    return token.fold(Err.new, (t) => _save(normalized, t, fingerprint: fingerprint));
  }
}

class SharePreferences {
  const SharePreferences(this._hub);
  final HubRepository _hub;
  Future<Result<void>> call(Appearance appearance) => _hub.savePreferences(appearance);
}

class Codebases {
  const Codebases(this._hub);
  final HubRepository _hub;

  Future<Result<List<Codebase>>> list() => _hub.codebases();
  Future<Result<void>> snapshot(String id) => _hub.snapshotCodebase(id);
}

class LoadWorkspaces {
  const LoadWorkspaces(this._hub);
  final HubRepository _hub;
  Future<Result<List<WorkspaceRoot>>> call() => _hub.workspaces();
}

class SetWorkspaceRoot {
  const SetWorkspaceRoot(this._hub);
  final HubRepository _hub;

  Future<Result<List<WorkspaceRoot>>> call(String node, String path, {bool remove = false}) async {
    final p = path.trim().replaceAll(RegExp(r'[\\/]+$'), '');
    if (node.isEmpty || p.isEmpty) return const Err(ValidationFailure('Pick a device and enter a folder.'));
    return _hub.setWorkspaceRoot(WorkspaceRoot(node: node, path: p), remove: remove);
  }
}

/// A new project folder's full path, or null when the name isn't a plain
/// folder name.
String? projectPath(String root, String name, {required bool windows}) {
  final n = name.trim();
  if (n.isEmpty || n == '.' || n == '..' || n.contains(RegExp(r'[\\/:*?"<>|]'))) return null;
  final sep = windows ? '\\' : '/';
  return root.endsWith(sep) ? '$root$n' : '$root$sep$n';
}

class LoadUsage {
  const LoadUsage(this._hub);
  final HubRepository _hub;
  Future<Result<UsageSummary>> call() => _hub.usage();
}

class LoadTailnet {
  const LoadTailnet(this._hub);
  final HubRepository _hub;
  Future<Result<List<TailnetDevice>>> call() => _hub.tailnet();
}

class CreatePairingInvite {
  const CreatePairingInvite(this._hub);
  final HubRepository _hub;
  Future<Result<PairingInvite>> call() => _hub.createPairingInvite();
}

class ListDevices {
  const ListDevices(this._hub);
  final HubRepository _hub;
  Future<Result<List<PairedDevice>>> call() => _hub.listDevices();
}

class RevokeDevice {
  const RevokeDevice(this._hub);
  final HubRepository _hub;
  Future<Result<void>> call(String id) => _hub.revokeDevice(id);
}

/// Unpairs this app: its token is revoked on the hub, then the hub address
/// and token are forgotten here, back to the connect screen.
class DisconnectThisDevice {
  const DisconnectThisDevice(this._settings, this._hub);
  final SettingsRepository _settings;
  final HubRepository _hub;

  Future<Result<void>> call() async {
    final id = _hub.current.deviceId;
    // Forget it here even if the hub can't be reached; it can still be revoked from another device.
    if (id.isNotEmpty) await _hub.revokeDevice(id);
    final cleared = await _settings.clearConnection();
    await _hub.disconnect();
    return cleared;
  }
}

/// Unsent message text per box (a session id, or "quick-start").
class Drafts {
  const Drafts(this._settings);
  final SettingsRepository _settings;
  Future<String> load(String key) => _settings.loadDraft(key);
  Future<void> save(String key, String text) => _settings.saveDraft(key, text);
}

class ThemeSettings {
  const ThemeSettings(this._settings);
  final SettingsRepository _settings;
  Future<Appearance> load() => _settings.loadAppearance();
  Future<Result<void>> save(Appearance appearance) => _settings.saveAppearance(appearance);
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

/// Reads a `tether://pair?hub=…&code=…&fp=…` link from a QR code.
({String url, String code, String fingerprint})? parsePairingLink(String text) {
  final u = Uri.tryParse(text.trim());
  if (u == null || u.scheme != 'tether' || u.host != 'pair') return null;
  final hub = u.queryParameters['hub'] ?? '', code = u.queryParameters['code'] ?? '';
  if (hub.isEmpty || code.isEmpty) return null;
  return (url: hub, code: code, fingerprint: u.queryParameters['fp'] ?? '');
}
