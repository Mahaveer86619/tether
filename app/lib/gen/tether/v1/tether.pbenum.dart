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

import 'package:protobuf/protobuf.dart' as $pb;

class SessionState extends $pb.ProtobufEnum {
  static const SessionState SESSION_STATE_UNSPECIFIED =
      SessionState._(0, _omitEnumNames ? '' : 'SESSION_STATE_UNSPECIFIED');

  /// Nobody is writing to the session; it can be resumed.
  static const SessionState SESSION_STATE_IDLE =
      SessionState._(1, _omitEnumNames ? '' : 'SESSION_STATE_IDLE');

  /// A Tether-run process is working on a turn.
  static const SessionState SESSION_STATE_RUNNING =
      SessionState._(2, _omitEnumNames ? '' : 'SESSION_STATE_RUNNING');
  static const SessionState SESSION_STATE_AWAITING_APPROVAL = SessionState._(
      3, _omitEnumNames ? '' : 'SESSION_STATE_AWAITING_APPROVAL');

  /// A Tether-run process is alive and waiting for the next message.
  static const SessionState SESSION_STATE_READY =
      SessionState._(4, _omitEnumNames ? '' : 'SESSION_STATE_READY');

  /// Transcript written recently by a process Tether can't see (no hooks);
  /// mirror only, or fork.
  static const SessionState SESSION_STATE_TERMINAL_ACTIVE =
      SessionState._(5, _omitEnumNames ? '' : 'SESSION_STATE_TERMINAL_ACTIVE');
  static const SessionState SESSION_STATE_ERROR =
      SessionState._(6, _omitEnumNames ? '' : 'SESSION_STATE_ERROR');

  static const $core.List<SessionState> values = <SessionState>[
    SESSION_STATE_UNSPECIFIED,
    SESSION_STATE_IDLE,
    SESSION_STATE_RUNNING,
    SESSION_STATE_AWAITING_APPROVAL,
    SESSION_STATE_READY,
    SESSION_STATE_TERMINAL_ACTIVE,
    SESSION_STATE_ERROR,
  ];

  static final $core.List<SessionState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static SessionState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SessionState._(super.value, super.name);
}

/// Where a session's live process runs.
class SessionHost extends $pb.ProtobufEnum {
  static const SessionHost SESSION_HOST_UNSPECIFIED =
      SessionHost._(0, _omitEnumNames ? '' : 'SESSION_HOST_UNSPECIFIED');

  /// No live process.
  static const SessionHost SESSION_HOST_NONE =
      SessionHost._(1, _omitEnumNames ? '' : 'SESSION_HOST_NONE');

  /// `claude -p` run by the agent; no terminal to attach to.
  static const SessionHost SESSION_HOST_HEADLESS =
      SessionHost._(2, _omitEnumNames ? '' : 'SESSION_HOST_HEADLESS');

  /// Interactive Claude Code in a tmux window owned by the agent; attachable.
  static const SessionHost SESSION_HOST_TMUX =
      SessionHost._(3, _omitEnumNames ? '' : 'SESSION_HOST_TMUX');

  /// Interactive Claude Code started by you in some terminal; Tether sees it
  /// through hooks but cannot type into it.
  static const SessionHost SESSION_HOST_TERMINAL =
      SessionHost._(4, _omitEnumNames ? '' : 'SESSION_HOST_TERMINAL');

  static const $core.List<SessionHost> values = <SessionHost>[
    SESSION_HOST_UNSPECIFIED,
    SESSION_HOST_NONE,
    SESSION_HOST_HEADLESS,
    SESSION_HOST_TMUX,
    SESSION_HOST_TERMINAL,
  ];

  static final $core.List<SessionHost?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SessionHost? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SessionHost._(super.value, super.name);
}

class Decision extends $pb.ProtobufEnum {
  static const Decision DECISION_UNSPECIFIED =
      Decision._(0, _omitEnumNames ? '' : 'DECISION_UNSPECIFIED');
  static const Decision DECISION_ALLOW =
      Decision._(1, _omitEnumNames ? '' : 'DECISION_ALLOW');
  static const Decision DECISION_DENY =
      Decision._(2, _omitEnumNames ? '' : 'DECISION_DENY');

  static const $core.List<Decision> values = <Decision>[
    DECISION_UNSPECIFIED,
    DECISION_ALLOW,
    DECISION_DENY,
  ];

  static final $core.List<Decision?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Decision? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Decision._(super.value, super.name);
}

class ApprovalRequest_Kind extends $pb.ProtobufEnum {
  static const ApprovalRequest_Kind KIND_UNSPECIFIED =
      ApprovalRequest_Kind._(0, _omitEnumNames ? '' : 'KIND_UNSPECIFIED');
  static const ApprovalRequest_Kind KIND_TOOL =
      ApprovalRequest_Kind._(1, _omitEnumNames ? '' : 'KIND_TOOL');

  /// Claude Code asks whether to trust a folder it hasn't opened before.
  static const ApprovalRequest_Kind KIND_FOLDER_TRUST =
      ApprovalRequest_Kind._(2, _omitEnumNames ? '' : 'KIND_FOLDER_TRUST');

  /// Claude asks the user questions (AskUserQuestion); input_json holds
  /// them, and the decision carries the answers.
  static const ApprovalRequest_Kind KIND_QUESTION =
      ApprovalRequest_Kind._(3, _omitEnumNames ? '' : 'KIND_QUESTION');

  static const $core.List<ApprovalRequest_Kind> values = <ApprovalRequest_Kind>[
    KIND_UNSPECIFIED,
    KIND_TOOL,
    KIND_FOLDER_TRUST,
    KIND_QUESTION,
  ];

  static final $core.List<ApprovalRequest_Kind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ApprovalRequest_Kind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ApprovalRequest_Kind._(super.value, super.name);
}

class RawEvents_Source extends $pb.ProtobufEnum {
  static const RawEvents_Source SOURCE_UNSPECIFIED =
      RawEvents_Source._(0, _omitEnumNames ? '' : 'SOURCE_UNSPECIFIED');

  /// Live output of a Tether-run `claude -p --output-format stream-json`.
  static const RawEvents_Source SOURCE_STREAM =
      RawEvents_Source._(1, _omitEnumNames ? '' : 'SOURCE_STREAM');

  /// Lines from ~/.claude/projects/<project>/<session>.jsonl.
  static const RawEvents_Source SOURCE_TRANSCRIPT =
      RawEvents_Source._(2, _omitEnumNames ? '' : 'SOURCE_TRANSCRIPT');

  static const $core.List<RawEvents_Source> values = <RawEvents_Source>[
    SOURCE_UNSPECIFIED,
    SOURCE_STREAM,
    SOURCE_TRANSCRIPT,
  ];

  static final $core.List<RawEvents_Source?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RawEvents_Source? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RawEvents_Source._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
