// This is a generated file - do not edit.
//
// Generated from tether/v1/render.proto.

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

@$core.Deprecated('Use timelineItemDescriptor instead')
const TimelineItem$json = {
  '1': 'TimelineItem',
  '2': [
    {'1': 'item_id', '3': 1, '4': 1, '5': 9, '10': 'itemId'},
    {'1': 'ord', '3': 2, '4': 1, '5': 4, '10': 'ord'},
    {
      '1': 'parent_tool_use_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'parentToolUseId'
    },
    {'1': 'ts_ms', '3': 4, '4': 1, '5': 3, '10': 'tsMs'},
    {
      '1': 'user',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.UserText',
      '9': 0,
      '10': 'user'
    },
    {
      '1': 'markdown',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Markdown',
      '9': 0,
      '10': 'markdown'
    },
    {
      '1': 'tool',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ToolCard',
      '9': 0,
      '10': 'tool'
    },
    {
      '1': 'thinking',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Thinking',
      '9': 0,
      '10': 'thinking'
    },
    {
      '1': 'notice',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Notice',
      '9': 0,
      '10': 'notice'
    },
    {
      '1': 'result',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ResultSummary',
      '9': 0,
      '10': 'result'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `TimelineItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timelineItemDescriptor = $convert.base64Decode(
    'CgxUaW1lbGluZUl0ZW0SFwoHaXRlbV9pZBgBIAEoCVIGaXRlbUlkEhAKA29yZBgCIAEoBFIDb3'
    'JkEisKEnBhcmVudF90b29sX3VzZV9pZBgDIAEoCVIPcGFyZW50VG9vbFVzZUlkEhMKBXRzX21z'
    'GAQgASgDUgR0c01zEikKBHVzZXIYCiABKAsyEy50ZXRoZXIudjEuVXNlclRleHRIAFIEdXNlch'
    'IxCghtYXJrZG93bhgLIAEoCzITLnRldGhlci52MS5NYXJrZG93bkgAUghtYXJrZG93bhIpCgR0'
    'b29sGAwgASgLMhMudGV0aGVyLnYxLlRvb2xDYXJkSABSBHRvb2wSMQoIdGhpbmtpbmcYDSABKA'
    'syEy50ZXRoZXIudjEuVGhpbmtpbmdIAFIIdGhpbmtpbmcSKwoGbm90aWNlGA4gASgLMhEudGV0'
    'aGVyLnYxLk5vdGljZUgAUgZub3RpY2USMgoGcmVzdWx0GA8gASgLMhgudGV0aGVyLnYxLlJlc3'
    'VsdFN1bW1hcnlIAFIGcmVzdWx0QgYKBGtpbmQ=');

@$core.Deprecated('Use userTextDescriptor instead')
const UserText$json = {
  '1': 'UserText',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `UserText`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userTextDescriptor =
    $convert.base64Decode('CghVc2VyVGV4dBISCgR0ZXh0GAEgASgJUgR0ZXh0');

@$core.Deprecated('Use markdownDescriptor instead')
const Markdown$json = {
  '1': 'Markdown',
  '2': [
    {
      '1': 'blocks',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Block',
      '10': 'blocks'
    },
    {'1': 'streaming', '3': 2, '4': 1, '5': 8, '10': 'streaming'},
  ],
};

/// Descriptor for `Markdown`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markdownDescriptor = $convert.base64Decode(
    'CghNYXJrZG93bhIoCgZibG9ja3MYASADKAsyEC50ZXRoZXIudjEuQmxvY2tSBmJsb2NrcxIcCg'
    'lzdHJlYW1pbmcYAiABKAhSCXN0cmVhbWluZw==');

@$core.Deprecated('Use thinkingDescriptor instead')
const Thinking$json = {
  '1': 'Thinking',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'streaming', '3': 2, '4': 1, '5': 8, '10': 'streaming'},
  ],
};

/// Descriptor for `Thinking`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List thinkingDescriptor = $convert.base64Decode(
    'CghUaGlua2luZxISCgR0ZXh0GAEgASgJUgR0ZXh0EhwKCXN0cmVhbWluZxgCIAEoCFIJc3RyZW'
    'FtaW5n');

@$core.Deprecated('Use noticeDescriptor instead')
const Notice$json = {
  '1': 'Notice',
  '2': [
    {
      '1': 'level',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.Notice.Level',
      '10': 'level'
    },
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
  ],
  '4': [Notice_Level$json],
};

@$core.Deprecated('Use noticeDescriptor instead')
const Notice_Level$json = {
  '1': 'Level',
  '2': [
    {'1': 'LEVEL_UNSPECIFIED', '2': 0},
    {'1': 'LEVEL_INFO', '2': 1},
    {'1': 'LEVEL_WARNING', '2': 2},
    {'1': 'LEVEL_ERROR', '2': 3},
  ],
};

/// Descriptor for `Notice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List noticeDescriptor = $convert.base64Decode(
    'CgZOb3RpY2USLQoFbGV2ZWwYASABKA4yFy50ZXRoZXIudjEuTm90aWNlLkxldmVsUgVsZXZlbB'
    'ISCgR0ZXh0GAIgASgJUgR0ZXh0IlIKBUxldmVsEhUKEUxFVkVMX1VOU1BFQ0lGSUVEEAASDgoK'
    'TEVWRUxfSU5GTxABEhEKDUxFVkVMX1dBUk5JTkcQAhIPCgtMRVZFTF9FUlJPUhAD');

@$core.Deprecated('Use resultSummaryDescriptor instead')
const ResultSummary$json = {
  '1': 'ResultSummary',
  '2': [
    {'1': 'is_error', '3': 1, '4': 1, '5': 8, '10': 'isError'},
    {'1': 'subtype', '3': 2, '4': 1, '5': 9, '10': 'subtype'},
    {'1': 'num_turns', '3': 3, '4': 1, '5': 5, '10': 'numTurns'},
    {'1': 'duration_ms', '3': 4, '4': 1, '5': 3, '10': 'durationMs'},
    {'1': 'cost_usd', '3': 5, '4': 1, '5': 1, '10': 'costUsd'},
  ],
};

/// Descriptor for `ResultSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resultSummaryDescriptor = $convert.base64Decode(
    'Cg1SZXN1bHRTdW1tYXJ5EhkKCGlzX2Vycm9yGAEgASgIUgdpc0Vycm9yEhgKB3N1YnR5cGUYAi'
    'ABKAlSB3N1YnR5cGUSGwoJbnVtX3R1cm5zGAMgASgFUghudW1UdXJucxIfCgtkdXJhdGlvbl9t'
    'cxgEIAEoA1IKZHVyYXRpb25NcxIZCghjb3N0X3VzZBgFIAEoAVIHY29zdFVzZA==');

@$core.Deprecated('Use spanDescriptor instead')
const Span$json = {
  '1': 'Span',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'bold', '3': 2, '4': 1, '5': 8, '10': 'bold'},
    {'1': 'italic', '3': 3, '4': 1, '5': 8, '10': 'italic'},
    {'1': 'code', '3': 4, '4': 1, '5': 8, '10': 'code'},
    {'1': 'strike', '3': 5, '4': 1, '5': 8, '10': 'strike'},
    {'1': 'link', '3': 6, '4': 1, '5': 9, '10': 'link'},
  ],
};

/// Descriptor for `Span`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List spanDescriptor = $convert.base64Decode(
    'CgRTcGFuEhIKBHRleHQYASABKAlSBHRleHQSEgoEYm9sZBgCIAEoCFIEYm9sZBIWCgZpdGFsaW'
    'MYAyABKAhSBml0YWxpYxISCgRjb2RlGAQgASgIUgRjb2RlEhYKBnN0cmlrZRgFIAEoCFIGc3Ry'
    'aWtlEhIKBGxpbmsYBiABKAlSBGxpbms=');

@$core.Deprecated('Use blockDescriptor instead')
const Block$json = {
  '1': 'Block',
  '2': [
    {
      '1': 'heading',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Heading',
      '9': 0,
      '10': 'heading'
    },
    {
      '1': 'paragraph',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Paragraph',
      '9': 0,
      '10': 'paragraph'
    },
    {
      '1': 'list',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ListBlock',
      '9': 0,
      '10': 'list'
    },
    {
      '1': 'code',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.CodeBlock',
      '9': 0,
      '10': 'code'
    },
    {
      '1': 'table',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Table',
      '9': 0,
      '10': 'table'
    },
    {
      '1': 'quote',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Quote',
      '9': 0,
      '10': 'quote'
    },
    {
      '1': 'divider',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Divider',
      '9': 0,
      '10': 'divider'
    },
    {
      '1': 'image',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.Image',
      '9': 0,
      '10': 'image'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `Block`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockDescriptor = $convert.base64Decode(
    'CgVCbG9jaxIuCgdoZWFkaW5nGAEgASgLMhIudGV0aGVyLnYxLkhlYWRpbmdIAFIHaGVhZGluZx'
    'I0CglwYXJhZ3JhcGgYAiABKAsyFC50ZXRoZXIudjEuUGFyYWdyYXBoSABSCXBhcmFncmFwaBIq'
    'CgRsaXN0GAMgASgLMhQudGV0aGVyLnYxLkxpc3RCbG9ja0gAUgRsaXN0EioKBGNvZGUYBCABKA'
    'syFC50ZXRoZXIudjEuQ29kZUJsb2NrSABSBGNvZGUSKAoFdGFibGUYBSABKAsyEC50ZXRoZXIu'
    'djEuVGFibGVIAFIFdGFibGUSKAoFcXVvdGUYBiABKAsyEC50ZXRoZXIudjEuUXVvdGVIAFIFcX'
    'VvdGUSLgoHZGl2aWRlchgHIAEoCzISLnRldGhlci52MS5EaXZpZGVySABSB2RpdmlkZXISKAoF'
    'aW1hZ2UYCCABKAsyEC50ZXRoZXIudjEuSW1hZ2VIAFIFaW1hZ2VCBgoEa2luZA==');

@$core.Deprecated('Use headingDescriptor instead')
const Heading$json = {
  '1': 'Heading',
  '2': [
    {'1': 'level', '3': 1, '4': 1, '5': 5, '10': 'level'},
    {
      '1': 'spans',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Span',
      '10': 'spans'
    },
  ],
};

/// Descriptor for `Heading`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headingDescriptor = $convert.base64Decode(
    'CgdIZWFkaW5nEhQKBWxldmVsGAEgASgFUgVsZXZlbBIlCgVzcGFucxgCIAMoCzIPLnRldGhlci'
    '52MS5TcGFuUgVzcGFucw==');

@$core.Deprecated('Use paragraphDescriptor instead')
const Paragraph$json = {
  '1': 'Paragraph',
  '2': [
    {
      '1': 'spans',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Span',
      '10': 'spans'
    },
  ],
};

/// Descriptor for `Paragraph`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paragraphDescriptor = $convert.base64Decode(
    'CglQYXJhZ3JhcGgSJQoFc3BhbnMYASADKAsyDy50ZXRoZXIudjEuU3BhblIFc3BhbnM=');

@$core.Deprecated('Use listBlockDescriptor instead')
const ListBlock$json = {
  '1': 'ListBlock',
  '2': [
    {'1': 'ordered', '3': 1, '4': 1, '5': 8, '10': 'ordered'},
    {'1': 'start', '3': 2, '4': 1, '5': 5, '10': 'start'},
    {
      '1': 'items',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.ListItem',
      '10': 'items'
    },
  ],
};

/// Descriptor for `ListBlock`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBlockDescriptor = $convert.base64Decode(
    'CglMaXN0QmxvY2sSGAoHb3JkZXJlZBgBIAEoCFIHb3JkZXJlZBIUCgVzdGFydBgCIAEoBVIFc3'
    'RhcnQSKQoFaXRlbXMYAyADKAsyEy50ZXRoZXIudjEuTGlzdEl0ZW1SBWl0ZW1z');

@$core.Deprecated('Use listItemDescriptor instead')
const ListItem$json = {
  '1': 'ListItem',
  '2': [
    {
      '1': 'checked',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'checked',
      '17': true
    },
    {
      '1': 'blocks',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Block',
      '10': 'blocks'
    },
  ],
  '8': [
    {'1': '_checked'},
  ],
};

/// Descriptor for `ListItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listItemDescriptor = $convert.base64Decode(
    'CghMaXN0SXRlbRIdCgdjaGVja2VkGAEgASgISABSB2NoZWNrZWSIAQESKAoGYmxvY2tzGAIgAy'
    'gLMhAudGV0aGVyLnYxLkJsb2NrUgZibG9ja3NCCgoIX2NoZWNrZWQ=');

@$core.Deprecated('Use codeBlockDescriptor instead')
const CodeBlock$json = {
  '1': 'CodeBlock',
  '2': [
    {'1': 'lang', '3': 1, '4': 1, '5': 9, '10': 'lang'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `CodeBlock`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List codeBlockDescriptor = $convert.base64Decode(
    'CglDb2RlQmxvY2sSEgoEbGFuZxgBIAEoCVIEbGFuZxISCgR0ZXh0GAIgASgJUgR0ZXh0');

@$core.Deprecated('Use tableDescriptor instead')
const Table$json = {
  '1': 'Table',
  '2': [
    {
      '1': 'align',
      '3': 1,
      '4': 3,
      '5': 14,
      '6': '.tether.v1.Table.Align',
      '10': 'align'
    },
    {
      '1': 'header',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.TableCell',
      '10': 'header'
    },
    {
      '1': 'rows',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.TableRow',
      '10': 'rows'
    },
  ],
  '4': [Table_Align$json],
};

@$core.Deprecated('Use tableDescriptor instead')
const Table_Align$json = {
  '1': 'Align',
  '2': [
    {'1': 'ALIGN_UNSPECIFIED', '2': 0},
    {'1': 'ALIGN_LEFT', '2': 1},
    {'1': 'ALIGN_CENTER', '2': 2},
    {'1': 'ALIGN_RIGHT', '2': 3},
  ],
};

/// Descriptor for `Table`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tableDescriptor = $convert.base64Decode(
    'CgVUYWJsZRIsCgVhbGlnbhgBIAMoDjIWLnRldGhlci52MS5UYWJsZS5BbGlnblIFYWxpZ24SLA'
    'oGaGVhZGVyGAIgAygLMhQudGV0aGVyLnYxLlRhYmxlQ2VsbFIGaGVhZGVyEicKBHJvd3MYAyAD'
    'KAsyEy50ZXRoZXIudjEuVGFibGVSb3dSBHJvd3MiUQoFQWxpZ24SFQoRQUxJR05fVU5TUEVDSU'
    'ZJRUQQABIOCgpBTElHTl9MRUZUEAESEAoMQUxJR05fQ0VOVEVSEAISDwoLQUxJR05fUklHSFQQ'
    'Aw==');

@$core.Deprecated('Use tableRowDescriptor instead')
const TableRow$json = {
  '1': 'TableRow',
  '2': [
    {
      '1': 'cells',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.TableCell',
      '10': 'cells'
    },
  ],
};

/// Descriptor for `TableRow`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tableRowDescriptor = $convert.base64Decode(
    'CghUYWJsZVJvdxIqCgVjZWxscxgBIAMoCzIULnRldGhlci52MS5UYWJsZUNlbGxSBWNlbGxz');

@$core.Deprecated('Use tableCellDescriptor instead')
const TableCell$json = {
  '1': 'TableCell',
  '2': [
    {
      '1': 'spans',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Span',
      '10': 'spans'
    },
  ],
};

/// Descriptor for `TableCell`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tableCellDescriptor = $convert.base64Decode(
    'CglUYWJsZUNlbGwSJQoFc3BhbnMYASADKAsyDy50ZXRoZXIudjEuU3BhblIFc3BhbnM=');

@$core.Deprecated('Use quoteDescriptor instead')
const Quote$json = {
  '1': 'Quote',
  '2': [
    {
      '1': 'blocks',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Block',
      '10': 'blocks'
    },
  ],
};

/// Descriptor for `Quote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List quoteDescriptor = $convert.base64Decode(
    'CgVRdW90ZRIoCgZibG9ja3MYASADKAsyEC50ZXRoZXIudjEuQmxvY2tSBmJsb2Nrcw==');

@$core.Deprecated('Use dividerDescriptor instead')
const Divider$json = {
  '1': 'Divider',
};

/// Descriptor for `Divider`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dividerDescriptor =
    $convert.base64Decode('CgdEaXZpZGVy');

@$core.Deprecated('Use imageDescriptor instead')
const Image$json = {
  '1': 'Image',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'alt', '3': 2, '4': 1, '5': 9, '10': 'alt'},
  ],
};

/// Descriptor for `Image`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageDescriptor = $convert.base64Decode(
    'CgVJbWFnZRIQCgN1cmwYASABKAlSA3VybBIQCgNhbHQYAiABKAlSA2FsdA==');

@$core.Deprecated('Use toolCardDescriptor instead')
const ToolCard$json = {
  '1': 'ToolCard',
  '2': [
    {'1': 'tool_use_id', '3': 1, '4': 1, '5': 9, '10': 'toolUseId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'status',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.ToolCard.Status',
      '10': 'status'
    },
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'shell',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ShellCard',
      '9': 0,
      '10': 'shell'
    },
    {
      '1': 'edit',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.EditCard',
      '9': 0,
      '10': 'edit'
    },
    {
      '1': 'write',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.WriteCard',
      '9': 0,
      '10': 'write'
    },
    {
      '1': 'read',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ReadCard',
      '9': 0,
      '10': 'read'
    },
    {
      '1': 'search',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.SearchCard',
      '9': 0,
      '10': 'search'
    },
    {
      '1': 'todos',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.TodoCard',
      '9': 0,
      '10': 'todos'
    },
    {
      '1': 'agent',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.AgentCard',
      '9': 0,
      '10': 'agent'
    },
    {
      '1': 'web',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.WebCard',
      '9': 0,
      '10': 'web'
    },
    {
      '1': 'generic',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.GenericCard',
      '9': 0,
      '10': 'generic'
    },
    {
      '1': 'output',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.tether.v1.ToolOutput',
      '10': 'output'
    },
  ],
  '4': [ToolCard_Status$json],
  '8': [
    {'1': 'detail'},
  ],
};

@$core.Deprecated('Use toolCardDescriptor instead')
const ToolCard_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'STATUS_UNSPECIFIED', '2': 0},
    {'1': 'STATUS_PENDING', '2': 1},
    {'1': 'STATUS_RUNNING', '2': 2},
    {'1': 'STATUS_SUCCEEDED', '2': 3},
    {'1': 'STATUS_FAILED', '2': 4},
  ],
};

/// Descriptor for `ToolCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toolCardDescriptor = $convert.base64Decode(
    'CghUb29sQ2FyZBIeCgt0b29sX3VzZV9pZBgBIAEoCVIJdG9vbFVzZUlkEhIKBG5hbWUYAiABKA'
    'lSBG5hbWUSMgoGc3RhdHVzGAMgASgOMhoudGV0aGVyLnYxLlRvb2xDYXJkLlN0YXR1c1IGc3Rh'
    'dHVzEhQKBXRpdGxlGAQgASgJUgV0aXRsZRIsCgVzaGVsbBgKIAEoCzIULnRldGhlci52MS5TaG'
    'VsbENhcmRIAFIFc2hlbGwSKQoEZWRpdBgLIAEoCzITLnRldGhlci52MS5FZGl0Q2FyZEgAUgRl'
    'ZGl0EiwKBXdyaXRlGAwgASgLMhQudGV0aGVyLnYxLldyaXRlQ2FyZEgAUgV3cml0ZRIpCgRyZW'
    'FkGA0gASgLMhMudGV0aGVyLnYxLlJlYWRDYXJkSABSBHJlYWQSLwoGc2VhcmNoGA4gASgLMhUu'
    'dGV0aGVyLnYxLlNlYXJjaENhcmRIAFIGc2VhcmNoEisKBXRvZG9zGA8gASgLMhMudGV0aGVyLn'
    'YxLlRvZG9DYXJkSABSBXRvZG9zEiwKBWFnZW50GBAgASgLMhQudGV0aGVyLnYxLkFnZW50Q2Fy'
    'ZEgAUgVhZ2VudBImCgN3ZWIYESABKAsyEi50ZXRoZXIudjEuV2ViQ2FyZEgAUgN3ZWISMgoHZ2'
    'VuZXJpYxgSIAEoCzIWLnRldGhlci52MS5HZW5lcmljQ2FyZEgAUgdnZW5lcmljEi0KBm91dHB1'
    'dBgeIAEoCzIVLnRldGhlci52MS5Ub29sT3V0cHV0UgZvdXRwdXQicQoGU3RhdHVzEhYKElNUQV'
    'RVU19VTlNQRUNJRklFRBAAEhIKDlNUQVRVU19QRU5ESU5HEAESEgoOU1RBVFVTX1JVTk5JTkcQ'
    'AhIUChBTVEFUVVNfU1VDQ0VFREVEEAMSEQoNU1RBVFVTX0ZBSUxFRBAEQggKBmRldGFpbA==');

@$core.Deprecated('Use toolOutputDescriptor instead')
const ToolOutput$json = {
  '1': 'ToolOutput',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'is_error', '3': 2, '4': 1, '5': 8, '10': 'isError'},
    {'1': 'omitted_lines', '3': 3, '4': 1, '5': 5, '10': 'omittedLines'},
  ],
};

/// Descriptor for `ToolOutput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toolOutputDescriptor = $convert.base64Decode(
    'CgpUb29sT3V0cHV0EhIKBHRleHQYASABKAlSBHRleHQSGQoIaXNfZXJyb3IYAiABKAhSB2lzRX'
    'Jyb3ISIwoNb21pdHRlZF9saW5lcxgDIAEoBVIMb21pdHRlZExpbmVz');

@$core.Deprecated('Use shellCardDescriptor instead')
const ShellCard$json = {
  '1': 'ShellCard',
  '2': [
    {'1': 'shell', '3': 1, '4': 1, '5': 9, '10': 'shell'},
    {'1': 'command', '3': 2, '4': 1, '5': 9, '10': 'command'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
  ],
};

/// Descriptor for `ShellCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shellCardDescriptor = $convert.base64Decode(
    'CglTaGVsbENhcmQSFAoFc2hlbGwYASABKAlSBXNoZWxsEhgKB2NvbW1hbmQYAiABKAlSB2NvbW'
    '1hbmQSIAoLZGVzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9u');

@$core.Deprecated('Use editCardDescriptor instead')
const EditCard$json = {
  '1': 'EditCard',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'unified_diff', '3': 2, '4': 1, '5': 9, '10': 'unifiedDiff'},
    {'1': 'added', '3': 3, '4': 1, '5': 5, '10': 'added'},
    {'1': 'removed', '3': 4, '4': 1, '5': 5, '10': 'removed'},
  ],
};

/// Descriptor for `EditCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editCardDescriptor = $convert.base64Decode(
    'CghFZGl0Q2FyZBISCgRwYXRoGAEgASgJUgRwYXRoEiEKDHVuaWZpZWRfZGlmZhgCIAEoCVILdW'
    '5pZmllZERpZmYSFAoFYWRkZWQYAyABKAVSBWFkZGVkEhgKB3JlbW92ZWQYBCABKAVSB3JlbW92'
    'ZWQ=');

@$core.Deprecated('Use writeCardDescriptor instead')
const WriteCard$json = {
  '1': 'WriteCard',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'preview', '3': 2, '4': 1, '5': 9, '10': 'preview'},
    {'1': 'lines', '3': 3, '4': 1, '5': 5, '10': 'lines'},
  ],
};

/// Descriptor for `WriteCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeCardDescriptor = $convert.base64Decode(
    'CglXcml0ZUNhcmQSEgoEcGF0aBgBIAEoCVIEcGF0aBIYCgdwcmV2aWV3GAIgASgJUgdwcmV2aW'
    'V3EhQKBWxpbmVzGAMgASgFUgVsaW5lcw==');

@$core.Deprecated('Use readCardDescriptor instead')
const ReadCard$json = {
  '1': 'ReadCard',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
    {'1': 'limit', '3': 3, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `ReadCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List readCardDescriptor = $convert.base64Decode(
    'CghSZWFkQ2FyZBISCgRwYXRoGAEgASgJUgRwYXRoEhYKBm9mZnNldBgCIAEoBVIGb2Zmc2V0Eh'
    'QKBWxpbWl0GAMgASgFUgVsaW1pdA==');

@$core.Deprecated('Use searchCardDescriptor instead')
const SearchCard$json = {
  '1': 'SearchCard',
  '2': [
    {'1': 'pattern', '3': 1, '4': 1, '5': 9, '10': 'pattern'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'glob', '3': 3, '4': 1, '5': 9, '10': 'glob'},
  ],
};

/// Descriptor for `SearchCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchCardDescriptor = $convert.base64Decode(
    'CgpTZWFyY2hDYXJkEhgKB3BhdHRlcm4YASABKAlSB3BhdHRlcm4SEgoEcGF0aBgCIAEoCVIEcG'
    'F0aBISCgRnbG9iGAMgASgJUgRnbG9i');

@$core.Deprecated('Use todoDescriptor instead')
const Todo$json = {
  '1': 'Todo',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 9, '10': 'content'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.tether.v1.Todo.Status',
      '10': 'status'
    },
    {'1': 'active_form', '3': 3, '4': 1, '5': 9, '10': 'activeForm'},
  ],
  '4': [Todo_Status$json],
};

@$core.Deprecated('Use todoDescriptor instead')
const Todo_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'STATUS_UNSPECIFIED', '2': 0},
    {'1': 'STATUS_PENDING', '2': 1},
    {'1': 'STATUS_IN_PROGRESS', '2': 2},
    {'1': 'STATUS_COMPLETED', '2': 3},
  ],
};

/// Descriptor for `Todo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List todoDescriptor = $convert.base64Decode(
    'CgRUb2RvEhgKB2NvbnRlbnQYASABKAlSB2NvbnRlbnQSLgoGc3RhdHVzGAIgASgOMhYudGV0aG'
    'VyLnYxLlRvZG8uU3RhdHVzUgZzdGF0dXMSHwoLYWN0aXZlX2Zvcm0YAyABKAlSCmFjdGl2ZUZv'
    'cm0iYgoGU3RhdHVzEhYKElNUQVRVU19VTlNQRUNJRklFRBAAEhIKDlNUQVRVU19QRU5ESU5HEA'
    'ESFgoSU1RBVFVTX0lOX1BST0dSRVNTEAISFAoQU1RBVFVTX0NPTVBMRVRFRBAD');

@$core.Deprecated('Use todoCardDescriptor instead')
const TodoCard$json = {
  '1': 'TodoCard',
  '2': [
    {
      '1': 'todos',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.tether.v1.Todo',
      '10': 'todos'
    },
  ],
};

/// Descriptor for `TodoCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List todoCardDescriptor = $convert.base64Decode(
    'CghUb2RvQ2FyZBIlCgV0b2RvcxgBIAMoCzIPLnRldGhlci52MS5Ub2RvUgV0b2Rvcw==');

@$core.Deprecated('Use agentCardDescriptor instead')
const AgentCard$json = {
  '1': 'AgentCard',
  '2': [
    {'1': 'description', '3': 1, '4': 1, '5': 9, '10': 'description'},
    {'1': 'subagent_type', '3': 2, '4': 1, '5': 9, '10': 'subagentType'},
    {'1': 'prompt', '3': 3, '4': 1, '5': 9, '10': 'prompt'},
  ],
};

/// Descriptor for `AgentCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentCardDescriptor = $convert.base64Decode(
    'CglBZ2VudENhcmQSIAoLZGVzY3JpcHRpb24YASABKAlSC2Rlc2NyaXB0aW9uEiMKDXN1YmFnZW'
    '50X3R5cGUYAiABKAlSDHN1YmFnZW50VHlwZRIWCgZwcm9tcHQYAyABKAlSBnByb21wdA==');

@$core.Deprecated('Use webCardDescriptor instead')
const WebCard$json = {
  '1': 'WebCard',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'query', '3': 2, '4': 1, '5': 9, '10': 'query'},
  ],
};

/// Descriptor for `WebCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List webCardDescriptor = $convert.base64Decode(
    'CgdXZWJDYXJkEhAKA3VybBgBIAEoCVIDdXJsEhQKBXF1ZXJ5GAIgASgJUgVxdWVyeQ==');

@$core.Deprecated('Use genericCardDescriptor instead')
const GenericCard$json = {
  '1': 'GenericCard',
  '2': [
    {'1': 'input_json', '3': 1, '4': 1, '5': 9, '10': 'inputJson'},
  ],
};

/// Descriptor for `GenericCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List genericCardDescriptor = $convert.base64Decode(
    'CgtHZW5lcmljQ2FyZBIdCgppbnB1dF9qc29uGAEgASgJUglpbnB1dEpzb24=');
