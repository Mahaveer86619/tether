// This is a generated file - do not edit.
//
// Generated from tether/v1/render.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Notice_Level extends $pb.ProtobufEnum {
  static const Notice_Level LEVEL_UNSPECIFIED =
      Notice_Level._(0, _omitEnumNames ? '' : 'LEVEL_UNSPECIFIED');
  static const Notice_Level LEVEL_INFO =
      Notice_Level._(1, _omitEnumNames ? '' : 'LEVEL_INFO');
  static const Notice_Level LEVEL_WARNING =
      Notice_Level._(2, _omitEnumNames ? '' : 'LEVEL_WARNING');
  static const Notice_Level LEVEL_ERROR =
      Notice_Level._(3, _omitEnumNames ? '' : 'LEVEL_ERROR');

  static const $core.List<Notice_Level> values = <Notice_Level>[
    LEVEL_UNSPECIFIED,
    LEVEL_INFO,
    LEVEL_WARNING,
    LEVEL_ERROR,
  ];

  static final $core.List<Notice_Level?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Notice_Level? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Notice_Level._(super.value, super.name);
}

class Table_Align extends $pb.ProtobufEnum {
  static const Table_Align ALIGN_UNSPECIFIED =
      Table_Align._(0, _omitEnumNames ? '' : 'ALIGN_UNSPECIFIED');
  static const Table_Align ALIGN_LEFT =
      Table_Align._(1, _omitEnumNames ? '' : 'ALIGN_LEFT');
  static const Table_Align ALIGN_CENTER =
      Table_Align._(2, _omitEnumNames ? '' : 'ALIGN_CENTER');
  static const Table_Align ALIGN_RIGHT =
      Table_Align._(3, _omitEnumNames ? '' : 'ALIGN_RIGHT');

  static const $core.List<Table_Align> values = <Table_Align>[
    ALIGN_UNSPECIFIED,
    ALIGN_LEFT,
    ALIGN_CENTER,
    ALIGN_RIGHT,
  ];

  static final $core.List<Table_Align?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Table_Align? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Table_Align._(super.value, super.name);
}

class ToolCard_Status extends $pb.ProtobufEnum {
  static const ToolCard_Status STATUS_UNSPECIFIED =
      ToolCard_Status._(0, _omitEnumNames ? '' : 'STATUS_UNSPECIFIED');
  static const ToolCard_Status STATUS_PENDING =
      ToolCard_Status._(1, _omitEnumNames ? '' : 'STATUS_PENDING');
  static const ToolCard_Status STATUS_RUNNING =
      ToolCard_Status._(2, _omitEnumNames ? '' : 'STATUS_RUNNING');
  static const ToolCard_Status STATUS_SUCCEEDED =
      ToolCard_Status._(3, _omitEnumNames ? '' : 'STATUS_SUCCEEDED');
  static const ToolCard_Status STATUS_FAILED =
      ToolCard_Status._(4, _omitEnumNames ? '' : 'STATUS_FAILED');

  static const $core.List<ToolCard_Status> values = <ToolCard_Status>[
    STATUS_UNSPECIFIED,
    STATUS_PENDING,
    STATUS_RUNNING,
    STATUS_SUCCEEDED,
    STATUS_FAILED,
  ];

  static final $core.List<ToolCard_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ToolCard_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ToolCard_Status._(super.value, super.name);
}

class Todo_Status extends $pb.ProtobufEnum {
  static const Todo_Status STATUS_UNSPECIFIED =
      Todo_Status._(0, _omitEnumNames ? '' : 'STATUS_UNSPECIFIED');
  static const Todo_Status STATUS_PENDING =
      Todo_Status._(1, _omitEnumNames ? '' : 'STATUS_PENDING');
  static const Todo_Status STATUS_IN_PROGRESS =
      Todo_Status._(2, _omitEnumNames ? '' : 'STATUS_IN_PROGRESS');
  static const Todo_Status STATUS_COMPLETED =
      Todo_Status._(3, _omitEnumNames ? '' : 'STATUS_COMPLETED');

  static const $core.List<Todo_Status> values = <Todo_Status>[
    STATUS_UNSPECIFIED,
    STATUS_PENDING,
    STATUS_IN_PROGRESS,
    STATUS_COMPLETED,
  ];

  static final $core.List<Todo_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Todo_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Todo_Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
