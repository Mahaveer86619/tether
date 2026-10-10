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
  welcome,
  ack,
  error,
  nodeStatus,
  sessionInfo,
  timeline,
  approvalRequested,
  approvalResolved,
  agentHello,
  sessionIndex,
  rawEvents,
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
    Welcome? welcome,
    Ack? ack,
    Error? error,
    NodeStatus? nodeStatus,
    SessionInfo? sessionInfo,
    TimelineUpdate? timeline,
    ApprovalRequest? approvalRequested,
    ApprovalResolved? approvalResolved,
    AgentHello? agentHello,
    SessionIndex? sessionIndex,
    RawEvents? rawEvents,
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
    if (welcome != null) result.welcome = welcome;
    if (ack != null) result.ack = ack;
    if (error != null) result.error = error;
    if (nodeStatus != null) result.nodeStatus = nodeStatus;
    if (sessionInfo != null) result.sessionInfo = sessionInfo;
    if (timeline != null) result.timeline = timeline;
    if (approvalRequested != null) result.approvalRequested = approvalRequested;
    if (approvalResolved != null) result.approvalResolved = approvalResolved;
    if (agentHello != null) result.agentHello = agentHello;
    if (sessionIndex != null) result.sessionIndex = sessionIndex;
    if (rawEvents != null) result.rawEvents = rawEvents;
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
    30: Frame_Body.welcome,
    31: Frame_Body.ack,
    32: Frame_Body.error,
    33: Frame_Body.nodeStatus,
    34: Frame_Body.sessionInfo,
    35: Frame_Body.timeline,
    36: Frame_Body.approvalRequested,
    37: Frame_Body.approvalResolved,
    50: Frame_Body.agentHello,
    51: Frame_Body.sessionIndex,
    52: Frame_Body.rawEvents,
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
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      50,
      51,
      52,
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
    ..aOM<AgentHello>(50, _omitFieldNames ? '' : 'agentHello',
        subBuilder: AgentHello.$_createMessage)
    ..aOM<SessionIndex>(51, _omitFieldNames ? '' : 'sessionIndex',
        subBuilder: SessionIndex.$_createMessage)
    ..aOM<RawEvents>(52, _omitFieldNames ? '' : 'rawEvents',
        subBuilder: RawEvents.$_createMessage)
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
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(36)
  @$pb.TagNumber(37)
  @$pb.TagNumber(50)
  @$pb.TagNumber(51)
  @$pb.TagNumber(52)
  @$pb.TagNumber(60)
  Frame_Body whichBody() => _Frame_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(36)
  @$pb.TagNumber(37)
  @$pb.TagNumber(50)
  @$pb.TagNumber(51)
  @$pb.TagNumber(52)
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

  /// Hub -> client
  @$pb.TagNumber(30)
  Welcome get welcome => $_getN(11);
  @$pb.TagNumber(30)
  set welcome(Welcome value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasWelcome() => $_has(11);
  @$pb.TagNumber(30)
  void clearWelcome() => $_clearField(30);
  @$pb.TagNumber(30)
  Welcome ensureWelcome() => $_ensure(11);

  @$pb.TagNumber(31)
  Ack get ack => $_getN(12);
  @$pb.TagNumber(31)
  set ack(Ack value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasAck() => $_has(12);
  @$pb.TagNumber(31)
  void clearAck() => $_clearField(31);
  @$pb.TagNumber(31)
  Ack ensureAck() => $_ensure(12);

  @$pb.TagNumber(32)
  Error get error => $_getN(13);
  @$pb.TagNumber(32)
  set error(Error value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasError() => $_has(13);
  @$pb.TagNumber(32)
  void clearError() => $_clearField(32);
  @$pb.TagNumber(32)
  Error ensureError() => $_ensure(13);

  @$pb.TagNumber(33)
  NodeStatus get nodeStatus => $_getN(14);
  @$pb.TagNumber(33)
  set nodeStatus(NodeStatus value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasNodeStatus() => $_has(14);
  @$pb.TagNumber(33)
  void clearNodeStatus() => $_clearField(33);
  @$pb.TagNumber(33)
  NodeStatus ensureNodeStatus() => $_ensure(14);

  @$pb.TagNumber(34)
  SessionInfo get sessionInfo => $_getN(15);
  @$pb.TagNumber(34)
  set sessionInfo(SessionInfo value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasSessionInfo() => $_has(15);
  @$pb.TagNumber(34)
  void clearSessionInfo() => $_clearField(34);
  @$pb.TagNumber(34)
  SessionInfo ensureSessionInfo() => $_ensure(15);

  @$pb.TagNumber(35)
  TimelineUpdate get timeline => $_getN(16);
  @$pb.TagNumber(35)
  set timeline(TimelineUpdate value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasTimeline() => $_has(16);
  @$pb.TagNumber(35)
  void clearTimeline() => $_clearField(35);
  @$pb.TagNumber(35)
  TimelineUpdate ensureTimeline() => $_ensure(16);

  @$pb.TagNumber(36)
  ApprovalRequest get approvalRequested => $_getN(17);
  @$pb.TagNumber(36)
  set approvalRequested(ApprovalRequest value) => $_setField(36, value);
  @$pb.TagNumber(36)
  $core.bool hasApprovalRequested() => $_has(17);
  @$pb.TagNumber(36)
  void clearApprovalRequested() => $_clearField(36);
  @$pb.TagNumber(36)
  ApprovalRequest ensureApprovalRequested() => $_ensure(17);

  @$pb.TagNumber(37)
  ApprovalResolved get approvalResolved => $_getN(18);
  @$pb.TagNumber(37)
  set approvalResolved(ApprovalResolved value) => $_setField(37, value);
  @$pb.TagNumber(37)
  $core.bool hasApprovalResolved() => $_has(18);
  @$pb.TagNumber(37)
  void clearApprovalResolved() => $_clearField(37);
  @$pb.TagNumber(37)
  ApprovalResolved ensureApprovalResolved() => $_ensure(18);

  /// Agent -> hub
  @$pb.TagNumber(50)
  AgentHello get agentHello => $_getN(19);
  @$pb.TagNumber(50)
  set agentHello(AgentHello value) => $_setField(50, value);
  @$pb.TagNumber(50)
  $core.bool hasAgentHello() => $_has(19);
  @$pb.TagNumber(50)
  void clearAgentHello() => $_clearField(50);
  @$pb.TagNumber(50)
  AgentHello ensureAgentHello() => $_ensure(19);

  @$pb.TagNumber(51)
  SessionIndex get sessionIndex => $_getN(20);
  @$pb.TagNumber(51)
  set sessionIndex(SessionIndex value) => $_setField(51, value);
  @$pb.TagNumber(51)
  $core.bool hasSessionIndex() => $_has(20);
  @$pb.TagNumber(51)
  void clearSessionIndex() => $_clearField(51);
  @$pb.TagNumber(51)
  SessionIndex ensureSessionIndex() => $_ensure(20);

  @$pb.TagNumber(52)
  RawEvents get rawEvents => $_getN(21);
  @$pb.TagNumber(52)
  set rawEvents(RawEvents value) => $_setField(52, value);
  @$pb.TagNumber(52)
  $core.bool hasRawEvents() => $_has(21);
  @$pb.TagNumber(52)
  void clearRawEvents() => $_clearField(52);
  @$pb.TagNumber(52)
  RawEvents ensureRawEvents() => $_ensure(21);

  /// Hub -> agent
  @$pb.TagNumber(60)
  AgentCommand get agentCommand => $_getN(22);
  @$pb.TagNumber(60)
  set agentCommand(AgentCommand value) => $_setField(60, value);
  @$pb.TagNumber(60)
  $core.bool hasAgentCommand() => $_has(22);
  @$pb.TagNumber(60)
  void clearAgentCommand() => $_clearField(60);
  @$pb.TagNumber(60)
  AgentCommand ensureAgentCommand() => $_ensure(22);
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

  /// Subscribe with this as after_seq to receive only later changes.
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
  }) {
    final result = ApprovalDecision._();
    if (approvalId != null) result.approvalId = approvalId;
    if (decision != null) result.decision = decision;
    if (message != null) result.message = message;
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
  }) {
    final result = CreateSession._();
    if (node != null) result.node = node;
    if (cwd != null) result.cwd = cwd;
    if (prompt != null) result.prompt = prompt;
    if (model != null) result.model = model;
    if (permissionMode != null) result.permissionMode = permissionMode;
    if (name != null) result.name = name;
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
}

class SendMessage extends $pb.GeneratedMessage {
  factory SendMessage({
    $core.String? session,
    $core.String? text,
    $core.bool? fork,
  }) {
    final result = SendMessage._();
    if (session != null) result.session = session;
    if (text != null) result.text = text;
    if (fork != null) result.fork = fork;
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
}

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

class Welcome extends $pb.GeneratedMessage {
  factory Welcome({
    $core.String? hubVersion,
    $core.Iterable<NodeStatus>? nodes,
    $core.Iterable<SessionInfo>? sessions,
    $core.Iterable<ApprovalRequest>? pendingApprovals,
  }) {
    final result = Welcome._();
    if (hubVersion != null) result.hubVersion = hubVersion;
    if (nodes != null) result.nodes.addAll(nodes);
    if (sessions != null) result.sessions.addAll(sessions);
    if (pendingApprovals != null)
      result.pendingApprovals.addAll(pendingApprovals);
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

  /// True when sessions is the node's complete list.
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
}

class AgentCommand_SendInput extends $pb.GeneratedMessage {
  factory AgentCommand_SendInput({
    $core.String? session,
    $core.String? text,
  }) {
    final result = AgentCommand_SendInput._();
    if (session != null) result.session = session;
    if (text != null) result.text = text;
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

enum AgentCommand_Op { start, send, interrupt, mirror, stopMirror, notSet }

class AgentCommand extends $pb.GeneratedMessage {
  factory AgentCommand({
    AgentCommand_StartRun? start,
    AgentCommand_SendInput? send,
    AgentCommand_Interrupt? interrupt,
    AgentCommand_Mirror? mirror,
    AgentCommand_StopMirror? stopMirror,
  }) {
    final result = AgentCommand._();
    if (start != null) result.start = start;
    if (send != null) result.send = send;
    if (interrupt != null) result.interrupt = interrupt;
    if (mirror != null) result.mirror = mirror;
    if (stopMirror != null) result.stopMirror = stopMirror;
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
    0: AgentCommand_Op.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCommand.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5])
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
  AgentCommand_Op whichOp() => _AgentCommand_OpByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
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
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
