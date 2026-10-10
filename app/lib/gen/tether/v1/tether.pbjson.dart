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
    'IAEoCzIWLnRldGhlci52MS5TdG9wU2Vzc2lvbkgAUgtzdG9wU2Vzc2lvbhIuCgd3ZWxjb21lGB'
    '4gASgLMhIudGV0aGVyLnYxLldlbGNvbWVIAFIHd2VsY29tZRIiCgNhY2sYHyABKAsyDi50ZXRo'
    'ZXIudjEuQWNrSABSA2FjaxIoCgVlcnJvchggIAEoCzIQLnRldGhlci52MS5FcnJvckgAUgVlcn'
    'JvchI4Cgtub2RlX3N0YXR1cxghIAEoCzIVLnRldGhlci52MS5Ob2RlU3RhdHVzSABSCm5vZGVT'
    'dGF0dXMSOwoMc2Vzc2lvbl9pbmZvGCIgASgLMhYudGV0aGVyLnYxLlNlc3Npb25JbmZvSABSC3'
    'Nlc3Npb25JbmZvEjcKCHRpbWVsaW5lGCMgASgLMhkudGV0aGVyLnYxLlRpbWVsaW5lVXBkYXRl'
    'SABSCHRpbWVsaW5lEksKEmFwcHJvdmFsX3JlcXVlc3RlZBgkIAEoCzIaLnRldGhlci52MS5BcH'
    'Byb3ZhbFJlcXVlc3RIAFIRYXBwcm92YWxSZXF1ZXN0ZWQSSgoRYXBwcm92YWxfcmVzb2x2ZWQY'
    'JSABKAsyGy50ZXRoZXIudjEuQXBwcm92YWxSZXNvbHZlZEgAUhBhcHByb3ZhbFJlc29sdmVkEj'
    'gKC2FnZW50X2hlbGxvGDIgASgLMhUudGV0aGVyLnYxLkFnZW50SGVsbG9IAFIKYWdlbnRIZWxs'
    'bxI+Cg1zZXNzaW9uX2luZGV4GDMgASgLMhcudGV0aGVyLnYxLlNlc3Npb25JbmRleEgAUgxzZX'
    'NzaW9uSW5kZXgSNQoKcmF3X2V2ZW50cxg0IAEoCzIULnRldGhlci52MS5SYXdFdmVudHNIAFIJ'
    'cmF3RXZlbnRzEj4KDWFnZW50X2NvbW1hbmQYPCABKAsyFy50ZXRoZXIudjEuQWdlbnRDb21tYW'
    '5kSABSDGFnZW50Q29tbWFuZEIGCgRib2R5');

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
  ],
};

/// Descriptor for `NodeStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeStatusDescriptor = $convert.base64Decode(
    'CgpOb2RlU3RhdHVzEhIKBG5vZGUYASABKAlSBG5vZGUSFgoGb25saW5lGAIgASgIUgZvbmxpbm'
    'USDgoCb3MYAyABKAlSAm9zEhoKCGhvc3RuYW1lGAQgASgJUghob3N0bmFtZRIlCg5jbGF1ZGVf'
    'dmVyc2lvbhgFIAEoCVINY2xhdWRlVmVyc2lvbhIjCg1hZ2VudF92ZXJzaW9uGAYgASgJUgxhZ2'
    'VudFZlcnNpb24SIAoMbGFzdF9zZWVuX21zGAcgASgDUgpsYXN0U2Vlbk1zEikKEHJ1bm5pbmdf'
    'c2Vzc2lvbnMYCCABKAVSD3J1bm5pbmdTZXNzaW9ucw==');

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
    'cHV0GBIgASgIUg10ZXJtaW5hbElucHV0');

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
  ],
};

/// Descriptor for `ApprovalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvalRequestDescriptor = $convert.base64Decode(
    'Cg9BcHByb3ZhbFJlcXVlc3QSHwoLYXBwcm92YWxfaWQYASABKAlSCmFwcHJvdmFsSWQSGAoHc2'
    'Vzc2lvbhgCIAEoCVIHc2Vzc2lvbhISCgRub2RlGAMgASgJUgRub2RlEhsKCXRvb2xfbmFtZRgE'
    'IAEoCVIIdG9vbE5hbWUSHQoKaW5wdXRfanNvbhgFIAEoCVIJaW5wdXRKc29uEiAKC2Rlc2NyaX'
    'B0aW9uGAYgASgJUgtkZXNjcmlwdGlvbhIdCgpjcmVhdGVkX21zGAcgASgDUgljcmVhdGVkTXMS'
    'LQoHcHJldmlldxgIIAEoCzITLnRldGhlci52MS5Ub29sQ2FyZFIHcHJldmlldxIzCgRraW5kGA'
    'kgASgOMh8udGV0aGVyLnYxLkFwcHJvdmFsUmVxdWVzdC5LaW5kUgRraW5kIkIKBEtpbmQSFAoQ'
    'S0lORF9VTlNQRUNJRklFRBAAEg0KCUtJTkRfVE9PTBABEhUKEUtJTkRfRk9MREVSX1RSVVNUEA'
    'I=');

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
  ],
};

/// Descriptor for `ApprovalDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvalDecisionDescriptor = $convert.base64Decode(
    'ChBBcHByb3ZhbERlY2lzaW9uEh8KC2FwcHJvdmFsX2lkGAEgASgJUgphcHByb3ZhbElkEi8KCG'
    'RlY2lzaW9uGAIgASgOMhMudGV0aGVyLnYxLkRlY2lzaW9uUghkZWNpc2lvbhIYCgdtZXNzYWdl'
    'GAMgASgJUgdtZXNzYWdl');

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

@$core.Deprecated('Use clientHelloDescriptor instead')
const ClientHello$json = {
  '1': 'ClientHello',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'client_name', '3': 2, '4': 1, '5': 9, '10': 'clientName'},
    {'1': 'platform', '3': 3, '4': 1, '5': 9, '10': 'platform'},
  ],
};

/// Descriptor for `ClientHello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientHelloDescriptor = $convert.base64Decode(
    'CgtDbGllbnRIZWxsbxIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SHwoLY2xpZW50X25hbWUYAiABKA'
    'lSCmNsaWVudE5hbWUSGgoIcGxhdGZvcm0YAyABKAlSCHBsYXRmb3Jt');

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
  ],
};

/// Descriptor for `CreateSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSessionDescriptor = $convert.base64Decode(
    'Cg1DcmVhdGVTZXNzaW9uEhIKBG5vZGUYASABKAlSBG5vZGUSEAoDY3dkGAIgASgJUgNjd2QSFg'
    'oGcHJvbXB0GAMgASgJUgZwcm9tcHQSFAoFbW9kZWwYBCABKAlSBW1vZGVsEicKD3Blcm1pc3Np'
    'b25fbW9kZRgFIAEoCVIOcGVybWlzc2lvbk1vZGUSEgoEbmFtZRgGIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use sendMessageDescriptor instead')
const SendMessage$json = {
  '1': 'SendMessage',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'fork', '3': 3, '4': 1, '5': 8, '10': 'fork'},
  ],
};

/// Descriptor for `SendMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMessageDescriptor = $convert.base64Decode(
    'CgtTZW5kTWVzc2FnZRIYCgdzZXNzaW9uGAEgASgJUgdzZXNzaW9uEhIKBHRleHQYAiABKAlSBH'
    'RleHQSEgoEZm9yaxgDIAEoCFIEZm9yaw==');

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
  ],
};

/// Descriptor for `Welcome`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List welcomeDescriptor = $convert.base64Decode(
    'CgdXZWxjb21lEh8KC2h1Yl92ZXJzaW9uGAEgASgJUgpodWJWZXJzaW9uEisKBW5vZGVzGAIgAy'
    'gLMhUudGV0aGVyLnYxLk5vZGVTdGF0dXNSBW5vZGVzEjIKCHNlc3Npb25zGAMgAygLMhYudGV0'
    'aGVyLnYxLlNlc3Npb25JbmZvUghzZXNzaW9ucxJHChFwZW5kaW5nX2FwcHJvdmFscxgEIAMoCz'
    'IaLnRldGhlci52MS5BcHByb3ZhbFJlcXVlc3RSEHBlbmRpbmdBcHByb3ZhbHM=');

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
  ],
  '3': [
    AgentCommand_StartRun$json,
    AgentCommand_SendInput$json,
    AgentCommand_Interrupt$json,
    AgentCommand_Mirror$json,
    AgentCommand_StopMirror$json,
    AgentCommand_Stop$json
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
  ],
};

@$core.Deprecated('Use agentCommandDescriptor instead')
const AgentCommand_SendInput$json = {
  '1': 'SendInput',
  '2': [
    {'1': 'session', '3': 1, '4': 1, '5': 9, '10': 'session'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
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

/// Descriptor for `AgentCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentCommandDescriptor = $convert.base64Decode(
    'CgxBZ2VudENvbW1hbmQSOAoFc3RhcnQYASABKAsyIC50ZXRoZXIudjEuQWdlbnRDb21tYW5kLl'
    'N0YXJ0UnVuSABSBXN0YXJ0EjcKBHNlbmQYAiABKAsyIS50ZXRoZXIudjEuQWdlbnRDb21tYW5k'
    'LlNlbmRJbnB1dEgAUgRzZW5kEkEKCWludGVycnVwdBgDIAEoCzIhLnRldGhlci52MS5BZ2VudE'
    'NvbW1hbmQuSW50ZXJydXB0SABSCWludGVycnVwdBI4CgZtaXJyb3IYBCABKAsyHi50ZXRoZXIu'
    'djEuQWdlbnRDb21tYW5kLk1pcnJvckgAUgZtaXJyb3ISRQoLc3RvcF9taXJyb3IYBSABKAsyIi'
    '50ZXRoZXIudjEuQWdlbnRDb21tYW5kLlN0b3BNaXJyb3JIAFIKc3RvcE1pcnJvchIyCgRzdG9w'
    'GAYgASgLMhwudGV0aGVyLnYxLkFnZW50Q29tbWFuZC5TdG9wSABSBHN0b3AazQEKCFN0YXJ0Un'
    'VuEhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24SEAoDY3dkGAIgASgJUgNjd2QSFgoGcHJvbXB0'
    'GAMgASgJUgZwcm9tcHQSFAoFbW9kZWwYBCABKAlSBW1vZGVsEicKD3Blcm1pc3Npb25fbW9kZR'
    'gFIAEoCVIOcGVybWlzc2lvbk1vZGUSEgoEbmFtZRgGIAEoCVIEbmFtZRIWCgZyZXN1bWUYByAB'
    'KAlSBnJlc3VtZRISCgRmb3JrGAggASgIUgRmb3JrGjkKCVNlbmRJbnB1dBIYCgdzZXNzaW9uGA'
    'EgASgJUgdzZXNzaW9uEhIKBHRleHQYAiABKAlSBHRleHQaJQoJSW50ZXJydXB0EhgKB3Nlc3Np'
    'b24YASABKAlSB3Nlc3Npb24aQwoGTWlycm9yEhgKB3Nlc3Npb24YASABKAlSB3Nlc3Npb24SHw'
    'oLZnJvbV9vZmZzZXQYAiABKANSCmZyb21PZmZzZXQaJgoKU3RvcE1pcnJvchIYCgdzZXNzaW9u'
    'GAEgASgJUgdzZXNzaW9uGiAKBFN0b3ASGAoHc2Vzc2lvbhgBIAEoCVIHc2Vzc2lvbkIECgJvcA'
    '==');
