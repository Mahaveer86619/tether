
import '../../core/result.dart';
import '../entities/entities.dart';

/// Access to the hub: live state, timelines and commands.
abstract interface class HubRepository {
  /// Points the repository at a hub and (re)connects.
  void connect(HubConnection connection);

  /// Leaves the hub: closes the connection and drops everything cached from it.
  Future<void> disconnect();

  void retryNow();

  /// Whether the app is in the foreground; see [HubSocket.setPresence].
  void setActive({required bool active});

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
  Future<Result<String>> sendMessage(String sessionId, String text, {bool fork = false, List<String> attachments = const [], String clientId = ''});

  /// Has the hub keep a copy of the session's transcript, or stop.
  Future<Result<void>> setGlobal(String sessionId, {required bool global});

  /// Continues a global session on the hub's machine; returns the new id.
  Future<Result<String>> continueOnHub(String sessionId, String text);

  /// Starts a chat and its first session; see docs/chats.md.
  Future<Result<Chat>> createChat(NewChatRequest request);

  /// Makes a chat of a session that has none, or returns the one it's in.
  Future<Result<Chat>> chatForSession(String sessionId);

  /// Renames a chat; an empty [title] lets the hub name it again.
  Future<Result<Chat>> renameChat(String chatId, String title);

  Future<Result<Chat>> setChatArchived(String chatId, {required bool archived});

  /// Sends to the chat's active session; returns the session that got it.
  Future<Result<String>> sendToChat(String chatId, String text, {List<String> attachments = const [], String clientId = ''});

  /// Records where the chat works; with [move], carries the conversation
  /// over to a new session there.
  Future<Result<Chat>> setChatTarget(String chatId, ChatTarget target, {bool move = true, String text = ''});

  /// Adds a session to a chat, or with [unlink] takes it out.
  Future<Result<Chat>> linkSession(String chatId, String sessionId, {bool unlink = false});

  Future<Result<ChatContext>> chatContext(String chatId);

  /// Folders a chat could run in, ranked for [prompt].
  Future<Result<TargetSuggestions>> targetSuggestions(String prompt);

  Future<Result<List<int>>> artifactBytes(String id);

  /// A link that works without a token for an hour.
  Future<Result<String>> artifactLink(String id);
  Future<Result<void>> deleteArtifact(String id);

  Future<Result<List<Codebase>>> codebases();

  /// Asks the codebase's device to send the hub a fresh copy.
  Future<Result<void>> snapshotCodebase(String id);

  /// Pages sessions made, newest first; [session] empty means all of them.
  Future<Result<List<HostedPage>>> pages({String session = ''});

  /// Stops Claude's current turn; the session stays open.
  Future<Result<void>> interrupt(String sessionId);

  /// Ends a session the agent hosts (tmux or headless).
  Future<Result<void>> endSession(String sessionId);

  /// Shares app settings with every connected client.
  Future<Result<void>> savePreferences(Appearance appearance);

  /// Folders on each machine that new projects are created in.
  Future<Result<List<WorkspaceRoot>>> workspaces();

  /// Adds or removes a workspace root; returns them all.
  Future<Result<List<WorkspaceRoot>>> setWorkspaceRoot(WorkspaceRoot root, {required bool remove});

  /// Token usage per machine and session.
  Future<Result<UsageSummary>> usage();

  /// The apps connected to the hub now. A hub from before 0.15 has no list.
  Future<Result<List<ConnectedClient>>> clients();

  /// The machines on the hub's tailnet, and which run Tether.
  Future<Result<List<TailnetDevice>>> tailnet();

  /// A one-time code another device can pair with.
  Future<Result<PairingInvite>> createPairingInvite();

  Future<Result<List<PairedDevice>>> listDevices();

  /// Revokes a paired device; its token stops working at once.
  Future<Result<void>> revokeDevice(String id);

  /// Trades a pairing code for this device's own token.
  Future<Result<String>> pair({
    required String url,
    required String code,
    required String fingerprint,
    required String name,
    required String platform,
  });

  /// Marks a session done (or not) on the hub, for every client.
  Future<Result<void>> setArchived(String sessionId, {required bool archived});

  /// [answers] answer a question: each question's text to the chosen labels or the user's own words.
  /// [option] picks a prompt's choice (1-based); 0 takes the one selected.
  Future<Result<void>> decideApproval(String approvalId, {required bool allow, String message = '', Map<String, String> answers = const {}, int option = 0});

  /// Switches the session's permission mode; with [revertAfter], the hub
  /// puts the current one back after that long.
  Future<Result<void>> setMode(String sessionId, PermissionMode mode, {Duration? revertAfter});

  /// Reads the session's terminal on its machine.
  Future<Result<ScreenSnapshot>> screen(String sessionId);

  /// Presses keys (Enter, Escape, Up, Down, Left, Right, Tab, BTab, Space,
  /// Backspace or one character) in the session's terminal, then types [text].
  Future<Result<void>> sendKeys(String sessionId, List<String> keys, {String text = ''});

  Future<void> dispose();
}

/// Files moving between this device and the hub's artifact store, with
/// progress. Files are streamed from and to disk, never held in memory.
abstract interface class TransferRepository {
  /// Emits the current transfers immediately, then every change.
  Stream<Map<String, Transfer>> watch();

  Map<String, Transfer> get current;

  /// Downloads the artifact and saves it where the user can find it,
  /// after checking its sha256.
  Future<Result<void>> download(Artifact artifact);

  Future<Result<void>> pause(String id);
  Future<Result<void>> resume(String id);
  Future<Result<void>> cancel(String id);

  /// Forgets a finished transfer.
  void dismiss(String id);

  /// Uploads [file], resuming after dropped connections. With a [session]
  /// it's attached to that session; [deliver] also puts it in the session's
  /// folder now rather than with the next message.
  Future<Result<Artifact>> upload(LocalFile file, {String session = '', String note = '', bool deliver = false});
}

abstract interface class SettingsRepository {
  Future<Result<HubConnection>> loadConnection();
  Future<Result<void>> saveConnection(HubConnection connection);

  /// Forgets the hub address and token.
  Future<Result<void>> clearConnection();
  /// Unsent text from a message box; empty when there is none.
  Future<String> loadDraft(String key);
  Future<void> saveDraft(String key, String text);

  /// Messages not yet seen in a session's timeline; see [OutboxEntry].
  Future<List<OutboxEntry>> loadOutbox(String session);
  Future<void> saveOutbox(String session, List<OutboxEntry> entries);

  Future<Appearance> loadAppearance();
  Future<Result<void>> saveAppearance(Appearance appearance);
}

/// Releases of the app: finding one, fetching it, installing it.
abstract interface class UpdateRepository {
  /// This platform's key in a release (android, windows), or null where
  /// the app can't update itself.
  String? get platform;

  /// The newest release the hub knows of; null when there's none.
  Future<Result<Release?>> latest();

  /// Downloads [asset], checks its sha256, and returns the file's path.
  /// A file already downloaded and intact is reused.
  Future<Result<String>> download(UpdateAsset asset, {void Function(int received, int total)? onProgress});

  /// Starts installing a downloaded file. On Windows the app must then exit
  /// for the update to be applied.
  Future<Result<void>> install(String path);

  /// The version the user chose to skip, or empty.
  Future<String> skipped();
  Future<void> skip(String version);

  /// The last version the user was notified about, so it's said once.
  Future<String> notified();
  Future<void> setNotified(String version);

  Future<void> notify(String title, String body);
}
