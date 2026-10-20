// This is a generated file - do not edit.
//
// Generated from tether/v1/tether.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'render.pb.dart' as $0;
import 'tether.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'tether.pbenum.dart';

enum Frame_Body {
  clientHello,
  subscribe,
  unsubscribe,
  createSession,
  sendMessage,
  interruptSession,
  approvalDecision,
  stopSession,
  welcome,
  ack,
  error,
  nodeStatus,
  sessionInfo,
  timeline,
  approvalRequested,
  approvalResolved,
  sessionRemoved,
  preferences,
  artifactAdded,
  agentHello,
  sessionIndex,
  rawEvents,
  usageReport,
  planUsage,
  agentCommand,
  notSet
}

/// Every WebSocket message is one Frame, encoded with protojson.
class Frame extends $pb.GeneratedMessage {
  factory Frame({
    $core.int? v,
    $core.String? id,
    $core.String? replyTo,
    $fixnum.Int64? seq,
    ClientHello? clientHello,
    Subscribe? subscribe,
    Unsubscribe? unsubscribe,
    CreateSession? createSession,
    SendMessage? sendMessage,
    InterruptSession? interruptSession,
    ApprovalDecision? approvalDecision,
    StopSession? stopSession,
    Welcome? welcome,
    Ack? ack,
    Error? error,
    NodeStatus? nodeStatus,
    SessionInfo? sessionInfo,
    TimelineUpdate? timeline,
    ApprovalRequest? approvalRequested,
    ApprovalResolved? approvalResolved,
    SessionRemoved? sessionRemoved,
    Preferences? preferences,
    Artifact? artifactAdded,
    AgentHello? agentHello,
    SessionIndex? sessionIndex,
    RawEvents? rawEvents,
    UsageReport? usageReport,
    PlanUsage? planUsage,
    AgentCommand? agentCommand,
  }) {
    final result = Frame._();
    if (v != null) result.v = v;
    if (id != null) result.id = id;
    if (replyTo != null) result.replyTo = replyTo;
    if (seq != null) result.seq = seq;
    if (clientHello != null) result.clientHello = clientHello;
    if (subscribe != null) result.subscribe = subscribe;
    if (unsubscribe != null) result.unsubscribe = unsubscribe;
    if (createSession != null) result.createSession = createSession;
    if (sendMessage != null) result.sendMessage = sendMessage;
    if (interruptSession != null) result.interruptSession = interruptSession;
    if (approvalDecision != null) result.approvalDecision = approvalDecision;
    if (stopSession != null) result.stopSession = stopSession;
    if (welcome != null) result.welcome = welcome;
    if (ack != null) result.ack = ack;
    if (error != null) result.error = error;
    if (nodeStatus != null) result.nodeStatus = nodeStatus;
    if (sessionInfo != null) result.sessionInfo = sessionInfo;
    if (timeline != null) result.timeline = timeline;
    if (approvalRequested != null) result.approvalRequested = approvalRequested;
    if (approvalResolved != null) result.approvalResolved = approvalResolved;
    if (sessionRemoved != null) result.sessionRemoved = sessionRemoved;
    if (preferences != null) result.preferences = preferences;
    if (artifactAdded != null) result.artifactAdded = artifactAdded;
    if (agentHello != null) result.agentHello = agentHello;
    if (sessionIndex != null) result.sessionIndex = sessionIndex;
    if (rawEvents != null) result.rawEvents = rawEvents;
    if (usageReport != null) result.usageReport = usageReport;
    if (planUsage != null) result.planUsage = planUsage;
    if (agentCommand != null) result.agentCommand = agentCommand;
    return result;
  }

  Frame._();

  factory Frame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Frame()..mergeFromBuffer(data, registry);
  factory Frame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Frame()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Frame_Body> _Frame_BodyByTag = {
    10: Frame_Body.clientHello,
    11: Frame_Body.subscribe,
    12: Frame_Body.unsubscribe,
    13: Frame_Body.createSession,
    14: Frame_Body.sendMessage,
    15: Frame_Body.interruptSession,
    16: Frame_Body.approvalDecision,
    17: Frame_Body.stopSession,
    30: Frame_Body.welcome,
    31: Frame_Body.ack,
    32: Frame_Body.error,
    33: Frame_Body.nodeStatus,
    34: Frame_Body.sessionInfo,
    35: Frame_Body.timeline,
    36: Frame_Body.approvalRequested,
    37: Frame_Body.approvalResolved,
    38: Frame_Body.sessionRemoved,
    39: Frame_Body.preferences,
    40: Frame_Body.artifactAdded,
    50: Frame_Body.agentHello,
    51: Frame_Body.sessionIndex,
    52: Frame_Body.rawEvents,
    53: Frame_Body.usageReport,
    54: Frame_Body.planUsage,
    60: Frame_Body.agentCommand,
    0: Frame_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Frame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Frame.$_createMessage)
    ..oo(0, [
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
      40,
      50,
      51,
      52,
      53,
      54,
      60
    ])
    ..aI(1, _omitFieldNames ? '' : 'v', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..aOS(3, _omitFieldNames ? '' : 'replyTo')
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<ClientHello>(10, _omitFieldNames ? '' : 'clientHello',
        subBuilder: ClientHello.$_createMessage)
    ..aOM<Subscribe>(11, _omitFieldNames ? '' : 'subscribe',
        subBuilder: Subscribe.$_createMessage)
    ..aOM<Unsubscribe>(12, _omitFieldNames ? '' : 'unsubscribe',
        subBuilder: Unsubscribe.$_createMessage)
    ..aOM<CreateSession>(13, _omitFieldNames ? '' : 'createSession',
        subBuilder: CreateSession.$_createMessage)
    ..aOM<SendMessage>(14, _omitFieldNames ? '' : 'sendMessage',
        subBuilder: SendMessage.$_createMessage)
    ..aOM<InterruptSession>(15, _omitFieldNames ? '' : 'interruptSession',
        subBuilder: InterruptSession.$_createMessage)
    ..aOM<ApprovalDecision>(16, _omitFieldNames ? '' : 'approvalDecision',
        subBuilder: ApprovalDecision.$_createMessage)
    ..aOM<StopSession>(17, _omitFieldNames ? '' : 'stopSession',
        subBuilder: StopSession.$_createMessage)
    ..aOM<Welcome>(30, _omitFieldNames ? '' : 'welcome',
        subBuilder: Welcome.$_createMessage)
    ..aOM<Ack>(31, _omitFieldNames ? '' : 'ack',
        subBuilder: Ack.$_createMessage)
    ..aOM<Error>(32, _omitFieldNames ? '' : 'error',
        subBuilder: Error.$_createMessage)
    ..aOM<NodeStatus>(33, _omitFieldNames ? '' : 'nodeStatus',
        subBuilder: NodeStatus.$_createMessage)
    ..aOM<SessionInfo>(34, _omitFieldNames ? '' : 'sessionInfo',
        subBuilder: SessionInfo.$_createMessage)
    ..aOM<TimelineUpdate>(35, _omitFieldNames ? '' : 'timeline',
        subBuilder: TimelineUpdate.$_createMessage)
    ..aOM<ApprovalRequest>(36, _omitFieldNames ? '' : 'approvalRequested',
        subBuilder: ApprovalRequest.$_createMessage)
    ..aOM<ApprovalResolved>(37, _omitFieldNames ? '' : 'approvalResolved',
        subBuilder: ApprovalResolved.$_createMessage)
    ..aOM<SessionRemoved>(38, _omitFieldNames ? '' : 'sessionRemoved',
        subBuilder: SessionRemoved.$_createMessage)
    ..aOM<Preferences>(39, _omitFieldNames ? '' : 'preferences',
        subBuilder: Preferences.$_createMessage)
    ..aOM<Artifact>(40, _omitFieldNames ? '' : 'artifactAdded',
        subBuilder: Artifact.$_createMessage)
    ..aOM<AgentHello>(50, _omitFieldNames ? '' : 'agentHello',
        subBuilder: AgentHello.$_createMessage)
    ..aOM<SessionIndex>(51, _omitFieldNames ? '' : 'sessionIndex',
        subBuilder: SessionIndex.$_createMessage)
    ..aOM<RawEvents>(52, _omitFieldNames ? '' : 'rawEvents',
        subBuilder: RawEvents.$_createMessage)
    ..aOM<UsageReport>(53, _omitFieldNames ? '' : 'usageReport',
        subBuilder: UsageReport.$_createMessage)
    ..aOM<PlanUsage>(54, _omitFieldNames ? '' : 'planUsage',
        subBuilder: PlanUsage.$_createMessage)
    ..aOM<AgentCommand>(60, _omitFieldNames ? '' : 'agentCommand',
        subBuilder: AgentCommand.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Frame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Frame copyWith(void Function(Frame) updates) =>
      super.copyWith((message) => updates(message as Frame)) as Frame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Frame() / Frame.new instead')
  static Frame create() => Frame._();
  static $pb.GeneratedMessage $_createMessage() => Frame._();
  @$core.override
  Frame createEmptyInstance() => Frame._();
  @$core.pragma('dart2js:noInline')
  static Frame getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Frame>(Frame.$_createMessage);
  static Frame? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(36)
  @$pb.TagNumber(37)
  @$pb.TagNumber(38)
  @$pb.TagNumber(39)
  @$pb.TagNumber(40)
  @$pb.TagNumber(50)
  @$pb.TagNumber(51)
  @$pb.TagNumber(52)
  @$pb.TagNumber(53)
  @$pb.TagNumber(54)
  @$pb.TagNumber(60)
  Frame_Body whichBody() => _Frame_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(36)
  @$pb.TagNumber(37)
  @$pb.TagNumber(38)
  @$pb.TagNumber(39)
  @$pb.TagNumber(40)
  @$pb.TagNumber(50)
  @$pb.TagNumber(51)
  @$pb.TagNumber(52)
  @$pb.TagNumber(53)
  @$pb.TagNumber(54)
  @$pb.TagNumber(60)
  void clearBody() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.int get v => $_getIZ(0);
  @$pb.TagNumber(1)
  set v($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasV() => $_has(0);
  @$pb.TagNumber(1)
  void clearV() => $_clearField(1);

  /// Set by the sender of a command; echoed in reply_to on the Ack or Error.
  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get replyTo => $_getSZ(2);
  @$pb.TagNumber(3)
  set replyTo($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReplyTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearReplyTo() => $_clearField(3);

  /// Per-session sequence number on timeline frames, assigned by the hub.
  @$pb.TagNumber(4)
  $fixnum.Int64 get seq => $_getI64(3);
  @$pb.TagNumber(4)
  set seq($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSeq() => $_has(3);
  @$pb.TagNumber(4)
  void clearSeq() => $_clearField(4);

  /// Client -> hub
  @$pb.TagNumber(10)
  ClientHello get clientHello => $_getN(4);
  @$pb.TagNumber(10)
  set clientHello(ClientHello value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasClientHello() => $_has(4);
  @$pb.TagNumber(10)
  void clearClientHello() => $_clearField(10);
  @$pb.TagNumber(10)
  ClientHello ensureClientHello() => $_ensure(4);

  @$pb.TagNumber(11)
  Subscribe get subscribe => $_getN(5);
  @$pb.TagNumber(11)
  set subscribe(Subscribe value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSubscribe() => $_has(5);
  @$pb.TagNumber(11)
  void clearSubscribe() => $_clearField(11);
  @$pb.TagNumber(11)
  Subscribe ensureSubscribe() => $_ensure(5);

  @$pb.TagNumber(12)
  Unsubscribe get unsubscribe => $_getN(6);
  @$pb.TagNumber(12)
  set unsubscribe(Unsubscribe value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasUnsubscribe() => $_has(6);
  @$pb.TagNumber(12)
  void clearUnsubscribe() => $_clearField(12);
  @$pb.TagNumber(12)
  Unsubscribe ensureUnsubscribe() => $_ensure(6);

  @$pb.TagNumber(13)
  CreateSession get createSession => $_getN(7);
  @$pb.TagNumber(13)
  set createSession(CreateSession value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasCreateSession() => $_has(7);
  @$pb.TagNumber(13)
  void clearCreateSession() => $_clearField(13);
  @$pb.TagNumber(13)
  CreateSession ensureCreateSession() => $_ensure(7);

  @$pb.TagNumber(14)
  SendMessage get sendMessage => $_getN(8);
  @$pb.TagNumber(14)
  set sendMessage(SendMessage value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasSendMessage() => $_has(8);
  @$pb.TagNumber(14)
  void clearSendMessage() => $_clearField(14);
  @$pb.TagNumber(14)
  SendMessage ensureSendMessage() => $_ensure(8);

  @$pb.TagNumber(15)
  InterruptSession get interruptSession => $_getN(9);
  @$pb.TagNumber(15)
  set interruptSession(InterruptSession value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasInterruptSession() => $_has(9);
  @$pb.TagNumber(15)
  void clearInterruptSession() => $_clearField(15);
  @$pb.TagNumber(15)
  InterruptSession ensureInterruptSession() => $_ensure(9);

  @$pb.TagNumber(16)
  ApprovalDecision get approvalDecision => $_getN(10);
  @$pb.TagNumber(16)
  set approvalDecision(ApprovalDecision value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasApprovalDecision() => $_has(10);
  @$pb.TagNumber(16)
  void clearApprovalDecision() => $_clearField(16);
  @$pb.TagNumber(16)
  ApprovalDecision ensureApprovalDecision() => $_ensure(10);

  @$pb.TagNumber(17)
  StopSession get stopSession => $_getN(11);
  @$pb.TagNumber(17)
  set stopSession(StopSession value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasStopSession() => $_has(11);
  @$pb.TagNumber(17)
  void clearStopSession() => $_clearField(17);
  @$pb.TagNumber(17)
  StopSession ensureStopSession() => $_ensure(11);

  /// Hub -> client
  @$pb.TagNumber(30)
  Welcome get welcome => $_getN(12);
  @$pb.TagNumber(30)
  set welcome(Welcome value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasWelcome() => $_has(12);
  @$pb.TagNumber(30)
  void clearWelcome() => $_clearField(30);
  @$pb.TagNumber(30)
  Welcome ensureWelcome() => $_ensure(12);

  @$pb.TagNumber(31)
  Ack get ack => $_getN(13);
  @$pb.TagNumber(31)
  set ack(Ack value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasAck() => $_has(13);
  @$pb.TagNumber(31)
  void clearAck() => $_clearField(31);
  @$pb.TagNumber(31)
  Ack ensureAck() => $_ensure(13);

  @$pb.TagNumber(32)
  Error get error => $_getN(14);
  @$pb.TagNumber(32)
  set error(Error value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasError() => $_has(14);
  @$pb.TagNumber(32)
  void clearError() => $_clearField(32);
  @$pb.TagNumber(32)
  Error ensureError() => $_ensure(14);

  @$pb.TagNumber(33)
  NodeStatus get nodeStatus => $_getN(15);
  @$pb.TagNumber(33)
  set nodeStatus(NodeStatus value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasNodeStatus() => $_has(15);
  @$pb.TagNumber(33)
  void clearNodeStatus() => $_clearField(33);
  @$pb.TagNumber(33)
  NodeStatus ensureNodeStatus() => $_ensure(15);

  @$pb.TagNumber(34)
  SessionInfo get sessionInfo => $_getN(16);
  @$pb.TagNumber(34)
  set sessionInfo(SessionInfo value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasSessionInfo() => $_has(16);
  @$pb.TagNumber(34)
  void clearSessionInfo() => $_clearField(34);
  @$pb.TagNumber(34)
  SessionInfo ensureSessionInfo() => $_ensure(16);

  @$pb.TagNumber(35)
  TimelineUpdate get timeline => $_getN(17);
  @$pb.TagNumber(35)
  set timeline(TimelineUpdate value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasTimeline() => $_has(17);
  @$pb.TagNumber(35)
  void clearTimeline() => $_clearField(35);
  @$pb.TagNumber(35)
  TimelineUpdate ensureTimeline() => $_ensure(17);

  @$pb.TagNumber(36)
  ApprovalRequest get approvalRequested => $_getN(18);
  @$pb.TagNumber(36)
  set approvalRequested(ApprovalRequest value) => $_setField(36, value);
  @$pb.TagNumber(36)
  $core.bool hasApprovalRequested() => $_has(18);
  @$pb.TagNumber(36)
  void clearApprovalRequested() => $_clearField(36);
  @$pb.TagNumber(36)
  ApprovalRequest ensureApprovalRequested() => $_ensure(18);

  @$pb.TagNumber(37)
  ApprovalResolved get approvalResolved => $_getN(19);
  @$pb.TagNumber(37)
  set approvalResolved(ApprovalResolved value) => $_setField(37, value);
  @$pb.TagNumber(37)
  $core.bool hasApprovalResolved() => $_has(19);
  @$pb.TagNumber(37)
  void clearApprovalResolved() => $_clearField(37);
  @$pb.TagNumber(37)
  ApprovalResolved ensureApprovalResolved() => $_ensure(19);

  @$pb.TagNumber(38)
  SessionRemoved get sessionRemoved => $_getN(20);
  @$pb.TagNumber(38)
  set sessionRemoved(SessionRemoved value) => $_setField(38, value);
  @$pb.TagNumber(38)
  $core.bool hasSessionRemoved() => $_has(20);
  @$pb.TagNumber(38)
  void clearSessionRemoved() => $_clearField(38);
  @$pb.TagNumber(38)
  SessionRemoved ensureSessionRemoved() => $_ensure(20);

  /// The shared app settings changed (sent to every client).
  @$pb.TagNumber(39)
  Preferences get preferences => $_getN(21);
  @$pb.TagNumber(39)
  set preferences(Preferences value) => $_setField(39, value);
  @$pb.TagNumber(39)
  $core.bool hasPreferences() => $_has(21);
  @$pb.TagNumber(39)
  void clearPreferences() => $_clearField(39);
  @$pb.TagNumber(39)
  Preferences ensurePreferences() => $_ensure(21);

  /// A file was added to the artifact store (sent to every client).
  @$pb.TagNumber(40)
  Artifact get artifactAdded => $_getN(22);
  @$pb.TagNumber(40)
  set artifactAdded(Artifact value) => $_setField(40, value);
  @$pb.TagNumber(40)
  $core.bool hasArtifactAdded() => $_has(22);
  @$pb.TagNumber(40)
  void clearArtifactAdded() => $_clearField(40);
  @$pb.TagNumber(40)
  Artifact ensureArtifactAdded() => $_ensure(22);

  /// Agent -> hub
  @$pb.TagNumber(50)
  AgentHello get agentHello => $_getN(23);
  @$pb.TagNumber(50)
  set agentHello(AgentHello value) => $_setField(50, value);
  @$pb.TagNumber(50)
  $core.bool hasAgentHello() => $_has(23);
  @$pb.TagNumber(50)
  void clearAgentHello() => $_clearField(50);
  @$pb.TagNumber(50)
  AgentHello ensureAgentHello() => $_ensure(23);

  @$pb.TagNumber(51)
  SessionIndex get sessionIndex => $_getN(24);
  @$pb.TagNumber(51)
  set sessionIndex(SessionIndex value) => $_setField(51, value);
  @$pb.TagNumber(51)
  $core.bool hasSessionIndex() => $_has(24);
  @$pb.TagNumber(51)
  void clearSessionIndex() => $_clearField(51);
  @$pb.TagNumber(51)
  SessionIndex ensureSessionIndex() => $_ensure(24);

  @$pb.TagNumber(52)
  RawEvents get rawEvents => $_getN(25);
  @$pb.TagNumber(52)
  set rawEvents(RawEvents value) => $_setField(52, value);
  @$pb.TagNumber(52)
  $core.bool hasRawEvents() => $_has(25);
  @$pb.TagNumber(52)
  void clearRawEvents() => $_clearField(52);
  @$pb.TagNumber(52)
  RawEvents ensureRawEvents() => $_ensure(25);

  /// Token usage read from transcripts, per assistant message.
  @$pb.TagNumber(53)
  UsageReport get usageReport => $_getN(26);
  @$pb.TagNumber(53)
  set usageReport(UsageReport value) => $_setField(53, value);
  @$pb.TagNumber(53)
  $core.bool hasUsageReport() => $_has(26);
  @$pb.TagNumber(53)
  void clearUsageReport() => $_clearField(53);
  @$pb.TagNumber(53)
  UsageReport ensureUsageReport() => $_ensure(26);

  /// The node's plan limits, from `claude -p /usage`.
  @$pb.TagNumber(54)
  PlanUsage get planUsage => $_getN(27);
  @$pb.TagNumber(54)
  set planUsage(PlanUsage value) => $_setField(54, value);
  @$pb.TagNumber(54)
  $core.bool hasPlanUsage() => $_has(27);
  @$pb.TagNumber(54)
  void clearPlanUsage() => $_clearField(54);
  @$pb.TagNumber(54)
  PlanUsage ensurePlanUsage() => $_ensure(27);

  /// Hub -> agent
  @$pb.TagNumber(60)
  AgentCommand get agentCommand => $_getN(28);
  @$pb.TagNumber(60)
  set agentCommand(AgentCommand value) => $_setField(60, value);
  @$pb.TagNumber(60)
  $core.bool hasAgentCommand() => $_has(28);
  @$pb.TagNumber(60)
  void clearAgentCommand() => $_clearField(60);
  @$pb.TagNumber(60)
  AgentCommand ensureAgentCommand() => $_ensure(28);
}

class NodeStatus extends $pb.GeneratedMessage {
  factory NodeStatus({
    $core.String? node,
    $core.bool? online,
    $core.String? os,
    $core.String? hostname,
    $core.String? claudeVersion,
    $core.String? agentVersion,
    $fixnum.Int64? lastSeenMs,
    $core.int? runningSessions,
    $core.String? ip,
  }) {
    final result = NodeStatus._();
    if (node != null) result.node = node;
    if (online != null) result.online = online;
    if (os != null) result.os = os;
    if (hostname != null) result.hostname = hostname;
    if (claudeVersion != null) result.claudeVersion = claudeVersion;
    if (agentVersion != null) result.agentVersion = agentVersion;
    if (lastSeenMs != null) result.lastSeenMs = lastSeenMs;
    if (runningSessions != null) result.runningSessions = runningSessions;
    if (ip != null) result.ip = ip;
    return result;
  }

  NodeStatus._();

  factory NodeStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeStatus()..mergeFromBuffer(data, registry);
  factory NodeStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: NodeStatus.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'node')
    ..aOB(2, _omitFieldNames ? '' : 'online')
    ..aOS(3, _omitFieldNames ? '' : 'os')
    ..aOS(4, _omitFieldNames ? '' : 'hostname')
    ..aOS(5, _omitFieldNames ? '' : 'claudeVersion')
    ..aOS(6, _omitFieldNames ? '' : 'agentVersion')
    ..aInt64(7, _omitFieldNames ? '' : 'lastSeenMs')
    ..aI(8, _omitFieldNames ? '' : 'runningSessions')
    ..aOS(9, _omitFieldNames ? '' : 'ip')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeStatus copyWith(void Function(NodeStatus) updates) =>
      super.copyWith((message) => updates(message as NodeStatus)) as NodeStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NodeStatus() / NodeStatus.new instead')
  static NodeStatus create() => NodeStatus._();
  static $pb.GeneratedMessage $_createMessage() => NodeStatus._();
  @$core.override
  NodeStatus createEmptyInstance() => NodeStatus._();
  @$core.pragma('dart2js:noInline')
  static NodeStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeStatus>(NodeStatus.$_createMessage);
  static NodeStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get node => $_getSZ(0);
  @$pb.TagNumber(1)
  set node($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearNode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get online => $_getBF(1);
  @$pb.TagNumber(2)
  set online($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOnline() => $_has(1);
  @$pb.TagNumber(2)
  void clearOnline() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get os => $_getSZ(2);
  @$pb.TagNumber(3)
  set os($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOs() => $_has(2);
  @$pb.TagNumber(3)
  void clearOs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get hostname => $_getSZ(3);
  @$pb.TagNumber(4)
  set hostname($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHostname() => $_has(3);
  @$pb.TagNumber(4)
  void clearHostname() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get claudeVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set claudeVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasClaudeVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearClaudeVersion() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get agentVersion => $_getSZ(5);
  @$pb.TagNumber(6)
  set agentVersion($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAgentVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearAgentVersion() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get lastSeenMs => $_getI64(6);
  @$pb.TagNumber(7)
  set lastSeenMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLastSeenMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastSeenMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get runningSessions => $_getIZ(7);
  @$pb.TagNumber(8)
  set runningSessions($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRunningSessions() => $_has(7);
  @$pb.TagNumber(8)
  void clearRunningSessions() => $_clearField(8);

  /// The address the agent connects to the hub from, set by the hub.
  @$pb.TagNumber(9)
  $core.String get ip => $_getSZ(8);
  @$pb.TagNumber(9)
  set ip($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIp() => $_has(8);
  @$pb.TagNumber(9)
  void clearIp() => $_clearField(9);
}

class SessionInfo extends $pb.GeneratedMessage {
  factory SessionInfo({
    $core.String? id,
    $core.String? node,
    $core.String? title,
    $core.String? cwd,
    $core.String? gitBranch,
    $fixnum.Int64? createdMs,
    $fixnum.Int64? updatedMs,
    $core.int? messageCount,
    SessionState? state,
    $core.String? lastPrompt,
    $core.String? claudeVersion,
    $core.String? model,
    $core.Iterable<$0.Todo>? todos,
    $core.double? lastCostUsd,
    $core.String? error,
    SessionHost? host,
    $core.String? attachCommand,
    $core.bool? terminalInput,
    $core.bool? archived,
    $core.String? parent,
    $core.String? forkPoint,
    $core.String? lineage,
    $core.bool? scratch,
    $core.bool? global,
    $core.String? codebase,
    $core.String? snapshot,
  }) {
    final result = SessionInfo._();
    if (id != null) result.id = id;
    if (node != null) result.node = node;
    if (title != null) result.title = title;
    if (cwd != null) result.cwd = cwd;
    if (gitBranch != null) result.gitBranch = gitBranch;
    if (createdMs != null) result.createdMs = createdMs;
    if (updatedMs != null) result.updatedMs = updatedMs;
    if (messageCount != null) result.messageCount = messageCount;
    if (state != null) result.state = state;
    if (lastPrompt != null) result.lastPrompt = lastPrompt;
    if (claudeVersion != null) result.claudeVersion = claudeVersion;
    if (model != null) result.model = model;
    if (todos != null) result.todos.addAll(todos);
    if (lastCostUsd != null) result.lastCostUsd = lastCostUsd;
    if (error != null) result.error = error;
    if (host != null) result.host = host;
    if (attachCommand != null) result.attachCommand = attachCommand;
    if (terminalInput != null) result.terminalInput = terminalInput;
    if (archived != null) result.archived = archived;
    if (parent != null) result.parent = parent;
    if (forkPoint != null) result.forkPoint = forkPoint;
    if (lineage != null) result.lineage = lineage;
    if (scratch != null) result.scratch = scratch;
    if (global != null) result.global = global;
    if (codebase != null) result.codebase = codebase;
    if (snapshot != null) result.snapshot = snapshot;
    return result;
  }

  SessionInfo._();

  factory SessionInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionInfo()..mergeFromBuffer(data, registry);
  factory SessionInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SessionInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'node')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'cwd')
    ..aOS(5, _omitFieldNames ? '' : 'gitBranch')
    ..aInt64(6, _omitFieldNames ? '' : 'createdMs')
    ..aInt64(7, _omitFieldNames ? '' : 'updatedMs')
    ..aI(8, _omitFieldNames ? '' : 'messageCount')
    ..aE<SessionState>(9, _omitFieldNames ? '' : 'state',
        enumValues: SessionState.values)
    ..aOS(10, _omitFieldNames ? '' : 'lastPrompt')
    ..aOS(11, _omitFieldNames ? '' : 'claudeVersion')
    ..aOS(12, _omitFieldNames ? '' : 'model')
    ..pPM<$0.Todo>(13, _omitFieldNames ? '' : 'todos',
        subBuilder: $0.Todo.$_createMessage)
    ..aD(14, _omitFieldNames ? '' : 'lastCostUsd')
    ..aOS(15, _omitFieldNames ? '' : 'error')
    ..aE<SessionHost>(16, _omitFieldNames ? '' : 'host',
        enumValues: SessionHost.values)
    ..aOS(17, _omitFieldNames ? '' : 'attachCommand')
    ..aOB(18, _omitFieldNames ? '' : 'terminalInput')
    ..aOB(19, _omitFieldNames ? '' : 'archived')
    ..aOS(20, _omitFieldNames ? '' : 'parent')
    ..aOS(21, _omitFieldNames ? '' : 'forkPoint')
    ..aOS(22, _omitFieldNames ? '' : 'lineage')
    ..aOB(23, _omitFieldNames ? '' : 'scratch')
    ..aOB(24, _omitFieldNames ? '' : 'global')
    ..aOS(25, _omitFieldNames ? '' : 'codebase')
    ..aOS(26, _omitFieldNames ? '' : 'snapshot')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionInfo copyWith(void Function(SessionInfo) updates) =>
      super.copyWith((message) => updates(message as SessionInfo))
          as SessionInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionInfo() / SessionInfo.new instead')
  static SessionInfo create() => SessionInfo._();
  static $pb.GeneratedMessage $_createMessage() => SessionInfo._();
  @$core.override
  SessionInfo createEmptyInstance() => SessionInfo._();
  @$core.pragma('dart2js:noInline')
  static SessionInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionInfo>(
          SessionInfo.$_createMessage);
  static SessionInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get node => $_getSZ(1);
  @$pb.TagNumber(2)
  set node($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNode() => $_has(1);
  @$pb.TagNumber(2)
  void clearNode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get cwd => $_getSZ(3);
  @$pb.TagNumber(4)
  set cwd($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCwd() => $_has(3);
  @$pb.TagNumber(4)
  void clearCwd() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get gitBranch => $_getSZ(4);
  @$pb.TagNumber(5)
  set gitBranch($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGitBranch() => $_has(4);
  @$pb.TagNumber(5)
  void clearGitBranch() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdMs => $_getI64(5);
  @$pb.TagNumber(6)
  set createdMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get updatedMs => $_getI64(6);
  @$pb.TagNumber(7)
  set updatedMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUpdatedMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearUpdatedMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get messageCount => $_getIZ(7);
  @$pb.TagNumber(8)
  set messageCount($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMessageCount() => $_has(7);
  @$pb.TagNumber(8)
  void clearMessageCount() => $_clearField(8);

  @$pb.TagNumber(9)
  SessionState get state => $_getN(8);
  @$pb.TagNumber(9)
  set state(SessionState value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasState() => $_has(8);
  @$pb.TagNumber(9)
  void clearState() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get lastPrompt => $_getSZ(9);
  @$pb.TagNumber(10)
  set lastPrompt($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLastPrompt() => $_has(9);
  @$pb.TagNumber(10)
  void clearLastPrompt() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get claudeVersion => $_getSZ(10);
  @$pb.TagNumber(11)
  set claudeVersion($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasClaudeVersion() => $_has(10);
  @$pb.TagNumber(11)
  void clearClaudeVersion() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get model => $_getSZ(11);
  @$pb.TagNumber(12)
  set model($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasModel() => $_has(11);
  @$pb.TagNumber(12)
  void clearModel() => $_clearField(12);

  /// Filled by the hub from the timeline.
  @$pb.TagNumber(13)
  $pb.PbList<$0.Todo> get todos => $_getList(12);

  @$pb.TagNumber(14)
  $core.double get lastCostUsd => $_getN(13);
  @$pb.TagNumber(14)
  set lastCostUsd($core.double value) => $_setDouble(13, value);
  @$pb.TagNumber(14)
  $core.bool hasLastCostUsd() => $_has(13);
  @$pb.TagNumber(14)
  void clearLastCostUsd() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get error => $_getSZ(14);
  @$pb.TagNumber(15)
  set error($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasError() => $_has(14);
  @$pb.TagNumber(15)
  void clearError() => $_clearField(15);

  @$pb.TagNumber(16)
  SessionHost get host => $_getN(15);
  @$pb.TagNumber(16)
  set host(SessionHost value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasHost() => $_has(15);
  @$pb.TagNumber(16)
  void clearHost() => $_clearField(16);

  /// Command to open the live session in a terminal on its node, if any.
  @$pb.TagNumber(17)
  $core.String get attachCommand => $_getSZ(16);
  @$pb.TagNumber(17)
  set attachCommand($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasAttachCommand() => $_has(16);
  @$pb.TagNumber(17)
  void clearAttachCommand() => $_clearField(17);

  /// A terminal session the agent can type into anyway (Windows consoles).
  @$pb.TagNumber(18)
  $core.bool get terminalInput => $_getBF(17);
  @$pb.TagNumber(18)
  set terminalInput($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(18)
  $core.bool hasTerminalInput() => $_has(17);
  @$pb.TagNumber(18)
  void clearTerminalInput() => $_clearField(18);

  /// Set by the user ("mark as done"); kept by the hub across agent updates
  /// and cleared when the session starts working again.
  @$pb.TagNumber(19)
  $core.bool get archived => $_getBF(18);
  @$pb.TagNumber(19)
  set archived($core.bool value) => $_setBool(18, value);
  @$pb.TagNumber(19)
  $core.bool hasArchived() => $_has(18);
  @$pb.TagNumber(19)
  void clearArchived() => $_clearField(19);

  /// Lineage, owned by the hub like archived: the session this one split off
  /// from, the parent's last timeline item at that moment, and how ("fork",
  /// later "branch").
  @$pb.TagNumber(20)
  $core.String get parent => $_getSZ(19);
  @$pb.TagNumber(20)
  set parent($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasParent() => $_has(19);
  @$pb.TagNumber(20)
  void clearParent() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.String get forkPoint => $_getSZ(20);
  @$pb.TagNumber(21)
  set forkPoint($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasForkPoint() => $_has(20);
  @$pb.TagNumber(21)
  void clearForkPoint() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.String get lineage => $_getSZ(21);
  @$pb.TagNumber(22)
  set lineage($core.String value) => $_setString(21, value);
  @$pb.TagNumber(22)
  $core.bool hasLineage() => $_has(21);
  @$pb.TagNumber(22)
  void clearLineage() => $_clearField(22);

  /// Runs in its own scratch folder on the hub's machine (a hub session).
  @$pb.TagNumber(23)
  $core.bool get scratch => $_getBF(22);
  @$pb.TagNumber(23)
  set scratch($core.bool value) => $_setBool(22, value);
  @$pb.TagNumber(23)
  $core.bool hasScratch() => $_has(22);
  @$pb.TagNumber(23)
  void clearScratch() => $_clearField(23);

  /// The hub keeps a copy of its transcript, so it can be continued on the
  /// hub's machine when its own machine is closed or offline.
  @$pb.TagNumber(24)
  $core.bool get global => $_getBF(23);
  @$pb.TagNumber(24)
  set global($core.bool value) => $_setBool(23, value);
  @$pb.TagNumber(24)
  $core.bool hasGlobal() => $_has(23);
  @$pb.TagNumber(24)
  void clearGlobal() => $_clearField(24);

  /// The codebase its folder belongs to, and the snapshot the hub took of it
  /// for this session (set on forks); see docs/plan.md#codebases-on-the-hub.
  @$pb.TagNumber(25)
  $core.String get codebase => $_getSZ(24);
  @$pb.TagNumber(25)
  set codebase($core.String value) => $_setString(24, value);
  @$pb.TagNumber(25)
  $core.bool hasCodebase() => $_has(24);
  @$pb.TagNumber(25)
  void clearCodebase() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.String get snapshot => $_getSZ(25);
  @$pb.TagNumber(26)
  set snapshot($core.String value) => $_setString(25, value);
  @$pb.TagNumber(26)
  $core.bool hasSnapshot() => $_has(25);
  @$pb.TagNumber(26)
  void clearSnapshot() => $_clearField(26);
}

/// A session no longer exists on its node (its transcript was deleted).
class SessionRemoved extends $pb.GeneratedMessage {
  factory SessionRemoved({
    $core.String? session,
  }) {
    final result = SessionRemoved._();
    if (session != null) result.session = session;
    return result;
  }

  SessionRemoved._();

  factory SessionRemoved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionRemoved()..mergeFromBuffer(data, registry);
  factory SessionRemoved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionRemoved()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionRemoved',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SessionRemoved.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionRemoved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionRemoved copyWith(void Function(SessionRemoved) updates) =>
      super.copyWith((message) => updates(message as SessionRemoved))
          as SessionRemoved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionRemoved() / SessionRemoved.new instead')
  static SessionRemoved create() => SessionRemoved._();
  static $pb.GeneratedMessage $_createMessage() => SessionRemoved._();
  @$core.override
  SessionRemoved createEmptyInstance() => SessionRemoved._();
  @$core.pragma('dart2js:noInline')
  static SessionRemoved getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionRemoved>(
          SessionRemoved.$_createMessage);
  static SessionRemoved? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class TimelineUpdate extends $pb.GeneratedMessage {
  factory TimelineUpdate({
    $core.String? session,
    $core.Iterable<$0.TimelineItem>? items,
  }) {
    final result = TimelineUpdate._();
    if (session != null) result.session = session;
    if (items != null) result.items.addAll(items);
    return result;
  }

  TimelineUpdate._();

  factory TimelineUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelineUpdate()..mergeFromBuffer(data, registry);
  factory TimelineUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelineUpdate()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimelineUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: TimelineUpdate.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..pPM<$0.TimelineItem>(2, _omitFieldNames ? '' : 'items',
        subBuilder: $0.TimelineItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelineUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelineUpdate copyWith(void Function(TimelineUpdate) updates) =>
      super.copyWith((message) => updates(message as TimelineUpdate))
          as TimelineUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TimelineUpdate() / TimelineUpdate.new instead')
  static TimelineUpdate create() => TimelineUpdate._();
  static $pb.GeneratedMessage $_createMessage() => TimelineUpdate._();
  @$core.override
  TimelineUpdate createEmptyInstance() => TimelineUpdate._();
  @$core.pragma('dart2js:noInline')
  static TimelineUpdate getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TimelineUpdate>(
          TimelineUpdate.$_createMessage);
  static TimelineUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$0.TimelineItem> get items => $_getList(1);
}

/// Response of GET /api/v1/sessions/{id}/timeline.
class TimelinePage extends $pb.GeneratedMessage {
  factory TimelinePage({
    $core.String? session,
    $core.Iterable<$0.TimelineItem>? items,
    $fixnum.Int64? seq,
  }) {
    final result = TimelinePage._();
    if (session != null) result.session = session;
    if (items != null) result.items.addAll(items);
    if (seq != null) result.seq = seq;
    return result;
  }

  TimelinePage._();

  factory TimelinePage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelinePage()..mergeFromBuffer(data, registry);
  factory TimelinePage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelinePage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimelinePage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: TimelinePage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..pPM<$0.TimelineItem>(2, _omitFieldNames ? '' : 'items',
        subBuilder: $0.TimelineItem.$_createMessage)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelinePage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelinePage copyWith(void Function(TimelinePage) updates) =>
      super.copyWith((message) => updates(message as TimelinePage))
          as TimelinePage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TimelinePage() / TimelinePage.new instead')
  static TimelinePage create() => TimelinePage._();
  static $pb.GeneratedMessage $_createMessage() => TimelinePage._();
  @$core.override
  TimelinePage createEmptyInstance() => TimelinePage._();
  @$core.pragma('dart2js:noInline')
  static TimelinePage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TimelinePage>(
          TimelinePage.$_createMessage);
  static TimelinePage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  /// Ordered by ord.
  @$pb.TagNumber(2)
  $pb.PbList<$0.TimelineItem> get items => $_getList(1);

  /// The session's latest seq. Subscribe with it as after_seq to receive
  /// only later changes; if it is lower than a cached seq, the hub was reset.
  @$pb.TagNumber(3)
  $fixnum.Int64 get seq => $_getI64(2);
  @$pb.TagNumber(3)
  set seq($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSeq() => $_has(2);
  @$pb.TagNumber(3)
  void clearSeq() => $_clearField(3);
}

class ApprovalRequest extends $pb.GeneratedMessage {
  factory ApprovalRequest({
    $core.String? approvalId,
    $core.String? session,
    $core.String? node,
    $core.String? toolName,
    $core.String? inputJson,
    $core.String? description,
    $fixnum.Int64? createdMs,
    $0.ToolCard? preview,
    ApprovalRequest_Kind? kind,
  }) {
    final result = ApprovalRequest._();
    if (approvalId != null) result.approvalId = approvalId;
    if (session != null) result.session = session;
    if (node != null) result.node = node;
    if (toolName != null) result.toolName = toolName;
    if (inputJson != null) result.inputJson = inputJson;
    if (description != null) result.description = description;
    if (createdMs != null) result.createdMs = createdMs;
    if (preview != null) result.preview = preview;
    if (kind != null) result.kind = kind;
    return result;
  }

  ApprovalRequest._();

  factory ApprovalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ApprovalRequest()..mergeFromBuffer(data, registry);
  factory ApprovalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ApprovalRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApprovalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ApprovalRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'approvalId')
    ..aOS(2, _omitFieldNames ? '' : 'session')
    ..aOS(3, _omitFieldNames ? '' : 'node')
    ..aOS(4, _omitFieldNames ? '' : 'toolName')
    ..aOS(5, _omitFieldNames ? '' : 'inputJson')
    ..aOS(6, _omitFieldNames ? '' : 'description')
    ..aInt64(7, _omitFieldNames ? '' : 'createdMs')
    ..aOM<$0.ToolCard>(8, _omitFieldNames ? '' : 'preview',
        subBuilder: $0.ToolCard.$_createMessage)
    ..aE<ApprovalRequest_Kind>(9, _omitFieldNames ? '' : 'kind',
        enumValues: ApprovalRequest_Kind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovalRequest copyWith(void Function(ApprovalRequest) updates) =>
      super.copyWith((message) => updates(message as ApprovalRequest))
          as ApprovalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ApprovalRequest() / ApprovalRequest.new instead')
  static ApprovalRequest create() => ApprovalRequest._();
  static $pb.GeneratedMessage $_createMessage() => ApprovalRequest._();
  @$core.override
  ApprovalRequest createEmptyInstance() => ApprovalRequest._();
  @$core.pragma('dart2js:noInline')
  static ApprovalRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ApprovalRequest>(
          ApprovalRequest.$_createMessage);
  static ApprovalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get approvalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set approvalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApprovalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearApprovalId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get session => $_getSZ(1);
  @$pb.TagNumber(2)
  set session($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSession() => $_has(1);
  @$pb.TagNumber(2)
  void clearSession() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get node => $_getSZ(2);
  @$pb.TagNumber(3)
  set node($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNode() => $_has(2);
  @$pb.TagNumber(3)
  void clearNode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get toolName => $_getSZ(3);
  @$pb.TagNumber(4)
  set toolName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasToolName() => $_has(3);
  @$pb.TagNumber(4)
  void clearToolName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get inputJson => $_getSZ(4);
  @$pb.TagNumber(5)
  set inputJson($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInputJson() => $_has(4);
  @$pb.TagNumber(5)
  void clearInputJson() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get description => $_getSZ(5);
  @$pb.TagNumber(6)
  set description($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDescription() => $_has(5);
  @$pb.TagNumber(6)
  void clearDescription() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get createdMs => $_getI64(6);
  @$pb.TagNumber(7)
  set createdMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedMs() => $_clearField(7);

  /// The tool rendered as a card, for the approval sheet.
  @$pb.TagNumber(8)
  $0.ToolCard get preview => $_getN(7);
  @$pb.TagNumber(8)
  set preview($0.ToolCard value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasPreview() => $_has(7);
  @$pb.TagNumber(8)
  void clearPreview() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.ToolCard ensurePreview() => $_ensure(7);

  @$pb.TagNumber(9)
  ApprovalRequest_Kind get kind => $_getN(8);
  @$pb.TagNumber(9)
  set kind(ApprovalRequest_Kind value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasKind() => $_has(8);
  @$pb.TagNumber(9)
  void clearKind() => $_clearField(9);
}

class ApprovalDecision extends $pb.GeneratedMessage {
  factory ApprovalDecision({
    $core.String? approvalId,
    Decision? decision,
    $core.String? message,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? answers,
  }) {
    final result = ApprovalDecision._();
    if (approvalId != null) result.approvalId = approvalId;
    if (decision != null) result.decision = decision;
    if (message != null) result.message = message;
    if (answers != null) result.answers.addEntries(answers);
    return result;
  }

  ApprovalDecision._();

  factory ApprovalDecision.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ApprovalDecision()..mergeFromBuffer(data, registry);
  factory ApprovalDecision.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ApprovalDecision()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApprovalDecision',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ApprovalDecision.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'approvalId')
    ..aE<Decision>(2, _omitFieldNames ? '' : 'decision',
        enumValues: Decision.values)
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'answers',
        entryClassName: 'ApprovalDecision.AnswersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('tether.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovalDecision clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovalDecision copyWith(void Function(ApprovalDecision) updates) =>
      super.copyWith((message) => updates(message as ApprovalDecision))
          as ApprovalDecision;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ApprovalDecision() / ApprovalDecision.new instead')
  static ApprovalDecision create() => ApprovalDecision._();
  static $pb.GeneratedMessage $_createMessage() => ApprovalDecision._();
  @$core.override
  ApprovalDecision createEmptyInstance() => ApprovalDecision._();
  @$core.pragma('dart2js:noInline')
  static ApprovalDecision getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ApprovalDecision>(
          ApprovalDecision.$_createMessage);
  static ApprovalDecision? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get approvalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set approvalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApprovalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearApprovalId() => $_clearField(1);

  @$pb.TagNumber(2)
  Decision get decision => $_getN(1);
  @$pb.TagNumber(2)
  set decision(Decision value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDecision() => $_has(1);
  @$pb.TagNumber(2)
  void clearDecision() => $_clearField(2);

  /// Shown to Claude when denying.
  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);

  /// For a question: each question's text to the chosen option labels, joined
  /// with ", ", or the user's own words.
  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get answers => $_getMap(3);
}

class ApprovalResolved extends $pb.GeneratedMessage {
  factory ApprovalResolved({
    $core.String? approvalId,
    $core.String? session,
    Decision? decision,
    $core.String? by,
  }) {
    final result = ApprovalResolved._();
    if (approvalId != null) result.approvalId = approvalId;
    if (session != null) result.session = session;
    if (decision != null) result.decision = decision;
    if (by != null) result.by = by;
    return result;
  }

  ApprovalResolved._();

  factory ApprovalResolved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ApprovalResolved()..mergeFromBuffer(data, registry);
  factory ApprovalResolved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ApprovalResolved()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApprovalResolved',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ApprovalResolved.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'approvalId')
    ..aOS(2, _omitFieldNames ? '' : 'session')
    ..aE<Decision>(3, _omitFieldNames ? '' : 'decision',
        enumValues: Decision.values)
    ..aOS(4, _omitFieldNames ? '' : 'by')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovalResolved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovalResolved copyWith(void Function(ApprovalResolved) updates) =>
      super.copyWith((message) => updates(message as ApprovalResolved))
          as ApprovalResolved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ApprovalResolved() / ApprovalResolved.new instead')
  static ApprovalResolved create() => ApprovalResolved._();
  static $pb.GeneratedMessage $_createMessage() => ApprovalResolved._();
  @$core.override
  ApprovalResolved createEmptyInstance() => ApprovalResolved._();
  @$core.pragma('dart2js:noInline')
  static ApprovalResolved getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ApprovalResolved>(
          ApprovalResolved.$_createMessage);
  static ApprovalResolved? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get approvalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set approvalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApprovalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearApprovalId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get session => $_getSZ(1);
  @$pb.TagNumber(2)
  set session($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSession() => $_has(1);
  @$pb.TagNumber(2)
  void clearSession() => $_clearField(2);

  @$pb.TagNumber(3)
  Decision get decision => $_getN(2);
  @$pb.TagNumber(3)
  set decision(Decision value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDecision() => $_has(2);
  @$pb.TagNumber(3)
  void clearDecision() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get by => $_getSZ(3);
  @$pb.TagNumber(4)
  set by($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBy() => $_has(3);
  @$pb.TagNumber(4)
  void clearBy() => $_clearField(4);
}

class ClientHello extends $pb.GeneratedMessage {
  factory ClientHello({
    $core.String? token,
    $core.String? clientName,
    $core.String? platform,
  }) {
    final result = ClientHello._();
    if (token != null) result.token = token;
    if (clientName != null) result.clientName = clientName;
    if (platform != null) result.platform = platform;
    return result;
  }

  ClientHello._();

  factory ClientHello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClientHello()..mergeFromBuffer(data, registry);
  factory ClientHello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClientHello()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientHello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ClientHello.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'clientName')
    ..aOS(3, _omitFieldNames ? '' : 'platform')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientHello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientHello copyWith(void Function(ClientHello) updates) =>
      super.copyWith((message) => updates(message as ClientHello))
          as ClientHello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ClientHello() / ClientHello.new instead')
  static ClientHello create() => ClientHello._();
  static $pb.GeneratedMessage $_createMessage() => ClientHello._();
  @$core.override
  ClientHello createEmptyInstance() => ClientHello._();
  @$core.pragma('dart2js:noInline')
  static ClientHello getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ClientHello>(
          ClientHello.$_createMessage);
  static ClientHello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get clientName => $_getSZ(1);
  @$pb.TagNumber(2)
  set clientName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientName() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get platform => $_getSZ(2);
  @$pb.TagNumber(3)
  set platform($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlatform() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlatform() => $_clearField(3);
}

class Subscribe extends $pb.GeneratedMessage {
  factory Subscribe({
    $core.String? session,
    $fixnum.Int64? afterSeq,
  }) {
    final result = Subscribe._();
    if (session != null) result.session = session;
    if (afterSeq != null) result.afterSeq = afterSeq;
    return result;
  }

  Subscribe._();

  factory Subscribe.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Subscribe()..mergeFromBuffer(data, registry);
  factory Subscribe.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Subscribe()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Subscribe',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Subscribe.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'afterSeq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscribe clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscribe copyWith(void Function(Subscribe) updates) =>
      super.copyWith((message) => updates(message as Subscribe)) as Subscribe;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Subscribe() / Subscribe.new instead')
  static Subscribe create() => Subscribe._();
  static $pb.GeneratedMessage $_createMessage() => Subscribe._();
  @$core.override
  Subscribe createEmptyInstance() => Subscribe._();
  @$core.pragma('dart2js:noInline')
  static Subscribe getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Subscribe>(Subscribe.$_createMessage);
  static Subscribe? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  /// Replay items with seq greater than this; 0 replays everything.
  @$pb.TagNumber(2)
  $fixnum.Int64 get afterSeq => $_getI64(1);
  @$pb.TagNumber(2)
  set afterSeq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAfterSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearAfterSeq() => $_clearField(2);
}

class Unsubscribe extends $pb.GeneratedMessage {
  factory Unsubscribe({
    $core.String? session,
  }) {
    final result = Unsubscribe._();
    if (session != null) result.session = session;
    return result;
  }

  Unsubscribe._();

  factory Unsubscribe.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Unsubscribe()..mergeFromBuffer(data, registry);
  factory Unsubscribe.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Unsubscribe()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Unsubscribe',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Unsubscribe.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Unsubscribe clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Unsubscribe copyWith(void Function(Unsubscribe) updates) =>
      super.copyWith((message) => updates(message as Unsubscribe))
          as Unsubscribe;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Unsubscribe() / Unsubscribe.new instead')
  static Unsubscribe create() => Unsubscribe._();
  static $pb.GeneratedMessage $_createMessage() => Unsubscribe._();
  @$core.override
  Unsubscribe createEmptyInstance() => Unsubscribe._();
  @$core.pragma('dart2js:noInline')
  static Unsubscribe getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Unsubscribe>(
          Unsubscribe.$_createMessage);
  static Unsubscribe? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class CreateSession extends $pb.GeneratedMessage {
  factory CreateSession({
    $core.String? node,
    $core.String? cwd,
    $core.String? prompt,
    $core.String? model,
    $core.String? permissionMode,
    $core.String? name,
    $core.bool? createCwd,
    $core.Iterable<$core.String>? attachments,
    $core.bool? scratch,
  }) {
    final result = CreateSession._();
    if (node != null) result.node = node;
    if (cwd != null) result.cwd = cwd;
    if (prompt != null) result.prompt = prompt;
    if (model != null) result.model = model;
    if (permissionMode != null) result.permissionMode = permissionMode;
    if (name != null) result.name = name;
    if (createCwd != null) result.createCwd = createCwd;
    if (attachments != null) result.attachments.addAll(attachments);
    if (scratch != null) result.scratch = scratch;
    return result;
  }

  CreateSession._();

  factory CreateSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateSession()..mergeFromBuffer(data, registry);
  factory CreateSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: CreateSession.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'node')
    ..aOS(2, _omitFieldNames ? '' : 'cwd')
    ..aOS(3, _omitFieldNames ? '' : 'prompt')
    ..aOS(4, _omitFieldNames ? '' : 'model')
    ..aOS(5, _omitFieldNames ? '' : 'permissionMode')
    ..aOS(6, _omitFieldNames ? '' : 'name')
    ..aOB(7, _omitFieldNames ? '' : 'createCwd')
    ..pPS(8, _omitFieldNames ? '' : 'attachments')
    ..aOB(9, _omitFieldNames ? '' : 'scratch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSession copyWith(void Function(CreateSession) updates) =>
      super.copyWith((message) => updates(message as CreateSession))
          as CreateSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CreateSession() / CreateSession.new instead')
  static CreateSession create() => CreateSession._();
  static $pb.GeneratedMessage $_createMessage() => CreateSession._();
  @$core.override
  CreateSession createEmptyInstance() => CreateSession._();
  @$core.pragma('dart2js:noInline')
  static CreateSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateSession>(
          CreateSession.$_createMessage);
  static CreateSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get node => $_getSZ(0);
  @$pb.TagNumber(1)
  set node($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearNode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get cwd => $_getSZ(1);
  @$pb.TagNumber(2)
  set cwd($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCwd() => $_has(1);
  @$pb.TagNumber(2)
  void clearCwd() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get prompt => $_getSZ(2);
  @$pb.TagNumber(3)
  set prompt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrompt() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrompt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get model => $_getSZ(3);
  @$pb.TagNumber(4)
  set model($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModel() => $_has(3);
  @$pb.TagNumber(4)
  void clearModel() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get permissionMode => $_getSZ(4);
  @$pb.TagNumber(5)
  set permissionMode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPermissionMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearPermissionMode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get name => $_getSZ(5);
  @$pb.TagNumber(6)
  set name($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasName() => $_has(5);
  @$pb.TagNumber(6)
  void clearName() => $_clearField(6);

  /// Create cwd first: a new project folder in a workspace.
  @$pb.TagNumber(7)
  $core.bool get createCwd => $_getBF(6);
  @$pb.TagNumber(7)
  set createCwd($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreateCwd() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreateCwd() => $_clearField(7);

  /// Artifact ids to put in the session's folder and mention in the prompt.
  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get attachments => $_getList(7);

  /// A hub session: run on the hub's machine in a fresh scratch folder.
  /// node and cwd may be left empty.
  @$pb.TagNumber(9)
  $core.bool get scratch => $_getBF(8);
  @$pb.TagNumber(9)
  set scratch($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasScratch() => $_has(8);
  @$pb.TagNumber(9)
  void clearScratch() => $_clearField(9);
}

/// REST body for POST /api/v1/sessions/{id}/archive.
class ArchiveSession extends $pb.GeneratedMessage {
  factory ArchiveSession({
    $core.bool? archived,
  }) {
    final result = ArchiveSession._();
    if (archived != null) result.archived = archived;
    return result;
  }

  ArchiveSession._();

  factory ArchiveSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArchiveSession()..mergeFromBuffer(data, registry);
  factory ArchiveSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArchiveSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArchiveSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ArchiveSession.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'archived')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveSession copyWith(void Function(ArchiveSession) updates) =>
      super.copyWith((message) => updates(message as ArchiveSession))
          as ArchiveSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ArchiveSession() / ArchiveSession.new instead')
  static ArchiveSession create() => ArchiveSession._();
  static $pb.GeneratedMessage $_createMessage() => ArchiveSession._();
  @$core.override
  ArchiveSession createEmptyInstance() => ArchiveSession._();
  @$core.pragma('dart2js:noInline')
  static ArchiveSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ArchiveSession>(
          ArchiveSession.$_createMessage);
  static ArchiveSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get archived => $_getBF(0);
  @$pb.TagNumber(1)
  set archived($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasArchived() => $_has(0);
  @$pb.TagNumber(1)
  void clearArchived() => $_clearField(1);
}

/// REST body for POST /api/v1/sessions/{id}/global.
class SetGlobal extends $pb.GeneratedMessage {
  factory SetGlobal({
    $core.bool? global,
  }) {
    final result = SetGlobal._();
    if (global != null) result.global = global;
    return result;
  }

  SetGlobal._();

  factory SetGlobal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetGlobal()..mergeFromBuffer(data, registry);
  factory SetGlobal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetGlobal()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetGlobal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SetGlobal.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'global')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetGlobal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetGlobal copyWith(void Function(SetGlobal) updates) =>
      super.copyWith((message) => updates(message as SetGlobal)) as SetGlobal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetGlobal() / SetGlobal.new instead')
  static SetGlobal create() => SetGlobal._();
  static $pb.GeneratedMessage $_createMessage() => SetGlobal._();
  @$core.override
  SetGlobal createEmptyInstance() => SetGlobal._();
  @$core.pragma('dart2js:noInline')
  static SetGlobal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetGlobal>(SetGlobal.$_createMessage);
  static SetGlobal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get global => $_getBF(0);
  @$pb.TagNumber(1)
  set global($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGlobal() => $_has(0);
  @$pb.TagNumber(1)
  void clearGlobal() => $_clearField(1);
}

class SendMessage extends $pb.GeneratedMessage {
  factory SendMessage({
    $core.String? session,
    $core.String? text,
    $core.bool? fork,
    $core.Iterable<$core.String>? attachments,
  }) {
    final result = SendMessage._();
    if (session != null) result.session = session;
    if (text != null) result.text = text;
    if (fork != null) result.fork = fork;
    if (attachments != null) result.attachments.addAll(attachments);
    return result;
  }

  SendMessage._();

  factory SendMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendMessage()..mergeFromBuffer(data, registry);
  factory SendMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendMessage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SendMessage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aOB(3, _omitFieldNames ? '' : 'fork')
    ..pPS(4, _omitFieldNames ? '' : 'attachments')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessage copyWith(void Function(SendMessage) updates) =>
      super.copyWith((message) => updates(message as SendMessage))
          as SendMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SendMessage() / SendMessage.new instead')
  static SendMessage create() => SendMessage._();
  static $pb.GeneratedMessage $_createMessage() => SendMessage._();
  @$core.override
  SendMessage createEmptyInstance() => SendMessage._();
  @$core.pragma('dart2js:noInline')
  static SendMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SendMessage>(
          SendMessage.$_createMessage);
  static SendMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  /// Continue in a new session id, leaving the original untouched.
  @$pb.TagNumber(3)
  $core.bool get fork => $_getBF(2);
  @$pb.TagNumber(3)
  set fork($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFork() => $_has(2);
  @$pb.TagNumber(3)
  void clearFork() => $_clearField(3);

  /// Artifact ids to put in the session's folder and mention in the message.
  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get attachments => $_getList(3);
}

/// Stops the current turn; the session stays open.
class InterruptSession extends $pb.GeneratedMessage {
  factory InterruptSession({
    $core.String? session,
  }) {
    final result = InterruptSession._();
    if (session != null) result.session = session;
    return result;
  }

  InterruptSession._();

  factory InterruptSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InterruptSession()..mergeFromBuffer(data, registry);
  factory InterruptSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InterruptSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InterruptSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: InterruptSession.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InterruptSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InterruptSession copyWith(void Function(InterruptSession) updates) =>
      super.copyWith((message) => updates(message as InterruptSession))
          as InterruptSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use InterruptSession() / InterruptSession.new instead')
  static InterruptSession create() => InterruptSession._();
  static $pb.GeneratedMessage $_createMessage() => InterruptSession._();
  @$core.override
  InterruptSession createEmptyInstance() => InterruptSession._();
  @$core.pragma('dart2js:noInline')
  static InterruptSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<InterruptSession>(
          InterruptSession.$_createMessage);
  static InterruptSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

/// Ends a session the agent hosts (tmux or headless). Sessions open in your
/// own terminal can only be interrupted, not ended.
class StopSession extends $pb.GeneratedMessage {
  factory StopSession({
    $core.String? session,
  }) {
    final result = StopSession._();
    if (session != null) result.session = session;
    return result;
  }

  StopSession._();

  factory StopSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopSession()..mergeFromBuffer(data, registry);
  factory StopSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: StopSession.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopSession copyWith(void Function(StopSession) updates) =>
      super.copyWith((message) => updates(message as StopSession))
          as StopSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopSession() / StopSession.new instead')
  static StopSession create() => StopSession._();
  static $pb.GeneratedMessage $_createMessage() => StopSession._();
  @$core.override
  StopSession createEmptyInstance() => StopSession._();
  @$core.pragma('dart2js:noInline')
  static StopSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StopSession>(
          StopSession.$_createMessage);
  static StopSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class Welcome extends $pb.GeneratedMessage {
  factory Welcome({
    $core.String? hubVersion,
    $core.Iterable<NodeStatus>? nodes,
    $core.Iterable<SessionInfo>? sessions,
    $core.Iterable<ApprovalRequest>? pendingApprovals,
    Preferences? preferences,
    $core.String? hubNode,
    $core.String? deviceId,
    $core.String? clientIp,
  }) {
    final result = Welcome._();
    if (hubVersion != null) result.hubVersion = hubVersion;
    if (nodes != null) result.nodes.addAll(nodes);
    if (sessions != null) result.sessions.addAll(sessions);
    if (pendingApprovals != null)
      result.pendingApprovals.addAll(pendingApprovals);
    if (preferences != null) result.preferences = preferences;
    if (hubNode != null) result.hubNode = hubNode;
    if (deviceId != null) result.deviceId = deviceId;
    if (clientIp != null) result.clientIp = clientIp;
    return result;
  }

  Welcome._();

  factory Welcome.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Welcome()..mergeFromBuffer(data, registry);
  factory Welcome.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Welcome()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Welcome',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Welcome.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'hubVersion')
    ..pPM<NodeStatus>(2, _omitFieldNames ? '' : 'nodes',
        subBuilder: NodeStatus.$_createMessage)
    ..pPM<SessionInfo>(3, _omitFieldNames ? '' : 'sessions',
        subBuilder: SessionInfo.$_createMessage)
    ..pPM<ApprovalRequest>(4, _omitFieldNames ? '' : 'pendingApprovals',
        subBuilder: ApprovalRequest.$_createMessage)
    ..aOM<Preferences>(5, _omitFieldNames ? '' : 'preferences',
        subBuilder: Preferences.$_createMessage)
    ..aOS(6, _omitFieldNames ? '' : 'hubNode')
    ..aOS(7, _omitFieldNames ? '' : 'deviceId')
    ..aOS(8, _omitFieldNames ? '' : 'clientIp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Welcome clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Welcome copyWith(void Function(Welcome) updates) =>
      super.copyWith((message) => updates(message as Welcome)) as Welcome;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Welcome() / Welcome.new instead')
  static Welcome create() => Welcome._();
  static $pb.GeneratedMessage $_createMessage() => Welcome._();
  @$core.override
  Welcome createEmptyInstance() => Welcome._();
  @$core.pragma('dart2js:noInline')
  static Welcome getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Welcome>(Welcome.$_createMessage);
  static Welcome? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get hubVersion => $_getSZ(0);
  @$pb.TagNumber(1)
  set hubVersion($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHubVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearHubVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<NodeStatus> get nodes => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<SessionInfo> get sessions => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<ApprovalRequest> get pendingApprovals => $_getList(3);

  /// Unset until some client has saved them.
  @$pb.TagNumber(5)
  Preferences get preferences => $_getN(4);
  @$pb.TagNumber(5)
  set preferences(Preferences value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPreferences() => $_has(4);
  @$pb.TagNumber(5)
  void clearPreferences() => $_clearField(5);
  @$pb.TagNumber(5)
  Preferences ensurePreferences() => $_ensure(4);

  /// The node running on the hub's own machine, where hub sessions run.
  @$pb.TagNumber(6)
  $core.String get hubNode => $_getSZ(5);
  @$pb.TagNumber(6)
  set hubNode($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHubNode() => $_has(5);
  @$pb.TagNumber(6)
  void clearHubNode() => $_clearField(6);

  /// About the client receiving this: its paired device id (empty for the
  /// admin token or a trusted tailnet) and the address it connected from,
  /// which matches NodeStatus.ip for the node on its own machine.
  @$pb.TagNumber(7)
  $core.String get deviceId => $_getSZ(6);
  @$pb.TagNumber(7)
  set deviceId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDeviceId() => $_has(6);
  @$pb.TagNumber(7)
  void clearDeviceId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get clientIp => $_getSZ(7);
  @$pb.TagNumber(8)
  set clientIp($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasClientIp() => $_has(7);
  @$pb.TagNumber(8)
  void clearClientIp() => $_clearField(8);
}

class Ack extends $pb.GeneratedMessage {
  factory Ack({
    $core.String? session,
  }) {
    final result = Ack._();
    if (session != null) result.session = session;
    return result;
  }

  Ack._();

  factory Ack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Ack()..mergeFromBuffer(data, registry);
  factory Ack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Ack()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ack',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Ack.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack copyWith(void Function(Ack) updates) =>
      super.copyWith((message) => updates(message as Ack)) as Ack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Ack() / Ack.new instead')
  static Ack create() => Ack._();
  static $pb.GeneratedMessage $_createMessage() => Ack._();
  @$core.override
  Ack createEmptyInstance() => Ack._();
  @$core.pragma('dart2js:noInline')
  static Ack getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Ack>(Ack.$_createMessage);
  static Ack? _defaultInstance;

  /// Set when the command created a session (create, or send with fork).
  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class Error extends $pb.GeneratedMessage {
  factory Error({
    $core.String? code,
    $core.String? message,
  }) {
    final result = Error._();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    return result;
  }

  Error._();

  factory Error.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Error()..mergeFromBuffer(data, registry);
  factory Error.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Error()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Error',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Error.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error copyWith(void Function(Error) updates) =>
      super.copyWith((message) => updates(message as Error)) as Error;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Error() / Error.new instead')
  static Error create() => Error._();
  static $pb.GeneratedMessage $_createMessage() => Error._();
  @$core.override
  Error createEmptyInstance() => Error._();
  @$core.pragma('dart2js:noInline')
  static Error getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Error>(Error.$_createMessage);
  static Error? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class AgentHello extends $pb.GeneratedMessage {
  factory AgentHello({
    $core.String? token,
    NodeStatus? status,
  }) {
    final result = AgentHello._();
    if (token != null) result.token = token;
    if (status != null) result.status = status;
    return result;
  }

  AgentHello._();

  factory AgentHello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentHello()..mergeFromBuffer(data, registry);
  factory AgentHello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentHello()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentHello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentHello.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOM<NodeStatus>(2, _omitFieldNames ? '' : 'status',
        subBuilder: NodeStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentHello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentHello copyWith(void Function(AgentHello) updates) =>
      super.copyWith((message) => updates(message as AgentHello)) as AgentHello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentHello() / AgentHello.new instead')
  static AgentHello create() => AgentHello._();
  static $pb.GeneratedMessage $_createMessage() => AgentHello._();
  @$core.override
  AgentHello createEmptyInstance() => AgentHello._();
  @$core.pragma('dart2js:noInline')
  static AgentHello getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentHello>(AgentHello.$_createMessage);
  static AgentHello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  NodeStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(NodeStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
  @$pb.TagNumber(2)
  NodeStatus ensureStatus() => $_ensure(1);
}

class SessionIndex extends $pb.GeneratedMessage {
  factory SessionIndex({
    $core.bool? full,
    $core.Iterable<SessionInfo>? sessions,
    $core.Iterable<$core.String>? removed,
  }) {
    final result = SessionIndex._();
    if (full != null) result.full = full;
    if (sessions != null) result.sessions.addAll(sessions);
    if (removed != null) result.removed.addAll(removed);
    return result;
  }

  SessionIndex._();

  factory SessionIndex.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionIndex()..mergeFromBuffer(data, registry);
  factory SessionIndex.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionIndex()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionIndex',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SessionIndex.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'full')
    ..pPM<SessionInfo>(2, _omitFieldNames ? '' : 'sessions',
        subBuilder: SessionInfo.$_createMessage)
    ..pPS(3, _omitFieldNames ? '' : 'removed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionIndex clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionIndex copyWith(void Function(SessionIndex) updates) =>
      super.copyWith((message) => updates(message as SessionIndex))
          as SessionIndex;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionIndex() / SessionIndex.new instead')
  static SessionIndex create() => SessionIndex._();
  static $pb.GeneratedMessage $_createMessage() => SessionIndex._();
  @$core.override
  SessionIndex createEmptyInstance() => SessionIndex._();
  @$core.pragma('dart2js:noInline')
  static SessionIndex getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionIndex>(
          SessionIndex.$_createMessage);
  static SessionIndex? _defaultInstance;

  /// True when sessions is the node's complete list; the hub forgets the
  /// node's other sessions.
  @$pb.TagNumber(1)
  $core.bool get full => $_getBF(0);
  @$pb.TagNumber(1)
  set full($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFull() => $_has(0);
  @$pb.TagNumber(1)
  void clearFull() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<SessionInfo> get sessions => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get removed => $_getList(2);
}

class RawEvents extends $pb.GeneratedMessage {
  factory RawEvents({
    $core.String? session,
    RawEvents_Source? source,
    $core.Iterable<$core.String>? lines,
    $fixnum.Int64? endOffset,
  }) {
    final result = RawEvents._();
    if (session != null) result.session = session;
    if (source != null) result.source = source;
    if (lines != null) result.lines.addAll(lines);
    if (endOffset != null) result.endOffset = endOffset;
    return result;
  }

  RawEvents._();

  factory RawEvents.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RawEvents()..mergeFromBuffer(data, registry);
  factory RawEvents.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RawEvents()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RawEvents',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: RawEvents.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aE<RawEvents_Source>(2, _omitFieldNames ? '' : 'source',
        enumValues: RawEvents_Source.values)
    ..pPS(3, _omitFieldNames ? '' : 'lines')
    ..aInt64(4, _omitFieldNames ? '' : 'endOffset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RawEvents clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RawEvents copyWith(void Function(RawEvents) updates) =>
      super.copyWith((message) => updates(message as RawEvents)) as RawEvents;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RawEvents() / RawEvents.new instead')
  static RawEvents create() => RawEvents._();
  static $pb.GeneratedMessage $_createMessage() => RawEvents._();
  @$core.override
  RawEvents createEmptyInstance() => RawEvents._();
  @$core.pragma('dart2js:noInline')
  static RawEvents getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RawEvents>(RawEvents.$_createMessage);
  static RawEvents? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  RawEvents_Source get source => $_getN(1);
  @$pb.TagNumber(2)
  set source(RawEvents_Source value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSource() => $_has(1);
  @$pb.TagNumber(2)
  void clearSource() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get lines => $_getList(2);

  /// For transcripts: byte offset just past the last line.
  @$pb.TagNumber(4)
  $fixnum.Int64 get endOffset => $_getI64(3);
  @$pb.TagNumber(4)
  set endOffset($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndOffset() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndOffset() => $_clearField(4);
}

class AgentCommand_StartRun extends $pb.GeneratedMessage {
  factory AgentCommand_StartRun({
    $core.String? session,
    $core.String? cwd,
    $core.String? prompt,
    $core.String? model,
    $core.String? permissionMode,
    $core.String? name,
    $core.String? resume,
    $core.bool? fork,
    $core.bool? createCwd,
    $core.Iterable<Artifact>? attachments,
    $core.bool? scratch,
    $core.String? restoreTranscript,
    $core.String? restoreCodebase,
    $core.String? restoreSnapshot,
  }) {
    final result = AgentCommand_StartRun._();
    if (session != null) result.session = session;
    if (cwd != null) result.cwd = cwd;
    if (prompt != null) result.prompt = prompt;
    if (model != null) result.model = model;
    if (permissionMode != null) result.permissionMode = permissionMode;
    if (name != null) result.name = name;
    if (resume != null) result.resume = resume;
    if (fork != null) result.fork = fork;
    if (createCwd != null) result.createCwd = createCwd;
    if (attachments != null) result.attachments.addAll(attachments);
    if (scratch != null) result.scratch = scratch;
    if (restoreTranscript != null) result.restoreTranscript = restoreTranscript;
    if (restoreCodebase != null) result.restoreCodebase = restoreCodebase;
    if (restoreSnapshot != null) result.restoreSnapshot = restoreSnapshot;
    return result;
  }

  AgentCommand_StartRun._();

  factory AgentCommand_StartRun.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_StartRun()..mergeFromBuffer(data, registry);
  factory AgentCommand_StartRun.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_StartRun()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.StartRun',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_StartRun.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aOS(2, _omitFieldNames ? '' : 'cwd')
    ..aOS(3, _omitFieldNames ? '' : 'prompt')
    ..aOS(4, _omitFieldNames ? '' : 'model')
    ..aOS(5, _omitFieldNames ? '' : 'permissionMode')
    ..aOS(6, _omitFieldNames ? '' : 'name')
    ..aOS(7, _omitFieldNames ? '' : 'resume')
    ..aOB(8, _omitFieldNames ? '' : 'fork')
    ..aOB(9, _omitFieldNames ? '' : 'createCwd')
    ..pPM<Artifact>(10, _omitFieldNames ? '' : 'attachments',
        subBuilder: Artifact.$_createMessage)
    ..aOB(11, _omitFieldNames ? '' : 'scratch')
    ..aOS(12, _omitFieldNames ? '' : 'restoreTranscript')
    ..aOS(13, _omitFieldNames ? '' : 'restoreCodebase')
    ..aOS(14, _omitFieldNames ? '' : 'restoreSnapshot')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_StartRun clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_StartRun copyWith(
          void Function(AgentCommand_StartRun) updates) =>
      super.copyWith((message) => updates(message as AgentCommand_StartRun))
          as AgentCommand_StartRun;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AgentCommand_StartRun() / AgentCommand_StartRun.new instead')
  static AgentCommand_StartRun create() => AgentCommand_StartRun._();
  static $pb.GeneratedMessage $_createMessage() => AgentCommand_StartRun._();
  @$core.override
  AgentCommand_StartRun createEmptyInstance() => AgentCommand_StartRun._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_StartRun getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_StartRun>(
          AgentCommand_StartRun.$_createMessage);
  static AgentCommand_StartRun? _defaultInstance;

  /// Pre-assigned by the hub so clients can subscribe immediately.
  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get cwd => $_getSZ(1);
  @$pb.TagNumber(2)
  set cwd($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCwd() => $_has(1);
  @$pb.TagNumber(2)
  void clearCwd() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get prompt => $_getSZ(2);
  @$pb.TagNumber(3)
  set prompt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrompt() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrompt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get model => $_getSZ(3);
  @$pb.TagNumber(4)
  set model($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModel() => $_has(3);
  @$pb.TagNumber(4)
  void clearModel() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get permissionMode => $_getSZ(4);
  @$pb.TagNumber(5)
  set permissionMode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPermissionMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearPermissionMode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get name => $_getSZ(5);
  @$pb.TagNumber(6)
  set name($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasName() => $_has(5);
  @$pb.TagNumber(6)
  void clearName() => $_clearField(6);

  /// Resume this existing session instead of starting fresh.
  @$pb.TagNumber(7)
  $core.String get resume => $_getSZ(6);
  @$pb.TagNumber(7)
  set resume($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasResume() => $_has(6);
  @$pb.TagNumber(7)
  void clearResume() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get fork => $_getBF(7);
  @$pb.TagNumber(8)
  set fork($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFork() => $_has(7);
  @$pb.TagNumber(8)
  void clearFork() => $_clearField(8);

  /// Create cwd first (a new project folder).
  @$pb.TagNumber(9)
  $core.bool get createCwd => $_getBF(8);
  @$pb.TagNumber(9)
  set createCwd($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCreateCwd() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreateCwd() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<Artifact> get attachments => $_getList(9);

  /// Run in <scratch dir>/<session>, created now.
  @$pb.TagNumber(11)
  $core.bool get scratch => $_getBF(10);
  @$pb.TagNumber(11)
  set scratch($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasScratch() => $_has(10);
  @$pb.TagNumber(11)
  void clearScratch() => $_clearField(11);

  /// Put this transcript (an artifact) where Claude Code looks for the
  /// resumed session first: continuing a global session elsewhere.
  @$pb.TagNumber(12)
  $core.String get restoreTranscript => $_getSZ(11);
  @$pb.TagNumber(12)
  set restoreTranscript($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasRestoreTranscript() => $_has(11);
  @$pb.TagNumber(12)
  void clearRestoreTranscript() => $_clearField(12);

  /// Restore this codebase snapshot into <codebases dir>/<codebase> first,
  /// with its .env files; cwd is then relative to that folder.
  @$pb.TagNumber(13)
  $core.String get restoreCodebase => $_getSZ(12);
  @$pb.TagNumber(13)
  set restoreCodebase($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasRestoreCodebase() => $_has(12);
  @$pb.TagNumber(13)
  void clearRestoreCodebase() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get restoreSnapshot => $_getSZ(13);
  @$pb.TagNumber(14)
  set restoreSnapshot($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasRestoreSnapshot() => $_has(13);
  @$pb.TagNumber(14)
  void clearRestoreSnapshot() => $_clearField(14);
}

class AgentCommand_SendInput extends $pb.GeneratedMessage {
  factory AgentCommand_SendInput({
    $core.String? session,
    $core.String? text,
    $core.Iterable<Artifact>? attachments,
  }) {
    final result = AgentCommand_SendInput._();
    if (session != null) result.session = session;
    if (text != null) result.text = text;
    if (attachments != null) result.attachments.addAll(attachments);
    return result;
  }

  AgentCommand_SendInput._();

  factory AgentCommand_SendInput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_SendInput()..mergeFromBuffer(data, registry);
  factory AgentCommand_SendInput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_SendInput()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.SendInput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_SendInput.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..pPM<Artifact>(3, _omitFieldNames ? '' : 'attachments',
        subBuilder: Artifact.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_SendInput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_SendInput copyWith(
          void Function(AgentCommand_SendInput) updates) =>
      super.copyWith((message) => updates(message as AgentCommand_SendInput))
          as AgentCommand_SendInput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AgentCommand_SendInput() / AgentCommand_SendInput.new instead')
  static AgentCommand_SendInput create() => AgentCommand_SendInput._();
  static $pb.GeneratedMessage $_createMessage() => AgentCommand_SendInput._();
  @$core.override
  AgentCommand_SendInput createEmptyInstance() => AgentCommand_SendInput._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_SendInput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_SendInput>(
          AgentCommand_SendInput.$_createMessage);
  static AgentCommand_SendInput? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  /// Fetched into the session's folder first; the text then lists them.
  @$pb.TagNumber(3)
  $pb.PbList<Artifact> get attachments => $_getList(2);
}

class AgentCommand_Interrupt extends $pb.GeneratedMessage {
  factory AgentCommand_Interrupt({
    $core.String? session,
  }) {
    final result = AgentCommand_Interrupt._();
    if (session != null) result.session = session;
    return result;
  }

  AgentCommand_Interrupt._();

  factory AgentCommand_Interrupt.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_Interrupt()..mergeFromBuffer(data, registry);
  factory AgentCommand_Interrupt.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_Interrupt()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.Interrupt',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_Interrupt.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_Interrupt clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_Interrupt copyWith(
          void Function(AgentCommand_Interrupt) updates) =>
      super.copyWith((message) => updates(message as AgentCommand_Interrupt))
          as AgentCommand_Interrupt;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AgentCommand_Interrupt() / AgentCommand_Interrupt.new instead')
  static AgentCommand_Interrupt create() => AgentCommand_Interrupt._();
  static $pb.GeneratedMessage $_createMessage() => AgentCommand_Interrupt._();
  @$core.override
  AgentCommand_Interrupt createEmptyInstance() => AgentCommand_Interrupt._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_Interrupt getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_Interrupt>(
          AgentCommand_Interrupt.$_createMessage);
  static AgentCommand_Interrupt? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class AgentCommand_Mirror extends $pb.GeneratedMessage {
  factory AgentCommand_Mirror({
    $core.String? session,
    $fixnum.Int64? fromOffset,
  }) {
    final result = AgentCommand_Mirror._();
    if (session != null) result.session = session;
    if (fromOffset != null) result.fromOffset = fromOffset;
    return result;
  }

  AgentCommand_Mirror._();

  factory AgentCommand_Mirror.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_Mirror()..mergeFromBuffer(data, registry);
  factory AgentCommand_Mirror.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_Mirror()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.Mirror',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_Mirror.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aInt64(2, _omitFieldNames ? '' : 'fromOffset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_Mirror clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_Mirror copyWith(void Function(AgentCommand_Mirror) updates) =>
      super.copyWith((message) => updates(message as AgentCommand_Mirror))
          as AgentCommand_Mirror;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use AgentCommand_Mirror() / AgentCommand_Mirror.new instead')
  static AgentCommand_Mirror create() => AgentCommand_Mirror._();
  static $pb.GeneratedMessage $_createMessage() => AgentCommand_Mirror._();
  @$core.override
  AgentCommand_Mirror createEmptyInstance() => AgentCommand_Mirror._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_Mirror getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_Mirror>(
          AgentCommand_Mirror.$_createMessage);
  static AgentCommand_Mirror? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get fromOffset => $_getI64(1);
  @$pb.TagNumber(2)
  set fromOffset($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFromOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearFromOffset() => $_clearField(2);
}

class AgentCommand_StopMirror extends $pb.GeneratedMessage {
  factory AgentCommand_StopMirror({
    $core.String? session,
  }) {
    final result = AgentCommand_StopMirror._();
    if (session != null) result.session = session;
    return result;
  }

  AgentCommand_StopMirror._();

  factory AgentCommand_StopMirror.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_StopMirror()..mergeFromBuffer(data, registry);
  factory AgentCommand_StopMirror.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_StopMirror()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.StopMirror',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_StopMirror.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_StopMirror clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_StopMirror copyWith(
          void Function(AgentCommand_StopMirror) updates) =>
      super.copyWith((message) => updates(message as AgentCommand_StopMirror))
          as AgentCommand_StopMirror;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AgentCommand_StopMirror() / AgentCommand_StopMirror.new instead')
  static AgentCommand_StopMirror create() => AgentCommand_StopMirror._();
  static $pb.GeneratedMessage $_createMessage() => AgentCommand_StopMirror._();
  @$core.override
  AgentCommand_StopMirror createEmptyInstance() => AgentCommand_StopMirror._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_StopMirror getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_StopMirror>(
          AgentCommand_StopMirror.$_createMessage);
  static AgentCommand_StopMirror? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class AgentCommand_Stop extends $pb.GeneratedMessage {
  factory AgentCommand_Stop({
    $core.String? session,
  }) {
    final result = AgentCommand_Stop._();
    if (session != null) result.session = session;
    return result;
  }

  AgentCommand_Stop._();

  factory AgentCommand_Stop.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_Stop()..mergeFromBuffer(data, registry);
  factory AgentCommand_Stop.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_Stop()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.Stop',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_Stop.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_Stop clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_Stop copyWith(void Function(AgentCommand_Stop) updates) =>
      super.copyWith((message) => updates(message as AgentCommand_Stop))
          as AgentCommand_Stop;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentCommand_Stop() / AgentCommand_Stop.new instead')
  static AgentCommand_Stop create() => AgentCommand_Stop._();
  static $pb.GeneratedMessage $_createMessage() => AgentCommand_Stop._();
  @$core.override
  AgentCommand_Stop createEmptyInstance() => AgentCommand_Stop._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_Stop getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentCommand_Stop>(
          AgentCommand_Stop.$_createMessage);
  static AgentCommand_Stop? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class AgentCommand_Forget extends $pb.GeneratedMessage {
  factory AgentCommand_Forget({
    $core.String? session,
  }) {
    final result = AgentCommand_Forget._();
    if (session != null) result.session = session;
    return result;
  }

  AgentCommand_Forget._();

  factory AgentCommand_Forget.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_Forget()..mergeFromBuffer(data, registry);
  factory AgentCommand_Forget.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_Forget()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.Forget',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_Forget.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_Forget clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_Forget copyWith(void Function(AgentCommand_Forget) updates) =>
      super.copyWith((message) => updates(message as AgentCommand_Forget))
          as AgentCommand_Forget;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use AgentCommand_Forget() / AgentCommand_Forget.new instead')
  static AgentCommand_Forget create() => AgentCommand_Forget._();
  static $pb.GeneratedMessage $_createMessage() => AgentCommand_Forget._();
  @$core.override
  AgentCommand_Forget createEmptyInstance() => AgentCommand_Forget._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_Forget getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_Forget>(
          AgentCommand_Forget.$_createMessage);
  static AgentCommand_Forget? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class AgentCommand_UploadTranscript extends $pb.GeneratedMessage {
  factory AgentCommand_UploadTranscript({
    $core.String? session,
  }) {
    final result = AgentCommand_UploadTranscript._();
    if (session != null) result.session = session;
    return result;
  }

  AgentCommand_UploadTranscript._();

  factory AgentCommand_UploadTranscript.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_UploadTranscript()..mergeFromBuffer(data, registry);
  factory AgentCommand_UploadTranscript.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_UploadTranscript()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.UploadTranscript',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_UploadTranscript.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_UploadTranscript clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_UploadTranscript copyWith(
          void Function(AgentCommand_UploadTranscript) updates) =>
      super.copyWith(
              (message) => updates(message as AgentCommand_UploadTranscript))
          as AgentCommand_UploadTranscript;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AgentCommand_UploadTranscript() / AgentCommand_UploadTranscript.new instead')
  static AgentCommand_UploadTranscript create() =>
      AgentCommand_UploadTranscript._();
  static $pb.GeneratedMessage $_createMessage() =>
      AgentCommand_UploadTranscript._();
  @$core.override
  AgentCommand_UploadTranscript createEmptyInstance() =>
      AgentCommand_UploadTranscript._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_UploadTranscript getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_UploadTranscript>(
          AgentCommand_UploadTranscript.$_createMessage);
  static AgentCommand_UploadTranscript? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
}

class AgentCommand_SnapshotCodebase extends $pb.GeneratedMessage {
  factory AgentCommand_SnapshotCodebase({
    Codebase? codebase,
    $core.String? session,
  }) {
    final result = AgentCommand_SnapshotCodebase._();
    if (codebase != null) result.codebase = codebase;
    if (session != null) result.session = session;
    return result;
  }

  AgentCommand_SnapshotCodebase._();

  factory AgentCommand_SnapshotCodebase.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_SnapshotCodebase()..mergeFromBuffer(data, registry);
  factory AgentCommand_SnapshotCodebase.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_SnapshotCodebase()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.SnapshotCodebase',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_SnapshotCodebase.$_createMessage)
    ..aOM<Codebase>(1, _omitFieldNames ? '' : 'codebase',
        subBuilder: Codebase.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'session')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_SnapshotCodebase clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_SnapshotCodebase copyWith(
          void Function(AgentCommand_SnapshotCodebase) updates) =>
      super.copyWith(
              (message) => updates(message as AgentCommand_SnapshotCodebase))
          as AgentCommand_SnapshotCodebase;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AgentCommand_SnapshotCodebase() / AgentCommand_SnapshotCodebase.new instead')
  static AgentCommand_SnapshotCodebase create() =>
      AgentCommand_SnapshotCodebase._();
  static $pb.GeneratedMessage $_createMessage() =>
      AgentCommand_SnapshotCodebase._();
  @$core.override
  AgentCommand_SnapshotCodebase createEmptyInstance() =>
      AgentCommand_SnapshotCodebase._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_SnapshotCodebase getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_SnapshotCodebase>(
          AgentCommand_SnapshotCodebase.$_createMessage);
  static AgentCommand_SnapshotCodebase? _defaultInstance;

  @$pb.TagNumber(1)
  Codebase get codebase => $_getN(0);
  @$pb.TagNumber(1)
  set codebase(Codebase value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCodebase() => $_has(0);
  @$pb.TagNumber(1)
  void clearCodebase() => $_clearField(1);
  @$pb.TagNumber(1)
  Codebase ensureCodebase() => $_ensure(0);

  /// The session it's taken for, if any.
  @$pb.TagNumber(2)
  $core.String get session => $_getSZ(1);
  @$pb.TagNumber(2)
  set session($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSession() => $_has(1);
  @$pb.TagNumber(2)
  void clearSession() => $_clearField(2);
}

class AgentCommand_ScanCodebases extends $pb.GeneratedMessage {
  factory AgentCommand_ScanCodebases({
    $core.Iterable<$core.String>? roots,
  }) {
    final result = AgentCommand_ScanCodebases._();
    if (roots != null) result.roots.addAll(roots);
    return result;
  }

  AgentCommand_ScanCodebases._();

  factory AgentCommand_ScanCodebases.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_ScanCodebases()..mergeFromBuffer(data, registry);
  factory AgentCommand_ScanCodebases.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_ScanCodebases()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.ScanCodebases',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_ScanCodebases.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'roots')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_ScanCodebases clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_ScanCodebases copyWith(
          void Function(AgentCommand_ScanCodebases) updates) =>
      super.copyWith(
              (message) => updates(message as AgentCommand_ScanCodebases))
          as AgentCommand_ScanCodebases;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AgentCommand_ScanCodebases() / AgentCommand_ScanCodebases.new instead')
  static AgentCommand_ScanCodebases create() => AgentCommand_ScanCodebases._();
  static $pb.GeneratedMessage $_createMessage() =>
      AgentCommand_ScanCodebases._();
  @$core.override
  AgentCommand_ScanCodebases createEmptyInstance() =>
      AgentCommand_ScanCodebases._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_ScanCodebases getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_ScanCodebases>(
          AgentCommand_ScanCodebases.$_createMessage);
  static AgentCommand_ScanCodebases? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get roots => $_getList(0);
}

/// Into <cwd>/.tether/attachments/<name>, checked against its sha256.
class AgentCommand_FetchAttachment extends $pb.GeneratedMessage {
  factory AgentCommand_FetchAttachment({
    $core.String? session,
    $core.String? cwd,
    Artifact? artifact,
  }) {
    final result = AgentCommand_FetchAttachment._();
    if (session != null) result.session = session;
    if (cwd != null) result.cwd = cwd;
    if (artifact != null) result.artifact = artifact;
    return result;
  }

  AgentCommand_FetchAttachment._();

  factory AgentCommand_FetchAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_FetchAttachment()..mergeFromBuffer(data, registry);
  factory AgentCommand_FetchAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand_FetchAttachment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand.FetchAttachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand_FetchAttachment.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aOS(2, _omitFieldNames ? '' : 'cwd')
    ..aOM<Artifact>(3, _omitFieldNames ? '' : 'artifact',
        subBuilder: Artifact.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_FetchAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand_FetchAttachment copyWith(
          void Function(AgentCommand_FetchAttachment) updates) =>
      super.copyWith(
              (message) => updates(message as AgentCommand_FetchAttachment))
          as AgentCommand_FetchAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AgentCommand_FetchAttachment() / AgentCommand_FetchAttachment.new instead')
  static AgentCommand_FetchAttachment create() =>
      AgentCommand_FetchAttachment._();
  static $pb.GeneratedMessage $_createMessage() =>
      AgentCommand_FetchAttachment._();
  @$core.override
  AgentCommand_FetchAttachment createEmptyInstance() =>
      AgentCommand_FetchAttachment._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand_FetchAttachment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCommand_FetchAttachment>(
          AgentCommand_FetchAttachment.$_createMessage);
  static AgentCommand_FetchAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get cwd => $_getSZ(1);
  @$pb.TagNumber(2)
  set cwd($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCwd() => $_has(1);
  @$pb.TagNumber(2)
  void clearCwd() => $_clearField(2);

  @$pb.TagNumber(3)
  Artifact get artifact => $_getN(2);
  @$pb.TagNumber(3)
  set artifact(Artifact value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasArtifact() => $_has(2);
  @$pb.TagNumber(3)
  void clearArtifact() => $_clearField(3);
  @$pb.TagNumber(3)
  Artifact ensureArtifact() => $_ensure(2);
}

enum AgentCommand_Op {
  start,
  send,
  interrupt,
  mirror,
  stopMirror,
  stop,
  forget,
  uploadTranscript,
  snapshot,
  scan,
  fetch,
  notSet
}

class AgentCommand extends $pb.GeneratedMessage {
  factory AgentCommand({
    AgentCommand_StartRun? start,
    AgentCommand_SendInput? send,
    AgentCommand_Interrupt? interrupt,
    AgentCommand_Mirror? mirror,
    AgentCommand_StopMirror? stopMirror,
    AgentCommand_Stop? stop,
    AgentCommand_Forget? forget,
    AgentCommand_UploadTranscript? uploadTranscript,
    AgentCommand_SnapshotCodebase? snapshot,
    AgentCommand_ScanCodebases? scan,
    AgentCommand_FetchAttachment? fetch,
  }) {
    final result = AgentCommand._();
    if (start != null) result.start = start;
    if (send != null) result.send = send;
    if (interrupt != null) result.interrupt = interrupt;
    if (mirror != null) result.mirror = mirror;
    if (stopMirror != null) result.stopMirror = stopMirror;
    if (stop != null) result.stop = stop;
    if (forget != null) result.forget = forget;
    if (uploadTranscript != null) result.uploadTranscript = uploadTranscript;
    if (snapshot != null) result.snapshot = snapshot;
    if (scan != null) result.scan = scan;
    if (fetch != null) result.fetch = fetch;
    return result;
  }

  AgentCommand._();

  factory AgentCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand()..mergeFromBuffer(data, registry);
  factory AgentCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCommand()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, AgentCommand_Op> _AgentCommand_OpByTag = {
    1: AgentCommand_Op.start,
    2: AgentCommand_Op.send,
    3: AgentCommand_Op.interrupt,
    4: AgentCommand_Op.mirror,
    5: AgentCommand_Op.stopMirror,
    6: AgentCommand_Op.stop,
    7: AgentCommand_Op.forget,
    8: AgentCommand_Op.uploadTranscript,
    9: AgentCommand_Op.snapshot,
    10: AgentCommand_Op.scan,
    11: AgentCommand_Op.fetch,
    0: AgentCommand_Op.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    ..aOM<AgentCommand_StartRun>(1, _omitFieldNames ? '' : 'start',
        subBuilder: AgentCommand_StartRun.$_createMessage)
    ..aOM<AgentCommand_SendInput>(2, _omitFieldNames ? '' : 'send',
        subBuilder: AgentCommand_SendInput.$_createMessage)
    ..aOM<AgentCommand_Interrupt>(3, _omitFieldNames ? '' : 'interrupt',
        subBuilder: AgentCommand_Interrupt.$_createMessage)
    ..aOM<AgentCommand_Mirror>(4, _omitFieldNames ? '' : 'mirror',
        subBuilder: AgentCommand_Mirror.$_createMessage)
    ..aOM<AgentCommand_StopMirror>(5, _omitFieldNames ? '' : 'stopMirror',
        subBuilder: AgentCommand_StopMirror.$_createMessage)
    ..aOM<AgentCommand_Stop>(6, _omitFieldNames ? '' : 'stop',
        subBuilder: AgentCommand_Stop.$_createMessage)
    ..aOM<AgentCommand_Forget>(7, _omitFieldNames ? '' : 'forget',
        subBuilder: AgentCommand_Forget.$_createMessage)
    ..aOM<AgentCommand_UploadTranscript>(
        8, _omitFieldNames ? '' : 'uploadTranscript',
        subBuilder: AgentCommand_UploadTranscript.$_createMessage)
    ..aOM<AgentCommand_SnapshotCodebase>(9, _omitFieldNames ? '' : 'snapshot',
        subBuilder: AgentCommand_SnapshotCodebase.$_createMessage)
    ..aOM<AgentCommand_ScanCodebases>(10, _omitFieldNames ? '' : 'scan',
        subBuilder: AgentCommand_ScanCodebases.$_createMessage)
    ..aOM<AgentCommand_FetchAttachment>(11, _omitFieldNames ? '' : 'fetch',
        subBuilder: AgentCommand_FetchAttachment.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCommand copyWith(void Function(AgentCommand) updates) =>
      super.copyWith((message) => updates(message as AgentCommand))
          as AgentCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentCommand() / AgentCommand.new instead')
  static AgentCommand create() => AgentCommand._();
  static $pb.GeneratedMessage $_createMessage() => AgentCommand._();
  @$core.override
  AgentCommand createEmptyInstance() => AgentCommand._();
  @$core.pragma('dart2js:noInline')
  static AgentCommand getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentCommand>(
          AgentCommand.$_createMessage);
  static AgentCommand? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  AgentCommand_Op whichOp() => _AgentCommand_OpByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  void clearOp() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  AgentCommand_StartRun get start => $_getN(0);
  @$pb.TagNumber(1)
  set start(AgentCommand_StartRun value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStart() => $_has(0);
  @$pb.TagNumber(1)
  void clearStart() => $_clearField(1);
  @$pb.TagNumber(1)
  AgentCommand_StartRun ensureStart() => $_ensure(0);

  @$pb.TagNumber(2)
  AgentCommand_SendInput get send => $_getN(1);
  @$pb.TagNumber(2)
  set send(AgentCommand_SendInput value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSend() => $_has(1);
  @$pb.TagNumber(2)
  void clearSend() => $_clearField(2);
  @$pb.TagNumber(2)
  AgentCommand_SendInput ensureSend() => $_ensure(1);

  @$pb.TagNumber(3)
  AgentCommand_Interrupt get interrupt => $_getN(2);
  @$pb.TagNumber(3)
  set interrupt(AgentCommand_Interrupt value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasInterrupt() => $_has(2);
  @$pb.TagNumber(3)
  void clearInterrupt() => $_clearField(3);
  @$pb.TagNumber(3)
  AgentCommand_Interrupt ensureInterrupt() => $_ensure(2);

  @$pb.TagNumber(4)
  AgentCommand_Mirror get mirror => $_getN(3);
  @$pb.TagNumber(4)
  set mirror(AgentCommand_Mirror value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasMirror() => $_has(3);
  @$pb.TagNumber(4)
  void clearMirror() => $_clearField(4);
  @$pb.TagNumber(4)
  AgentCommand_Mirror ensureMirror() => $_ensure(3);

  @$pb.TagNumber(5)
  AgentCommand_StopMirror get stopMirror => $_getN(4);
  @$pb.TagNumber(5)
  set stopMirror(AgentCommand_StopMirror value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStopMirror() => $_has(4);
  @$pb.TagNumber(5)
  void clearStopMirror() => $_clearField(5);
  @$pb.TagNumber(5)
  AgentCommand_StopMirror ensureStopMirror() => $_ensure(4);

  @$pb.TagNumber(6)
  AgentCommand_Stop get stop => $_getN(5);
  @$pb.TagNumber(6)
  set stop(AgentCommand_Stop value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStop() => $_has(5);
  @$pb.TagNumber(6)
  void clearStop() => $_clearField(6);
  @$pb.TagNumber(6)
  AgentCommand_Stop ensureStop() => $_ensure(5);

  /// Delete a scratch session's folder and transcript (retention).
  @$pb.TagNumber(7)
  AgentCommand_Forget get forget => $_getN(6);
  @$pb.TagNumber(7)
  set forget(AgentCommand_Forget value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasForget() => $_has(6);
  @$pb.TagNumber(7)
  void clearForget() => $_clearField(7);
  @$pb.TagNumber(7)
  AgentCommand_Forget ensureForget() => $_ensure(6);

  /// Upload the session's whole transcript to the artifact store.
  @$pb.TagNumber(8)
  AgentCommand_UploadTranscript get uploadTranscript => $_getN(7);
  @$pb.TagNumber(8)
  set uploadTranscript(AgentCommand_UploadTranscript value) =>
      $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasUploadTranscript() => $_has(7);
  @$pb.TagNumber(8)
  void clearUploadTranscript() => $_clearField(8);
  @$pb.TagNumber(8)
  AgentCommand_UploadTranscript ensureUploadTranscript() => $_ensure(7);

  /// Snapshot a codebase into the hub, and its .env files into the vault.
  @$pb.TagNumber(9)
  AgentCommand_SnapshotCodebase get snapshot => $_getN(8);
  @$pb.TagNumber(9)
  set snapshot(AgentCommand_SnapshotCodebase value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSnapshot() => $_has(8);
  @$pb.TagNumber(9)
  void clearSnapshot() => $_clearField(9);
  @$pb.TagNumber(9)
  AgentCommand_SnapshotCodebase ensureSnapshot() => $_ensure(8);

  /// Report the codebases directly under these workspace roots.
  @$pb.TagNumber(10)
  AgentCommand_ScanCodebases get scan => $_getN(9);
  @$pb.TagNumber(10)
  set scan(AgentCommand_ScanCodebases value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasScan() => $_has(9);
  @$pb.TagNumber(10)
  void clearScan() => $_clearField(10);
  @$pb.TagNumber(10)
  AgentCommand_ScanCodebases ensureScan() => $_ensure(9);

  /// Download a file attached to a session into its folder.
  @$pb.TagNumber(11)
  AgentCommand_FetchAttachment get fetch => $_getN(10);
  @$pb.TagNumber(11)
  set fetch(AgentCommand_FetchAttachment value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasFetch() => $_has(10);
  @$pb.TagNumber(11)
  void clearFetch() => $_clearField(11);
  @$pb.TagNumber(11)
  AgentCommand_FetchAttachment ensureFetch() => $_ensure(10);
}

/// A folder on a node the hub keeps copies of. GET /api/v1/codebases.
class Codebase extends $pb.GeneratedMessage {
  factory Codebase({
    $core.String? id,
    $core.String? node,
    $core.String? path,
    $core.String? name,
    $core.String? gitRemote,
    $core.String? gitBranch,
    $core.String? gitHead,
    $fixnum.Int64? createdMs,
    $core.String? snapshot,
    $fixnum.Int64? snapshotMs,
    $core.int? files,
    $fixnum.Int64? bytes,
    $core.Iterable<EnvFile>? env,
    $core.String? error,
  }) {
    final result = Codebase._();
    if (id != null) result.id = id;
    if (node != null) result.node = node;
    if (path != null) result.path = path;
    if (name != null) result.name = name;
    if (gitRemote != null) result.gitRemote = gitRemote;
    if (gitBranch != null) result.gitBranch = gitBranch;
    if (gitHead != null) result.gitHead = gitHead;
    if (createdMs != null) result.createdMs = createdMs;
    if (snapshot != null) result.snapshot = snapshot;
    if (snapshotMs != null) result.snapshotMs = snapshotMs;
    if (files != null) result.files = files;
    if (bytes != null) result.bytes = bytes;
    if (env != null) result.env.addAll(env);
    if (error != null) result.error = error;
    return result;
  }

  Codebase._();

  factory Codebase.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Codebase()..mergeFromBuffer(data, registry);
  factory Codebase.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Codebase()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Codebase',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Codebase.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'node')
    ..aOS(3, _omitFieldNames ? '' : 'path')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOS(5, _omitFieldNames ? '' : 'gitRemote')
    ..aOS(6, _omitFieldNames ? '' : 'gitBranch')
    ..aOS(7, _omitFieldNames ? '' : 'gitHead')
    ..aInt64(8, _omitFieldNames ? '' : 'createdMs')
    ..aOS(9, _omitFieldNames ? '' : 'snapshot')
    ..aInt64(10, _omitFieldNames ? '' : 'snapshotMs')
    ..aI(11, _omitFieldNames ? '' : 'files')
    ..aInt64(12, _omitFieldNames ? '' : 'bytes')
    ..pPM<EnvFile>(13, _omitFieldNames ? '' : 'env',
        subBuilder: EnvFile.$_createMessage)
    ..aOS(14, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Codebase clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Codebase copyWith(void Function(Codebase) updates) =>
      super.copyWith((message) => updates(message as Codebase)) as Codebase;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Codebase() / Codebase.new instead')
  static Codebase create() => Codebase._();
  static $pb.GeneratedMessage $_createMessage() => Codebase._();
  @$core.override
  Codebase createEmptyInstance() => Codebase._();
  @$core.pragma('dart2js:noInline')
  static Codebase getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Codebase>(Codebase.$_createMessage);
  static Codebase? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get node => $_getSZ(1);
  @$pb.TagNumber(2)
  set node($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNode() => $_has(1);
  @$pb.TagNumber(2)
  void clearNode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get path => $_getSZ(2);
  @$pb.TagNumber(3)
  set path($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPath() => $_has(2);
  @$pb.TagNumber(3)
  void clearPath() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get gitRemote => $_getSZ(4);
  @$pb.TagNumber(5)
  set gitRemote($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGitRemote() => $_has(4);
  @$pb.TagNumber(5)
  void clearGitRemote() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get gitBranch => $_getSZ(5);
  @$pb.TagNumber(6)
  set gitBranch($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGitBranch() => $_has(5);
  @$pb.TagNumber(6)
  void clearGitBranch() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get gitHead => $_getSZ(6);
  @$pb.TagNumber(7)
  set gitHead($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGitHead() => $_has(6);
  @$pb.TagNumber(7)
  void clearGitHead() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get createdMs => $_getI64(7);
  @$pb.TagNumber(8)
  set createdMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedMs() => $_clearField(8);

  /// The latest snapshot.
  @$pb.TagNumber(9)
  $core.String get snapshot => $_getSZ(8);
  @$pb.TagNumber(9)
  set snapshot($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSnapshot() => $_has(8);
  @$pb.TagNumber(9)
  void clearSnapshot() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get snapshotMs => $_getI64(9);
  @$pb.TagNumber(10)
  set snapshotMs($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSnapshotMs() => $_has(9);
  @$pb.TagNumber(10)
  void clearSnapshotMs() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get files => $_getIZ(10);
  @$pb.TagNumber(11)
  set files($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasFiles() => $_has(10);
  @$pb.TagNumber(11)
  void clearFiles() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get bytes => $_getI64(11);
  @$pb.TagNumber(12)
  set bytes($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasBytes() => $_has(11);
  @$pb.TagNumber(12)
  void clearBytes() => $_clearField(12);

  /// .env files kept in the vault, by path in the codebase; values never
  /// leave the hub except to restore the codebase on the hub's machine.
  @$pb.TagNumber(13)
  $pb.PbList<EnvFile> get env => $_getList(12);

  /// Why the last snapshot failed, if it did.
  @$pb.TagNumber(14)
  $core.String get error => $_getSZ(13);
  @$pb.TagNumber(14)
  set error($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasError() => $_has(13);
  @$pb.TagNumber(14)
  void clearError() => $_clearField(14);
}

class CodebaseList extends $pb.GeneratedMessage {
  factory CodebaseList({
    $core.Iterable<Codebase>? codebases,
  }) {
    final result = CodebaseList._();
    if (codebases != null) result.codebases.addAll(codebases);
    return result;
  }

  CodebaseList._();

  factory CodebaseList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CodebaseList()..mergeFromBuffer(data, registry);
  factory CodebaseList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CodebaseList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CodebaseList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: CodebaseList.$_createMessage)
    ..pPM<Codebase>(1, _omitFieldNames ? '' : 'codebases',
        subBuilder: Codebase.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CodebaseList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CodebaseList copyWith(void Function(CodebaseList) updates) =>
      super.copyWith((message) => updates(message as CodebaseList))
          as CodebaseList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CodebaseList() / CodebaseList.new instead')
  static CodebaseList create() => CodebaseList._();
  static $pb.GeneratedMessage $_createMessage() => CodebaseList._();
  @$core.override
  CodebaseList createEmptyInstance() => CodebaseList._();
  @$core.pragma('dart2js:noInline')
  static CodebaseList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CodebaseList>(
          CodebaseList.$_createMessage);
  static CodebaseList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Codebase> get codebases => $_getList(0);
}

class SnapshotFile extends $pb.GeneratedMessage {
  factory SnapshotFile({
    $core.String? path,
    $core.String? sha256,
    $fixnum.Int64? size,
    $core.bool? executable,
  }) {
    final result = SnapshotFile._();
    if (path != null) result.path = path;
    if (sha256 != null) result.sha256 = sha256;
    if (size != null) result.size = size;
    if (executable != null) result.executable = executable;
    return result;
  }

  SnapshotFile._();

  factory SnapshotFile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SnapshotFile()..mergeFromBuffer(data, registry);
  factory SnapshotFile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SnapshotFile()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SnapshotFile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SnapshotFile.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'sha256')
    ..aInt64(3, _omitFieldNames ? '' : 'size')
    ..aOB(4, _omitFieldNames ? '' : 'executable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotFile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotFile copyWith(void Function(SnapshotFile) updates) =>
      super.copyWith((message) => updates(message as SnapshotFile))
          as SnapshotFile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SnapshotFile() / SnapshotFile.new instead')
  static SnapshotFile create() => SnapshotFile._();
  static $pb.GeneratedMessage $_createMessage() => SnapshotFile._();
  @$core.override
  SnapshotFile createEmptyInstance() => SnapshotFile._();
  @$core.pragma('dart2js:noInline')
  static SnapshotFile getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SnapshotFile>(
          SnapshotFile.$_createMessage);
  static SnapshotFile? _defaultInstance;

  /// Relative to the codebase, with forward slashes.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sha256 => $_getSZ(1);
  @$pb.TagNumber(2)
  set sha256($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSha256() => $_has(1);
  @$pb.TagNumber(2)
  void clearSha256() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get size => $_getI64(2);
  @$pb.TagNumber(3)
  set size($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get executable => $_getBF(3);
  @$pb.TagNumber(4)
  set executable($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExecutable() => $_has(3);
  @$pb.TagNumber(4)
  void clearExecutable() => $_clearField(4);
}

/// POST /api/v1/codebases/{id}/manifest answers with the hashes the hub
/// lacks; the agent uploads those (PUT /api/v1/blobs/{sha}) and posts the
/// same manifest to /snapshots to record it.
class SnapshotManifest extends $pb.GeneratedMessage {
  factory SnapshotManifest({
    $core.String? session,
    $core.Iterable<SnapshotFile>? files,
    $core.Iterable<$core.String>? skipped,
    $core.String? gitRemote,
    $core.String? gitBranch,
    $core.String? gitHead,
  }) {
    final result = SnapshotManifest._();
    if (session != null) result.session = session;
    if (files != null) result.files.addAll(files);
    if (skipped != null) result.skipped.addAll(skipped);
    if (gitRemote != null) result.gitRemote = gitRemote;
    if (gitBranch != null) result.gitBranch = gitBranch;
    if (gitHead != null) result.gitHead = gitHead;
    return result;
  }

  SnapshotManifest._();

  factory SnapshotManifest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SnapshotManifest()..mergeFromBuffer(data, registry);
  factory SnapshotManifest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SnapshotManifest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SnapshotManifest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SnapshotManifest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..pPM<SnapshotFile>(2, _omitFieldNames ? '' : 'files',
        subBuilder: SnapshotFile.$_createMessage)
    ..pPS(3, _omitFieldNames ? '' : 'skipped')
    ..aOS(4, _omitFieldNames ? '' : 'gitRemote')
    ..aOS(5, _omitFieldNames ? '' : 'gitBranch')
    ..aOS(6, _omitFieldNames ? '' : 'gitHead')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotManifest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotManifest copyWith(void Function(SnapshotManifest) updates) =>
      super.copyWith((message) => updates(message as SnapshotManifest))
          as SnapshotManifest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SnapshotManifest() / SnapshotManifest.new instead')
  static SnapshotManifest create() => SnapshotManifest._();
  static $pb.GeneratedMessage $_createMessage() => SnapshotManifest._();
  @$core.override
  SnapshotManifest createEmptyInstance() => SnapshotManifest._();
  @$core.pragma('dart2js:noInline')
  static SnapshotManifest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SnapshotManifest>(
          SnapshotManifest.$_createMessage);
  static SnapshotManifest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<SnapshotFile> get files => $_getList(1);

  /// Too big to copy, or unreadable.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get skipped => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get gitRemote => $_getSZ(3);
  @$pb.TagNumber(4)
  set gitRemote($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGitRemote() => $_has(3);
  @$pb.TagNumber(4)
  void clearGitRemote() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get gitBranch => $_getSZ(4);
  @$pb.TagNumber(5)
  set gitBranch($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGitBranch() => $_has(4);
  @$pb.TagNumber(5)
  void clearGitBranch() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get gitHead => $_getSZ(5);
  @$pb.TagNumber(6)
  set gitHead($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGitHead() => $_has(5);
  @$pb.TagNumber(6)
  void clearGitHead() => $_clearField(6);
}

class MissingBlobs extends $pb.GeneratedMessage {
  factory MissingBlobs({
    $core.Iterable<$core.String>? sha256,
  }) {
    final result = MissingBlobs._();
    if (sha256 != null) result.sha256.addAll(sha256);
    return result;
  }

  MissingBlobs._();

  factory MissingBlobs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MissingBlobs()..mergeFromBuffer(data, registry);
  factory MissingBlobs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MissingBlobs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MissingBlobs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: MissingBlobs.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'sha256')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MissingBlobs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MissingBlobs copyWith(void Function(MissingBlobs) updates) =>
      super.copyWith((message) => updates(message as MissingBlobs))
          as MissingBlobs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MissingBlobs() / MissingBlobs.new instead')
  static MissingBlobs create() => MissingBlobs._();
  static $pb.GeneratedMessage $_createMessage() => MissingBlobs._();
  @$core.override
  MissingBlobs createEmptyInstance() => MissingBlobs._();
  @$core.pragma('dart2js:noInline')
  static MissingBlobs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MissingBlobs>(
          MissingBlobs.$_createMessage);
  static MissingBlobs? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get sha256 => $_getList(0);
}

class Snapshot extends $pb.GeneratedMessage {
  factory Snapshot({
    $core.String? id,
    $core.String? codebase,
    $core.String? session,
    $core.String? parent,
    $fixnum.Int64? createdMs,
    $core.int? files,
    $fixnum.Int64? bytes,
    $core.String? gitHead,
    $core.int? skipped,
    $core.String? manifestSha256,
  }) {
    final result = Snapshot._();
    if (id != null) result.id = id;
    if (codebase != null) result.codebase = codebase;
    if (session != null) result.session = session;
    if (parent != null) result.parent = parent;
    if (createdMs != null) result.createdMs = createdMs;
    if (files != null) result.files = files;
    if (bytes != null) result.bytes = bytes;
    if (gitHead != null) result.gitHead = gitHead;
    if (skipped != null) result.skipped = skipped;
    if (manifestSha256 != null) result.manifestSha256 = manifestSha256;
    return result;
  }

  Snapshot._();

  factory Snapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Snapshot()..mergeFromBuffer(data, registry);
  factory Snapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Snapshot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Snapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Snapshot.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'codebase')
    ..aOS(3, _omitFieldNames ? '' : 'session')
    ..aOS(4, _omitFieldNames ? '' : 'parent')
    ..aInt64(5, _omitFieldNames ? '' : 'createdMs')
    ..aI(6, _omitFieldNames ? '' : 'files')
    ..aInt64(7, _omitFieldNames ? '' : 'bytes')
    ..aOS(8, _omitFieldNames ? '' : 'gitHead')
    ..aI(9, _omitFieldNames ? '' : 'skipped')
    ..aOS(10, _omitFieldNames ? '' : 'manifestSha256')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Snapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Snapshot copyWith(void Function(Snapshot) updates) =>
      super.copyWith((message) => updates(message as Snapshot)) as Snapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Snapshot() / Snapshot.new instead')
  static Snapshot create() => Snapshot._();
  static $pb.GeneratedMessage $_createMessage() => Snapshot._();
  @$core.override
  Snapshot createEmptyInstance() => Snapshot._();
  @$core.pragma('dart2js:noInline')
  static Snapshot getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Snapshot>(Snapshot.$_createMessage);
  static Snapshot? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get codebase => $_getSZ(1);
  @$pb.TagNumber(2)
  set codebase($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCodebase() => $_has(1);
  @$pb.TagNumber(2)
  void clearCodebase() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get session => $_getSZ(2);
  @$pb.TagNumber(3)
  set session($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSession() => $_has(2);
  @$pb.TagNumber(3)
  void clearSession() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get parent => $_getSZ(3);
  @$pb.TagNumber(4)
  set parent($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasParent() => $_has(3);
  @$pb.TagNumber(4)
  void clearParent() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get createdMs => $_getI64(4);
  @$pb.TagNumber(5)
  set createdMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get files => $_getIZ(5);
  @$pb.TagNumber(6)
  set files($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFiles() => $_has(5);
  @$pb.TagNumber(6)
  void clearFiles() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get bytes => $_getI64(6);
  @$pb.TagNumber(7)
  set bytes($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBytes() => $_has(6);
  @$pb.TagNumber(7)
  void clearBytes() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get gitHead => $_getSZ(7);
  @$pb.TagNumber(8)
  set gitHead($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasGitHead() => $_has(7);
  @$pb.TagNumber(8)
  void clearGitHead() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get skipped => $_getIZ(8);
  @$pb.TagNumber(9)
  set skipped($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSkipped() => $_has(8);
  @$pb.TagNumber(9)
  void clearSkipped() => $_clearField(9);

  /// The manifest, stored as a blob.
  @$pb.TagNumber(10)
  $core.String get manifestSha256 => $_getSZ(9);
  @$pb.TagNumber(10)
  set manifestSha256($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasManifestSha256() => $_has(9);
  @$pb.TagNumber(10)
  void clearManifestSha256() => $_clearField(10);
}

class SnapshotList extends $pb.GeneratedMessage {
  factory SnapshotList({
    $core.Iterable<Snapshot>? snapshots,
  }) {
    final result = SnapshotList._();
    if (snapshots != null) result.snapshots.addAll(snapshots);
    return result;
  }

  SnapshotList._();

  factory SnapshotList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SnapshotList()..mergeFromBuffer(data, registry);
  factory SnapshotList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SnapshotList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SnapshotList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SnapshotList.$_createMessage)
    ..pPM<Snapshot>(1, _omitFieldNames ? '' : 'snapshots',
        subBuilder: Snapshot.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotList copyWith(void Function(SnapshotList) updates) =>
      super.copyWith((message) => updates(message as SnapshotList))
          as SnapshotList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SnapshotList() / SnapshotList.new instead')
  static SnapshotList create() => SnapshotList._();
  static $pb.GeneratedMessage $_createMessage() => SnapshotList._();
  @$core.override
  SnapshotList createEmptyInstance() => SnapshotList._();
  @$core.pragma('dart2js:noInline')
  static SnapshotList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SnapshotList>(
          SnapshotList.$_createMessage);
  static SnapshotList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Snapshot> get snapshots => $_getList(0);
}

class EnvKey extends $pb.GeneratedMessage {
  factory EnvKey({
    $core.String? name,
    $core.String? fingerprint,
  }) {
    final result = EnvKey._();
    if (name != null) result.name = name;
    if (fingerprint != null) result.fingerprint = fingerprint;
    return result;
  }

  EnvKey._();

  factory EnvKey.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EnvKey()..mergeFromBuffer(data, registry);
  factory EnvKey.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EnvKey()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnvKey',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: EnvKey.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'fingerprint')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnvKey clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnvKey copyWith(void Function(EnvKey) updates) =>
      super.copyWith((message) => updates(message as EnvKey)) as EnvKey;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EnvKey() / EnvKey.new instead')
  static EnvKey create() => EnvKey._();
  static $pb.GeneratedMessage $_createMessage() => EnvKey._();
  @$core.override
  EnvKey createEmptyInstance() => EnvKey._();
  @$core.pragma('dart2js:noInline')
  static EnvKey getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnvKey>(EnvKey.$_createMessage);
  static EnvKey? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// A short keyed hash of the value, so changes show without the value.
  @$pb.TagNumber(2)
  $core.String get fingerprint => $_getSZ(1);
  @$pb.TagNumber(2)
  set fingerprint($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFingerprint() => $_has(1);
  @$pb.TagNumber(2)
  void clearFingerprint() => $_clearField(2);
}

class EnvFile extends $pb.GeneratedMessage {
  factory EnvFile({
    $core.String? path,
    $core.Iterable<EnvKey>? keys,
    $fixnum.Int64? updatedMs,
    $core.String? content,
  }) {
    final result = EnvFile._();
    if (path != null) result.path = path;
    if (keys != null) result.keys.addAll(keys);
    if (updatedMs != null) result.updatedMs = updatedMs;
    if (content != null) result.content = content;
    return result;
  }

  EnvFile._();

  factory EnvFile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EnvFile()..mergeFromBuffer(data, registry);
  factory EnvFile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EnvFile()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnvFile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: EnvFile.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..pPM<EnvKey>(2, _omitFieldNames ? '' : 'keys',
        subBuilder: EnvKey.$_createMessage)
    ..aInt64(3, _omitFieldNames ? '' : 'updatedMs')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnvFile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnvFile copyWith(void Function(EnvFile) updates) =>
      super.copyWith((message) => updates(message as EnvFile)) as EnvFile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EnvFile() / EnvFile.new instead')
  static EnvFile create() => EnvFile._();
  static $pb.GeneratedMessage $_createMessage() => EnvFile._();
  @$core.override
  EnvFile createEmptyInstance() => EnvFile._();
  @$core.pragma('dart2js:noInline')
  static EnvFile getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnvFile>(EnvFile.$_createMessage);
  static EnvFile? _defaultInstance;

  /// Relative to the codebase, e.g. "server/.env".
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<EnvKey> get keys => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get updatedMs => $_getI64(2);
  @$pb.TagNumber(3)
  set updatedMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUpdatedMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpdatedMs() => $_clearField(3);

  /// Only between agent and hub: the file as written, for the vault or to
  /// restore it. Never in API responses to apps.
  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);
}

/// PUT /api/v1/codebases/{id}/env (an agent storing), and what the hub's own
/// agent gets back when restoring.
class EnvFiles extends $pb.GeneratedMessage {
  factory EnvFiles({
    $core.Iterable<EnvFile>? files,
  }) {
    final result = EnvFiles._();
    if (files != null) result.files.addAll(files);
    return result;
  }

  EnvFiles._();

  factory EnvFiles.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EnvFiles()..mergeFromBuffer(data, registry);
  factory EnvFiles.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EnvFiles()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnvFiles',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: EnvFiles.$_createMessage)
    ..pPM<EnvFile>(1, _omitFieldNames ? '' : 'files',
        subBuilder: EnvFile.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnvFiles clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnvFiles copyWith(void Function(EnvFiles) updates) =>
      super.copyWith((message) => updates(message as EnvFiles)) as EnvFiles;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EnvFiles() / EnvFiles.new instead')
  static EnvFiles create() => EnvFiles._();
  static $pb.GeneratedMessage $_createMessage() => EnvFiles._();
  @$core.override
  EnvFiles createEmptyInstance() => EnvFiles._();
  @$core.pragma('dart2js:noInline')
  static EnvFiles getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnvFiles>(EnvFiles.$_createMessage);
  static EnvFiles? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<EnvFile> get files => $_getList(0);
}

/// Codebases an agent found under its workspace roots:
/// POST /api/v1/codebases/found.
class FoundCodebases extends $pb.GeneratedMessage {
  factory FoundCodebases({
    $core.String? node,
    $core.Iterable<Codebase>? codebases,
  }) {
    final result = FoundCodebases._();
    if (node != null) result.node = node;
    if (codebases != null) result.codebases.addAll(codebases);
    return result;
  }

  FoundCodebases._();

  factory FoundCodebases.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FoundCodebases()..mergeFromBuffer(data, registry);
  factory FoundCodebases.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FoundCodebases()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FoundCodebases',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: FoundCodebases.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'node')
    ..pPM<Codebase>(2, _omitFieldNames ? '' : 'codebases',
        subBuilder: Codebase.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FoundCodebases clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FoundCodebases copyWith(void Function(FoundCodebases) updates) =>
      super.copyWith((message) => updates(message as FoundCodebases))
          as FoundCodebases;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FoundCodebases() / FoundCodebases.new instead')
  static FoundCodebases create() => FoundCodebases._();
  static $pb.GeneratedMessage $_createMessage() => FoundCodebases._();
  @$core.override
  FoundCodebases createEmptyInstance() => FoundCodebases._();
  @$core.pragma('dart2js:noInline')
  static FoundCodebases getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FoundCodebases>(
          FoundCodebases.$_createMessage);
  static FoundCodebases? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get node => $_getSZ(0);
  @$pb.TagNumber(1)
  set node($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearNode() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Codebase> get codebases => $_getList(1);
}

/// An app or agent that paired with its own token. Revoking deletes it.
class Device extends $pb.GeneratedMessage {
  factory Device({
    $core.String? id,
    $core.String? kind,
    $core.String? name,
    $core.String? platform,
    $fixnum.Int64? createdMs,
    $fixnum.Int64? lastSeenMs,
  }) {
    final result = Device._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (name != null) result.name = name;
    if (platform != null) result.platform = platform;
    if (createdMs != null) result.createdMs = createdMs;
    if (lastSeenMs != null) result.lastSeenMs = lastSeenMs;
    return result;
  }

  Device._();

  factory Device.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Device()..mergeFromBuffer(data, registry);
  factory Device.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Device()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Device',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Device.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'platform')
    ..aInt64(5, _omitFieldNames ? '' : 'createdMs')
    ..aInt64(6, _omitFieldNames ? '' : 'lastSeenMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device copyWith(void Function(Device) updates) =>
      super.copyWith((message) => updates(message as Device)) as Device;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Device() / Device.new instead')
  static Device create() => Device._();
  static $pb.GeneratedMessage $_createMessage() => Device._();
  @$core.override
  Device createEmptyInstance() => Device._();
  @$core.pragma('dart2js:noInline')
  static Device getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Device>(Device.$_createMessage);
  static Device? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// "client" (an app or tetherctl) or "node" (an agent).
  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  /// For a node, the node name its token is bound to.
  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get platform => $_getSZ(3);
  @$pb.TagNumber(4)
  set platform($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlatform() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlatform() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get createdMs => $_getI64(4);
  @$pb.TagNumber(5)
  set createdMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get lastSeenMs => $_getI64(5);
  @$pb.TagNumber(6)
  set lastSeenMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLastSeenMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearLastSeenMs() => $_clearField(6);
}

class DeviceList extends $pb.GeneratedMessage {
  factory DeviceList({
    $core.Iterable<Device>? devices,
  }) {
    final result = DeviceList._();
    if (devices != null) result.devices.addAll(devices);
    return result;
  }

  DeviceList._();

  factory DeviceList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceList()..mergeFromBuffer(data, registry);
  factory DeviceList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: DeviceList.$_createMessage)
    ..pPM<Device>(1, _omitFieldNames ? '' : 'devices',
        subBuilder: Device.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceList copyWith(void Function(DeviceList) updates) =>
      super.copyWith((message) => updates(message as DeviceList)) as DeviceList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeviceList() / DeviceList.new instead')
  static DeviceList create() => DeviceList._();
  static $pb.GeneratedMessage $_createMessage() => DeviceList._();
  @$core.override
  DeviceList createEmptyInstance() => DeviceList._();
  @$core.pragma('dart2js:noInline')
  static DeviceList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceList>(DeviceList.$_createMessage);
  static DeviceList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Device> get devices => $_getList(0);
}

/// A one-time code another device can pair with until expires_ms.
class PairingCode extends $pb.GeneratedMessage {
  factory PairingCode({
    $core.String? code,
    $fixnum.Int64? expiresMs,
    $core.String? certFingerprint,
  }) {
    final result = PairingCode._();
    if (code != null) result.code = code;
    if (expiresMs != null) result.expiresMs = expiresMs;
    if (certFingerprint != null) result.certFingerprint = certFingerprint;
    return result;
  }

  PairingCode._();

  factory PairingCode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingCode()..mergeFromBuffer(data, registry);
  factory PairingCode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingCode()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairingCode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: PairingCode.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aInt64(2, _omitFieldNames ? '' : 'expiresMs')
    ..aOS(3, _omitFieldNames ? '' : 'certFingerprint')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingCode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingCode copyWith(void Function(PairingCode) updates) =>
      super.copyWith((message) => updates(message as PairingCode))
          as PairingCode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PairingCode() / PairingCode.new instead')
  static PairingCode create() => PairingCode._();
  static $pb.GeneratedMessage $_createMessage() => PairingCode._();
  @$core.override
  PairingCode createEmptyInstance() => PairingCode._();
  @$core.pragma('dart2js:noInline')
  static PairingCode getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PairingCode>(
          PairingCode.$_createMessage);
  static PairingCode? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiresMs => $_getI64(1);
  @$pb.TagNumber(2)
  set expiresMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiresMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresMs() => $_clearField(2);

  /// SHA-256 of the hub's TLS certificate (hex), when it serves its own
  /// self-signed one; clients pin it.
  @$pb.TagNumber(3)
  $core.String get certFingerprint => $_getSZ(2);
  @$pb.TagNumber(3)
  set certFingerprint($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCertFingerprint() => $_has(2);
  @$pb.TagNumber(3)
  void clearCertFingerprint() => $_clearField(3);
}

class PairRequest extends $pb.GeneratedMessage {
  factory PairRequest({
    $core.String? code,
    $core.String? kind,
    $core.String? name,
    $core.String? platform,
  }) {
    final result = PairRequest._();
    if (code != null) result.code = code;
    if (kind != null) result.kind = kind;
    if (name != null) result.name = name;
    if (platform != null) result.platform = platform;
    return result;
  }

  PairRequest._();

  factory PairRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairRequest()..mergeFromBuffer(data, registry);
  factory PairRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: PairRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'platform')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairRequest copyWith(void Function(PairRequest) updates) =>
      super.copyWith((message) => updates(message as PairRequest))
          as PairRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PairRequest() / PairRequest.new instead')
  static PairRequest create() => PairRequest._();
  static $pb.GeneratedMessage $_createMessage() => PairRequest._();
  @$core.override
  PairRequest createEmptyInstance() => PairRequest._();
  @$core.pragma('dart2js:noInline')
  static PairRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PairRequest>(
          PairRequest.$_createMessage);
  static PairRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  /// "client" or "node".
  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get platform => $_getSZ(3);
  @$pb.TagNumber(4)
  set platform($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlatform() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlatform() => $_clearField(4);
}

class PairResult extends $pb.GeneratedMessage {
  factory PairResult({
    Device? device,
    $core.String? token,
  }) {
    final result = PairResult._();
    if (device != null) result.device = device;
    if (token != null) result.token = token;
    return result;
  }

  PairResult._();

  factory PairResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairResult()..mergeFromBuffer(data, registry);
  factory PairResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: PairResult.$_createMessage)
    ..aOM<Device>(1, _omitFieldNames ? '' : 'device',
        subBuilder: Device.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairResult copyWith(void Function(PairResult) updates) =>
      super.copyWith((message) => updates(message as PairResult)) as PairResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PairResult() / PairResult.new instead')
  static PairResult create() => PairResult._();
  static $pb.GeneratedMessage $_createMessage() => PairResult._();
  @$core.override
  PairResult createEmptyInstance() => PairResult._();
  @$core.pragma('dart2js:noInline')
  static PairResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairResult>(PairResult.$_createMessage);
  static PairResult? _defaultInstance;

  @$pb.TagNumber(1)
  Device get device => $_getN(0);
  @$pb.TagNumber(1)
  set device(Device value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDevice() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevice() => $_clearField(1);
  @$pb.TagNumber(1)
  Device ensureDevice() => $_ensure(0);

  /// Shown once; the hub keeps only its hash.
  @$pb.TagNumber(2)
  $core.String get token => $_getSZ(1);
  @$pb.TagNumber(2)
  set token($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);
}

/// App settings every connected app shares. PUT /api/v1/preferences.
class Preferences extends $pb.GeneratedMessage {
  factory Preferences({
    $core.String? themeMode,
    $core.String? palette,
    $core.int? accent,
  }) {
    final result = Preferences._();
    if (themeMode != null) result.themeMode = themeMode;
    if (palette != null) result.palette = palette;
    if (accent != null) result.accent = accent;
    return result;
  }

  Preferences._();

  factory Preferences.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Preferences()..mergeFromBuffer(data, registry);
  factory Preferences.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Preferences()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Preferences',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Preferences.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'themeMode')
    ..aOS(2, _omitFieldNames ? '' : 'palette')
    ..aI(3, _omitFieldNames ? '' : 'accent', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Preferences clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Preferences copyWith(void Function(Preferences) updates) =>
      super.copyWith((message) => updates(message as Preferences))
          as Preferences;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Preferences() / Preferences.new instead')
  static Preferences create() => Preferences._();
  static $pb.GeneratedMessage $_createMessage() => Preferences._();
  @$core.override
  Preferences createEmptyInstance() => Preferences._();
  @$core.pragma('dart2js:noInline')
  static Preferences getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Preferences>(
          Preferences.$_createMessage);
  static Preferences? _defaultInstance;

  /// "system", "light" or "dark".
  @$pb.TagNumber(1)
  $core.String get themeMode => $_getSZ(0);
  @$pb.TagNumber(1)
  set themeMode($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasThemeMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearThemeMode() => $_clearField(1);

  /// A palette id, e.g. "claude" or "ocean".
  @$pb.TagNumber(2)
  $core.String get palette => $_getSZ(1);
  @$pb.TagNumber(2)
  set palette($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPalette() => $_has(1);
  @$pb.TagNumber(2)
  void clearPalette() => $_clearField(2);

  /// ARGB accent; unset keeps the palette's own.
  @$pb.TagNumber(3)
  $core.int get accent => $_getIZ(2);
  @$pb.TagNumber(3)
  set accent($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAccent() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccent() => $_clearField(3);
}

/// A machine on the hub's tailnet, as `tailscale status` sees it, and what of
/// Tether runs there. GET /api/v1/tailnet.
class TailnetDevice extends $pb.GeneratedMessage {
  factory TailnetDevice({
    $core.String? name,
    $core.String? hostname,
    $core.String? os,
    $core.bool? online,
    $core.Iterable<$core.String>? ips,
    $core.bool? self,
    $core.String? node,
    $core.Iterable<$core.String>? clients,
    $fixnum.Int64? lastSeenMs,
  }) {
    final result = TailnetDevice._();
    if (name != null) result.name = name;
    if (hostname != null) result.hostname = hostname;
    if (os != null) result.os = os;
    if (online != null) result.online = online;
    if (ips != null) result.ips.addAll(ips);
    if (self != null) result.self = self;
    if (node != null) result.node = node;
    if (clients != null) result.clients.addAll(clients);
    if (lastSeenMs != null) result.lastSeenMs = lastSeenMs;
    return result;
  }

  TailnetDevice._();

  factory TailnetDevice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TailnetDevice()..mergeFromBuffer(data, registry);
  factory TailnetDevice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TailnetDevice()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TailnetDevice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: TailnetDevice.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'hostname')
    ..aOS(3, _omitFieldNames ? '' : 'os')
    ..aOB(4, _omitFieldNames ? '' : 'online')
    ..pPS(5, _omitFieldNames ? '' : 'ips')
    ..aOB(6, _omitFieldNames ? '' : 'self')
    ..aOS(7, _omitFieldNames ? '' : 'node')
    ..pPS(8, _omitFieldNames ? '' : 'clients')
    ..aInt64(9, _omitFieldNames ? '' : 'lastSeenMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TailnetDevice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TailnetDevice copyWith(void Function(TailnetDevice) updates) =>
      super.copyWith((message) => updates(message as TailnetDevice))
          as TailnetDevice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TailnetDevice() / TailnetDevice.new instead')
  static TailnetDevice create() => TailnetDevice._();
  static $pb.GeneratedMessage $_createMessage() => TailnetDevice._();
  @$core.override
  TailnetDevice createEmptyInstance() => TailnetDevice._();
  @$core.pragma('dart2js:noInline')
  static TailnetDevice getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TailnetDevice>(
          TailnetDevice.$_createMessage);
  static TailnetDevice? _defaultInstance;

  /// The tailnet machine name (first label of its MagicDNS name).
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get hostname => $_getSZ(1);
  @$pb.TagNumber(2)
  set hostname($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHostname() => $_has(1);
  @$pb.TagNumber(2)
  void clearHostname() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get os => $_getSZ(2);
  @$pb.TagNumber(3)
  set os($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOs() => $_has(2);
  @$pb.TagNumber(3)
  void clearOs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get online => $_getBF(3);
  @$pb.TagNumber(4)
  set online($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOnline() => $_has(3);
  @$pb.TagNumber(4)
  void clearOnline() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get ips => $_getList(4);

  /// The hub's own machine.
  @$pb.TagNumber(6)
  $core.bool get self => $_getBF(5);
  @$pb.TagNumber(6)
  set self($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSelf() => $_has(5);
  @$pb.TagNumber(6)
  void clearSelf() => $_clearField(6);

  /// The Tether node connected from this machine, if any.
  @$pb.TagNumber(7)
  $core.String get node => $_getSZ(6);
  @$pb.TagNumber(7)
  set node($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNode() => $_has(6);
  @$pb.TagNumber(7)
  void clearNode() => $_clearField(7);

  /// Names of apps connected from this machine.
  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get clients => $_getList(7);

  @$pb.TagNumber(9)
  $fixnum.Int64 get lastSeenMs => $_getI64(8);
  @$pb.TagNumber(9)
  set lastSeenMs($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLastSeenMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearLastSeenMs() => $_clearField(9);
}

class Tailnet extends $pb.GeneratedMessage {
  factory Tailnet({
    $core.Iterable<TailnetDevice>? devices,
    $core.String? error,
  }) {
    final result = Tailnet._();
    if (devices != null) result.devices.addAll(devices);
    if (error != null) result.error = error;
    return result;
  }

  Tailnet._();

  factory Tailnet.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Tailnet()..mergeFromBuffer(data, registry);
  factory Tailnet.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Tailnet()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Tailnet',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Tailnet.$_createMessage)
    ..pPM<TailnetDevice>(1, _omitFieldNames ? '' : 'devices',
        subBuilder: TailnetDevice.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tailnet clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tailnet copyWith(void Function(Tailnet) updates) =>
      super.copyWith((message) => updates(message as Tailnet)) as Tailnet;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Tailnet() / Tailnet.new instead')
  static Tailnet create() => Tailnet._();
  static $pb.GeneratedMessage $_createMessage() => Tailnet._();
  @$core.override
  Tailnet createEmptyInstance() => Tailnet._();
  @$core.pragma('dart2js:noInline')
  static Tailnet getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Tailnet>(Tailnet.$_createMessage);
  static Tailnet? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TailnetDevice> get devices => $_getList(0);

  /// Set when `tailscale status` couldn't be read (no Tailscale on the hub).
  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// A fork, branch, merge or abandon, as the hub recorded it. GET
/// /api/v1/sessions/{id}/lineage returns the events a session is part of.
class LineageEvent extends $pb.GeneratedMessage {
  factory LineageEvent({
    $fixnum.Int64? id,
    $core.String? session,
    $core.String? parent,
    $core.String? kind,
    $core.String? forkPoint,
    $core.String? by,
    $fixnum.Int64? atMs,
    $core.String? detail,
  }) {
    final result = LineageEvent._();
    if (id != null) result.id = id;
    if (session != null) result.session = session;
    if (parent != null) result.parent = parent;
    if (kind != null) result.kind = kind;
    if (forkPoint != null) result.forkPoint = forkPoint;
    if (by != null) result.by = by;
    if (atMs != null) result.atMs = atMs;
    if (detail != null) result.detail = detail;
    return result;
  }

  LineageEvent._();

  factory LineageEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LineageEvent()..mergeFromBuffer(data, registry);
  factory LineageEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LineageEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LineageEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: LineageEvent.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'session')
    ..aOS(3, _omitFieldNames ? '' : 'parent')
    ..aOS(4, _omitFieldNames ? '' : 'kind')
    ..aOS(5, _omitFieldNames ? '' : 'forkPoint')
    ..aOS(6, _omitFieldNames ? '' : 'by')
    ..aInt64(7, _omitFieldNames ? '' : 'atMs')
    ..aOS(8, _omitFieldNames ? '' : 'detail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LineageEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LineageEvent copyWith(void Function(LineageEvent) updates) =>
      super.copyWith((message) => updates(message as LineageEvent))
          as LineageEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LineageEvent() / LineageEvent.new instead')
  static LineageEvent create() => LineageEvent._();
  static $pb.GeneratedMessage $_createMessage() => LineageEvent._();
  @$core.override
  LineageEvent createEmptyInstance() => LineageEvent._();
  @$core.pragma('dart2js:noInline')
  static LineageEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LineageEvent>(
          LineageEvent.$_createMessage);
  static LineageEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get session => $_getSZ(1);
  @$pb.TagNumber(2)
  set session($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSession() => $_has(1);
  @$pb.TagNumber(2)
  void clearSession() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get parent => $_getSZ(2);
  @$pb.TagNumber(3)
  set parent($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasParent() => $_has(2);
  @$pb.TagNumber(3)
  void clearParent() => $_clearField(3);

  /// "fork", "branch", "merge" or "abandon".
  @$pb.TagNumber(4)
  $core.String get kind => $_getSZ(3);
  @$pb.TagNumber(4)
  set kind($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKind() => $_has(3);
  @$pb.TagNumber(4)
  void clearKind() => $_clearField(4);

  /// The parent's timeline item it split at.
  @$pb.TagNumber(5)
  $core.String get forkPoint => $_getSZ(4);
  @$pb.TagNumber(5)
  set forkPoint($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasForkPoint() => $_has(4);
  @$pb.TagNumber(5)
  void clearForkPoint() => $_clearField(5);

  /// The app or tool that asked, as for message sources.
  @$pb.TagNumber(6)
  $core.String get by => $_getSZ(5);
  @$pb.TagNumber(6)
  set by($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBy() => $_has(5);
  @$pb.TagNumber(6)
  void clearBy() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get atMs => $_getI64(6);
  @$pb.TagNumber(7)
  set atMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAtMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearAtMs() => $_clearField(7);

  /// For a merge: the summary sent to the parent.
  @$pb.TagNumber(8)
  $core.String get detail => $_getSZ(7);
  @$pb.TagNumber(8)
  set detail($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDetail() => $_has(7);
  @$pb.TagNumber(8)
  void clearDetail() => $_clearField(8);
}

class LineageEvents extends $pb.GeneratedMessage {
  factory LineageEvents({
    $core.Iterable<LineageEvent>? events,
  }) {
    final result = LineageEvents._();
    if (events != null) result.events.addAll(events);
    return result;
  }

  LineageEvents._();

  factory LineageEvents.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LineageEvents()..mergeFromBuffer(data, registry);
  factory LineageEvents.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LineageEvents()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LineageEvents',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: LineageEvents.$_createMessage)
    ..pPM<LineageEvent>(1, _omitFieldNames ? '' : 'events',
        subBuilder: LineageEvent.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LineageEvents clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LineageEvents copyWith(void Function(LineageEvents) updates) =>
      super.copyWith((message) => updates(message as LineageEvents))
          as LineageEvents;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LineageEvents() / LineageEvents.new instead')
  static LineageEvents create() => LineageEvents._();
  static $pb.GeneratedMessage $_createMessage() => LineageEvents._();
  @$core.override
  LineageEvents createEmptyInstance() => LineageEvents._();
  @$core.pragma('dart2js:noInline')
  static LineageEvents getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LineageEvents>(
          LineageEvents.$_createMessage);
  static LineageEvents? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<LineageEvent> get events => $_getList(0);
}

/// One assistant message's token usage. A message is written over several
/// transcript lines, so the hub keeps the largest value it has seen per field.
class UsageEntry extends $pb.GeneratedMessage {
  factory UsageEntry({
    $core.String? session,
    $core.String? messageId,
    $core.String? model,
    $fixnum.Int64? tsMs,
    $fixnum.Int64? input,
    $fixnum.Int64? output,
    $fixnum.Int64? cacheWrite,
    $fixnum.Int64? cacheRead,
  }) {
    final result = UsageEntry._();
    if (session != null) result.session = session;
    if (messageId != null) result.messageId = messageId;
    if (model != null) result.model = model;
    if (tsMs != null) result.tsMs = tsMs;
    if (input != null) result.input = input;
    if (output != null) result.output = output;
    if (cacheWrite != null) result.cacheWrite = cacheWrite;
    if (cacheRead != null) result.cacheRead = cacheRead;
    return result;
  }

  UsageEntry._();

  factory UsageEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageEntry()..mergeFromBuffer(data, registry);
  factory UsageEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageEntry()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsageEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: UsageEntry.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..aOS(3, _omitFieldNames ? '' : 'model')
    ..aInt64(4, _omitFieldNames ? '' : 'tsMs')
    ..aInt64(5, _omitFieldNames ? '' : 'input')
    ..aInt64(6, _omitFieldNames ? '' : 'output')
    ..aInt64(7, _omitFieldNames ? '' : 'cacheWrite')
    ..aInt64(8, _omitFieldNames ? '' : 'cacheRead')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageEntry copyWith(void Function(UsageEntry) updates) =>
      super.copyWith((message) => updates(message as UsageEntry)) as UsageEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UsageEntry() / UsageEntry.new instead')
  static UsageEntry create() => UsageEntry._();
  static $pb.GeneratedMessage $_createMessage() => UsageEntry._();
  @$core.override
  UsageEntry createEmptyInstance() => UsageEntry._();
  @$core.pragma('dart2js:noInline')
  static UsageEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UsageEntry>(UsageEntry.$_createMessage);
  static UsageEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get model => $_getSZ(2);
  @$pb.TagNumber(3)
  set model($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasModel() => $_has(2);
  @$pb.TagNumber(3)
  void clearModel() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get tsMs => $_getI64(3);
  @$pb.TagNumber(4)
  set tsMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTsMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTsMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get input => $_getI64(4);
  @$pb.TagNumber(5)
  set input($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInput() => $_has(4);
  @$pb.TagNumber(5)
  void clearInput() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get output => $_getI64(5);
  @$pb.TagNumber(6)
  set output($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOutput() => $_has(5);
  @$pb.TagNumber(6)
  void clearOutput() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get cacheWrite => $_getI64(6);
  @$pb.TagNumber(7)
  set cacheWrite($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCacheWrite() => $_has(6);
  @$pb.TagNumber(7)
  void clearCacheWrite() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get cacheRead => $_getI64(7);
  @$pb.TagNumber(8)
  set cacheRead($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCacheRead() => $_has(7);
  @$pb.TagNumber(8)
  void clearCacheRead() => $_clearField(8);
}

class UsageReport extends $pb.GeneratedMessage {
  factory UsageReport({
    $core.Iterable<UsageEntry>? entries,
  }) {
    final result = UsageReport._();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  UsageReport._();

  factory UsageReport.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageReport()..mergeFromBuffer(data, registry);
  factory UsageReport.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageReport()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsageReport',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: UsageReport.$_createMessage)
    ..pPM<UsageEntry>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: UsageEntry.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageReport clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageReport copyWith(void Function(UsageReport) updates) =>
      super.copyWith((message) => updates(message as UsageReport))
          as UsageReport;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UsageReport() / UsageReport.new instead')
  static UsageReport create() => UsageReport._();
  static $pb.GeneratedMessage $_createMessage() => UsageReport._();
  @$core.override
  UsageReport createEmptyInstance() => UsageReport._();
  @$core.pragma('dart2js:noInline')
  static UsageReport getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UsageReport>(
          UsageReport.$_createMessage);
  static UsageReport? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<UsageEntry> get entries => $_getList(0);
}

class UsageTotals extends $pb.GeneratedMessage {
  factory UsageTotals({
    $fixnum.Int64? input,
    $fixnum.Int64? output,
    $fixnum.Int64? cacheWrite,
    $fixnum.Int64? cacheRead,
    $fixnum.Int64? messages,
  }) {
    final result = UsageTotals._();
    if (input != null) result.input = input;
    if (output != null) result.output = output;
    if (cacheWrite != null) result.cacheWrite = cacheWrite;
    if (cacheRead != null) result.cacheRead = cacheRead;
    if (messages != null) result.messages = messages;
    return result;
  }

  UsageTotals._();

  factory UsageTotals.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageTotals()..mergeFromBuffer(data, registry);
  factory UsageTotals.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageTotals()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsageTotals',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: UsageTotals.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'input')
    ..aInt64(2, _omitFieldNames ? '' : 'output')
    ..aInt64(3, _omitFieldNames ? '' : 'cacheWrite')
    ..aInt64(4, _omitFieldNames ? '' : 'cacheRead')
    ..aInt64(5, _omitFieldNames ? '' : 'messages')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageTotals clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageTotals copyWith(void Function(UsageTotals) updates) =>
      super.copyWith((message) => updates(message as UsageTotals))
          as UsageTotals;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UsageTotals() / UsageTotals.new instead')
  static UsageTotals create() => UsageTotals._();
  static $pb.GeneratedMessage $_createMessage() => UsageTotals._();
  @$core.override
  UsageTotals createEmptyInstance() => UsageTotals._();
  @$core.pragma('dart2js:noInline')
  static UsageTotals getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UsageTotals>(
          UsageTotals.$_createMessage);
  static UsageTotals? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get input => $_getI64(0);
  @$pb.TagNumber(1)
  set input($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInput() => $_has(0);
  @$pb.TagNumber(1)
  void clearInput() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get output => $_getI64(1);
  @$pb.TagNumber(2)
  set output($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOutput() => $_has(1);
  @$pb.TagNumber(2)
  void clearOutput() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get cacheWrite => $_getI64(2);
  @$pb.TagNumber(3)
  set cacheWrite($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCacheWrite() => $_has(2);
  @$pb.TagNumber(3)
  void clearCacheWrite() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get cacheRead => $_getI64(3);
  @$pb.TagNumber(4)
  set cacheRead($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCacheRead() => $_has(3);
  @$pb.TagNumber(4)
  void clearCacheRead() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get messages => $_getI64(4);
  @$pb.TagNumber(5)
  set messages($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMessages() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessages() => $_clearField(5);
}

class NodeUsage extends $pb.GeneratedMessage {
  factory NodeUsage({
    $core.String? node,
    UsageTotals? window,
    UsageTotals? today,
    UsageTotals? week,
    PlanUsage? plan,
  }) {
    final result = NodeUsage._();
    if (node != null) result.node = node;
    if (window != null) result.window = window;
    if (today != null) result.today = today;
    if (week != null) result.week = week;
    if (plan != null) result.plan = plan;
    return result;
  }

  NodeUsage._();

  factory NodeUsage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeUsage()..mergeFromBuffer(data, registry);
  factory NodeUsage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeUsage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeUsage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: NodeUsage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'node')
    ..aOM<UsageTotals>(2, _omitFieldNames ? '' : 'window',
        subBuilder: UsageTotals.$_createMessage)
    ..aOM<UsageTotals>(3, _omitFieldNames ? '' : 'today',
        subBuilder: UsageTotals.$_createMessage)
    ..aOM<UsageTotals>(4, _omitFieldNames ? '' : 'week',
        subBuilder: UsageTotals.$_createMessage)
    ..aOM<PlanUsage>(6, _omitFieldNames ? '' : 'plan',
        subBuilder: PlanUsage.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeUsage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeUsage copyWith(void Function(NodeUsage) updates) =>
      super.copyWith((message) => updates(message as NodeUsage)) as NodeUsage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NodeUsage() / NodeUsage.new instead')
  static NodeUsage create() => NodeUsage._();
  static $pb.GeneratedMessage $_createMessage() => NodeUsage._();
  @$core.override
  NodeUsage createEmptyInstance() => NodeUsage._();
  @$core.pragma('dart2js:noInline')
  static NodeUsage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeUsage>(NodeUsage.$_createMessage);
  static NodeUsage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get node => $_getSZ(0);
  @$pb.TagNumber(1)
  set node($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearNode() => $_clearField(1);

  /// The last 5 hours (Claude's usage window), since local midnight, and the
  /// last 7 days.
  @$pb.TagNumber(2)
  UsageTotals get window => $_getN(1);
  @$pb.TagNumber(2)
  set window(UsageTotals value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasWindow() => $_has(1);
  @$pb.TagNumber(2)
  void clearWindow() => $_clearField(2);
  @$pb.TagNumber(2)
  UsageTotals ensureWindow() => $_ensure(1);

  @$pb.TagNumber(3)
  UsageTotals get today => $_getN(2);
  @$pb.TagNumber(3)
  set today(UsageTotals value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasToday() => $_has(2);
  @$pb.TagNumber(3)
  void clearToday() => $_clearField(3);
  @$pb.TagNumber(3)
  UsageTotals ensureToday() => $_ensure(2);

  @$pb.TagNumber(4)
  UsageTotals get week => $_getN(3);
  @$pb.TagNumber(4)
  set week(UsageTotals value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasWeek() => $_has(3);
  @$pb.TagNumber(4)
  void clearWeek() => $_clearField(4);
  @$pb.TagNumber(4)
  UsageTotals ensureWeek() => $_ensure(3);

  /// The plan's limits as this node's Claude login reports them.
  @$pb.TagNumber(6)
  PlanUsage get plan => $_getN(4);
  @$pb.TagNumber(6)
  set plan(PlanUsage value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPlan() => $_has(4);
  @$pb.TagNumber(6)
  void clearPlan() => $_clearField(6);
  @$pb.TagNumber(6)
  PlanUsage ensurePlan() => $_ensure(4);
}

/// A plan limit from `/usage`, e.g. "session" 3% resetting "Oct 12, 3:19am".
class PlanLimit extends $pb.GeneratedMessage {
  factory PlanLimit({
    $core.String? label,
    $core.int? percent,
    $core.String? resets,
  }) {
    final result = PlanLimit._();
    if (label != null) result.label = label;
    if (percent != null) result.percent = percent;
    if (resets != null) result.resets = resets;
    return result;
  }

  PlanLimit._();

  factory PlanLimit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanLimit()..mergeFromBuffer(data, registry);
  factory PlanLimit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanLimit()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanLimit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: PlanLimit.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aI(2, _omitFieldNames ? '' : 'percent')
    ..aOS(3, _omitFieldNames ? '' : 'resets')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanLimit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanLimit copyWith(void Function(PlanLimit) updates) =>
      super.copyWith((message) => updates(message as PlanLimit)) as PlanLimit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlanLimit() / PlanLimit.new instead')
  static PlanLimit create() => PlanLimit._();
  static $pb.GeneratedMessage $_createMessage() => PlanLimit._();
  @$core.override
  PlanLimit createEmptyInstance() => PlanLimit._();
  @$core.pragma('dart2js:noInline')
  static PlanLimit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanLimit>(PlanLimit.$_createMessage);
  static PlanLimit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get percent => $_getIZ(1);
  @$pb.TagNumber(2)
  set percent($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPercent() => $_has(1);
  @$pb.TagNumber(2)
  void clearPercent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get resets => $_getSZ(2);
  @$pb.TagNumber(3)
  set resets($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasResets() => $_has(2);
  @$pb.TagNumber(3)
  void clearResets() => $_clearField(3);
}

/// What `claude -p /usage` says on a node. The text isn't a stable interface,
/// so the raw output is kept for when the limits can't be read from it.
class PlanUsage extends $pb.GeneratedMessage {
  factory PlanUsage({
    $core.String? node,
    $core.Iterable<PlanLimit>? limits,
    $core.String? raw,
    $fixnum.Int64? checkedMs,
    $core.String? error,
  }) {
    final result = PlanUsage._();
    if (node != null) result.node = node;
    if (limits != null) result.limits.addAll(limits);
    if (raw != null) result.raw = raw;
    if (checkedMs != null) result.checkedMs = checkedMs;
    if (error != null) result.error = error;
    return result;
  }

  PlanUsage._();

  factory PlanUsage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanUsage()..mergeFromBuffer(data, registry);
  factory PlanUsage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanUsage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanUsage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: PlanUsage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'node')
    ..pPM<PlanLimit>(2, _omitFieldNames ? '' : 'limits',
        subBuilder: PlanLimit.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'raw')
    ..aInt64(4, _omitFieldNames ? '' : 'checkedMs')
    ..aOS(5, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanUsage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanUsage copyWith(void Function(PlanUsage) updates) =>
      super.copyWith((message) => updates(message as PlanUsage)) as PlanUsage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlanUsage() / PlanUsage.new instead')
  static PlanUsage create() => PlanUsage._();
  static $pb.GeneratedMessage $_createMessage() => PlanUsage._();
  @$core.override
  PlanUsage createEmptyInstance() => PlanUsage._();
  @$core.pragma('dart2js:noInline')
  static PlanUsage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanUsage>(PlanUsage.$_createMessage);
  static PlanUsage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get node => $_getSZ(0);
  @$pb.TagNumber(1)
  set node($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearNode() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<PlanLimit> get limits => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get raw => $_getSZ(2);
  @$pb.TagNumber(3)
  set raw($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRaw() => $_has(2);
  @$pb.TagNumber(3)
  void clearRaw() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get checkedMs => $_getI64(3);
  @$pb.TagNumber(4)
  set checkedMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCheckedMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearCheckedMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get error => $_getSZ(4);
  @$pb.TagNumber(5)
  set error($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);
}

class SessionUsage extends $pb.GeneratedMessage {
  factory SessionUsage({
    $core.String? session,
    UsageTotals? total,
    $fixnum.Int64? lastMs,
  }) {
    final result = SessionUsage._();
    if (session != null) result.session = session;
    if (total != null) result.total = total;
    if (lastMs != null) result.lastMs = lastMs;
    return result;
  }

  SessionUsage._();

  factory SessionUsage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionUsage()..mergeFromBuffer(data, registry);
  factory SessionUsage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionUsage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionUsage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SessionUsage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aOM<UsageTotals>(2, _omitFieldNames ? '' : 'total',
        subBuilder: UsageTotals.$_createMessage)
    ..aInt64(3, _omitFieldNames ? '' : 'lastMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionUsage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionUsage copyWith(void Function(SessionUsage) updates) =>
      super.copyWith((message) => updates(message as SessionUsage))
          as SessionUsage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionUsage() / SessionUsage.new instead')
  static SessionUsage create() => SessionUsage._();
  static $pb.GeneratedMessage $_createMessage() => SessionUsage._();
  @$core.override
  SessionUsage createEmptyInstance() => SessionUsage._();
  @$core.pragma('dart2js:noInline')
  static SessionUsage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionUsage>(
          SessionUsage.$_createMessage);
  static SessionUsage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  UsageTotals get total => $_getN(1);
  @$pb.TagNumber(2)
  set total(UsageTotals value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTotal() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotal() => $_clearField(2);
  @$pb.TagNumber(2)
  UsageTotals ensureTotal() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lastMs => $_getI64(2);
  @$pb.TagNumber(3)
  set lastMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastMs() => $_clearField(3);
}

/// GET /api/v1/usage
class UsageSummary extends $pb.GeneratedMessage {
  factory UsageSummary({
    $core.Iterable<NodeUsage>? nodes,
    $core.Iterable<SessionUsage>? sessions,
  }) {
    final result = UsageSummary._();
    if (nodes != null) result.nodes.addAll(nodes);
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  UsageSummary._();

  factory UsageSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageSummary()..mergeFromBuffer(data, registry);
  factory UsageSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageSummary()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsageSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: UsageSummary.$_createMessage)
    ..pPM<NodeUsage>(1, _omitFieldNames ? '' : 'nodes',
        subBuilder: NodeUsage.$_createMessage)
    ..pPM<SessionUsage>(2, _omitFieldNames ? '' : 'sessions',
        subBuilder: SessionUsage.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageSummary copyWith(void Function(UsageSummary) updates) =>
      super.copyWith((message) => updates(message as UsageSummary))
          as UsageSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UsageSummary() / UsageSummary.new instead')
  static UsageSummary create() => UsageSummary._();
  static $pb.GeneratedMessage $_createMessage() => UsageSummary._();
  @$core.override
  UsageSummary createEmptyInstance() => UsageSummary._();
  @$core.pragma('dart2js:noInline')
  static UsageSummary getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UsageSummary>(
          UsageSummary.$_createMessage);
  static UsageSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<NodeUsage> get nodes => $_getList(0);

  /// Sessions used in the last 7 days, most tokens first.
  @$pb.TagNumber(2)
  $pb.PbList<SessionUsage> get sessions => $_getList(1);
}

/// A folder on a node that new projects are made in, e.g. ~/projects.
class WorkspaceRoot extends $pb.GeneratedMessage {
  factory WorkspaceRoot({
    $core.String? node,
    $core.String? path,
  }) {
    final result = WorkspaceRoot._();
    if (node != null) result.node = node;
    if (path != null) result.path = path;
    return result;
  }

  WorkspaceRoot._();

  factory WorkspaceRoot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorkspaceRoot()..mergeFromBuffer(data, registry);
  factory WorkspaceRoot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorkspaceRoot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkspaceRoot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: WorkspaceRoot.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'node')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkspaceRoot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkspaceRoot copyWith(void Function(WorkspaceRoot) updates) =>
      super.copyWith((message) => updates(message as WorkspaceRoot))
          as WorkspaceRoot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WorkspaceRoot() / WorkspaceRoot.new instead')
  static WorkspaceRoot create() => WorkspaceRoot._();
  static $pb.GeneratedMessage $_createMessage() => WorkspaceRoot._();
  @$core.override
  WorkspaceRoot createEmptyInstance() => WorkspaceRoot._();
  @$core.pragma('dart2js:noInline')
  static WorkspaceRoot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorkspaceRoot>(
          WorkspaceRoot.$_createMessage);
  static WorkspaceRoot? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get node => $_getSZ(0);
  @$pb.TagNumber(1)
  set node($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearNode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);
}

/// GET /api/v1/workspaces; PUT adds a root, DELETE (same body) removes it.
class Workspaces extends $pb.GeneratedMessage {
  factory Workspaces({
    $core.Iterable<WorkspaceRoot>? roots,
  }) {
    final result = Workspaces._();
    if (roots != null) result.roots.addAll(roots);
    return result;
  }

  Workspaces._();

  factory Workspaces.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Workspaces()..mergeFromBuffer(data, registry);
  factory Workspaces.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Workspaces()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Workspaces',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Workspaces.$_createMessage)
    ..pPM<WorkspaceRoot>(1, _omitFieldNames ? '' : 'roots',
        subBuilder: WorkspaceRoot.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Workspaces clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Workspaces copyWith(void Function(Workspaces) updates) =>
      super.copyWith((message) => updates(message as Workspaces)) as Workspaces;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Workspaces() / Workspaces.new instead')
  static Workspaces create() => Workspaces._();
  static $pb.GeneratedMessage $_createMessage() => Workspaces._();
  @$core.override
  Workspaces createEmptyInstance() => Workspaces._();
  @$core.pragma('dart2js:noInline')
  static Workspaces getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Workspaces>(Workspaces.$_createMessage);
  static Workspaces? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<WorkspaceRoot> get roots => $_getList(0);
}

/// A file in the hub's central store: something a session read or wrote,
/// or that someone attached. Content is stored once per SHA-256.
class Artifact extends $pb.GeneratedMessage {
  factory Artifact({
    $core.String? id,
    $core.String? sha256,
    $core.String? name,
    $core.String? mime,
    $fixnum.Int64? size,
    $core.String? session,
    $core.String? node,
    $core.String? origin,
    $core.String? path,
    $core.String? toolUseId,
    $fixnum.Int64? createdMs,
    $core.String? note,
  }) {
    final result = Artifact._();
    if (id != null) result.id = id;
    if (sha256 != null) result.sha256 = sha256;
    if (name != null) result.name = name;
    if (mime != null) result.mime = mime;
    if (size != null) result.size = size;
    if (session != null) result.session = session;
    if (node != null) result.node = node;
    if (origin != null) result.origin = origin;
    if (path != null) result.path = path;
    if (toolUseId != null) result.toolUseId = toolUseId;
    if (createdMs != null) result.createdMs = createdMs;
    if (note != null) result.note = note;
    return result;
  }

  Artifact._();

  factory Artifact.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Artifact()..mergeFromBuffer(data, registry);
  factory Artifact.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Artifact()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Artifact',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Artifact.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'sha256')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'mime')
    ..aInt64(5, _omitFieldNames ? '' : 'size')
    ..aOS(6, _omitFieldNames ? '' : 'session')
    ..aOS(7, _omitFieldNames ? '' : 'node')
    ..aOS(8, _omitFieldNames ? '' : 'origin')
    ..aOS(9, _omitFieldNames ? '' : 'path')
    ..aOS(10, _omitFieldNames ? '' : 'toolUseId')
    ..aInt64(11, _omitFieldNames ? '' : 'createdMs')
    ..aOS(12, _omitFieldNames ? '' : 'note')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Artifact clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Artifact copyWith(void Function(Artifact) updates) =>
      super.copyWith((message) => updates(message as Artifact)) as Artifact;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Artifact() / Artifact.new instead')
  static Artifact create() => Artifact._();
  static $pb.GeneratedMessage $_createMessage() => Artifact._();
  @$core.override
  Artifact createEmptyInstance() => Artifact._();
  @$core.pragma('dart2js:noInline')
  static Artifact getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Artifact>(Artifact.$_createMessage);
  static Artifact? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sha256 => $_getSZ(1);
  @$pb.TagNumber(2)
  set sha256($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSha256() => $_has(1);
  @$pb.TagNumber(2)
  void clearSha256() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get mime => $_getSZ(3);
  @$pb.TagNumber(4)
  set mime($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMime() => $_has(3);
  @$pb.TagNumber(4)
  void clearMime() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get size => $_getI64(4);
  @$pb.TagNumber(5)
  set size($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearSize() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get session => $_getSZ(5);
  @$pb.TagNumber(6)
  set session($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSession() => $_has(5);
  @$pb.TagNumber(6)
  void clearSession() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get node => $_getSZ(6);
  @$pb.TagNumber(7)
  set node($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNode() => $_has(6);
  @$pb.TagNumber(7)
  void clearNode() => $_clearField(7);

  /// "read" or "write" (by a tool), "attachment" (sent with a message) or
  /// "upload".
  @$pb.TagNumber(8)
  $core.String get origin => $_getSZ(7);
  @$pb.TagNumber(8)
  set origin($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOrigin() => $_has(7);
  @$pb.TagNumber(8)
  void clearOrigin() => $_clearField(8);

  /// Where it was on the node, if it came from a tool call.
  @$pb.TagNumber(9)
  $core.String get path => $_getSZ(8);
  @$pb.TagNumber(9)
  set path($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPath() => $_has(8);
  @$pb.TagNumber(9)
  void clearPath() => $_clearField(9);

  /// The tool call it belongs to, so the app can show it on that card.
  @$pb.TagNumber(10)
  $core.String get toolUseId => $_getSZ(9);
  @$pb.TagNumber(10)
  set toolUseId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasToolUseId() => $_has(9);
  @$pb.TagNumber(10)
  void clearToolUseId() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get createdMs => $_getI64(10);
  @$pb.TagNumber(11)
  set createdMs($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCreatedMs() => $_has(10);
  @$pb.TagNumber(11)
  void clearCreatedMs() => $_clearField(11);

  /// Written by whoever attached it.
  @$pb.TagNumber(12)
  $core.String get note => $_getSZ(11);
  @$pb.TagNumber(12)
  set note($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasNote() => $_has(11);
  @$pb.TagNumber(12)
  void clearNote() => $_clearField(12);
}

class ArtifactList extends $pb.GeneratedMessage {
  factory ArtifactList({
    $core.Iterable<Artifact>? artifacts,
  }) {
    final result = ArtifactList._();
    if (artifacts != null) result.artifacts.addAll(artifacts);
    return result;
  }

  ArtifactList._();

  factory ArtifactList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArtifactList()..mergeFromBuffer(data, registry);
  factory ArtifactList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArtifactList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArtifactList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ArtifactList.$_createMessage)
    ..pPM<Artifact>(1, _omitFieldNames ? '' : 'artifacts',
        subBuilder: Artifact.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArtifactList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArtifactList copyWith(void Function(ArtifactList) updates) =>
      super.copyWith((message) => updates(message as ArtifactList))
          as ArtifactList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ArtifactList() / ArtifactList.new instead')
  static ArtifactList create() => ArtifactList._();
  static $pb.GeneratedMessage $_createMessage() => ArtifactList._();
  @$core.override
  ArtifactList createEmptyInstance() => ArtifactList._();
  @$core.pragma('dart2js:noInline')
  static ArtifactList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ArtifactList>(
          ArtifactList.$_createMessage);
  static ArtifactList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Artifact> get artifacts => $_getList(0);
}

/// A resumable upload: POST /api/v1/uploads starts one, PATCH appends at
/// offset, and the last chunk turns it into the artifact.
class Upload extends $pb.GeneratedMessage {
  factory Upload({
    $core.String? id,
    $fixnum.Int64? offset,
    $fixnum.Int64? size,
    Artifact? artifact,
  }) {
    final result = Upload._();
    if (id != null) result.id = id;
    if (offset != null) result.offset = offset;
    if (size != null) result.size = size;
    if (artifact != null) result.artifact = artifact;
    return result;
  }

  Upload._();

  factory Upload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Upload()..mergeFromBuffer(data, registry);
  factory Upload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Upload()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Upload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Upload.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'offset')
    ..aInt64(3, _omitFieldNames ? '' : 'size')
    ..aOM<Artifact>(4, _omitFieldNames ? '' : 'artifact',
        subBuilder: Artifact.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Upload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Upload copyWith(void Function(Upload) updates) =>
      super.copyWith((message) => updates(message as Upload)) as Upload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Upload() / Upload.new instead')
  static Upload create() => Upload._();
  static $pb.GeneratedMessage $_createMessage() => Upload._();
  @$core.override
  Upload createEmptyInstance() => Upload._();
  @$core.pragma('dart2js:noInline')
  static Upload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Upload>(Upload.$_createMessage);
  static Upload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get offset => $_getI64(1);
  @$pb.TagNumber(2)
  set offset($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get size => $_getI64(2);
  @$pb.TagNumber(3)
  set size($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => $_clearField(3);

  @$pb.TagNumber(4)
  Artifact get artifact => $_getN(3);
  @$pb.TagNumber(4)
  set artifact(Artifact value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasArtifact() => $_has(3);
  @$pb.TagNumber(4)
  void clearArtifact() => $_clearField(4);
  @$pb.TagNumber(4)
  Artifact ensureArtifact() => $_ensure(3);
}

/// A link that opens the file without a token until expires_ms. url is a
/// path; clients put their hub address in front.
class ArtifactLink extends $pb.GeneratedMessage {
  factory ArtifactLink({
    $core.String? url,
    $fixnum.Int64? expiresMs,
  }) {
    final result = ArtifactLink._();
    if (url != null) result.url = url;
    if (expiresMs != null) result.expiresMs = expiresMs;
    return result;
  }

  ArtifactLink._();

  factory ArtifactLink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArtifactLink()..mergeFromBuffer(data, registry);
  factory ArtifactLink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArtifactLink()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArtifactLink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ArtifactLink.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aInt64(2, _omitFieldNames ? '' : 'expiresMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArtifactLink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArtifactLink copyWith(void Function(ArtifactLink) updates) =>
      super.copyWith((message) => updates(message as ArtifactLink))
          as ArtifactLink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ArtifactLink() / ArtifactLink.new instead')
  static ArtifactLink create() => ArtifactLink._();
  static $pb.GeneratedMessage $_createMessage() => ArtifactLink._();
  @$core.override
  ArtifactLink createEmptyInstance() => ArtifactLink._();
  @$core.pragma('dart2js:noInline')
  static ArtifactLink getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ArtifactLink>(
          ArtifactLink.$_createMessage);
  static ArtifactLink? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiresMs => $_getI64(1);
  @$pb.TagNumber(2)
  set expiresMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiresMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresMs() => $_clearField(2);
}

/// A small site a session made under .tether/pages/<name>/. Its files are
/// artifacts with origin "page" and path "<name>/<file>".
class Page extends $pb.GeneratedMessage {
  factory Page({
    $core.String? session,
    $core.String? name,
    $core.int? files,
    $fixnum.Int64? size,
    $fixnum.Int64? updatedMs,
    $core.String? url,
    $fixnum.Int64? expiresMs,
  }) {
    final result = Page._();
    if (session != null) result.session = session;
    if (name != null) result.name = name;
    if (files != null) result.files = files;
    if (size != null) result.size = size;
    if (updatedMs != null) result.updatedMs = updatedMs;
    if (url != null) result.url = url;
    if (expiresMs != null) result.expiresMs = expiresMs;
    return result;
  }

  Page._();

  factory Page.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Page()..mergeFromBuffer(data, registry);
  factory Page.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Page()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Page',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Page.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'session')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'files')
    ..aInt64(4, _omitFieldNames ? '' : 'size')
    ..aInt64(5, _omitFieldNames ? '' : 'updatedMs')
    ..aOS(6, _omitFieldNames ? '' : 'url')
    ..aInt64(7, _omitFieldNames ? '' : 'expiresMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Page clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Page copyWith(void Function(Page) updates) =>
      super.copyWith((message) => updates(message as Page)) as Page;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Page() / Page.new instead')
  static Page create() => Page._();
  static $pb.GeneratedMessage $_createMessage() => Page._();
  @$core.override
  Page createEmptyInstance() => Page._();
  @$core.pragma('dart2js:noInline')
  static Page getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Page>(Page.$_createMessage);
  static Page? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get session => $_getSZ(0);
  @$pb.TagNumber(1)
  set session($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get files => $_getIZ(2);
  @$pb.TagNumber(3)
  set files($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFiles() => $_has(2);
  @$pb.TagNumber(3)
  void clearFiles() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get updatedMs => $_getI64(4);
  @$pb.TagNumber(5)
  set updatedMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUpdatedMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearUpdatedMs() => $_clearField(5);

  /// A signed link to its index.html, as a path on the hub.
  @$pb.TagNumber(6)
  $core.String get url => $_getSZ(5);
  @$pb.TagNumber(6)
  set url($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get expiresMs => $_getI64(6);
  @$pb.TagNumber(7)
  set expiresMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExpiresMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearExpiresMs() => $_clearField(7);
}

/// GET /api/v1/pages?session=
class PageList extends $pb.GeneratedMessage {
  factory PageList({
    $core.Iterable<Page>? pages,
  }) {
    final result = PageList._();
    if (pages != null) result.pages.addAll(pages);
    return result;
  }

  PageList._();

  factory PageList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PageList()..mergeFromBuffer(data, registry);
  factory PageList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PageList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PageList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: PageList.$_createMessage)
    ..pPM<Page>(1, _omitFieldNames ? '' : 'pages',
        subBuilder: Page.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageList copyWith(void Function(PageList) updates) =>
      super.copyWith((message) => updates(message as PageList)) as PageList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PageList() / PageList.new instead')
  static PageList create() => PageList._();
  static $pb.GeneratedMessage $_createMessage() => PageList._();
  @$core.override
  PageList createEmptyInstance() => PageList._();
  @$core.pragma('dart2js:noInline')
  static PageList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PageList>(PageList.$_createMessage);
  static PageList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Page> get pages => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
