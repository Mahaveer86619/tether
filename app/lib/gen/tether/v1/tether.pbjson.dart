// This is a generated file - do not edit.
//
// Generated from tether/v1/tether.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use sessionStateDescriptor instead')
const SessionState$json = {
  '1': 'SessionState',
  '2': [
    {'1': 'SESSION_STATE_UNSPECIFIED', '2': 0},
    {'1': 'SESSION_STATE_IDLE', '2': 1},
    {'1': 'SESSION_STATE_RUNNING', '2': 2},
    {'1': 'SESSION_STATE_AWAITING_APPROVAL', '2': 3},
    {'1': 'SESSION_STATE_READY', '2': 4},
    {'1': 'SESSION_STATE_TERMINAL_ACTIVE', '2': 5},
    {'1': 'SESSION_STATE_ERROR', '2': 6},
  ],
};

/// Descriptor for `SessionState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sessionStateDescriptor = $convert.base64Decode(
    'CgxTZXNzaW9uU3RhdGUSHQoZU0VTU0lPTl9TVEFURV9VTlNQRUNJRklFRBAAEhYKElNFU1NJT0'
    '5fU1RBVEVfSURMRRABEhkKFVNFU1NJT05fU1RBVEVfUlVOTklORxACEiMKH1NFU1NJT05fU1RB'
    'VEVfQVdBSVRJTkdfQVBQUk9WQUwQAxIXChNTRVNTSU9OX1NUQVRFX1JFQURZEAQSIQodU0VTU0'
    'lPTl9TVEFURV9URVJNSU5BTF9BQ1RJVkUQBRIXChNTRVNTSU9OX1NUQVRFX0VSUk9SEAY=');

@$core.Deprecated('Use sessionHostDescriptor instead')
const SessionHost$json = {
  '1': 'SessionHost',
  '2': [
    {'1': 'SESSION_HOST_UNSPECIFIED', '2': 0},
    {'1': 'SESSION_HOST_NONE', '2': 1},
    {'1': 'SESSION_HOST_HEADLESS', '2': 2},
    {'1': 'SESSION_HOST_TMUX', '2': 3},
    {'1': 'SESSION_HOST_TERMINAL', '2': 4},
  ],
};

/// Descriptor for `SessionHost`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sessionHostDescriptor = $convert.base64Decode(
    'CgtTZXNzaW9uSG9zdBIcChhTRVNTSU9OX0hPU1RfVU5TUEVDSUZJRUQQABIVChFTRVNTSU9OX0'
    'hPU1RfTk9ORRABEhkKFVNFU1NJT05fSE9TVF9IRUFETEVTUxACEhUKEVNFU1NJT05fSE9TVF9U'
    'TVVYEAMSGQoVU0VTU0lPTl9IT1NUX1RFUk1JTkFMEAQ=');

@$core.Deprecated('Use decisionDescriptor instead')
const Decision$json = {
  '1': 'Decision',
  '2': [
    {'1': 'DECISION_UNSPECIFIED', '2': 0},
    {'1': 'DECISION_ALLOW', '2': 1},
    {'1': 'DECISION_DENY', '2': 2},
  ],
};

/// Descriptor for `Decision`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List decisionDescriptor = $convert.base64Decode(
    'CghEZWNpc2lvbhIYChRERUNJU0lPTl9VTlNQRUNJRklFRBAAEhIKDkRFQ0lTSU9OX0FMTE9XEA'
    'ESEQoNREVDSVNJT05fREVOWRAC');

@$core.Deprecated('Use frameDescriptor instead')
const Frame$json = {
  '1': 'Frame',
  '2': [
    {'1': 'v', '3': 1, '4': 1, '5': 13, '10': 'v'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'reply_to', '3': 3, '4': 1, '5': 9, '10': 'replyTo'},
    {'1': 'seq', '3': 4, '4': 1, '5': 4, '10': 'seq'},
    {
      '1': 'client_hello',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ClientHello',
      '9': 0,
      '10': 'clientHello'
    },
    {
      '1': 'subscribe',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Subscribe',
      '9': 0,
      '10': 'subscribe'
    },
    {
      '1': 'unsubscribe',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Unsubscribe',
      '9': 0,
      '10': 'unsubscribe'
    },
    {
      '1': 'create_session',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.CreateSession',
      '9': 0,
      '10': 'createSession'
    },
    {
      '1': 'send_message',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.SendMessage',
      '9': 0,
      '10': 'sendMessage'
    },
    {
      '1': 'interrupt_session',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.InterruptSession',
      '9': 0,
      '10': 'interruptSession'
    },
    {
      '1': 'approval_decision',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ApprovalDecision',
      '9': 0,
      '10': 'approvalDecision'
    },
    {
      '1': 'stop_session',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.StopSession',
      '9': 0,
      '10': 'stopSession'
    },
    {
      '1': 'client_presence',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ClientPresence',
      '9': 0,
      '10': 'clientPresence'
    },
    {
      '1': 'welcome',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Welcome',
      '9': 0,
      '10': 'welcome'
    },
    {
      '1': 'ack',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Ack',
      '9': 0,
      '10': 'ack'
    },
    {
      '1': 'error',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Error',
      '9': 0,
      '10': 'error'
    },
    {
      '1': 'node_status',
      '3': 33,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.NodeStatus',
      '9': 0,
      '10': 'nodeStatus'
    },
    {
      '1': 'session_info',
      '3': 34,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.SessionInfo',
      '9': 0,
      '10': 'sessionInfo'
    },
    {
      '1': 'timeline',
      '3': 35,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.TimelineUpdate',
      '9': 0,
      '10': 'timeline'
    },
    {
      '1': 'approval_requested',
      '3': 36,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ApprovalRequest',
      '9': 0,
      '10': 'approvalRequested'
    },
    {
      '1': 'approval_resolved',
      '3': 37,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ApprovalResolved',
      '9': 0,
      '10': 'approvalResolved'
    },
    {
      '1': 'session_removed',
      '3': 38,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.SessionRemoved',
      '9': 0,
      '10': 'sessionRemoved'
    },
    {
      '1': 'preferences',
      '3': 39,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Preferences',
      '9': 0,
      '10': 'preferences'
    },
    {
      '1': 'artifact_added',
      '3': 40,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Artifact',
      '9': 0,
      '10': 'artifactAdded'
    },
    {
      '1': 'chat',
      '3': 41,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Chat',
      '9': 0,
      '10': 'chat'
    },
    {
      '1': 'update_available',
      '3': 42,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UpdateManifest',
      '9': 0,
      '10': 'updateAvailable'
    },
    {
      '1': 'agent_hello',
      '3': 50,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentHello',
      '9': 0,
      '10': 'agentHello'
    },
    {
      '1': 'session_index',
      '3': 51,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.SessionIndex',
      '9': 0,
      '10': 'sessionIndex'
    },
    {
      '1': 'raw_events',
      '3': 52,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.RawEvents',
      '9': 0,
      '10': 'rawEvents'
    },
    {
      '1': 'usage_report',
      '3': 53,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UsageReport',
      '9': 0,
      '10': 'usageReport'
    },
    {
      '1': 'plan_usage',
      '3': 54,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.PlanUsage',
      '9': 0,
      '10': 'planUsage'
    },
    {
      '1': 'screen_snapshot',
      '3': 55,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ScreenSnapshot',
      '9': 0,
      '10': 'screenSnapshot'
    },
    {
      '1': 'mode_result',
      '3': 56,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ModeResult',
      '9': 0,
      '10': 'modeResult'
    },
    {
      '1': 'command_result',
      '3': 57,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.CommandResult',
      '9': 0,
      '10': 'commandResult'
    },
    {
      '1': 'agent_command',
      '3': 60,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand',
      '9': 0,
      '10': 'agentCommand'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `Frame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frameDescriptor = $convert.base64Decode(
    'CgVGcmFtZRIMCgF2GAEgASgNUgF2Eg4KAmlkGAIgASgJUgJpZBIZCghyZXBseV90bxgDIAEoCV'
    'IHcmVwbHlUbxIQCgNzZXEYBCABKARSA3NlcRI7CgxjbGllbnRfaGVsbG8YCiABKAsyFi50ZXRo'
    'ZXIudjEuQ2xpZW50SGVsbG9IAFILY2xpZW50SGVsbG8SNAoJc3Vic2NyaWJlGAsgASgLMhQudG'
    'V0aGVyLnYxLlN1YnNjcmliZUgAUglzdWJzY3JpYmUSOgoLdW5zdWJzY3JpYmUYDCABKAsyFi50'
    'ZXRoZXIudjEuVW5zdWJzY3JpYmVIAFILdW5zdWJzY3JpYmUSQQoOY3JlYXRlX3Nlc3Npb24YDS'
    'ABKAsyGC50ZXRoZXIudjEuQ3JlYXRlU2Vzc2lvbkgAUg1jcmVhdGVTZXNzaW9uEjsKDHNlbmRf'
    'bWVzc2FnZRgOIAEoCzIWLnRldGhlci52MS5TZW5kTWVzc2FnZUgAUgtzZW5kTWVzc2FnZRJKCh'
    'FpbnRlcnJ1cHRfc2Vzc2lvbhgPIAEoCzIbLnRldGhlci52MS5JbnRlcnJ1cHRTZXNzaW9uSABS'
    'EGludGVycnVwdFNlc3Npb24SSgoRYXBwcm92YWxfZGVjaXNpb24YECABKAsyGy50ZXRoZXIudj'
    'EuQXBwcm92YWxEZWNpc2lvbkgAUhBhcHByb3ZhbERlY2lzaW9uEjsKDHN0b3Bfc2Vzc2lvbhgR'
    'IAEoCzIWLnRldGhlci52MS5TdG9wU2Vzc2lvbkgAUgtzdG9wU2Vzc2lvbhJECg9jbGllbnRfcH'
    'Jlc2VuY2UYEiABKAsyGS50ZXRoZXIudjEuQ2xpZW50UHJlc2VuY2VIAFIOY2xpZW50UHJlc2Vu'
    'Y2USLgoHd2VsY29tZRgeIAEoCzISLnRldGhlci52MS5XZWxjb21lSABSB3dlbGNvbWUSIgoDYW'
    'NrGB8gASgLMg4udGV0aGVyLnYxLkFja0gAUgNhY2sSKAoFZXJyb3IYICABKAsyEC50ZXRoZXIu'
    'djEuRXJyb3JIAFIFZXJyb3ISOAoLbm9kZV9zdGF0dXMYISABKAsyFS50ZXRoZXIudjEuTm9kZV'
    'N0YXR1c0gAUgpub2RlU3RhdHVzEjsKDHNlc3Npb25faW5mbxgiIAEoCzIWLnRldGhlci52MS5T'
    'ZXNzaW9uSW5mb0gAUgtzZXNzaW9uSW5mbxI3Cgh0aW1lbGluZRgjIAEoCzIZLnRldGhlci52MS'
    '5UaW1lbGluZVVwZGF0ZUgAUgh0aW1lbGluZRJLChJhcHByb3ZhbF9yZXF1ZXN0ZWQYJCABKAsy'
    'Gi50ZXRoZXIudjEuQXBwcm92YWxSZXF1ZXN0SABSEWFwcHJvdmFsUmVxdWVzdGVkEkoKEWFwcH'
    'JvdmFsX3Jlc29sdmVkGCUgASgLMhsudGV0aGVyLnYxLkFwcHJvdmFsUmVzb2x2ZWRIAFIQYXBw'
    'cm92YWxSZXNvbHZlZBJECg9zZXNzaW9uX3JlbW92ZWQYJiABKAsyGS50ZXRoZXIudjEuU2Vzc2'
    'lvblJlbW92ZWRIAFIOc2Vzc2lvblJlbW92ZWQSOgoLcHJlZmVyZW5jZXMYJyABKAsyFi50ZXRo'
    'ZXIudjEuUHJlZmVyZW5jZXNIAFILcHJlZmVyZW5jZXMSPAoOYXJ0aWZhY3RfYWRkZWQYKCABKA'
    'syEy50ZXRoZXIudjEuQXJ0aWZhY3RIAFINYXJ0aWZhY3RBZGRlZBIlCgRjaGF0GCkgASgLMg8u'
    'dGV0aGVyLnYxLkNoYXRIAFIEY2hhdBJGChB1cGRhdGVfYXZhaWxhYmxlGCogASgLMhkudGV0aG'
    'VyLnYxLlVwZGF0ZU1hbmlmZXN0SABSD3VwZGF0ZUF2YWlsYWJsZRI4CgthZ2VudF9oZWxsbxgy'
    'IAEoCzIVLnRldGhlci52MS5BZ2VudEhlbGxvSABSCmFnZW50SGVsbG8SPgoNc2Vzc2lvbl9pbm'
    'RleBgzIAEoCzIXLnRldGhlci52MS5TZXNzaW9uSW5kZXhIAFIMc2Vzc2lvbkluZGV4EjUKCnJh'
    'd19ldmVudHMYNCABKAsyFC50ZXRoZXIudjEuUmF3RXZlbnRzSABSCXJhd0V2ZW50cxI7Cgx1c2'
    'FnZV9yZXBvcnQYNSABKAsyFi50ZXRoZXIudjEuVXNhZ2VSZXBvcnRIAFILdXNhZ2VSZXBvcnQS'
    'NQoKcGxhbl91c2FnZRg2IAEoCzIULnRldGhlci52MS5QbGFuVXNhZ2VIAFIJcGxhblVzYWdlEk'
    'QKD3NjcmVlbl9zbmFwc2hvdBg3IAEoCzIZLnRldGhlci52MS5TY3JlZW5TbmFwc2hvdEgAUg5z'
    'Y3JlZW5TbmFwc2hvdBI4Cgttb2RlX3Jlc3VsdBg4IAEoCzIVLnRldGhlci52MS5Nb2RlUmVzdW'
    'x0SABSCm1vZGVSZXN1bHQSQQoOY29tbWFuZF9yZXN1bHQYOSABKAsyGC50ZXRoZXIudjEuQ29t'
    'bWFuZFJlc3VsdEgAUg1jb21tYW5kUmVzdWx0Ej4KDWFnZW50X2NvbW1hbmQYPCABKAsyFy50ZX'
    'RoZXIudjEuQWdlbnRDb21tYW5kSABSDGFnZW50Q29tbWFuZEIGCgRib2R5');

@$core.Deprecated('Use nodeStatusDescriptor instead')
const NodeStatus$json = {
  '1': 'NodeStatus',
  '2': [
    {'1': 'node', '3': 1, '4': 1, '5': 9, '10': 'node'},
    {'1': 'online', '3': 2, '4': 1, '5': 8, '10': 'online'},
    {'1': 'os', '3': 3, '4': 1, '5': 9, '10': 'os'},
    {'1': 'hostname', '3': 4, '4': 1, '5': 9, '10': 'hostname'},
    {'1': 'claude_version', '3': 5, '4': 1, '5': 9, '10': 'claudeVersion'},
    {'1': 'agent_version', '3': 6, '4': 1, '5': 9, '10': 'agentVersion'},
    {'1': 'last_seen_ms', '3': 7, '4': 1, '5': 3, '10': 'lastSeenMs'},
    {'1': 'running_sessions', '3': 8, '4': 1, '5': 5, '10': 'runningSessions'},
    {'1': 'ip', '3': 9, '4': 1, '5': 9, '10': 'ip'},
  ],
};

/// Descriptor for `NodeStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeStatusDescriptor = $convert.base64Decode(
    'CgpOb2RlU3RhdHVzEhIKBG5vZGUYASABKAlSBG5vZGUSFgoGb25saW5lGAIgASgIUgZvbmxpbm'
    'USDgoCb3MYAyABKAlSAm9zEhoKCGhvc3RuYW1lGAQgASgJUghob3N0bmFtZRIlCg5jbGF1ZGVf'
    'dmVyc2lvbhgFIAEoCVINY2xhdWRlVmVyc2lvbhIjCg1hZ2VudF92ZXJzaW9uGAYgASgJUgxhZ2'
    'VudFZlcnNpb24SIAoMbGFzdF9zZWVuX21zGAcgASgDUgpsYXN0U2Vlbk1zEikKEHJ1bm5pbmdf'
    'c2Vzc2lvbnMYCCABKAVSD3J1bm5pbmdTZXNzaW9ucxIOCgJpcBgJIAEoCVICaXA=');

@$core.Deprecated('Use sessionInfoDescriptor instead')
const SessionInfo$json = {
  '1': 'SessionInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'node', '3': 2, '4': 1, '5': 9, '10': 'node'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cwd', '3': 4, '4': 1, '5': 9, '10': 'cwd'},
    {'1': 'git_branch', '3': 5, '4': 1, '5': 9, '10': 'gitBranch'},
    {'1': 'created_ms', '3': 6, '4': 1, '5': 3, '10': 'createdMs'},
    {'1': 'updated_ms', '3': 7, '4': 1, '5': 3, '10': 'updatedMs'},
    {'1': 'message_count', '3': 8, '4': 1, '5': 5, '10': 'messageCount'},
    {
      '1': 'state',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.SessionState',
      '10': 'state'
    },
    {'1': 'last_prompt', '3': 10, '4': 1, '5': 9, '10': 'lastPrompt'},
    {'1': 'claude_version', '3': 11, '4': 1, '5': 9, '10': 'claudeVersion'},
    {'1': 'model', '3': 12, '4': 1, '5': 9, '10': 'model'},
    {
      '1': 'todos',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Todo',
      '10': 'todos'
    },
    {'1': 'last_cost_usd', '3': 14, '4': 1, '5': 1, '10': 'lastCostUsd'},
    {'1': 'error', '3': 15, '4': 1, '5': 9, '10': 'error'},
    {
      '1': 'host',
      '3': 16,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.SessionHost',
      '10': 'host'
    },
    {'1': 'attach_command', '3': 17, '4': 1, '5': 9, '10': 'attachCommand'},
    {'1': 'terminal_input', '3': 18, '4': 1, '5': 8, '10': 'terminalInput'},
    {'1': 'archived', '3': 19, '4': 1, '5': 8, '10': 'archived'},
    {'1': 'parent', '3': 20, '4': 1, '5': 9, '10': 'parent'},
    {'1': 'fork_point', '3': 21, '4': 1, '5': 9, '10': 'forkPoint'},
    {'1': 'lineage', '3': 22, '4': 1, '5': 9, '10': 'lineage'},
    {'1': 'scratch', '3': 23, '4': 1, '5': 8, '10': 'scratch'},
    {'1': 'global', '3': 24, '4': 1, '5': 8, '10': 'global'},
    {'1': 'codebase', '3': 25, '4': 1, '5': 9, '10': 'codebase'},
    {'1': 'snapshot', '3': 26, '4': 1, '5': 9, '10': 'snapshot'},
    {'1': 'permission_mode', '3': 27, '4': 1, '5': 9, '10': 'permissionMode'},
    {'1': 'mode_revert_ms', '3': 28, '4': 1, '5': 3, '10': 'modeRevertMs'},
    {'1': 'mode_revert_to', '3': 29, '4': 1, '5': 9, '10': 'modeRevertTo'},
    {'1': 'backed_up_ms', '3': 30, '4': 1, '5': 3, '10': 'backedUpMs'},
    {'1': 'backed_up_bytes', '3': 31, '4': 1, '5': 3, '10': 'backedUpBytes'},
  ],
};

/// Descriptor for `SessionInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionInfoDescriptor = $convert.base64Decode(
    'CgtTZXNzaW9uSW5mbxIOCgJpZBgBIAEoCVICaWQSEgoEbm9kZRgCIAEoCVIEbm9kZRIUCgV0aX'
    'RsZRgDIAEoCVIFdGl0bGUSEAoDY3dkGAQgASgJUgNjd2QSHQoKZ2l0X2JyYW5jaBgFIAEoCVIJ'
    'Z2l0QnJhbmNoEh0KCmNyZWF0ZWRfbXMYBiABKANSCWNyZWF0ZWRNcxIdCgp1cGRhdGVkX21zGA'
    'cgASgDUgl1cGRhdGVkTXMSIwoNbWVzc2FnZV9jb3VudBgIIAEoBVIMbWVzc2FnZUNvdW50Ei0K'
    'BXN0YXRlGAkgASgOMhcudGV0aGVyLnYxLlNlc3Npb25TdGF0ZVIFc3RhdGUSHwoLbGFzdF9wcm'
    '9tcHQYCiABKAlSCmxhc3RQcm9tcHQSJQoOY2xhdWRlX3ZlcnNpb24YCyABKAlSDWNsYXVkZVZl'
    'cnNpb24SFAoFbW9kZWwYDCABKAlSBW1vZGVsEiUKBXRvZG9zGA0gAygLMg8udGV0aGVyLnYxLl'
    'RvZG9SBXRvZG9zEiIKDWxhc3RfY29zdF91c2QYDiABKAFSC2xhc3RDb3N0VXNkEhQKBWVycm9y'
    'GA8gASgJUgVlcnJvchIqCgRob3N0GBAgASgOMhYudGV0aGVyLnYxLlNlc3Npb25Ib3N0UgRob3'
    'N0EiUKDmF0dGFjaF9jb21tYW5kGBEgASgJUg1hdHRhY2hDb21tYW5kEiUKDnRlcm1pbmFsX2lu'
    'cHV0GBIgASgIUg10ZXJtaW5hbElucHV0EhoKCGFyY2hpdmVkGBMgASgIUghhcmNoaXZlZBIWCg'
    'ZwYXJlbnQYFCABKAlSBnBhcmVudBIdCgpmb3JrX3BvaW50GBUgASgJUglmb3JrUG9pbnQSGAoH'
    'bGluZWFnZRgWIAEoCVIHbGluZWFnZRIYCgdzY3JhdGNoGBcgASgIUgdzY3JhdGNoEhYKBmdsb2'
    'JhbBgYIAEoCFIGZ2xvYmFsEhoKCGNvZGViYXNlGBkgASgJUghjb2RlYmFzZRIaCghzbmFwc2hv'
    'dBgaIAEoCVIIc25hcHNob3QSJwoPcGVybWlzc2lvbl9tb2RlGBsgASgJUg5wZXJtaXNzaW9uTW'
    '9kZRIkCg5tb2RlX3JldmVydF9tcxgcIAEoA1IMbW9kZVJldmVydE1zEiQKDm1vZGVfcmV2ZXJ0'
    'X3RvGB0gASgJUgxtb2RlUmV2ZXJ0VG8SIAoMYmFja2VkX3VwX21zGB4gASgDUgpiYWNrZWRVcE'
    '1zEiYKD2JhY2tlZF91cF9ieXRlcxgfIAEoA1INYmFja2VkVXBCeXRlcw==');

@$core.Deprecated('Use sessionRemovedDescriptor instead')
const SessionRemoved$json = {
  '1': 'SessionRemoved',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

/// Descriptor for `SessionRemoved`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionRemovedDescriptor = $convert
    .base64Decode('Cg5TZXNzaW9uUmVtb3ZlZBIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9u');

@$core.Deprecated('Use timelineUpdateDescriptor instead')
const TimelineUpdate$json = {
  '1': 'TimelineUpdate',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {
      '1': 'items',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.TimelineItem',
      '10': 'items'
    },
  ],
};

/// Descriptor for `TimelineUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timelineUpdateDescriptor = $convert.base64Decode(
    'Cg5UaW1lbGluZVVwZGF0ZRIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEi0KBWl0ZW1zGAIgAy'
    'gLMhcudGV0aGVyLnYxLlRpbWVsaW5lSXRlbVIFaXRlbXM=');

@$core.Deprecated('Use timelinePageDescriptor instead')
const TimelinePage$json = {
  '1': 'TimelinePage',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {
      '1': 'items',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.TimelineItem',
      '10': 'items'
    },
    {'1': 'seq', '3': 3, '4': 1, '5': 4, '10': 'seq'},
  ],
};

/// Descriptor for `TimelinePage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timelinePageDescriptor = $convert.base64Decode(
    'CgxUaW1lbGluZVBhZ2USGAoHc2Vzc2lvbhgBIAEoCVIHc2Vzc2lvbhItCgVpdGVtcxgCIAMoCz'
    'IXLnRldGhlci52MS5UaW1lbGluZUl0ZW1SBWl0ZW1zEhAKA3NlcRgDIAEoBFIDc2Vx');

@$core.Deprecated('Use approvalRequestDescriptor instead')
const ApprovalRequest$json = {
  '1': 'ApprovalRequest',
  '2': [
    {'1': 'approval_id', '3': 1, '4': 1, '5': 9, '10': 'approvalId'},
    {'1': 'session', '3': 2, '4': 1, '5': 9, '10': 'session'},
    {'1': 'node', '3': 3, '4': 1, '5': 9, '10': 'node'},
    {'1': 'tool_name', '3': 4, '4': 1, '5': 9, '10': 'toolName'},
    {'1': 'input_json', '3': 5, '4': 1, '5': 9, '10': 'inputJson'},
    {'1': 'description', '3': 6, '4': 1, '5': 9, '10': 'description'},
    {'1': 'created_ms', '3': 7, '4': 1, '5': 3, '10': 'createdMs'},
    {
      '1': 'preview',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ToolCard',
      '10': 'preview'
    },
    {
      '1': 'kind',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.ApprovalRequest.Kind',
      '10': 'kind'
    },
    {'1': 'options', '3': 10, '4': 3, '5': 9, '10': 'options'},
    {'1': 'selected', '3': 11, '4': 1, '5': 5, '10': 'selected'},
    {'1': 'screen', '3': 12, '4': 1, '5': 9, '10': 'screen'},
  ],
  '4': [ApprovalRequest_Kind$json],
};

@$core.Deprecated('Use approvalRequestDescriptor instead')
const ApprovalRequest_Kind$json = {
  '1': 'Kind',
  '2': [
    {'1': 'KIND_UNSPECIFIED', '2': 0},
    {'1': 'KIND_TOOL', '2': 1},
    {'1': 'KIND_FOLDER_TRUST', '2': 2},
    {'1': 'KIND_QUESTION', '2': 3},
    {'1': 'KIND_PROMPT', '2': 4},
  ],
};

/// Descriptor for `ApprovalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvalRequestDescriptor = $convert.base64Decode(
    'Cg9BcHByb3ZhbFJlcXVlc3QSHwoLYXBwcm92YWxfaWQYASABKAlSCmFwcHJvdmFsSWQSGAoHc2'
    'Vzc2lvbhgCIAEoCVIHc2Vzc2lvbhISCgRub2RlGAMgASgJUgRub2RlEhsKCXRvb2xfbmFtZRgE'
    'IAEoCVIIdG9vbE5hbWUSHQoKaW5wdXRfanNvbhgFIAEoCVIJaW5wdXRKc29uEiAKC2Rlc2NyaX'
    'B0aW9uGAYgASgJUgtkZXNjcmlwdGlvbhIdCgpjcmVhdGVkX21zGAcgASgDUgljcmVhdGVkTXMS'
    'LQoHcHJldmlldxgIIAEoCzITLnRldGhlci52MS5Ub29sQ2FyZFIHcHJldmlldxIzCgRraW5kGA'
    'kgASgOMh8udGV0aGVyLnYxLkFwcHJvdmFsUmVxdWVzdC5LaW5kUgRraW5kEhgKB29wdGlvbnMY'
    'CiADKAlSB29wdGlvbnMSGgoIc2VsZWN0ZWQYCyABKAVSCHNlbGVjdGVkEhYKBnNjcmVlbhgMIA'
    'EoCVIGc2NyZWVuImYKBEtpbmQSFAoQS0lORF9VTlNQRUNJRklFRBAAEg0KCUtJTkRfVE9PTBAB'
    'EhUKEUtJTkRfRk9MREVSX1RSVVNUEAISEQoNS0lORF9RVUVTVElPThADEg8KC0tJTkRfUFJPTV'
    'BUEAQ=');

@$core.Deprecated('Use approvalDecisionDescriptor instead')
const ApprovalDecision$json = {
  '1': 'ApprovalDecision',
  '2': [
    {'1': 'approval_id', '3': 1, '4': 1, '5': 9, '10': 'approvalId'},
    {
      '1': 'decision',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.Decision',
      '10': 'decision'
    },
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    {
      '1': 'answers',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.ApprovalDecision.AnswersEntry',
      '10': 'answers'
    },
    {'1': 'option', '3': 5, '4': 1, '5': 5, '10': 'option'},
  ],
  '3': [ApprovalDecision_AnswersEntry$json],
};

@$core.Deprecated('Use approvalDecisionDescriptor instead')
const ApprovalDecision_AnswersEntry$json = {
  '1': 'AnswersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ApprovalDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvalDecisionDescriptor = $convert.base64Decode(
    'ChBBcHByb3ZhbERlY2lzaW9uEh8KC2FwcHJvdmFsX2lkGAEgASgJUgphcHByb3ZhbElkEi8KCG'
    'RlY2lzaW9uGAIgASgOMhMudGV0aGVyLnYxLkRlY2lzaW9uUghkZWNpc2lvbhIYCgdtZXNzYWdl'
    'GAMgASgJUgdtZXNzYWdlEkIKB2Fuc3dlcnMYBCADKAsyKC50ZXRoZXIudjEuQXBwcm92YWxEZW'
    'Npc2lvbi5BbnN3ZXJzRW50cnlSB2Fuc3dlcnMSFgoGb3B0aW9uGAUgASgFUgZvcHRpb24aOgoM'
    'QW5zd2Vyc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOA'
    'E=');

@$core.Deprecated('Use approvalResolvedDescriptor instead')
const ApprovalResolved$json = {
  '1': 'ApprovalResolved',
  '2': [
    {'1': 'approval_id', '3': 1, '4': 1, '5': 9, '10': 'approvalId'},
    {'1': 'session', '3': 2, '4': 1, '5': 9, '10': 'session'},
    {
      '1': 'decision',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.Decision',
      '10': 'decision'
    },
    {'1': 'by', '3': 4, '4': 1, '5': 9, '10': 'by'},
  ],
};

/// Descriptor for `ApprovalResolved`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvalResolvedDescriptor = $convert.base64Decode(
    'ChBBcHByb3ZhbFJlc29sdmVkEh8KC2FwcHJvdmFsX2lkGAEgASgJUgphcHByb3ZhbElkEhgKB3'
    'Nlc3Npb24YAiABKAlSB3Nlc3Npb24SLwoIZGVjaXNpb24YAyABKA4yEy50ZXRoZXIudjEuRGVj'
    'aXNpb25SCGRlY2lzaW9uEg4KAmJ5GAQgASgJUgJieQ==');

@$core.Deprecated('Use clientPresenceDescriptor instead')
const ClientPresence$json = {
  '1': 'ClientPresence',
  '2': [
    {'1': 'active', '3': 1, '4': 1, '5': 8, '10': 'active'},
  ],
};

/// Descriptor for `ClientPresence`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientPresenceDescriptor = $convert
    .base64Decode('Cg5DbGllbnRQcmVzZW5jZRIWCgZhY3RpdmUYASABKAhSBmFjdGl2ZQ==');

@$core.Deprecated('Use clientHelloDescriptor instead')
const ClientHello$json = {
  '1': 'ClientHello',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'client_name', '3': 2, '4': 1, '5': 9, '10': 'clientName'},
    {'1': 'platform', '3': 3, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'app_version', '3': 4, '4': 1, '5': 9, '10': 'appVersion'},
  ],
};

/// Descriptor for `ClientHello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientHelloDescriptor = $convert.base64Decode(
    'CgtDbGllbnRIZWxsbxIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SHwoLY2xpZW50X25hbWUYAiABKA'
    'lSCmNsaWVudE5hbWUSGgoIcGxhdGZvcm0YAyABKAlSCHBsYXRmb3JtEh8KC2FwcF92ZXJzaW9u'
    'GAQgASgJUgphcHBWZXJzaW9u');

@$core.Deprecated('Use connectedClientDescriptor instead')
const ConnectedClient$json = {
  '1': 'ConnectedClient',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'platform', '3': 2, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'app_version', '3': 3, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'device_id', '3': 4, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'ip', '3': 5, '4': 1, '5': 9, '10': 'ip'},
    {'1': 'connected_ms', '3': 6, '4': 1, '5': 3, '10': 'connectedMs'},
  ],
};

/// Descriptor for `ConnectedClient`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectedClientDescriptor = $convert.base64Decode(
    'Cg9Db25uZWN0ZWRDbGllbnQSEgoEbmFtZRgBIAEoCVIEbmFtZRIaCghwbGF0Zm9ybRgCIAEoCV'
    'IIcGxhdGZvcm0SHwoLYXBwX3ZlcnNpb24YAyABKAlSCmFwcFZlcnNpb24SGwoJZGV2aWNlX2lk'
    'GAQgASgJUghkZXZpY2VJZBIOCgJpcBgFIAEoCVICaXASIQoMY29ubmVjdGVkX21zGAYgASgDUg'
    'tjb25uZWN0ZWRNcw==');

@$core.Deprecated('Use clientListDescriptor instead')
const ClientList$json = {
  '1': 'ClientList',
  '2': [
    {
      '1': 'clients',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.ConnectedClient',
      '10': 'clients'
    },
  ],
};

/// Descriptor for `ClientList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientListDescriptor = $convert.base64Decode(
    'CgpDbGllbnRMaXN0EjQKB2NsaWVudHMYASADKAsyGi50ZXRoZXIudjEuQ29ubmVjdGVkQ2xpZW'
    '50UgdjbGllbnRz');

@$core.Deprecated('Use subscribeDescriptor instead')
const Subscribe$json = {
  '1': 'Subscribe',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'after_seq', '3': 2, '4': 1, '5': 4, '10': 'afterSeq'},
  ],
};

/// Descriptor for `Subscribe`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeDescriptor = $convert.base64Decode(
    'CglTdWJzY3JpYmUSGAoHc2Vzc2lvbhgBIAEoCVIHc2Vzc2lvbhIbCglhZnRlcl9zZXEYAiABKA'
    'RSCGFmdGVyU2Vx');

@$core.Deprecated('Use unsubscribeDescriptor instead')
const Unsubscribe$json = {
  '1': 'Unsubscribe',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

/// Descriptor for `Unsubscribe`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unsubscribeDescriptor = $convert
    .base64Decode('CgtVbnN1YnNjcmliZRIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9u');

@$core.Deprecated('Use createSessionDescriptor instead')
const CreateSession$json = {
  '1': 'CreateSession',
  '2': [
    {'1': 'node', '3': 1, '4': 1, '5': 9, '10': 'node'},
    {'1': 'cwd', '3': 2, '4': 1, '5': 9, '10': 'cwd'},
    {'1': 'prompt', '3': 3, '4': 1, '5': 9, '10': 'prompt'},
    {'1': 'model', '3': 4, '4': 1, '5': 9, '10': 'model'},
    {'1': 'permission_mode', '3': 5, '4': 1, '5': 9, '10': 'permissionMode'},
    {'1': 'name', '3': 6, '4': 1, '5': 9, '10': 'name'},
    {'1': 'create_cwd', '3': 7, '4': 1, '5': 8, '10': 'createCwd'},
    {'1': 'attachments', '3': 8, '4': 3, '5': 9, '10': 'attachments'},
    {'1': 'scratch', '3': 9, '4': 1, '5': 8, '10': 'scratch'},
  ],
};

/// Descriptor for `CreateSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSessionDescriptor = $convert.base64Decode(
    'Cg1DcmVhdGVTZXNzaW9uEhIKBG5vZGUYASABKAlSBG5vZGUSEAoDY3dkGAIgASgJUgNjd2QSFg'
    'oGcHJvbXB0GAMgASgJUgZwcm9tcHQSFAoFbW9kZWwYBCABKAlSBW1vZGVsEicKD3Blcm1pc3Np'
    'b25fbW9kZRgFIAEoCVIOcGVybWlzc2lvbk1vZGUSEgoEbmFtZRgGIAEoCVIEbmFtZRIdCgpjcm'
    'VhdGVfY3dkGAcgASgIUgljcmVhdGVDd2QSIAoLYXR0YWNobWVudHMYCCADKAlSC2F0dGFjaG1l'
    'bnRzEhgKB3NjcmF0Y2gYCSABKAhSB3NjcmF0Y2g=');

@$core.Deprecated('Use archiveSessionDescriptor instead')
const ArchiveSession$json = {
  '1': 'ArchiveSession',
  '2': [
    {'1': 'archived', '3': 1, '4': 1, '5': 8, '10': 'archived'},
  ],
};

/// Descriptor for `ArchiveSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveSessionDescriptor = $convert.base64Decode(
    'Cg5BcmNoaXZlU2Vzc2lvbhIaCghhcmNoaXZlZBgBIAEoCFIIYXJjaGl2ZWQ=');

@$core.Deprecated('Use setGlobalDescriptor instead')
const SetGlobal$json = {
  '1': 'SetGlobal',
  '2': [
    {'1': 'global', '3': 1, '4': 1, '5': 8, '10': 'global'},
  ],
};

/// Descriptor for `SetGlobal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setGlobalDescriptor =
    $convert.base64Decode('CglTZXRHbG9iYWwSFgoGZ2xvYmFsGAEgASgIUgZnbG9iYWw=');

@$core.Deprecated('Use sendMessageDescriptor instead')
const SendMessage$json = {
  '1': 'SendMessage',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'fork', '3': 3, '4': 1, '5': 8, '10': 'fork'},
    {'1': 'attachments', '3': 4, '4': 3, '5': 9, '10': 'attachments'},
    {'1': 'client_id', '3': 5, '4': 1, '5': 9, '10': 'clientId'},
  ],
};

/// Descriptor for `SendMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMessageDescriptor = $convert.base64Decode(
    'CgtTZW5kTWVzc2FnZRIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEhIKBHRleHQYAiABKAlSBH'
    'RleHQSEgoEZm9yaxgDIAEoCFIEZm9yaxIgCgthdHRhY2htZW50cxgEIAMoCVILYXR0YWNobWVu'
    'dHMSGwoJY2xpZW50X2lkGAUgASgJUghjbGllbnRJZA==');

@$core.Deprecated('Use interruptSessionDescriptor instead')
const InterruptSession$json = {
  '1': 'InterruptSession',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

/// Descriptor for `InterruptSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List interruptSessionDescriptor = $convert.base64Decode(
    'ChBJbnRlcnJ1cHRTZXNzaW9uEhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24=');

@$core.Deprecated('Use stopSessionDescriptor instead')
const StopSession$json = {
  '1': 'StopSession',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

/// Descriptor for `StopSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopSessionDescriptor = $convert
    .base64Decode('CgtTdG9wU2Vzc2lvbhIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9u');

@$core.Deprecated('Use welcomeDescriptor instead')
const Welcome$json = {
  '1': 'Welcome',
  '2': [
    {'1': 'hub_version', '3': 1, '4': 1, '5': 9, '10': 'hubVersion'},
    {
      '1': 'nodes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.NodeStatus',
      '10': 'nodes'
    },
    {
      '1': 'sessions',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.SessionInfo',
      '10': 'sessions'
    },
    {
      '1': 'pending_approvals',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.ApprovalRequest',
      '10': 'pendingApprovals'
    },
    {
      '1': 'preferences',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Preferences',
      '10': 'preferences'
    },
    {'1': 'hub_node', '3': 6, '4': 1, '5': 9, '10': 'hubNode'},
    {'1': 'device_id', '3': 7, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'client_ip', '3': 8, '4': 1, '5': 9, '10': 'clientIp'},
    {
      '1': 'chats',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Chat',
      '10': 'chats'
    },
    {
      '1': 'update',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UpdateManifest',
      '10': 'update'
    },
  ],
};

/// Descriptor for `Welcome`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List welcomeDescriptor = $convert.base64Decode(
    'CgdXZWxjb21lEh8KC2h1Yl92ZXJzaW9uGAEgASgJUgpodWJWZXJzaW9uEisKBW5vZGVzGAIgAy'
    'gLMhUudGV0aGVyLnYxLk5vZGVTdGF0dXNSBW5vZGVzEjIKCHNlc3Npb25zGAMgAygLMhYudGV0'
    'aGVyLnYxLlNlc3Npb25JbmZvUghzZXNzaW9ucxJHChFwZW5kaW5nX2FwcHJvdmFscxgEIAMoCz'
    'IaLnRldGhlci52MS5BcHByb3ZhbFJlcXVlc3RSEHBlbmRpbmdBcHByb3ZhbHMSOAoLcHJlZmVy'
    'ZW5jZXMYBSABKAsyFi50ZXRoZXIudjEuUHJlZmVyZW5jZXNSC3ByZWZlcmVuY2VzEhkKCGh1Yl'
    '9ub2RlGAYgASgJUgdodWJOb2RlEhsKCWRldmljZV9pZBgHIAEoCVIIZGV2aWNlSWQSGwoJY2xp'
    'ZW50X2lwGAggASgJUghjbGllbnRJcBIlCgVjaGF0cxgJIAMoCzIPLnRldGhlci52MS5DaGF0Ug'
    'VjaGF0cxIxCgZ1cGRhdGUYCiABKAsyGS50ZXRoZXIudjEuVXBkYXRlTWFuaWZlc3RSBnVwZGF0'
    'ZQ==');

@$core.Deprecated('Use ackDescriptor instead')
const Ack$json = {
  '1': 'Ack',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

/// Descriptor for `Ack`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ackDescriptor =
    $convert.base64Decode('CgNBY2sSGAoHc2Vzc2lvbhgBIAEoCVIHc2Vzc2lvbg==');

@$core.Deprecated('Use errorDescriptor instead')
const Error$json = {
  '1': 'Error',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `Error`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorDescriptor = $convert.base64Decode(
    'CgVFcnJvchISCgRjb2RlGAEgASgJUgRjb2RlEhgKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use agentHelloDescriptor instead')
const AgentHello$json = {
  '1': 'AgentHello',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.NodeStatus',
      '10': 'status'
    },
  ],
};

/// Descriptor for `AgentHello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentHelloDescriptor = $convert.base64Decode(
    'CgpBZ2VudEhlbGxvEhQKBXRva2VuGAEgASgJUgV0b2tlbhItCgZzdGF0dXMYAiABKAsyFS50ZX'
    'RoZXIudjEuTm9kZVN0YXR1c1IGc3RhdHVz');

@$core.Deprecated('Use sessionIndexDescriptor instead')
const SessionIndex$json = {
  '1': 'SessionIndex',
  '2': [
    {'1': 'full', '3': 1, '4': 1, '5': 8, '10': 'full'},
    {
      '1': 'sessions',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.SessionInfo',
      '10': 'sessions'
    },
    {'1': 'removed', '3': 3, '4': 3, '5': 9, '10': 'removed'},
  ],
};

/// Descriptor for `SessionIndex`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionIndexDescriptor = $convert.base64Decode(
    'CgxTZXNzaW9uSW5kZXgSEgoEZnVsbBgBIAEoCFIEZnVsbBIyCghzZXNzaW9ucxgCIAMoCzIWLn'
    'RldGhlci52MS5TZXNzaW9uSW5mb1IIc2Vzc2lvbnMSGAoHcmVtb3ZlZBgDIAMoCVIHcmVtb3Zl'
    'ZA==');

@$core.Deprecated('Use rawEventsDescriptor instead')
const RawEvents$json = {
  '1': 'RawEvents',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {
      '1': 'source',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.RawEvents.Source',
      '10': 'source'
    },
    {'1': 'lines', '3': 3, '4': 3, '5': 9, '10': 'lines'},
    {'1': 'end_offset', '3': 4, '4': 1, '5': 3, '10': 'endOffset'},
  ],
  '4': [RawEvents_Source$json],
};

@$core.Deprecated('Use rawEventsDescriptor instead')
const RawEvents_Source$json = {
  '1': 'Source',
  '2': [
    {'1': 'SOURCE_UNSPECIFIED', '2': 0},
    {'1': 'SOURCE_STREAM', '2': 1},
    {'1': 'SOURCE_TRANSCRIPT', '2': 2},
  ],
};

/// Descriptor for `RawEvents`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rawEventsDescriptor = $convert.base64Decode(
    'CglSYXdFdmVudHMSGAoHc2Vzc2lvbhgBIAEoCVIHc2Vzc2lvbhIzCgZzb3VyY2UYAiABKA4yGy'
    '50ZXRoZXIudjEuUmF3RXZlbnRzLlNvdXJjZVIGc291cmNlEhQKBWxpbmVzGAMgAygJUgVsaW5l'
    'cxIdCgplbmRfb2Zmc2V0GAQgASgDUgllbmRPZmZzZXQiSgoGU291cmNlEhYKElNPVVJDRV9VTl'
    'NQRUNJRklFRBAAEhEKDVNPVVJDRV9TVFJFQU0QARIVChFTT1VSQ0VfVFJBTlNDUklQVBAC');

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand$json = {
  '1': 'AgentCommand',
  '2': [
    {
      '1': 'start',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.StartRun',
      '9': 0,
      '10': 'start'
    },
    {
      '1': 'send',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.SendInput',
      '9': 0,
      '10': 'send'
    },
    {
      '1': 'interrupt',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.Interrupt',
      '9': 0,
      '10': 'interrupt'
    },
    {
      '1': 'mirror',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.Mirror',
      '9': 0,
      '10': 'mirror'
    },
    {
      '1': 'stop_mirror',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.StopMirror',
      '9': 0,
      '10': 'stopMirror'
    },
    {
      '1': 'stop',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.Stop',
      '9': 0,
      '10': 'stop'
    },
    {
      '1': 'forget',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.Forget',
      '9': 0,
      '10': 'forget'
    },
    {
      '1': 'upload_transcript',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.UploadTranscript',
      '9': 0,
      '10': 'uploadTranscript'
    },
    {
      '1': 'snapshot',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.SnapshotCodebase',
      '9': 0,
      '10': 'snapshot'
    },
    {
      '1': 'scan',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.ScanCodebases',
      '9': 0,
      '10': 'scan'
    },
    {
      '1': 'fetch',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.FetchAttachment',
      '9': 0,
      '10': 'fetch'
    },
    {
      '1': 'keys',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.SendKeys',
      '9': 0,
      '10': 'keys'
    },
    {
      '1': 'capture',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.CaptureScreen',
      '9': 0,
      '10': 'capture'
    },
    {
      '1': 'set_mode',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.SetMode',
      '9': 0,
      '10': 'setMode'
    },
    {
      '1': 'backup',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.BackupSessions',
      '9': 0,
      '10': 'backup'
    },
    {
      '1': 'self_update',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCommand.SelfUpdate',
      '9': 0,
      '10': 'selfUpdate'
    },
  ],
  '3': [
    AgentCommand_StartRun$json,
    AgentCommand_SendInput$json,
    AgentCommand_SelfUpdate$json,
    AgentCommand_SetMode$json,
    AgentCommand_Interrupt$json,
    AgentCommand_Mirror$json,
    AgentCommand_StopMirror$json,
    AgentCommand_Stop$json,
    AgentCommand_Forget$json,
    AgentCommand_UploadTranscript$json,
    AgentCommand_SnapshotCodebase$json,
    AgentCommand_ScanCodebases$json,
    AgentCommand_CaptureScreen$json,
    AgentCommand_BackupSessions$json,
    AgentCommand_FetchAttachment$json
  ],
  '8': [
    {'1': 'op'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_StartRun$json = {
  '1': 'StartRun',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'cwd', '3': 2, '4': 1, '5': 9, '10': 'cwd'},
    {'1': 'prompt', '3': 3, '4': 1, '5': 9, '10': 'prompt'},
    {'1': 'model', '3': 4, '4': 1, '5': 9, '10': 'model'},
    {'1': 'permission_mode', '3': 5, '4': 1, '5': 9, '10': 'permissionMode'},
    {'1': 'name', '3': 6, '4': 1, '5': 9, '10': 'name'},
    {'1': 'resume', '3': 7, '4': 1, '5': 9, '10': 'resume'},
    {'1': 'fork', '3': 8, '4': 1, '5': 8, '10': 'fork'},
    {'1': 'create_cwd', '3': 9, '4': 1, '5': 8, '10': 'createCwd'},
    {
      '1': 'attachments',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Artifact',
      '10': 'attachments'
    },
    {'1': 'scratch', '3': 11, '4': 1, '5': 8, '10': 'scratch'},
    {
      '1': 'restore_transcript',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'restoreTranscript'
    },
    {'1': 'restore_codebase', '3': 13, '4': 1, '5': 9, '10': 'restoreCodebase'},
    {'1': 'restore_snapshot', '3': 14, '4': 1, '5': 9, '10': 'restoreSnapshot'},
    {'1': 'system_prompt', '3': 15, '4': 1, '5': 9, '10': 'systemPrompt'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_SendInput$json = {
  '1': 'SendInput',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'attachments',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Artifact',
      '10': 'attachments'
    },
    {'1': 'permission_mode', '3': 4, '4': 1, '5': 9, '10': 'permissionMode'},
    {'1': 'system_prompt', '3': 5, '4': 1, '5': 9, '10': 'systemPrompt'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_SelfUpdate$json = {
  '1': 'SelfUpdate',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 9, '10': 'version'},
    {
      '1': 'asset',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UpdateAsset',
      '10': 'asset'
    },
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_SetMode$json = {
  '1': 'SetMode',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'mode', '3': 2, '4': 1, '5': 9, '10': 'mode'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_Interrupt$json = {
  '1': 'Interrupt',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_Mirror$json = {
  '1': 'Mirror',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'from_offset', '3': 2, '4': 1, '5': 3, '10': 'fromOffset'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_StopMirror$json = {
  '1': 'StopMirror',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_Stop$json = {
  '1': 'Stop',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_Forget$json = {
  '1': 'Forget',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_UploadTranscript$json = {
  '1': 'UploadTranscript',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_SnapshotCodebase$json = {
  '1': 'SnapshotCodebase',
  '2': [
    {
      '1': 'codebase',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Codebase',
      '10': 'codebase'
    },
    {'1': 'session', '3': 2, '4': 1, '5': 9, '10': 'session'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_ScanCodebases$json = {
  '1': 'ScanCodebases',
  '2': [
    {'1': 'roots', '3': 1, '4': 3, '5': 9, '10': 'roots'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_CaptureScreen$json = {
  '1': 'CaptureScreen',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_BackupSessions$json = {
  '1': 'BackupSessions',
  '2': [
    {
      '1': 'stored',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.AgentCommand.BackupSessions.StoredEntry',
      '10': 'stored'
    },
  ],
  '3': [AgentCommand_BackupSessions_StoredEntry$json],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_BackupSessions_StoredEntry$json = {
  '1': 'StoredEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 3, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_FetchAttachment$json = {
  '1': 'FetchAttachment',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'cwd', '3': 2, '4': 1, '5': 9, '10': 'cwd'},
    {
      '1': 'artifact',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Artifact',
      '10': 'artifact'
    },
  ],
};

/// Descriptor for `AgentCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentCommandDescriptor = $convert.base64Decode(
    'CgxBZ2VudENvbW1hbmQSOAoFc3RhcnQYASABKAsyIC50ZXRoZXIudjEuQWdlbnRDb21tYW5kLl'
    'N0YXJ0UnVuSABSBXN0YXJ0EjcKBHNlbmQYAiABKAsyIS50ZXRoZXIudjEuQWdlbnRDb21tYW5k'
    'LlNlbmRJbnB1dEgAUgRzZW5kEkEKCWludGVycnVwdBgDIAEoCzIhLnRldGhlci52MS5BZ2VudE'
    'NvbW1hbmQuSW50ZXJydXB0SABSCWludGVycnVwdBI4CgZtaXJyb3IYBCABKAsyHi50ZXRoZXIu'
    'djEuQWdlbnRDb21tYW5kLk1pcnJvckgAUgZtaXJyb3ISRQoLc3RvcF9taXJyb3IYBSABKAsyIi'
    '50ZXRoZXIudjEuQWdlbnRDb21tYW5kLlN0b3BNaXJyb3JIAFIKc3RvcE1pcnJvchIyCgRzdG9w'
    'GAYgASgLMhwudGV0aGVyLnYxLkFnZW50Q29tbWFuZC5TdG9wSABSBHN0b3ASOAoGZm9yZ2V0GA'
    'cgASgLMh4udGV0aGVyLnYxLkFnZW50Q29tbWFuZC5Gb3JnZXRIAFIGZm9yZ2V0ElcKEXVwbG9h'
    'ZF90cmFuc2NyaXB0GAggASgLMigudGV0aGVyLnYxLkFnZW50Q29tbWFuZC5VcGxvYWRUcmFuc2'
    'NyaXB0SABSEHVwbG9hZFRyYW5zY3JpcHQSRgoIc25hcHNob3QYCSABKAsyKC50ZXRoZXIudjEu'
    'QWdlbnRDb21tYW5kLlNuYXBzaG90Q29kZWJhc2VIAFIIc25hcHNob3QSOwoEc2NhbhgKIAEoCz'
    'IlLnRldGhlci52MS5BZ2VudENvbW1hbmQuU2NhbkNvZGViYXNlc0gAUgRzY2FuEj8KBWZldGNo'
    'GAsgASgLMicudGV0aGVyLnYxLkFnZW50Q29tbWFuZC5GZXRjaEF0dGFjaG1lbnRIAFIFZmV0Y2'
    'gSKQoEa2V5cxgMIAEoCzITLnRldGhlci52MS5TZW5kS2V5c0gAUgRrZXlzEkEKB2NhcHR1cmUY'
    'DSABKAsyJS50ZXRoZXIudjEuQWdlbnRDb21tYW5kLkNhcHR1cmVTY3JlZW5IAFIHY2FwdHVyZR'
    'I8CghzZXRfbW9kZRgOIAEoCzIfLnRldGhlci52MS5BZ2VudENvbW1hbmQuU2V0TW9kZUgAUgdz'
    'ZXRNb2RlEkAKBmJhY2t1cBgPIAEoCzImLnRldGhlci52MS5BZ2VudENvbW1hbmQuQmFja3VwU2'
    'Vzc2lvbnNIAFIGYmFja3VwEkUKC3NlbGZfdXBkYXRlGBAgASgLMiIudGV0aGVyLnYxLkFnZW50'
    'Q29tbWFuZC5TZWxmVXBkYXRlSABSCnNlbGZVcGRhdGUa5wMKCFN0YXJ0UnVuEhgKB3Nlc3Npb2'
    '4YASABKAlSB3Nlc3Npb24SEAoDY3dkGAIgASgJUgNjd2QSFgoGcHJvbXB0GAMgASgJUgZwcm9t'
    'cHQSFAoFbW9kZWwYBCABKAlSBW1vZGVsEicKD3Blcm1pc3Npb25fbW9kZRgFIAEoCVIOcGVybW'
    'lzc2lvbk1vZGUSEgoEbmFtZRgGIAEoCVIEbmFtZRIWCgZyZXN1bWUYByABKAlSBnJlc3VtZRIS'
    'CgRmb3JrGAggASgIUgRmb3JrEh0KCmNyZWF0ZV9jd2QYCSABKAhSCWNyZWF0ZUN3ZBI1CgthdH'
    'RhY2htZW50cxgKIAMoCzITLnRldGhlci52MS5BcnRpZmFjdFILYXR0YWNobWVudHMSGAoHc2Ny'
    'YXRjaBgLIAEoCFIHc2NyYXRjaBItChJyZXN0b3JlX3RyYW5zY3JpcHQYDCABKAlSEXJlc3Rvcm'
    'VUcmFuc2NyaXB0EikKEHJlc3RvcmVfY29kZWJhc2UYDSABKAlSD3Jlc3RvcmVDb2RlYmFzZRIp'
    'ChByZXN0b3JlX3NuYXBzaG90GA4gASgJUg9yZXN0b3JlU25hcHNob3QSIwoNc3lzdGVtX3Byb2'
    '1wdBgPIAEoCVIMc3lzdGVtUHJvbXB0Gr4BCglTZW5kSW5wdXQSGAoHc2Vzc2lvbhgBIAEoCVIH'
    'c2Vzc2lvbhISCgR0ZXh0GAIgASgJUgR0ZXh0EjUKC2F0dGFjaG1lbnRzGAMgAygLMhMudGV0aG'
    'VyLnYxLkFydGlmYWN0UgthdHRhY2htZW50cxInCg9wZXJtaXNzaW9uX21vZGUYBCABKAlSDnBl'
    'cm1pc3Npb25Nb2RlEiMKDXN5c3RlbV9wcm9tcHQYBSABKAlSDHN5c3RlbVByb21wdBpUCgpTZW'
    'xmVXBkYXRlEhgKB3ZlcnNpb24YASABKAlSB3ZlcnNpb24SLAoFYXNzZXQYAiABKAsyFi50ZXRo'
    'ZXIudjEuVXBkYXRlQXNzZXRSBWFzc2V0GjcKB1NldE1vZGUSGAoHc2Vzc2lvbhgBIAEoCVIHc2'
    'Vzc2lvbhISCgRtb2RlGAIgASgJUgRtb2RlGiUKCUludGVycnVwdBIYCgdzZXNzaW9uGAEgASgJ'
    'UgdzZXNzaW9uGkMKBk1pcnJvchIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEh8KC2Zyb21fb2'
    'Zmc2V0GAIgASgDUgpmcm9tT2Zmc2V0GiYKClN0b3BNaXJyb3ISGAoHc2Vzc2lvbhgBIAEoCVIH'
    'c2Vzc2lvbhogCgRTdG9wEhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24aIgoGRm9yZ2V0EhgKB3'
    'Nlc3Npb24YASABKAlSB3Nlc3Npb24aLAoQVXBsb2FkVHJhbnNjcmlwdBIYCgdzZXNzaW9uGAEg'
    'ASgJUgdzZXNzaW9uGl0KEFNuYXBzaG90Q29kZWJhc2USLwoIY29kZWJhc2UYASABKAsyEy50ZX'
    'RoZXIudjEuQ29kZWJhc2VSCGNvZGViYXNlEhgKB3Nlc3Npb24YAiABKAlSB3Nlc3Npb24aJQoN'
    'U2NhbkNvZGViYXNlcxIUCgVyb290cxgBIAMoCVIFcm9vdHMaKQoNQ2FwdHVyZVNjcmVlbhIYCg'
    'dzZXNzaW9uGAEgASgJUgdzZXNzaW9uGpcBCg5CYWNrdXBTZXNzaW9ucxJKCgZzdG9yZWQYASAD'
    'KAsyMi50ZXRoZXIudjEuQWdlbnRDb21tYW5kLkJhY2t1cFNlc3Npb25zLlN0b3JlZEVudHJ5Ug'
    'ZzdG9yZWQaOQoLU3RvcmVkRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKANS'
    'BXZhbHVlOgI4ARpuCg9GZXRjaEF0dGFjaG1lbnQSGAoHc2Vzc2lvbhgBIAEoCVIHc2Vzc2lvbh'
    'IQCgNjd2QYAiABKAlSA2N3ZBIvCghhcnRpZmFjdBgDIAEoCzITLnRldGhlci52MS5BcnRpZmFj'
    'dFIIYXJ0aWZhY3RCBAoCb3A=');

@$core.Deprecated('Use codebaseDescriptor instead')
const Codebase$json = {
  '1': 'Codebase',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'node', '3': 2, '4': 1, '5': 9, '10': 'node'},
    {'1': 'path', '3': 3, '4': 1, '5': 9, '10': 'path'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'git_remote', '3': 5, '4': 1, '5': 9, '10': 'gitRemote'},
    {'1': 'git_branch', '3': 6, '4': 1, '5': 9, '10': 'gitBranch'},
    {'1': 'git_head', '3': 7, '4': 1, '5': 9, '10': 'gitHead'},
    {'1': 'created_ms', '3': 8, '4': 1, '5': 3, '10': 'createdMs'},
    {'1': 'snapshot', '3': 9, '4': 1, '5': 9, '10': 'snapshot'},
    {'1': 'snapshot_ms', '3': 10, '4': 1, '5': 3, '10': 'snapshotMs'},
    {'1': 'files', '3': 11, '4': 1, '5': 5, '10': 'files'},
    {'1': 'bytes', '3': 12, '4': 1, '5': 3, '10': 'bytes'},
    {
      '1': 'env',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.EnvFile',
      '10': 'env'
    },
    {'1': 'error', '3': 14, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `Codebase`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List codebaseDescriptor = $convert.base64Decode(
    'CghDb2RlYmFzZRIOCgJpZBgBIAEoCVICaWQSEgoEbm9kZRgCIAEoCVIEbm9kZRISCgRwYXRoGA'
    'MgASgJUgRwYXRoEhIKBG5hbWUYBCABKAlSBG5hbWUSHQoKZ2l0X3JlbW90ZRgFIAEoCVIJZ2l0'
    'UmVtb3RlEh0KCmdpdF9icmFuY2gYBiABKAlSCWdpdEJyYW5jaBIZCghnaXRfaGVhZBgHIAEoCV'
    'IHZ2l0SGVhZBIdCgpjcmVhdGVkX21zGAggASgDUgljcmVhdGVkTXMSGgoIc25hcHNob3QYCSAB'
    'KAlSCHNuYXBzaG90Eh8KC3NuYXBzaG90X21zGAogASgDUgpzbmFwc2hvdE1zEhQKBWZpbGVzGA'
    'sgASgFUgVmaWxlcxIUCgVieXRlcxgMIAEoA1IFYnl0ZXMSJAoDZW52GA0gAygLMhIudGV0aGVy'
    'LnYxLkVudkZpbGVSA2VudhIUCgVlcnJvchgOIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use codebaseListDescriptor instead')
const CodebaseList$json = {
  '1': 'CodebaseList',
  '2': [
    {
      '1': 'codebases',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Codebase',
      '10': 'codebases'
    },
  ],
};

/// Descriptor for `CodebaseList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List codebaseListDescriptor = $convert.base64Decode(
    'CgxDb2RlYmFzZUxpc3QSMQoJY29kZWJhc2VzGAEgAygLMhMudGV0aGVyLnYxLkNvZGViYXNlUg'
    'ljb2RlYmFzZXM=');

@$core.Deprecated('Use snapshotFileDescriptor instead')
const SnapshotFile$json = {
  '1': 'SnapshotFile',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'sha256', '3': 2, '4': 1, '5': 9, '10': 'sha256'},
    {'1': 'size', '3': 3, '4': 1, '5': 3, '10': 'size'},
    {'1': 'executable', '3': 4, '4': 1, '5': 8, '10': 'executable'},
  ],
};

/// Descriptor for `SnapshotFile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotFileDescriptor = $convert.base64Decode(
    'CgxTbmFwc2hvdEZpbGUSEgoEcGF0aBgBIAEoCVIEcGF0aBIWCgZzaGEyNTYYAiABKAlSBnNoYT'
    'I1NhISCgRzaXplGAMgASgDUgRzaXplEh4KCmV4ZWN1dGFibGUYBCABKAhSCmV4ZWN1dGFibGU=');

@$core.Deprecated('Use snapshotManifestDescriptor instead')
const SnapshotManifest$json = {
  '1': 'SnapshotManifest',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {
      '1': 'files',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.SnapshotFile',
      '10': 'files'
    },
    {'1': 'skipped', '3': 3, '4': 3, '5': 9, '10': 'skipped'},
    {'1': 'git_remote', '3': 4, '4': 1, '5': 9, '10': 'gitRemote'},
    {'1': 'git_branch', '3': 5, '4': 1, '5': 9, '10': 'gitBranch'},
    {'1': 'git_head', '3': 6, '4': 1, '5': 9, '10': 'gitHead'},
  ],
};

/// Descriptor for `SnapshotManifest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotManifestDescriptor = $convert.base64Decode(
    'ChBTbmFwc2hvdE1hbmlmZXN0EhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24SLQoFZmlsZXMYAi'
    'ADKAsyFy50ZXRoZXIudjEuU25hcHNob3RGaWxlUgVmaWxlcxIYCgdza2lwcGVkGAMgAygJUgdz'
    'a2lwcGVkEh0KCmdpdF9yZW1vdGUYBCABKAlSCWdpdFJlbW90ZRIdCgpnaXRfYnJhbmNoGAUgAS'
    'gJUglnaXRCcmFuY2gSGQoIZ2l0X2hlYWQYBiABKAlSB2dpdEhlYWQ=');

@$core.Deprecated('Use missingBlobsDescriptor instead')
const MissingBlobs$json = {
  '1': 'MissingBlobs',
  '2': [
    {'1': 'sha256', '3': 1, '4': 3, '5': 9, '10': 'sha256'},
  ],
};

/// Descriptor for `MissingBlobs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List missingBlobsDescriptor = $convert
    .base64Decode('CgxNaXNzaW5nQmxvYnMSFgoGc2hhMjU2GAEgAygJUgZzaGEyNTY=');

@$core.Deprecated('Use snapshotDescriptor instead')
const Snapshot$json = {
  '1': 'Snapshot',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'codebase', '3': 2, '4': 1, '5': 9, '10': 'codebase'},
    {'1': 'session', '3': 3, '4': 1, '5': 9, '10': 'session'},
    {'1': 'parent', '3': 4, '4': 1, '5': 9, '10': 'parent'},
    {'1': 'created_ms', '3': 5, '4': 1, '5': 3, '10': 'createdMs'},
    {'1': 'files', '3': 6, '4': 1, '5': 5, '10': 'files'},
    {'1': 'bytes', '3': 7, '4': 1, '5': 3, '10': 'bytes'},
    {'1': 'git_head', '3': 8, '4': 1, '5': 9, '10': 'gitHead'},
    {'1': 'skipped', '3': 9, '4': 1, '5': 5, '10': 'skipped'},
    {'1': 'manifest_sha256', '3': 10, '4': 1, '5': 9, '10': 'manifestSha256'},
  ],
};

/// Descriptor for `Snapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotDescriptor = $convert.base64Decode(
    'CghTbmFwc2hvdBIOCgJpZBgBIAEoCVICaWQSGgoIY29kZWJhc2UYAiABKAlSCGNvZGViYXNlEh'
    'gKB3Nlc3Npb24YAyABKAlSB3Nlc3Npb24SFgoGcGFyZW50GAQgASgJUgZwYXJlbnQSHQoKY3Jl'
    'YXRlZF9tcxgFIAEoA1IJY3JlYXRlZE1zEhQKBWZpbGVzGAYgASgFUgVmaWxlcxIUCgVieXRlcx'
    'gHIAEoA1IFYnl0ZXMSGQoIZ2l0X2hlYWQYCCABKAlSB2dpdEhlYWQSGAoHc2tpcHBlZBgJIAEo'
    'BVIHc2tpcHBlZBInCg9tYW5pZmVzdF9zaGEyNTYYCiABKAlSDm1hbmlmZXN0U2hhMjU2');

@$core.Deprecated('Use snapshotListDescriptor instead')
const SnapshotList$json = {
  '1': 'SnapshotList',
  '2': [
    {
      '1': 'snapshots',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Snapshot',
      '10': 'snapshots'
    },
  ],
};

/// Descriptor for `SnapshotList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotListDescriptor = $convert.base64Decode(
    'CgxTbmFwc2hvdExpc3QSMQoJc25hcHNob3RzGAEgAygLMhMudGV0aGVyLnYxLlNuYXBzaG90Ug'
    'lzbmFwc2hvdHM=');

@$core.Deprecated('Use envKeyDescriptor instead')
const EnvKey$json = {
  '1': 'EnvKey',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'fingerprint', '3': 2, '4': 1, '5': 9, '10': 'fingerprint'},
  ],
};

/// Descriptor for `EnvKey`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List envKeyDescriptor = $convert.base64Decode(
    'CgZFbnZLZXkSEgoEbmFtZRgBIAEoCVIEbmFtZRIgCgtmaW5nZXJwcmludBgCIAEoCVILZmluZ2'
    'VycHJpbnQ=');

@$core.Deprecated('Use envFileDescriptor instead')
const EnvFile$json = {
  '1': 'EnvFile',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {
      '1': 'keys',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.EnvKey',
      '10': 'keys'
    },
    {'1': 'updated_ms', '3': 3, '4': 1, '5': 3, '10': 'updatedMs'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
  ],
};

/// Descriptor for `EnvFile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List envFileDescriptor = $convert.base64Decode(
    'CgdFbnZGaWxlEhIKBHBhdGgYASABKAlSBHBhdGgSJQoEa2V5cxgCIAMoCzIRLnRldGhlci52MS'
    '5FbnZLZXlSBGtleXMSHQoKdXBkYXRlZF9tcxgDIAEoA1IJdXBkYXRlZE1zEhgKB2NvbnRlbnQY'
    'BCABKAlSB2NvbnRlbnQ=');

@$core.Deprecated('Use envFilesDescriptor instead')
const EnvFiles$json = {
  '1': 'EnvFiles',
  '2': [
    {
      '1': 'files',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.EnvFile',
      '10': 'files'
    },
  ],
};

/// Descriptor for `EnvFiles`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List envFilesDescriptor = $convert.base64Decode(
    'CghFbnZGaWxlcxIoCgVmaWxlcxgBIAMoCzISLnRldGhlci52MS5FbnZGaWxlUgVmaWxlcw==');

@$core.Deprecated('Use foundCodebasesDescriptor instead')
const FoundCodebases$json = {
  '1': 'FoundCodebases',
  '2': [
    {'1': 'node', '3': 1, '4': 1, '5': 9, '10': 'node'},
    {
      '1': 'codebases',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Codebase',
      '10': 'codebases'
    },
  ],
};

/// Descriptor for `FoundCodebases`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List foundCodebasesDescriptor = $convert.base64Decode(
    'Cg5Gb3VuZENvZGViYXNlcxISCgRub2RlGAEgASgJUgRub2RlEjEKCWNvZGViYXNlcxgCIAMoCz'
    'ITLnRldGhlci52MS5Db2RlYmFzZVIJY29kZWJhc2Vz');

@$core.Deprecated('Use deviceDescriptor instead')
const Device$json = {
  '1': 'Device',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'platform', '3': 4, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'created_ms', '3': 5, '4': 1, '5': 3, '10': 'createdMs'},
    {'1': 'last_seen_ms', '3': 6, '4': 1, '5': 3, '10': 'lastSeenMs'},
  ],
};

/// Descriptor for `Device`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceDescriptor = $convert.base64Decode(
    'CgZEZXZpY2USDgoCaWQYASABKAlSAmlkEhIKBGtpbmQYAiABKAlSBGtpbmQSEgoEbmFtZRgDIA'
    'EoCVIEbmFtZRIaCghwbGF0Zm9ybRgEIAEoCVIIcGxhdGZvcm0SHQoKY3JlYXRlZF9tcxgFIAEo'
    'A1IJY3JlYXRlZE1zEiAKDGxhc3Rfc2Vlbl9tcxgGIAEoA1IKbGFzdFNlZW5Ncw==');

@$core.Deprecated('Use deviceListDescriptor instead')
const DeviceList$json = {
  '1': 'DeviceList',
  '2': [
    {
      '1': 'devices',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Device',
      '10': 'devices'
    },
  ],
};

/// Descriptor for `DeviceList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceListDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VMaXN0EisKB2RldmljZXMYASADKAsyES50ZXRoZXIudjEuRGV2aWNlUgdkZXZpY2'
    'Vz');

@$core.Deprecated('Use pairingCodeDescriptor instead')
const PairingCode$json = {
  '1': 'PairingCode',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'expires_ms', '3': 2, '4': 1, '5': 3, '10': 'expiresMs'},
    {'1': 'cert_fingerprint', '3': 3, '4': 1, '5': 9, '10': 'certFingerprint'},
  ],
};

/// Descriptor for `PairingCode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairingCodeDescriptor = $convert.base64Decode(
    'CgtQYWlyaW5nQ29kZRISCgRjb2RlGAEgASgJUgRjb2RlEh0KCmV4cGlyZXNfbXMYAiABKANSCW'
    'V4cGlyZXNNcxIpChBjZXJ0X2ZpbmdlcnByaW50GAMgASgJUg9jZXJ0RmluZ2VycHJpbnQ=');

@$core.Deprecated('Use pairRequestDescriptor instead')
const PairRequest$json = {
  '1': 'PairRequest',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'platform', '3': 4, '4': 1, '5': 9, '10': 'platform'},
  ],
};

/// Descriptor for `PairRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairRequestDescriptor = $convert.base64Decode(
    'CgtQYWlyUmVxdWVzdBISCgRjb2RlGAEgASgJUgRjb2RlEhIKBGtpbmQYAiABKAlSBGtpbmQSEg'
    'oEbmFtZRgDIAEoCVIEbmFtZRIaCghwbGF0Zm9ybRgEIAEoCVIIcGxhdGZvcm0=');

@$core.Deprecated('Use pairResultDescriptor instead')
const PairResult$json = {
  '1': 'PairResult',
  '2': [
    {
      '1': 'device',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Device',
      '10': 'device'
    },
    {'1': 'token', '3': 2, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `PairResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairResultDescriptor = $convert.base64Decode(
    'CgpQYWlyUmVzdWx0EikKBmRldmljZRgBIAEoCzIRLnRldGhlci52MS5EZXZpY2VSBmRldmljZR'
    'IUCgV0b2tlbhgCIAEoCVIFdG9rZW4=');

@$core.Deprecated('Use preferencesDescriptor instead')
const Preferences$json = {
  '1': 'Preferences',
  '2': [
    {'1': 'theme_mode', '3': 1, '4': 1, '5': 9, '10': 'themeMode'},
    {'1': 'palette', '3': 2, '4': 1, '5': 9, '10': 'palette'},
    {
      '1': 'accent',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'accent',
      '17': true
    },
  ],
  '8': [
    {'1': '_accent'},
  ],
};

/// Descriptor for `Preferences`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List preferencesDescriptor = $convert.base64Decode(
    'CgtQcmVmZXJlbmNlcxIdCgp0aGVtZV9tb2RlGAEgASgJUgl0aGVtZU1vZGUSGAoHcGFsZXR0ZR'
    'gCIAEoCVIHcGFsZXR0ZRIbCgZhY2NlbnQYAyABKA1IAFIGYWNjZW50iAEBQgkKB19hY2NlbnQ=');

@$core.Deprecated('Use tailnetDeviceDescriptor instead')
const TailnetDevice$json = {
  '1': 'TailnetDevice',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'hostname', '3': 2, '4': 1, '5': 9, '10': 'hostname'},
    {'1': 'os', '3': 3, '4': 1, '5': 9, '10': 'os'},
    {'1': 'online', '3': 4, '4': 1, '5': 8, '10': 'online'},
    {'1': 'ips', '3': 5, '4': 3, '5': 9, '10': 'ips'},
    {'1': 'self', '3': 6, '4': 1, '5': 8, '10': 'self'},
    {'1': 'node', '3': 7, '4': 1, '5': 9, '10': 'node'},
    {'1': 'clients', '3': 8, '4': 3, '5': 9, '10': 'clients'},
    {'1': 'last_seen_ms', '3': 9, '4': 1, '5': 3, '10': 'lastSeenMs'},
  ],
};

/// Descriptor for `TailnetDevice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tailnetDeviceDescriptor = $convert.base64Decode(
    'Cg1UYWlsbmV0RGV2aWNlEhIKBG5hbWUYASABKAlSBG5hbWUSGgoIaG9zdG5hbWUYAiABKAlSCG'
    'hvc3RuYW1lEg4KAm9zGAMgASgJUgJvcxIWCgZvbmxpbmUYBCABKAhSBm9ubGluZRIQCgNpcHMY'
    'BSADKAlSA2lwcxISCgRzZWxmGAYgASgIUgRzZWxmEhIKBG5vZGUYByABKAlSBG5vZGUSGAoHY2'
    'xpZW50cxgIIAMoCVIHY2xpZW50cxIgCgxsYXN0X3NlZW5fbXMYCSABKANSCmxhc3RTZWVuTXM=');

@$core.Deprecated('Use tailnetDescriptor instead')
const Tailnet$json = {
  '1': 'Tailnet',
  '2': [
    {
      '1': 'devices',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.TailnetDevice',
      '10': 'devices'
    },
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `Tailnet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tailnetDescriptor = $convert.base64Decode(
    'CgdUYWlsbmV0EjIKB2RldmljZXMYASADKAsyGC50ZXRoZXIudjEuVGFpbG5ldERldmljZVIHZG'
    'V2aWNlcxIUCgVlcnJvchgCIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use lineageEventDescriptor instead')
const LineageEvent$json = {
  '1': 'LineageEvent',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'session', '3': 2, '4': 1, '5': 9, '10': 'session'},
    {'1': 'parent', '3': 3, '4': 1, '5': 9, '10': 'parent'},
    {'1': 'kind', '3': 4, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'fork_point', '3': 5, '4': 1, '5': 9, '10': 'forkPoint'},
    {'1': 'by', '3': 6, '4': 1, '5': 9, '10': 'by'},
    {'1': 'at_ms', '3': 7, '4': 1, '5': 3, '10': 'atMs'},
    {'1': 'detail', '3': 8, '4': 1, '5': 9, '10': 'detail'},
  ],
};

/// Descriptor for `LineageEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lineageEventDescriptor = $convert.base64Decode(
    'CgxMaW5lYWdlRXZlbnQSDgoCaWQYASABKANSAmlkEhgKB3Nlc3Npb24YAiABKAlSB3Nlc3Npb2'
    '4SFgoGcGFyZW50GAMgASgJUgZwYXJlbnQSEgoEa2luZBgEIAEoCVIEa2luZBIdCgpmb3JrX3Bv'
    'aW50GAUgASgJUglmb3JrUG9pbnQSDgoCYnkYBiABKAlSAmJ5EhMKBWF0X21zGAcgASgDUgRhdE'
    '1zEhYKBmRldGFpbBgIIAEoCVIGZGV0YWls');

@$core.Deprecated('Use lineageEventsDescriptor instead')
const LineageEvents$json = {
  '1': 'LineageEvents',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.LineageEvent',
      '10': 'events'
    },
  ],
};

/// Descriptor for `LineageEvents`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lineageEventsDescriptor = $convert.base64Decode(
    'Cg1MaW5lYWdlRXZlbnRzEi8KBmV2ZW50cxgBIAMoCzIXLnRldGhlci52MS5MaW5lYWdlRXZlbn'
    'RSBmV2ZW50cw==');

@$core.Deprecated('Use usageEntryDescriptor instead')
const UsageEntry$json = {
  '1': 'UsageEntry',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'model', '3': 3, '4': 1, '5': 9, '10': 'model'},
    {'1': 'ts_ms', '3': 4, '4': 1, '5': 3, '10': 'tsMs'},
    {'1': 'input', '3': 5, '4': 1, '5': 3, '10': 'input'},
    {'1': 'output', '3': 6, '4': 1, '5': 3, '10': 'output'},
    {'1': 'cache_write', '3': 7, '4': 1, '5': 3, '10': 'cacheWrite'},
    {'1': 'cache_read', '3': 8, '4': 1, '5': 3, '10': 'cacheRead'},
  ],
};

/// Descriptor for `UsageEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List usageEntryDescriptor = $convert.base64Decode(
    'CgpVc2FnZUVudHJ5EhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24SHQoKbWVzc2FnZV9pZBgCIA'
    'EoCVIJbWVzc2FnZUlkEhQKBW1vZGVsGAMgASgJUgVtb2RlbBITCgV0c19tcxgEIAEoA1IEdHNN'
    'cxIUCgVpbnB1dBgFIAEoA1IFaW5wdXQSFgoGb3V0cHV0GAYgASgDUgZvdXRwdXQSHwoLY2FjaG'
    'Vfd3JpdGUYByABKANSCmNhY2hlV3JpdGUSHQoKY2FjaGVfcmVhZBgIIAEoA1IJY2FjaGVSZWFk');

@$core.Deprecated('Use usageReportDescriptor instead')
const UsageReport$json = {
  '1': 'UsageReport',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.UsageEntry',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `UsageReport`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List usageReportDescriptor = $convert.base64Decode(
    'CgtVc2FnZVJlcG9ydBIvCgdlbnRyaWVzGAEgAygLMhUudGV0aGVyLnYxLlVzYWdlRW50cnlSB2'
    'VudHJpZXM=');

@$core.Deprecated('Use usageTotalsDescriptor instead')
const UsageTotals$json = {
  '1': 'UsageTotals',
  '2': [
    {'1': 'input', '3': 1, '4': 1, '5': 3, '10': 'input'},
    {'1': 'output', '3': 2, '4': 1, '5': 3, '10': 'output'},
    {'1': 'cache_write', '3': 3, '4': 1, '5': 3, '10': 'cacheWrite'},
    {'1': 'cache_read', '3': 4, '4': 1, '5': 3, '10': 'cacheRead'},
    {'1': 'messages', '3': 5, '4': 1, '5': 3, '10': 'messages'},
  ],
};

/// Descriptor for `UsageTotals`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List usageTotalsDescriptor = $convert.base64Decode(
    'CgtVc2FnZVRvdGFscxIUCgVpbnB1dBgBIAEoA1IFaW5wdXQSFgoGb3V0cHV0GAIgASgDUgZvdX'
    'RwdXQSHwoLY2FjaGVfd3JpdGUYAyABKANSCmNhY2hlV3JpdGUSHQoKY2FjaGVfcmVhZBgEIAEo'
    'A1IJY2FjaGVSZWFkEhoKCG1lc3NhZ2VzGAUgASgDUghtZXNzYWdlcw==');

@$core.Deprecated('Use nodeUsageDescriptor instead')
const NodeUsage$json = {
  '1': 'NodeUsage',
  '2': [
    {'1': 'node', '3': 1, '4': 1, '5': 9, '10': 'node'},
    {
      '1': 'window',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UsageTotals',
      '10': 'window'
    },
    {
      '1': 'today',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UsageTotals',
      '10': 'today'
    },
    {
      '1': 'week',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UsageTotals',
      '10': 'week'
    },
    {
      '1': 'plan',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.PlanUsage',
      '10': 'plan'
    },
  ],
  '9': [
    {'1': 5, '2': 6},
  ],
};

/// Descriptor for `NodeUsage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeUsageDescriptor = $convert.base64Decode(
    'CglOb2RlVXNhZ2USEgoEbm9kZRgBIAEoCVIEbm9kZRIuCgZ3aW5kb3cYAiABKAsyFi50ZXRoZX'
    'IudjEuVXNhZ2VUb3RhbHNSBndpbmRvdxIsCgV0b2RheRgDIAEoCzIWLnRldGhlci52MS5Vc2Fn'
    'ZVRvdGFsc1IFdG9kYXkSKgoEd2VlaxgEIAEoCzIWLnRldGhlci52MS5Vc2FnZVRvdGFsc1IEd2'
    'VlaxIoCgRwbGFuGAYgASgLMhQudGV0aGVyLnYxLlBsYW5Vc2FnZVIEcGxhbkoECAUQBg==');

@$core.Deprecated('Use planLimitDescriptor instead')
const PlanLimit$json = {
  '1': 'PlanLimit',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'percent', '3': 2, '4': 1, '5': 5, '10': 'percent'},
    {'1': 'resets', '3': 3, '4': 1, '5': 9, '10': 'resets'},
  ],
};

/// Descriptor for `PlanLimit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planLimitDescriptor = $convert.base64Decode(
    'CglQbGFuTGltaXQSFAoFbGFiZWwYASABKAlSBWxhYmVsEhgKB3BlcmNlbnQYAiABKAVSB3Blcm'
    'NlbnQSFgoGcmVzZXRzGAMgASgJUgZyZXNldHM=');

@$core.Deprecated('Use planUsageDescriptor instead')
const PlanUsage$json = {
  '1': 'PlanUsage',
  '2': [
    {'1': 'node', '3': 1, '4': 1, '5': 9, '10': 'node'},
    {
      '1': 'limits',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.PlanLimit',
      '10': 'limits'
    },
    {'1': 'raw', '3': 3, '4': 1, '5': 9, '10': 'raw'},
    {'1': 'checked_ms', '3': 4, '4': 1, '5': 3, '10': 'checkedMs'},
    {'1': 'error', '3': 5, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `PlanUsage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planUsageDescriptor = $convert.base64Decode(
    'CglQbGFuVXNhZ2USEgoEbm9kZRgBIAEoCVIEbm9kZRIsCgZsaW1pdHMYAiADKAsyFC50ZXRoZX'
    'IudjEuUGxhbkxpbWl0UgZsaW1pdHMSEAoDcmF3GAMgASgJUgNyYXcSHQoKY2hlY2tlZF9tcxgE'
    'IAEoA1IJY2hlY2tlZE1zEhQKBWVycm9yGAUgASgJUgVlcnJvcg==');

@$core.Deprecated('Use sessionUsageDescriptor instead')
const SessionUsage$json = {
  '1': 'SessionUsage',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {
      '1': 'total',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UsageTotals',
      '10': 'total'
    },
    {'1': 'last_ms', '3': 3, '4': 1, '5': 3, '10': 'lastMs'},
  ],
};

/// Descriptor for `SessionUsage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionUsageDescriptor = $convert.base64Decode(
    'CgxTZXNzaW9uVXNhZ2USGAoHc2Vzc2lvbhgBIAEoCVIHc2Vzc2lvbhIsCgV0b3RhbBgCIAEoCz'
    'IWLnRldGhlci52MS5Vc2FnZVRvdGFsc1IFdG90YWwSFwoHbGFzdF9tcxgDIAEoA1IGbGFzdE1z');

@$core.Deprecated('Use usageSummaryDescriptor instead')
const UsageSummary$json = {
  '1': 'UsageSummary',
  '2': [
    {
      '1': 'nodes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.NodeUsage',
      '10': 'nodes'
    },
    {
      '1': 'sessions',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.SessionUsage',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `UsageSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List usageSummaryDescriptor = $convert.base64Decode(
    'CgxVc2FnZVN1bW1hcnkSKgoFbm9kZXMYASADKAsyFC50ZXRoZXIudjEuTm9kZVVzYWdlUgVub2'
    'RlcxIzCghzZXNzaW9ucxgCIAMoCzIXLnRldGhlci52MS5TZXNzaW9uVXNhZ2VSCHNlc3Npb25z');

@$core.Deprecated('Use workspaceRootDescriptor instead')
const WorkspaceRoot$json = {
  '1': 'WorkspaceRoot',
  '2': [
    {'1': 'node', '3': 1, '4': 1, '5': 9, '10': 'node'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `WorkspaceRoot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workspaceRootDescriptor = $convert.base64Decode(
    'Cg1Xb3Jrc3BhY2VSb290EhIKBG5vZGUYASABKAlSBG5vZGUSEgoEcGF0aBgCIAEoCVIEcGF0aA'
    '==');

@$core.Deprecated('Use workspacesDescriptor instead')
const Workspaces$json = {
  '1': 'Workspaces',
  '2': [
    {
      '1': 'roots',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.WorkspaceRoot',
      '10': 'roots'
    },
  ],
};

/// Descriptor for `Workspaces`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workspacesDescriptor = $convert.base64Decode(
    'CgpXb3Jrc3BhY2VzEi4KBXJvb3RzGAEgAygLMhgudGV0aGVyLnYxLldvcmtzcGFjZVJvb3RSBX'
    'Jvb3Rz');

@$core.Deprecated('Use artifactDescriptor instead')
const Artifact$json = {
  '1': 'Artifact',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'sha256', '3': 2, '4': 1, '5': 9, '10': 'sha256'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'mime', '3': 4, '4': 1, '5': 9, '10': 'mime'},
    {'1': 'size', '3': 5, '4': 1, '5': 3, '10': 'size'},
    {'1': 'session', '3': 6, '4': 1, '5': 9, '10': 'session'},
    {'1': 'node', '3': 7, '4': 1, '5': 9, '10': 'node'},
    {'1': 'origin', '3': 8, '4': 1, '5': 9, '10': 'origin'},
    {'1': 'path', '3': 9, '4': 1, '5': 9, '10': 'path'},
    {'1': 'tool_use_id', '3': 10, '4': 1, '5': 9, '10': 'toolUseId'},
    {'1': 'created_ms', '3': 11, '4': 1, '5': 3, '10': 'createdMs'},
    {'1': 'note', '3': 12, '4': 1, '5': 9, '10': 'note'},
  ],
};

/// Descriptor for `Artifact`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List artifactDescriptor = $convert.base64Decode(
    'CghBcnRpZmFjdBIOCgJpZBgBIAEoCVICaWQSFgoGc2hhMjU2GAIgASgJUgZzaGEyNTYSEgoEbm'
    'FtZRgDIAEoCVIEbmFtZRISCgRtaW1lGAQgASgJUgRtaW1lEhIKBHNpemUYBSABKANSBHNpemUS'
    'GAoHc2Vzc2lvbhgGIAEoCVIHc2Vzc2lvbhISCgRub2RlGAcgASgJUgRub2RlEhYKBm9yaWdpbh'
    'gIIAEoCVIGb3JpZ2luEhIKBHBhdGgYCSABKAlSBHBhdGgSHgoLdG9vbF91c2VfaWQYCiABKAlS'
    'CXRvb2xVc2VJZBIdCgpjcmVhdGVkX21zGAsgASgDUgljcmVhdGVkTXMSEgoEbm90ZRgMIAEoCV'
    'IEbm90ZQ==');

@$core.Deprecated('Use sendKeysDescriptor instead')
const SendKeys$json = {
  '1': 'SendKeys',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'keys', '3': 2, '4': 3, '5': 9, '10': 'keys'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `SendKeys`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendKeysDescriptor = $convert.base64Decode(
    'CghTZW5kS2V5cxIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEhIKBGtleXMYAiADKAlSBGtleX'
    'MSEgoEdGV4dBgDIAEoCVIEdGV4dA==');

@$core.Deprecated('Use setPermissionModeDescriptor instead')
const SetPermissionMode$json = {
  '1': 'SetPermissionMode',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'mode', '3': 2, '4': 1, '5': 9, '10': 'mode'},
    {'1': 'revert_after_ms', '3': 3, '4': 1, '5': 3, '10': 'revertAfterMs'},
  ],
};

/// Descriptor for `SetPermissionMode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPermissionModeDescriptor = $convert.base64Decode(
    'ChFTZXRQZXJtaXNzaW9uTW9kZRIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEhIKBG1vZGUYAi'
    'ABKAlSBG1vZGUSJgoPcmV2ZXJ0X2FmdGVyX21zGAMgASgDUg1yZXZlcnRBZnRlck1z');

@$core.Deprecated('Use commandResultDescriptor instead')
const CommandResult$json = {
  '1': 'CommandResult',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'command', '3': 2, '4': 1, '5': 9, '10': 'command'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `CommandResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandResultDescriptor = $convert.base64Decode(
    'Cg1Db21tYW5kUmVzdWx0EhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24SGAoHY29tbWFuZBgCIA'
    'EoCVIHY29tbWFuZBIUCgVlcnJvchgDIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use modeResultDescriptor instead')
const ModeResult$json = {
  '1': 'ModeResult',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'mode', '3': 2, '4': 1, '5': 9, '10': 'mode'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `ModeResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modeResultDescriptor = $convert.base64Decode(
    'CgpNb2RlUmVzdWx0EhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24SEgoEbW9kZRgCIAEoCVIEbW'
    '9kZRIUCgVlcnJvchgDIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use screenSnapshotDescriptor instead')
const ScreenSnapshot$json = {
  '1': 'ScreenSnapshot',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'captured_ms', '3': 3, '4': 1, '5': 3, '10': 'capturedMs'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `ScreenSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List screenSnapshotDescriptor = $convert.base64Decode(
    'Cg5TY3JlZW5TbmFwc2hvdBIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEhIKBHRleHQYAiABKA'
    'lSBHRleHQSHwoLY2FwdHVyZWRfbXMYAyABKANSCmNhcHR1cmVkTXMSFAoFZXJyb3IYBCABKAlS'
    'BWVycm9y');

@$core.Deprecated('Use artifactListDescriptor instead')
const ArtifactList$json = {
  '1': 'ArtifactList',
  '2': [
    {
      '1': 'artifacts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Artifact',
      '10': 'artifacts'
    },
  ],
};

/// Descriptor for `ArtifactList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List artifactListDescriptor = $convert.base64Decode(
    'CgxBcnRpZmFjdExpc3QSMQoJYXJ0aWZhY3RzGAEgAygLMhMudGV0aGVyLnYxLkFydGlmYWN0Ug'
    'lhcnRpZmFjdHM=');

@$core.Deprecated('Use uploadDescriptor instead')
const Upload$json = {
  '1': 'Upload',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'offset', '3': 2, '4': 1, '5': 3, '10': 'offset'},
    {'1': 'size', '3': 3, '4': 1, '5': 3, '10': 'size'},
    {
      '1': 'artifact',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Artifact',
      '10': 'artifact'
    },
  ],
};

/// Descriptor for `Upload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadDescriptor = $convert.base64Decode(
    'CgZVcGxvYWQSDgoCaWQYASABKAlSAmlkEhYKBm9mZnNldBgCIAEoA1IGb2Zmc2V0EhIKBHNpem'
    'UYAyABKANSBHNpemUSLwoIYXJ0aWZhY3QYBCABKAsyEy50ZXRoZXIudjEuQXJ0aWZhY3RSCGFy'
    'dGlmYWN0');

@$core.Deprecated('Use artifactLinkDescriptor instead')
const ArtifactLink$json = {
  '1': 'ArtifactLink',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'expires_ms', '3': 2, '4': 1, '5': 3, '10': 'expiresMs'},
  ],
};

/// Descriptor for `ArtifactLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List artifactLinkDescriptor = $convert.base64Decode(
    'CgxBcnRpZmFjdExpbmsSEAoDdXJsGAEgASgJUgN1cmwSHQoKZXhwaXJlc19tcxgCIAEoA1IJZX'
    'hwaXJlc01z');

@$core.Deprecated('Use pageDescriptor instead')
const Page$json = {
  '1': 'Page',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'files', '3': 3, '4': 1, '5': 5, '10': 'files'},
    {'1': 'size', '3': 4, '4': 1, '5': 3, '10': 'size'},
    {'1': 'updated_ms', '3': 5, '4': 1, '5': 3, '10': 'updatedMs'},
    {'1': 'url', '3': 6, '4': 1, '5': 9, '10': 'url'},
    {'1': 'expires_ms', '3': 7, '4': 1, '5': 3, '10': 'expiresMs'},
  ],
};

/// Descriptor for `Page`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageDescriptor = $convert.base64Decode(
    'CgRQYWdlEhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24SEgoEbmFtZRgCIAEoCVIEbmFtZRIUCg'
    'VmaWxlcxgDIAEoBVIFZmlsZXMSEgoEc2l6ZRgEIAEoA1IEc2l6ZRIdCgp1cGRhdGVkX21zGAUg'
    'ASgDUgl1cGRhdGVkTXMSEAoDdXJsGAYgASgJUgN1cmwSHQoKZXhwaXJlc19tcxgHIAEoA1IJZX'
    'hwaXJlc01z');

@$core.Deprecated('Use pageListDescriptor instead')
const PageList$json = {
  '1': 'PageList',
  '2': [
    {
      '1': 'pages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Page',
      '10': 'pages'
    },
  ],
};

/// Descriptor for `PageList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageListDescriptor = $convert.base64Decode(
    'CghQYWdlTGlzdBIlCgVwYWdlcxgBIAMoCzIPLnRldGhlci52MS5QYWdlUgVwYWdlcw==');

@$core.Deprecated('Use chatDescriptor instead')
const Chat$json = {
  '1': 'Chat',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'title_by_user', '3': 3, '4': 1, '5': 8, '10': 'titleByUser'},
    {'1': 'created_ms', '3': 4, '4': 1, '5': 3, '10': 'createdMs'},
    {'1': 'updated_ms', '3': 5, '4': 1, '5': 3, '10': 'updatedMs'},
    {'1': 'archived', '3': 6, '4': 1, '5': 8, '10': 'archived'},
    {
      '1': 'target',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ChatTarget',
      '10': 'target'
    },
    {'1': 'active_session', '3': 8, '4': 1, '5': 9, '10': 'activeSession'},
    {
      '1': 'sessions',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.ChatLink',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `Chat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatDescriptor = $convert.base64Decode(
    'CgRDaGF0Eg4KAmlkGAEgASgJUgJpZBIUCgV0aXRsZRgCIAEoCVIFdGl0bGUSIgoNdGl0bGVfYn'
    'lfdXNlchgDIAEoCFILdGl0bGVCeVVzZXISHQoKY3JlYXRlZF9tcxgEIAEoA1IJY3JlYXRlZE1z'
    'Eh0KCnVwZGF0ZWRfbXMYBSABKANSCXVwZGF0ZWRNcxIaCghhcmNoaXZlZBgGIAEoCFIIYXJjaG'
    'l2ZWQSLQoGdGFyZ2V0GAcgASgLMhUudGV0aGVyLnYxLkNoYXRUYXJnZXRSBnRhcmdldBIlCg5h'
    'Y3RpdmVfc2Vzc2lvbhgIIAEoCVINYWN0aXZlU2Vzc2lvbhIvCghzZXNzaW9ucxgJIAMoCzITLn'
    'RldGhlci52MS5DaGF0TGlua1IIc2Vzc2lvbnM=');

@$core.Deprecated('Use chatTargetDescriptor instead')
const ChatTarget$json = {
  '1': 'ChatTarget',
  '2': [
    {'1': 'mode', '3': 1, '4': 1, '5': 9, '10': 'mode'},
    {'1': 'node', '3': 2, '4': 1, '5': 9, '10': 'node'},
    {'1': 'cwd', '3': 3, '4': 1, '5': 9, '10': 'cwd'},
    {'1': 'state', '3': 4, '4': 1, '5': 9, '10': 'state'},
    {'1': 'reason', '3': 5, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'scratch', '3': 6, '4': 1, '5': 8, '10': 'scratch'},
  ],
};

/// Descriptor for `ChatTarget`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatTargetDescriptor = $convert.base64Decode(
    'CgpDaGF0VGFyZ2V0EhIKBG1vZGUYASABKAlSBG1vZGUSEgoEbm9kZRgCIAEoCVIEbm9kZRIQCg'
    'Njd2QYAyABKAlSA2N3ZBIUCgVzdGF0ZRgEIAEoCVIFc3RhdGUSFgoGcmVhc29uGAUgASgJUgZy'
    'ZWFzb24SGAoHc2NyYXRjaBgGIAEoCFIHc2NyYXRjaA==');

@$core.Deprecated('Use chatLinkDescriptor instead')
const ChatLink$json = {
  '1': 'ChatLink',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'role', '3': 2, '4': 1, '5': 9, '10': 'role'},
    {'1': 'linked_ms', '3': 3, '4': 1, '5': 3, '10': 'linkedMs'},
  ],
};

/// Descriptor for `ChatLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatLinkDescriptor = $convert.base64Decode(
    'CghDaGF0TGluaxIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEhIKBHJvbGUYAiABKAlSBHJvbG'
    'USGwoJbGlua2VkX21zGAMgASgDUghsaW5rZWRNcw==');

@$core.Deprecated('Use createChatDescriptor instead')
const CreateChat$json = {
  '1': 'CreateChat',
  '2': [
    {'1': 'prompt', '3': 1, '4': 1, '5': 9, '10': 'prompt'},
    {
      '1': 'target',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ChatTarget',
      '10': 'target'
    },
    {'1': 'attachments', '3': 3, '4': 3, '5': 9, '10': 'attachments'},
    {'1': 'model', '3': 4, '4': 1, '5': 9, '10': 'model'},
    {'1': 'permission_mode', '3': 5, '4': 1, '5': 9, '10': 'permissionMode'},
    {'1': 'title', '3': 6, '4': 1, '5': 9, '10': 'title'},
    {'1': 'session', '3': 7, '4': 1, '5': 9, '10': 'session'},
    {'1': 'client_id', '3': 8, '4': 1, '5': 9, '10': 'clientId'},
  ],
};

/// Descriptor for `CreateChat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createChatDescriptor = $convert.base64Decode(
    'CgpDcmVhdGVDaGF0EhYKBnByb21wdBgBIAEoCVIGcHJvbXB0Ei0KBnRhcmdldBgCIAEoCzIVLn'
    'RldGhlci52MS5DaGF0VGFyZ2V0UgZ0YXJnZXQSIAoLYXR0YWNobWVudHMYAyADKAlSC2F0dGFj'
    'aG1lbnRzEhQKBW1vZGVsGAQgASgJUgVtb2RlbBInCg9wZXJtaXNzaW9uX21vZGUYBSABKAlSDn'
    'Blcm1pc3Npb25Nb2RlEhQKBXRpdGxlGAYgASgJUgV0aXRsZRIYCgdzZXNzaW9uGAcgASgJUgdz'
    'ZXNzaW9uEhsKCWNsaWVudF9pZBgIIAEoCVIIY2xpZW50SWQ=');

@$core.Deprecated('Use updateChatDescriptor instead')
const UpdateChat$json = {
  '1': 'UpdateChat',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'title', '17': true},
    {
      '1': 'archived',
      '3': 2,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'archived',
      '17': true
    },
  ],
  '8': [
    {'1': '_title'},
    {'1': '_archived'},
  ],
};

/// Descriptor for `UpdateChat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateChatDescriptor = $convert.base64Decode(
    'CgpVcGRhdGVDaGF0EhkKBXRpdGxlGAEgASgJSABSBXRpdGxliAEBEh8KCGFyY2hpdmVkGAIgAS'
    'gISAFSCGFyY2hpdmVkiAEBQggKBl90aXRsZUILCglfYXJjaGl2ZWQ=');

@$core.Deprecated('Use setChatTargetDescriptor instead')
const SetChatTarget$json = {
  '1': 'SetChatTarget',
  '2': [
    {
      '1': 'target',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ChatTarget',
      '10': 'target'
    },
    {'1': 'move', '3': 2, '4': 1, '5': 8, '10': 'move'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `SetChatTarget`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setChatTargetDescriptor = $convert.base64Decode(
    'Cg1TZXRDaGF0VGFyZ2V0Ei0KBnRhcmdldBgBIAEoCzIVLnRldGhlci52MS5DaGF0VGFyZ2V0Ug'
    'Z0YXJnZXQSEgoEbW92ZRgCIAEoCFIEbW92ZRISCgR0ZXh0GAMgASgJUgR0ZXh0');

@$core.Deprecated('Use linkSessionDescriptor instead')
const LinkSession$json = {
  '1': 'LinkSession',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'role', '3': 2, '4': 1, '5': 9, '10': 'role'},
    {'1': 'unlink', '3': 3, '4': 1, '5': 8, '10': 'unlink'},
  ],
};

/// Descriptor for `LinkSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkSessionDescriptor = $convert.base64Decode(
    'CgtMaW5rU2Vzc2lvbhIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEhIKBHJvbGUYAiABKAlSBH'
    'JvbGUSFgoGdW5saW5rGAMgASgIUgZ1bmxpbms=');

@$core.Deprecated('Use chatListDescriptor instead')
const ChatList$json = {
  '1': 'ChatList',
  '2': [
    {
      '1': 'chats',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Chat',
      '10': 'chats'
    },
  ],
};

/// Descriptor for `ChatList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatListDescriptor = $convert.base64Decode(
    'CghDaGF0TGlzdBIlCgVjaGF0cxgBIAMoCzIPLnRldGhlci52MS5DaGF0UgVjaGF0cw==');

@$core.Deprecated('Use chatMessageDescriptor instead')
const ChatMessage$json = {
  '1': 'ChatMessage',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'item_id', '3': 2, '4': 1, '5': 9, '10': 'itemId'},
    {'1': 'role', '3': 3, '4': 1, '5': 9, '10': 'role'},
    {'1': 'text', '3': 4, '4': 1, '5': 9, '10': 'text'},
    {'1': 'ts_ms', '3': 5, '4': 1, '5': 3, '10': 'tsMs'},
  ],
};

/// Descriptor for `ChatMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageDescriptor = $convert.base64Decode(
    'CgtDaGF0TWVzc2FnZRIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEhcKB2l0ZW1faWQYAiABKA'
    'lSBml0ZW1JZBISCgRyb2xlGAMgASgJUgRyb2xlEhIKBHRleHQYBCABKAlSBHRleHQSEwoFdHNf'
    'bXMYBSABKANSBHRzTXM=');

@$core.Deprecated('Use chatNoteDescriptor instead')
const ChatNote$json = {
  '1': 'ChatNote',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
    {'1': 'updated_ms', '3': 3, '4': 1, '5': 3, '10': 'updatedMs'},
  ],
};

/// Descriptor for `ChatNote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatNoteDescriptor = $convert.base64Decode(
    'CghDaGF0Tm90ZRISCgRraW5kGAEgASgJUgRraW5kEhQKBXZhbHVlGAIgASgJUgV2YWx1ZRIdCg'
    'p1cGRhdGVkX21zGAMgASgDUgl1cGRhdGVkTXM=');

@$core.Deprecated('Use chatContextDescriptor instead')
const ChatContext$json = {
  '1': 'ChatContext',
  '2': [
    {
      '1': 'chat',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Chat',
      '10': 'chat'
    },
    {
      '1': 'messages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.ChatMessage',
      '10': 'messages'
    },
    {
      '1': 'notes',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.ChatNote',
      '10': 'notes'
    },
  ],
};

/// Descriptor for `ChatContext`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatContextDescriptor = $convert.base64Decode(
    'CgtDaGF0Q29udGV4dBIjCgRjaGF0GAEgASgLMg8udGV0aGVyLnYxLkNoYXRSBGNoYXQSMgoIbW'
    'Vzc2FnZXMYAiADKAsyFi50ZXRoZXIudjEuQ2hhdE1lc3NhZ2VSCG1lc3NhZ2VzEikKBW5vdGVz'
    'GAMgAygLMhMudGV0aGVyLnYxLkNoYXROb3RlUgVub3Rlcw==');

@$core.Deprecated('Use targetCandidateDescriptor instead')
const TargetCandidate$json = {
  '1': 'TargetCandidate',
  '2': [
    {'1': 'node', '3': 1, '4': 1, '5': 9, '10': 'node'},
    {'1': 'cwd', '3': 2, '4': 1, '5': 9, '10': 'cwd'},
    {'1': 'label', '3': 3, '4': 1, '5': 9, '10': 'label'},
    {'1': 'online', '3': 4, '4': 1, '5': 8, '10': 'online'},
    {'1': 'score', '3': 5, '4': 1, '5': 1, '10': 'score'},
    {'1': 'reason', '3': 6, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'last_used_ms', '3': 7, '4': 1, '5': 3, '10': 'lastUsedMs'},
  ],
};

/// Descriptor for `TargetCandidate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List targetCandidateDescriptor = $convert.base64Decode(
    'Cg9UYXJnZXRDYW5kaWRhdGUSEgoEbm9kZRgBIAEoCVIEbm9kZRIQCgNjd2QYAiABKAlSA2N3ZB'
    'IUCgVsYWJlbBgDIAEoCVIFbGFiZWwSFgoGb25saW5lGAQgASgIUgZvbmxpbmUSFAoFc2NvcmUY'
    'BSABKAFSBXNjb3JlEhYKBnJlYXNvbhgGIAEoCVIGcmVhc29uEiAKDGxhc3RfdXNlZF9tcxgHIA'
    'EoA1IKbGFzdFVzZWRNcw==');

@$core.Deprecated('Use targetSuggestionsDescriptor instead')
const TargetSuggestions$json = {
  '1': 'TargetSuggestions',
  '2': [
    {
      '1': 'candidates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.TargetCandidate',
      '10': 'candidates'
    },
    {
      '1': 'pick',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.TargetCandidate',
      '10': 'pick'
    },
  ],
};

/// Descriptor for `TargetSuggestions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List targetSuggestionsDescriptor = $convert.base64Decode(
    'ChFUYXJnZXRTdWdnZXN0aW9ucxI6CgpjYW5kaWRhdGVzGAEgAygLMhoudGV0aGVyLnYxLlRhcm'
    'dldENhbmRpZGF0ZVIKY2FuZGlkYXRlcxIuCgRwaWNrGAIgASgLMhoudGV0aGVyLnYxLlRhcmdl'
    'dENhbmRpZGF0ZVIEcGljaw==');

@$core.Deprecated('Use updateAssetDescriptor instead')
const UpdateAsset$json = {
  '1': 'UpdateAsset',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'sha256', '3': 3, '4': 1, '5': 9, '10': 'sha256'},
    {'1': 'size', '3': 4, '4': 1, '5': 3, '10': 'size'},
  ],
};

/// Descriptor for `UpdateAsset`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateAssetDescriptor = $convert.base64Decode(
    'CgtVcGRhdGVBc3NldBISCgRuYW1lGAEgASgJUgRuYW1lEhAKA3VybBgCIAEoCVIDdXJsEhYKBn'
    'NoYTI1NhgDIAEoCVIGc2hhMjU2EhIKBHNpemUYBCABKANSBHNpemU=');

@$core.Deprecated('Use updateManifestDescriptor instead')
const UpdateManifest$json = {
  '1': 'UpdateManifest',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 9, '10': 'version'},
    {'1': 'notes', '3': 2, '4': 1, '5': 9, '10': 'notes'},
    {'1': 'published', '3': 3, '4': 1, '5': 9, '10': 'published'},
    {'1': 'min_supported', '3': 4, '4': 1, '5': 9, '10': 'minSupported'},
    {
      '1': 'platforms',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.UpdateManifest.PlatformsEntry',
      '10': 'platforms'
    },
  ],
  '3': [UpdateManifest_PlatformsEntry$json],
};

@$core.Deprecated('Use updateManifestDescriptor instead')
const UpdateManifest_PlatformsEntry$json = {
  '1': 'PlatformsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UpdateAsset',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `UpdateManifest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateManifestDescriptor = $convert.base64Decode(
    'Cg5VcGRhdGVNYW5pZmVzdBIYCgd2ZXJzaW9uGAEgASgJUgd2ZXJzaW9uEhQKBW5vdGVzGAIgAS'
    'gJUgVub3RlcxIcCglwdWJsaXNoZWQYAyABKAlSCXB1Ymxpc2hlZBIjCg1taW5fc3VwcG9ydGVk'
    'GAQgASgJUgxtaW5TdXBwb3J0ZWQSRgoJcGxhdGZvcm1zGAUgAygLMigudGV0aGVyLnYxLlVwZG'
    'F0ZU1hbmlmZXN0LlBsYXRmb3Jtc0VudHJ5UglwbGF0Zm9ybXMaVAoOUGxhdGZvcm1zRW50cnkS'
    'EAoDa2V5GAEgASgJUgNrZXkSLAoFdmFsdWUYAiABKAsyFi50ZXRoZXIudjEuVXBkYXRlQXNzZX'
    'RSBXZhbHVlOgI4AQ==');
