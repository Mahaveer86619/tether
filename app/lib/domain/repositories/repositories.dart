
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

  /// Starts a chat and its first session; see docs/architecture/chats.md.
  Future<Result<Chat>> createChat(NewChatRequest request);

  /// Makes a chat of a session that has none, or returns the one it's in.
  Future<Result<Chat>> chatForSession(String sessionId);

  /// Renames a chat; an empty [title] lets the hub name it again.
  Future<Result<Chat>> renameChat(String chatId, String title);

  Future<Result<Chat>> setChatArchived(String chatId, {required bool archived});

  /// Deletes a chat. The sessions it held stay, listed on their own.
  Future<Result<void>> deleteChat(String chatId);

  /// A token that opens only the hub's notifications, for [installId], and the
  /// tunnel's address.
  Future<Result<NotifyAccess>> notifyAccess(String installId);

  /// Asks the hub to send a test notification.
  Future<Result<void>> sendTestNotification();

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

  /// Whether a chat keeps its project folder in step on another device.
  Future<Result<ChatRemote>> chatRemote(String chatId);
  Future<Result<void>> setChatRemote(String chatId, {required bool on, String node = '', bool allowSecrets = false});
  Future<Result<List<ProjectFile>>> projectFiles(String repo);
  Future<Result<void>> putProjectFile(String repo, String path, String content);
  Future<Result<void>> deleteProjectFile(String repo, String path);
  Future<Result<List<SkillInfo>>> skills();
  Future<Result<SkillDetail>> skill(String name);
  Future<Result<SkillInfo>> decideSkill(String name, {required SkillDecision decision, int version = 0});

  /// Starts a session that drafts a skill for the routine; returns its id.
  Future<Result<String>> draftSkill(String example);

  /// Routines that keep coming back in the hub's history; [days] 0 means all of it.
  Future<Result<RoutineReport>> routines({int days = 30, int runs = 3});

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

/// This device's Tailscale: checking it, and bringing it up where the device
/// allows (the desktop can; a phone can only be asked to, or opened).
abstract interface class TailscaleRepository {
  /// Whether the app can start Tailscale itself rather than only open it.
  bool get canStart;

  Future<TailscaleStatus> status();

  /// Brings Tailscale up and reports each change on the way, ending with the
  /// last status: running, or why it isn't. It can take minutes when the owner
  /// has to sign in.
  Stream<TailscaleStatus> start();

  /// Opens the Tailscale app, where there is one.
  Future<void> openApp();

  /// The other devices on the tailnet, when this platform can list them
  /// (the desktop can; a phone's Tailscale app does not say).
  Future<List<TailnetPeer>> peers();
}

/// What a phone does to be told things with the app closed: a background
/// service that asks the hub for news. Only Android has one.
abstract interface class NotifyDevice {
  bool get available;

  /// Tells the service where to listen (tailnet address first, then the
  /// tunnel), with which token, for which kinds, or stops it.
  Future<void> configure({required bool enabled, required String token, required List<String> urls, required Set<NotifyKind> kinds});

  /// The app is on screen, so the service leaves showing news to it.
  Future<void> setActive(bool active);

  Future<bool> permitted();
  Future<void> askPermission();
  Future<NotifyStatus> status();
}

/// Asks an address whether a Tether hub answers there.
abstract interface class HubProbe {
  /// A hub's hello, or null when nothing answers in time or it is not a hub.
  Future<HubHello?> hello(String host, {int port = 7420});
}

abstract interface class SettingsRepository {
  Future<Result<HubConnection>> loadConnection();
  Future<Result<void>> saveConnection(HubConnection connection);

  /// Forgets the hub address and token.
  Future<Result<void>> clearConnection();

  /// Hubs connected to before, newest first.
  Future<List<KnownHub>> loadKnownHubs();
  Future<void> rememberHub(KnownHub hub);
  Future<void> forgetHub(String url);

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
/// The Windows app's own updater (WinSparkle): it checks the signed feed,
/// shows its own dialogs, runs the installer and restarts the app.
abstract interface class DesktopUpdater {
  bool get available;

  /// Points it at the feed and starts the scheduled checks.
  Future<void> start();

  /// Checks now, with its dialog.
  Future<void> checkNow();
}

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
