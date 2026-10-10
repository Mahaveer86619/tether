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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'render.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'render.pbenum.dart';

enum TimelineItem_Kind {
  user,
  markdown,
  tool,
  thinking,
  notice,
  result,
  notSet
}

/// One entry in a session's timeline. Clients key items by item_id, replace
/// them on every upsert, and order them by ord.
class TimelineItem extends $pb.GeneratedMessage {
  factory TimelineItem({
    $core.String? itemId,
    $fixnum.Int64? ord,
    $core.String? parentToolUseId,
    $fixnum.Int64? tsMs,
    UserText? user,
    Markdown? markdown,
    ToolCard? tool,
    Thinking? thinking,
    Notice? notice,
    ResultSummary? result,
  }) {
    final result$ = TimelineItem._();
    if (itemId != null) result$.itemId = itemId;
    if (ord != null) result$.ord = ord;
    if (parentToolUseId != null) result$.parentToolUseId = parentToolUseId;
    if (tsMs != null) result$.tsMs = tsMs;
    if (user != null) result$.user = user;
    if (markdown != null) result$.markdown = markdown;
    if (tool != null) result$.tool = tool;
    if (thinking != null) result$.thinking = thinking;
    if (notice != null) result$.notice = notice;
    if (result != null) result$.result = result;
    return result$;
  }

  TimelineItem._();

  factory TimelineItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelineItem()..mergeFromBuffer(data, registry);
  factory TimelineItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelineItem()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, TimelineItem_Kind> _TimelineItem_KindByTag =
      {
    10: TimelineItem_Kind.user,
    11: TimelineItem_Kind.markdown,
    12: TimelineItem_Kind.tool,
    13: TimelineItem_Kind.thinking,
    14: TimelineItem_Kind.notice,
    15: TimelineItem_Kind.result,
    0: TimelineItem_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimelineItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: TimelineItem.$_createMessage)
    ..oo(0, [10, 11, 12, 13, 14, 15])
    ..aOS(1, _omitFieldNames ? '' : 'itemId')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'ord', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'parentToolUseId')
    ..aInt64(4, _omitFieldNames ? '' : 'tsMs')
    ..aOM<UserText>(10, _omitFieldNames ? '' : 'user',
        subBuilder: UserText.$_createMessage)
    ..aOM<Markdown>(11, _omitFieldNames ? '' : 'markdown',
        subBuilder: Markdown.$_createMessage)
    ..aOM<ToolCard>(12, _omitFieldNames ? '' : 'tool',
        subBuilder: ToolCard.$_createMessage)
    ..aOM<Thinking>(13, _omitFieldNames ? '' : 'thinking',
        subBuilder: Thinking.$_createMessage)
    ..aOM<Notice>(14, _omitFieldNames ? '' : 'notice',
        subBuilder: Notice.$_createMessage)
    ..aOM<ResultSummary>(15, _omitFieldNames ? '' : 'result',
        subBuilder: ResultSummary.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelineItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelineItem copyWith(void Function(TimelineItem) updates) =>
      super.copyWith((message) => updates(message as TimelineItem))
          as TimelineItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TimelineItem() / TimelineItem.new instead')
  static TimelineItem create() => TimelineItem._();
  static $pb.GeneratedMessage $_createMessage() => TimelineItem._();
  @$core.override
  TimelineItem createEmptyInstance() => TimelineItem._();
  @$core.pragma('dart2js:noInline')
  static TimelineItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TimelineItem>(
          TimelineItem.$_createMessage);
  static TimelineItem? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  TimelineItem_Kind whichKind() => _TimelineItem_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get itemId => $_getSZ(0);
  @$pb.TagNumber(1)
  set itemId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasItemId() => $_has(0);
  @$pb.TagNumber(1)
  void clearItemId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get ord => $_getI64(1);
  @$pb.TagNumber(2)
  set ord($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOrd() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrd() => $_clearField(2);

  /// Set when the item was produced inside a sub-agent run.
  @$pb.TagNumber(3)
  $core.String get parentToolUseId => $_getSZ(2);
  @$pb.TagNumber(3)
  set parentToolUseId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasParentToolUseId() => $_has(2);
  @$pb.TagNumber(3)
  void clearParentToolUseId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get tsMs => $_getI64(3);
  @$pb.TagNumber(4)
  set tsMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTsMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTsMs() => $_clearField(4);

  @$pb.TagNumber(10)
  UserText get user => $_getN(4);
  @$pb.TagNumber(10)
  set user(UserText value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasUser() => $_has(4);
  @$pb.TagNumber(10)
  void clearUser() => $_clearField(10);
  @$pb.TagNumber(10)
  UserText ensureUser() => $_ensure(4);

  @$pb.TagNumber(11)
  Markdown get markdown => $_getN(5);
  @$pb.TagNumber(11)
  set markdown(Markdown value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasMarkdown() => $_has(5);
  @$pb.TagNumber(11)
  void clearMarkdown() => $_clearField(11);
  @$pb.TagNumber(11)
  Markdown ensureMarkdown() => $_ensure(5);

  @$pb.TagNumber(12)
  ToolCard get tool => $_getN(6);
  @$pb.TagNumber(12)
  set tool(ToolCard value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasTool() => $_has(6);
  @$pb.TagNumber(12)
  void clearTool() => $_clearField(12);
  @$pb.TagNumber(12)
  ToolCard ensureTool() => $_ensure(6);

  @$pb.TagNumber(13)
  Thinking get thinking => $_getN(7);
  @$pb.TagNumber(13)
  set thinking(Thinking value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasThinking() => $_has(7);
  @$pb.TagNumber(13)
  void clearThinking() => $_clearField(13);
  @$pb.TagNumber(13)
  Thinking ensureThinking() => $_ensure(7);

  @$pb.TagNumber(14)
  Notice get notice => $_getN(8);
  @$pb.TagNumber(14)
  set notice(Notice value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasNotice() => $_has(8);
  @$pb.TagNumber(14)
  void clearNotice() => $_clearField(14);
  @$pb.TagNumber(14)
  Notice ensureNotice() => $_ensure(8);

  @$pb.TagNumber(15)
  ResultSummary get result => $_getN(9);
  @$pb.TagNumber(15)
  set result(ResultSummary value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasResult() => $_has(9);
  @$pb.TagNumber(15)
  void clearResult() => $_clearField(15);
  @$pb.TagNumber(15)
  ResultSummary ensureResult() => $_ensure(9);
}

class UserText extends $pb.GeneratedMessage {
  factory UserText({
    $core.String? text,
  }) {
    final result = UserText._();
    if (text != null) result.text = text;
    return result;
  }

  UserText._();

  factory UserText.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserText()..mergeFromBuffer(data, registry);
  factory UserText.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserText()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserText',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: UserText.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserText clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserText copyWith(void Function(UserText) updates) =>
      super.copyWith((message) => updates(message as UserText)) as UserText;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserText() / UserText.new instead')
  static UserText create() => UserText._();
  static $pb.GeneratedMessage $_createMessage() => UserText._();
  @$core.override
  UserText createEmptyInstance() => UserText._();
  @$core.pragma('dart2js:noInline')
  static UserText getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserText>(UserText.$_createMessage);
  static UserText? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
}

class Markdown extends $pb.GeneratedMessage {
  factory Markdown({
    $core.Iterable<Block>? blocks,
    $core.bool? streaming,
  }) {
    final result = Markdown._();
    if (blocks != null) result.blocks.addAll(blocks);
    if (streaming != null) result.streaming = streaming;
    return result;
  }

  Markdown._();

  factory Markdown.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Markdown()..mergeFromBuffer(data, registry);
  factory Markdown.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Markdown()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Markdown',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Markdown.$_createMessage)
    ..pPM<Block>(1, _omitFieldNames ? '' : 'blocks',
        subBuilder: Block.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'streaming')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Markdown clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Markdown copyWith(void Function(Markdown) updates) =>
      super.copyWith((message) => updates(message as Markdown)) as Markdown;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Markdown() / Markdown.new instead')
  static Markdown create() => Markdown._();
  static $pb.GeneratedMessage $_createMessage() => Markdown._();
  @$core.override
  Markdown createEmptyInstance() => Markdown._();
  @$core.pragma('dart2js:noInline')
  static Markdown getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Markdown>(Markdown.$_createMessage);
  static Markdown? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Block> get blocks => $_getList(0);

  /// True while text is still arriving.
  @$pb.TagNumber(2)
  $core.bool get streaming => $_getBF(1);
  @$pb.TagNumber(2)
  set streaming($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStreaming() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreaming() => $_clearField(2);
}

class Thinking extends $pb.GeneratedMessage {
  factory Thinking({
    $core.String? text,
    $core.bool? streaming,
  }) {
    final result = Thinking._();
    if (text != null) result.text = text;
    if (streaming != null) result.streaming = streaming;
    return result;
  }

  Thinking._();

  factory Thinking.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Thinking()..mergeFromBuffer(data, registry);
  factory Thinking.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Thinking()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Thinking',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Thinking.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOB(2, _omitFieldNames ? '' : 'streaming')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Thinking clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Thinking copyWith(void Function(Thinking) updates) =>
      super.copyWith((message) => updates(message as Thinking)) as Thinking;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Thinking() / Thinking.new instead')
  static Thinking create() => Thinking._();
  static $pb.GeneratedMessage $_createMessage() => Thinking._();
  @$core.override
  Thinking createEmptyInstance() => Thinking._();
  @$core.pragma('dart2js:noInline')
  static Thinking getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Thinking>(Thinking.$_createMessage);
  static Thinking? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get streaming => $_getBF(1);
  @$pb.TagNumber(2)
  set streaming($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStreaming() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreaming() => $_clearField(2);
}

class Notice extends $pb.GeneratedMessage {
  factory Notice({
    Notice_Level? level,
    $core.String? text,
  }) {
    final result = Notice._();
    if (level != null) result.level = level;
    if (text != null) result.text = text;
    return result;
  }

  Notice._();

  factory Notice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Notice()..mergeFromBuffer(data, registry);
  factory Notice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Notice()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Notice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Notice.$_createMessage)
    ..aE<Notice_Level>(1, _omitFieldNames ? '' : 'level',
        enumValues: Notice_Level.values)
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Notice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Notice copyWith(void Function(Notice) updates) =>
      super.copyWith((message) => updates(message as Notice)) as Notice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Notice() / Notice.new instead')
  static Notice create() => Notice._();
  static $pb.GeneratedMessage $_createMessage() => Notice._();
  @$core.override
  Notice createEmptyInstance() => Notice._();
  @$core.pragma('dart2js:noInline')
  static Notice getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Notice>(Notice.$_createMessage);
  static Notice? _defaultInstance;

  @$pb.TagNumber(1)
  Notice_Level get level => $_getN(0);
  @$pb.TagNumber(1)
  set level(Notice_Level value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLevel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);
}

class ResultSummary extends $pb.GeneratedMessage {
  factory ResultSummary({
    $core.bool? isError,
    $core.String? subtype,
    $core.int? numTurns,
    $fixnum.Int64? durationMs,
    $core.double? costUsd,
  }) {
    final result = ResultSummary._();
    if (isError != null) result.isError = isError;
    if (subtype != null) result.subtype = subtype;
    if (numTurns != null) result.numTurns = numTurns;
    if (durationMs != null) result.durationMs = durationMs;
    if (costUsd != null) result.costUsd = costUsd;
    return result;
  }

  ResultSummary._();

  factory ResultSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResultSummary()..mergeFromBuffer(data, registry);
  factory ResultSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResultSummary()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResultSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ResultSummary.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'isError')
    ..aOS(2, _omitFieldNames ? '' : 'subtype')
    ..aI(3, _omitFieldNames ? '' : 'numTurns')
    ..aInt64(4, _omitFieldNames ? '' : 'durationMs')
    ..aD(5, _omitFieldNames ? '' : 'costUsd')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResultSummary copyWith(void Function(ResultSummary) updates) =>
      super.copyWith((message) => updates(message as ResultSummary))
          as ResultSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ResultSummary() / ResultSummary.new instead')
  static ResultSummary create() => ResultSummary._();
  static $pb.GeneratedMessage $_createMessage() => ResultSummary._();
  @$core.override
  ResultSummary createEmptyInstance() => ResultSummary._();
  @$core.pragma('dart2js:noInline')
  static ResultSummary getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ResultSummary>(
          ResultSummary.$_createMessage);
  static ResultSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isError => $_getBF(0);
  @$pb.TagNumber(1)
  set isError($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsError() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsError() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get subtype => $_getSZ(1);
  @$pb.TagNumber(2)
  set subtype($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubtype() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubtype() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get numTurns => $_getIZ(2);
  @$pb.TagNumber(3)
  set numTurns($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNumTurns() => $_has(2);
  @$pb.TagNumber(3)
  void clearNumTurns() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get durationMs => $_getI64(3);
  @$pb.TagNumber(4)
  set durationMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get costUsd => $_getN(4);
  @$pb.TagNumber(5)
  set costUsd($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCostUsd() => $_has(4);
  @$pb.TagNumber(5)
  void clearCostUsd() => $_clearField(5);
}

class Span extends $pb.GeneratedMessage {
  factory Span({
    $core.String? text,
    $core.bool? bold,
    $core.bool? italic,
    $core.bool? code,
    $core.bool? strike,
    $core.String? link,
  }) {
    final result = Span._();
    if (text != null) result.text = text;
    if (bold != null) result.bold = bold;
    if (italic != null) result.italic = italic;
    if (code != null) result.code = code;
    if (strike != null) result.strike = strike;
    if (link != null) result.link = link;
    return result;
  }

  Span._();

  factory Span.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Span()..mergeFromBuffer(data, registry);
  factory Span.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Span()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Span',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Span.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOB(2, _omitFieldNames ? '' : 'bold')
    ..aOB(3, _omitFieldNames ? '' : 'italic')
    ..aOB(4, _omitFieldNames ? '' : 'code')
    ..aOB(5, _omitFieldNames ? '' : 'strike')
    ..aOS(6, _omitFieldNames ? '' : 'link')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Span clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Span copyWith(void Function(Span) updates) =>
      super.copyWith((message) => updates(message as Span)) as Span;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Span() / Span.new instead')
  static Span create() => Span._();
  static $pb.GeneratedMessage $_createMessage() => Span._();
  @$core.override
  Span createEmptyInstance() => Span._();
  @$core.pragma('dart2js:noInline')
  static Span getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Span>(Span.$_createMessage);
  static Span? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get bold => $_getBF(1);
  @$pb.TagNumber(2)
  set bold($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBold() => $_has(1);
  @$pb.TagNumber(2)
  void clearBold() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get italic => $_getBF(2);
  @$pb.TagNumber(3)
  set italic($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasItalic() => $_has(2);
  @$pb.TagNumber(3)
  void clearItalic() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get code => $_getBF(3);
  @$pb.TagNumber(4)
  set code($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearCode() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get strike => $_getBF(4);
  @$pb.TagNumber(5)
  set strike($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStrike() => $_has(4);
  @$pb.TagNumber(5)
  void clearStrike() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get link => $_getSZ(5);
  @$pb.TagNumber(6)
  set link($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLink() => $_has(5);
  @$pb.TagNumber(6)
  void clearLink() => $_clearField(6);
}

enum Block_Kind {
  heading,
  paragraph,
  list,
  code,
  table,
  quote,
  divider,
  image,
  notSet
}

class Block extends $pb.GeneratedMessage {
  factory Block({
    Heading? heading,
    Paragraph? paragraph,
    ListBlock? list,
    CodeBlock? code,
    Table? table,
    Quote? quote,
    Divider? divider,
    Image? image,
  }) {
    final result = Block._();
    if (heading != null) result.heading = heading;
    if (paragraph != null) result.paragraph = paragraph;
    if (list != null) result.list = list;
    if (code != null) result.code = code;
    if (table != null) result.table = table;
    if (quote != null) result.quote = quote;
    if (divider != null) result.divider = divider;
    if (image != null) result.image = image;
    return result;
  }

  Block._();

  factory Block.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Block()..mergeFromBuffer(data, registry);
  factory Block.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Block()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Block_Kind> _Block_KindByTag = {
    1: Block_Kind.heading,
    2: Block_Kind.paragraph,
    3: Block_Kind.list,
    4: Block_Kind.code,
    5: Block_Kind.table,
    6: Block_Kind.quote,
    7: Block_Kind.divider,
    8: Block_Kind.image,
    0: Block_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Block',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Block.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8])
    ..aOM<Heading>(1, _omitFieldNames ? '' : 'heading',
        subBuilder: Heading.$_createMessage)
    ..aOM<Paragraph>(2, _omitFieldNames ? '' : 'paragraph',
        subBuilder: Paragraph.$_createMessage)
    ..aOM<ListBlock>(3, _omitFieldNames ? '' : 'list',
        subBuilder: ListBlock.$_createMessage)
    ..aOM<CodeBlock>(4, _omitFieldNames ? '' : 'code',
        subBuilder: CodeBlock.$_createMessage)
    ..aOM<Table>(5, _omitFieldNames ? '' : 'table',
        subBuilder: Table.$_createMessage)
    ..aOM<Quote>(6, _omitFieldNames ? '' : 'quote',
        subBuilder: Quote.$_createMessage)
    ..aOM<Divider>(7, _omitFieldNames ? '' : 'divider',
        subBuilder: Divider.$_createMessage)
    ..aOM<Image>(8, _omitFieldNames ? '' : 'image',
        subBuilder: Image.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Block clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Block copyWith(void Function(Block) updates) =>
      super.copyWith((message) => updates(message as Block)) as Block;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Block() / Block.new instead')
  static Block create() => Block._();
  static $pb.GeneratedMessage $_createMessage() => Block._();
  @$core.override
  Block createEmptyInstance() => Block._();
  @$core.pragma('dart2js:noInline')
  static Block getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Block>(Block.$_createMessage);
  static Block? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  Block_Kind whichKind() => _Block_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Heading get heading => $_getN(0);
  @$pb.TagNumber(1)
  set heading(Heading value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHeading() => $_has(0);
  @$pb.TagNumber(1)
  void clearHeading() => $_clearField(1);
  @$pb.TagNumber(1)
  Heading ensureHeading() => $_ensure(0);

  @$pb.TagNumber(2)
  Paragraph get paragraph => $_getN(1);
  @$pb.TagNumber(2)
  set paragraph(Paragraph value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasParagraph() => $_has(1);
  @$pb.TagNumber(2)
  void clearParagraph() => $_clearField(2);
  @$pb.TagNumber(2)
  Paragraph ensureParagraph() => $_ensure(1);

  @$pb.TagNumber(3)
  ListBlock get list => $_getN(2);
  @$pb.TagNumber(3)
  set list(ListBlock value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasList() => $_has(2);
  @$pb.TagNumber(3)
  void clearList() => $_clearField(3);
  @$pb.TagNumber(3)
  ListBlock ensureList() => $_ensure(2);

  @$pb.TagNumber(4)
  CodeBlock get code => $_getN(3);
  @$pb.TagNumber(4)
  set code(CodeBlock value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearCode() => $_clearField(4);
  @$pb.TagNumber(4)
  CodeBlock ensureCode() => $_ensure(3);

  @$pb.TagNumber(5)
  Table get table => $_getN(4);
  @$pb.TagNumber(5)
  set table(Table value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTable() => $_has(4);
  @$pb.TagNumber(5)
  void clearTable() => $_clearField(5);
  @$pb.TagNumber(5)
  Table ensureTable() => $_ensure(4);

  @$pb.TagNumber(6)
  Quote get quote => $_getN(5);
  @$pb.TagNumber(6)
  set quote(Quote value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasQuote() => $_has(5);
  @$pb.TagNumber(6)
  void clearQuote() => $_clearField(6);
  @$pb.TagNumber(6)
  Quote ensureQuote() => $_ensure(5);

  @$pb.TagNumber(7)
  Divider get divider => $_getN(6);
  @$pb.TagNumber(7)
  set divider(Divider value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDivider() => $_has(6);
  @$pb.TagNumber(7)
  void clearDivider() => $_clearField(7);
  @$pb.TagNumber(7)
  Divider ensureDivider() => $_ensure(6);

  @$pb.TagNumber(8)
  Image get image => $_getN(7);
  @$pb.TagNumber(8)
  set image(Image value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasImage() => $_has(7);
  @$pb.TagNumber(8)
  void clearImage() => $_clearField(8);
  @$pb.TagNumber(8)
  Image ensureImage() => $_ensure(7);
}

class Heading extends $pb.GeneratedMessage {
  factory Heading({
    $core.int? level,
    $core.Iterable<Span>? spans,
  }) {
    final result = Heading._();
    if (level != null) result.level = level;
    if (spans != null) result.spans.addAll(spans);
    return result;
  }

  Heading._();

  factory Heading.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Heading()..mergeFromBuffer(data, registry);
  factory Heading.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Heading()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Heading',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Heading.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'level')
    ..pPM<Span>(2, _omitFieldNames ? '' : 'spans',
        subBuilder: Span.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heading clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heading copyWith(void Function(Heading) updates) =>
      super.copyWith((message) => updates(message as Heading)) as Heading;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Heading() / Heading.new instead')
  static Heading create() => Heading._();
  static $pb.GeneratedMessage $_createMessage() => Heading._();
  @$core.override
  Heading createEmptyInstance() => Heading._();
  @$core.pragma('dart2js:noInline')
  static Heading getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Heading>(Heading.$_createMessage);
  static Heading? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get level => $_getIZ(0);
  @$pb.TagNumber(1)
  set level($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLevel() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Span> get spans => $_getList(1);
}

class Paragraph extends $pb.GeneratedMessage {
  factory Paragraph({
    $core.Iterable<Span>? spans,
  }) {
    final result = Paragraph._();
    if (spans != null) result.spans.addAll(spans);
    return result;
  }

  Paragraph._();

  factory Paragraph.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Paragraph()..mergeFromBuffer(data, registry);
  factory Paragraph.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Paragraph()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Paragraph',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Paragraph.$_createMessage)
    ..pPM<Span>(1, _omitFieldNames ? '' : 'spans',
        subBuilder: Span.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Paragraph clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Paragraph copyWith(void Function(Paragraph) updates) =>
      super.copyWith((message) => updates(message as Paragraph)) as Paragraph;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Paragraph() / Paragraph.new instead')
  static Paragraph create() => Paragraph._();
  static $pb.GeneratedMessage $_createMessage() => Paragraph._();
  @$core.override
  Paragraph createEmptyInstance() => Paragraph._();
  @$core.pragma('dart2js:noInline')
  static Paragraph getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Paragraph>(Paragraph.$_createMessage);
  static Paragraph? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Span> get spans => $_getList(0);
}

class ListBlock extends $pb.GeneratedMessage {
  factory ListBlock({
    $core.bool? ordered,
    $core.int? start,
    $core.Iterable<ListItem>? items,
  }) {
    final result = ListBlock._();
    if (ordered != null) result.ordered = ordered;
    if (start != null) result.start = start;
    if (items != null) result.items.addAll(items);
    return result;
  }

  ListBlock._();

  factory ListBlock.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBlock()..mergeFromBuffer(data, registry);
  factory ListBlock.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBlock()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBlock',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ListBlock.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ordered')
    ..aI(2, _omitFieldNames ? '' : 'start')
    ..pPM<ListItem>(3, _omitFieldNames ? '' : 'items',
        subBuilder: ListItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBlock clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBlock copyWith(void Function(ListBlock) updates) =>
      super.copyWith((message) => updates(message as ListBlock)) as ListBlock;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListBlock() / ListBlock.new instead')
  static ListBlock create() => ListBlock._();
  static $pb.GeneratedMessage $_createMessage() => ListBlock._();
  @$core.override
  ListBlock createEmptyInstance() => ListBlock._();
  @$core.pragma('dart2js:noInline')
  static ListBlock getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBlock>(ListBlock.$_createMessage);
  static ListBlock? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ordered => $_getBF(0);
  @$pb.TagNumber(1)
  set ordered($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrdered() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrdered() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get start => $_getIZ(1);
  @$pb.TagNumber(2)
  set start($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStart() => $_has(1);
  @$pb.TagNumber(2)
  void clearStart() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<ListItem> get items => $_getList(2);
}

class ListItem extends $pb.GeneratedMessage {
  factory ListItem({
    $core.bool? checked,
    $core.Iterable<Block>? blocks,
  }) {
    final result = ListItem._();
    if (checked != null) result.checked = checked;
    if (blocks != null) result.blocks.addAll(blocks);
    return result;
  }

  ListItem._();

  factory ListItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListItem()..mergeFromBuffer(data, registry);
  factory ListItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ListItem.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'checked')
    ..pPM<Block>(2, _omitFieldNames ? '' : 'blocks',
        subBuilder: Block.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListItem copyWith(void Function(ListItem) updates) =>
      super.copyWith((message) => updates(message as ListItem)) as ListItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListItem() / ListItem.new instead')
  static ListItem create() => ListItem._();
  static $pb.GeneratedMessage $_createMessage() => ListItem._();
  @$core.override
  ListItem createEmptyInstance() => ListItem._();
  @$core.pragma('dart2js:noInline')
  static ListItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListItem>(ListItem.$_createMessage);
  static ListItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get checked => $_getBF(0);
  @$pb.TagNumber(1)
  set checked($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChecked() => $_has(0);
  @$pb.TagNumber(1)
  void clearChecked() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Block> get blocks => $_getList(1);
}

class CodeBlock extends $pb.GeneratedMessage {
  factory CodeBlock({
    $core.String? lang,
    $core.String? text,
  }) {
    final result = CodeBlock._();
    if (lang != null) result.lang = lang;
    if (text != null) result.text = text;
    return result;
  }

  CodeBlock._();

  factory CodeBlock.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CodeBlock()..mergeFromBuffer(data, registry);
  factory CodeBlock.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CodeBlock()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CodeBlock',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: CodeBlock.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'lang')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CodeBlock clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CodeBlock copyWith(void Function(CodeBlock) updates) =>
      super.copyWith((message) => updates(message as CodeBlock)) as CodeBlock;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CodeBlock() / CodeBlock.new instead')
  static CodeBlock create() => CodeBlock._();
  static $pb.GeneratedMessage $_createMessage() => CodeBlock._();
  @$core.override
  CodeBlock createEmptyInstance() => CodeBlock._();
  @$core.pragma('dart2js:noInline')
  static CodeBlock getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CodeBlock>(CodeBlock.$_createMessage);
  static CodeBlock? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get lang => $_getSZ(0);
  @$pb.TagNumber(1)
  set lang($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLang() => $_has(0);
  @$pb.TagNumber(1)
  void clearLang() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);
}

class Table extends $pb.GeneratedMessage {
  factory Table({
    $core.Iterable<Table_Align>? align,
    $core.Iterable<TableCell>? header,
    $core.Iterable<TableRow>? rows,
  }) {
    final result = Table._();
    if (align != null) result.align.addAll(align);
    if (header != null) result.header.addAll(header);
    if (rows != null) result.rows.addAll(rows);
    return result;
  }

  Table._();

  factory Table.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Table()..mergeFromBuffer(data, registry);
  factory Table.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Table()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Table',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Table.$_createMessage)
    ..pc<Table_Align>(1, _omitFieldNames ? '' : 'align', $pb.PbFieldType.KE,
        valueOf: Table_Align.valueOf,
        enumValues: Table_Align.values,
        defaultEnumValue: Table_Align.ALIGN_UNSPECIFIED)
    ..pPM<TableCell>(2, _omitFieldNames ? '' : 'header',
        subBuilder: TableCell.$_createMessage)
    ..pPM<TableRow>(3, _omitFieldNames ? '' : 'rows',
        subBuilder: TableRow.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Table clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Table copyWith(void Function(Table) updates) =>
      super.copyWith((message) => updates(message as Table)) as Table;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Table() / Table.new instead')
  static Table create() => Table._();
  static $pb.GeneratedMessage $_createMessage() => Table._();
  @$core.override
  Table createEmptyInstance() => Table._();
  @$core.pragma('dart2js:noInline')
  static Table getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Table>(Table.$_createMessage);
  static Table? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Table_Align> get align => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<TableCell> get header => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<TableRow> get rows => $_getList(2);
}

class TableRow extends $pb.GeneratedMessage {
  factory TableRow({
    $core.Iterable<TableCell>? cells,
  }) {
    final result = TableRow._();
    if (cells != null) result.cells.addAll(cells);
    return result;
  }

  TableRow._();

  factory TableRow.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TableRow()..mergeFromBuffer(data, registry);
  factory TableRow.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TableRow()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TableRow',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: TableRow.$_createMessage)
    ..pPM<TableCell>(1, _omitFieldNames ? '' : 'cells',
        subBuilder: TableCell.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TableRow clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TableRow copyWith(void Function(TableRow) updates) =>
      super.copyWith((message) => updates(message as TableRow)) as TableRow;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TableRow() / TableRow.new instead')
  static TableRow create() => TableRow._();
  static $pb.GeneratedMessage $_createMessage() => TableRow._();
  @$core.override
  TableRow createEmptyInstance() => TableRow._();
  @$core.pragma('dart2js:noInline')
  static TableRow getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TableRow>(TableRow.$_createMessage);
  static TableRow? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TableCell> get cells => $_getList(0);
}

class TableCell extends $pb.GeneratedMessage {
  factory TableCell({
    $core.Iterable<Span>? spans,
  }) {
    final result = TableCell._();
    if (spans != null) result.spans.addAll(spans);
    return result;
  }

  TableCell._();

  factory TableCell.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TableCell()..mergeFromBuffer(data, registry);
  factory TableCell.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TableCell()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TableCell',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: TableCell.$_createMessage)
    ..pPM<Span>(1, _omitFieldNames ? '' : 'spans',
        subBuilder: Span.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TableCell clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TableCell copyWith(void Function(TableCell) updates) =>
      super.copyWith((message) => updates(message as TableCell)) as TableCell;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TableCell() / TableCell.new instead')
  static TableCell create() => TableCell._();
  static $pb.GeneratedMessage $_createMessage() => TableCell._();
  @$core.override
  TableCell createEmptyInstance() => TableCell._();
  @$core.pragma('dart2js:noInline')
  static TableCell getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TableCell>(TableCell.$_createMessage);
  static TableCell? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Span> get spans => $_getList(0);
}

class Quote extends $pb.GeneratedMessage {
  factory Quote({
    $core.Iterable<Block>? blocks,
  }) {
    final result = Quote._();
    if (blocks != null) result.blocks.addAll(blocks);
    return result;
  }

  Quote._();

  factory Quote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Quote()..mergeFromBuffer(data, registry);
  factory Quote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Quote()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Quote',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Quote.$_createMessage)
    ..pPM<Block>(1, _omitFieldNames ? '' : 'blocks',
        subBuilder: Block.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Quote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Quote copyWith(void Function(Quote) updates) =>
      super.copyWith((message) => updates(message as Quote)) as Quote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Quote() / Quote.new instead')
  static Quote create() => Quote._();
  static $pb.GeneratedMessage $_createMessage() => Quote._();
  @$core.override
  Quote createEmptyInstance() => Quote._();
  @$core.pragma('dart2js:noInline')
  static Quote getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Quote>(Quote.$_createMessage);
  static Quote? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Block> get blocks => $_getList(0);
}

class Divider extends $pb.GeneratedMessage {
  factory Divider() => Divider._();

  Divider._();

  factory Divider.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Divider()..mergeFromBuffer(data, registry);
  factory Divider.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Divider()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Divider',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Divider.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Divider clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Divider copyWith(void Function(Divider) updates) =>
      super.copyWith((message) => updates(message as Divider)) as Divider;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Divider() / Divider.new instead')
  static Divider create() => Divider._();
  static $pb.GeneratedMessage $_createMessage() => Divider._();
  @$core.override
  Divider createEmptyInstance() => Divider._();
  @$core.pragma('dart2js:noInline')
  static Divider getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Divider>(Divider.$_createMessage);
  static Divider? _defaultInstance;
}

class Image extends $pb.GeneratedMessage {
  factory Image({
    $core.String? url,
    $core.String? alt,
  }) {
    final result = Image._();
    if (url != null) result.url = url;
    if (alt != null) result.alt = alt;
    return result;
  }

  Image._();

  factory Image.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Image()..mergeFromBuffer(data, registry);
  factory Image.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Image()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Image',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Image.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aOS(2, _omitFieldNames ? '' : 'alt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Image clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Image copyWith(void Function(Image) updates) =>
      super.copyWith((message) => updates(message as Image)) as Image;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Image() / Image.new instead')
  static Image create() => Image._();
  static $pb.GeneratedMessage $_createMessage() => Image._();
  @$core.override
  Image createEmptyInstance() => Image._();
  @$core.pragma('dart2js:noInline')
  static Image getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Image>(Image.$_createMessage);
  static Image? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get alt => $_getSZ(1);
  @$pb.TagNumber(2)
  set alt($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAlt() => $_has(1);
  @$pb.TagNumber(2)
  void clearAlt() => $_clearField(2);
}

enum ToolCard_Detail {
  shell,
  edit,
  write,
  read,
  search,
  todos,
  agent,
  web,
  generic,
  notSet
}

class ToolCard extends $pb.GeneratedMessage {
  factory ToolCard({
    $core.String? toolUseId,
    $core.String? name,
    ToolCard_Status? status,
    $core.String? title,
    ShellCard? shell,
    EditCard? edit,
    WriteCard? write,
    ReadCard? read,
    SearchCard? search,
    TodoCard? todos,
    AgentCard? agent,
    WebCard? web,
    GenericCard? generic,
    ToolOutput? output,
  }) {
    final result = ToolCard._();
    if (toolUseId != null) result.toolUseId = toolUseId;
    if (name != null) result.name = name;
    if (status != null) result.status = status;
    if (title != null) result.title = title;
    if (shell != null) result.shell = shell;
    if (edit != null) result.edit = edit;
    if (write != null) result.write = write;
    if (read != null) result.read = read;
    if (search != null) result.search = search;
    if (todos != null) result.todos = todos;
    if (agent != null) result.agent = agent;
    if (web != null) result.web = web;
    if (generic != null) result.generic = generic;
    if (output != null) result.output = output;
    return result;
  }

  ToolCard._();

  factory ToolCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ToolCard()..mergeFromBuffer(data, registry);
  factory ToolCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ToolCard()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ToolCard_Detail> _ToolCard_DetailByTag = {
    10: ToolCard_Detail.shell,
    11: ToolCard_Detail.edit,
    12: ToolCard_Detail.write,
    13: ToolCard_Detail.read,
    14: ToolCard_Detail.search,
    15: ToolCard_Detail.todos,
    16: ToolCard_Detail.agent,
    17: ToolCard_Detail.web,
    18: ToolCard_Detail.generic,
    0: ToolCard_Detail.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ToolCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ToolCard.$_createMessage)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18])
    ..aOS(1, _omitFieldNames ? '' : 'toolUseId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<ToolCard_Status>(3, _omitFieldNames ? '' : 'status',
        enumValues: ToolCard_Status.values)
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOM<ShellCard>(10, _omitFieldNames ? '' : 'shell',
        subBuilder: ShellCard.$_createMessage)
    ..aOM<EditCard>(11, _omitFieldNames ? '' : 'edit',
        subBuilder: EditCard.$_createMessage)
    ..aOM<WriteCard>(12, _omitFieldNames ? '' : 'write',
        subBuilder: WriteCard.$_createMessage)
    ..aOM<ReadCard>(13, _omitFieldNames ? '' : 'read',
        subBuilder: ReadCard.$_createMessage)
    ..aOM<SearchCard>(14, _omitFieldNames ? '' : 'search',
        subBuilder: SearchCard.$_createMessage)
    ..aOM<TodoCard>(15, _omitFieldNames ? '' : 'todos',
        subBuilder: TodoCard.$_createMessage)
    ..aOM<AgentCard>(16, _omitFieldNames ? '' : 'agent',
        subBuilder: AgentCard.$_createMessage)
    ..aOM<WebCard>(17, _omitFieldNames ? '' : 'web',
        subBuilder: WebCard.$_createMessage)
    ..aOM<GenericCard>(18, _omitFieldNames ? '' : 'generic',
        subBuilder: GenericCard.$_createMessage)
    ..aOM<ToolOutput>(30, _omitFieldNames ? '' : 'output',
        subBuilder: ToolOutput.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToolCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToolCard copyWith(void Function(ToolCard) updates) =>
      super.copyWith((message) => updates(message as ToolCard)) as ToolCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ToolCard() / ToolCard.new instead')
  static ToolCard create() => ToolCard._();
  static $pb.GeneratedMessage $_createMessage() => ToolCard._();
  @$core.override
  ToolCard createEmptyInstance() => ToolCard._();
  @$core.pragma('dart2js:noInline')
  static ToolCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ToolCard>(ToolCard.$_createMessage);
  static ToolCard? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  ToolCard_Detail whichDetail() => _ToolCard_DetailByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  void clearDetail() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get toolUseId => $_getSZ(0);
  @$pb.TagNumber(1)
  set toolUseId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToolUseId() => $_has(0);
  @$pb.TagNumber(1)
  void clearToolUseId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  ToolCard_Status get status => $_getN(2);
  @$pb.TagNumber(3)
  set status(ToolCard_Status value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearStatus() => $_clearField(3);

  /// Short human summary, e.g. the Bash description or the file path.
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(10)
  ShellCard get shell => $_getN(4);
  @$pb.TagNumber(10)
  set shell(ShellCard value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasShell() => $_has(4);
  @$pb.TagNumber(10)
  void clearShell() => $_clearField(10);
  @$pb.TagNumber(10)
  ShellCard ensureShell() => $_ensure(4);

  @$pb.TagNumber(11)
  EditCard get edit => $_getN(5);
  @$pb.TagNumber(11)
  set edit(EditCard value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasEdit() => $_has(5);
  @$pb.TagNumber(11)
  void clearEdit() => $_clearField(11);
  @$pb.TagNumber(11)
  EditCard ensureEdit() => $_ensure(5);

  @$pb.TagNumber(12)
  WriteCard get write => $_getN(6);
  @$pb.TagNumber(12)
  set write(WriteCard value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasWrite() => $_has(6);
  @$pb.TagNumber(12)
  void clearWrite() => $_clearField(12);
  @$pb.TagNumber(12)
  WriteCard ensureWrite() => $_ensure(6);

  @$pb.TagNumber(13)
  ReadCard get read => $_getN(7);
  @$pb.TagNumber(13)
  set read(ReadCard value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRead() => $_has(7);
  @$pb.TagNumber(13)
  void clearRead() => $_clearField(13);
  @$pb.TagNumber(13)
  ReadCard ensureRead() => $_ensure(7);

  @$pb.TagNumber(14)
  SearchCard get search => $_getN(8);
  @$pb.TagNumber(14)
  set search(SearchCard value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasSearch() => $_has(8);
  @$pb.TagNumber(14)
  void clearSearch() => $_clearField(14);
  @$pb.TagNumber(14)
  SearchCard ensureSearch() => $_ensure(8);

  @$pb.TagNumber(15)
  TodoCard get todos => $_getN(9);
  @$pb.TagNumber(15)
  set todos(TodoCard value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasTodos() => $_has(9);
  @$pb.TagNumber(15)
  void clearTodos() => $_clearField(15);
  @$pb.TagNumber(15)
  TodoCard ensureTodos() => $_ensure(9);

  @$pb.TagNumber(16)
  AgentCard get agent => $_getN(10);
  @$pb.TagNumber(16)
  set agent(AgentCard value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasAgent() => $_has(10);
  @$pb.TagNumber(16)
  void clearAgent() => $_clearField(16);
  @$pb.TagNumber(16)
  AgentCard ensureAgent() => $_ensure(10);

  @$pb.TagNumber(17)
  WebCard get web => $_getN(11);
  @$pb.TagNumber(17)
  set web(WebCard value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasWeb() => $_has(11);
  @$pb.TagNumber(17)
  void clearWeb() => $_clearField(17);
  @$pb.TagNumber(17)
  WebCard ensureWeb() => $_ensure(11);

  @$pb.TagNumber(18)
  GenericCard get generic => $_getN(12);
  @$pb.TagNumber(18)
  set generic(GenericCard value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasGeneric() => $_has(12);
  @$pb.TagNumber(18)
  void clearGeneric() => $_clearField(18);
  @$pb.TagNumber(18)
  GenericCard ensureGeneric() => $_ensure(12);

  @$pb.TagNumber(30)
  ToolOutput get output => $_getN(13);
  @$pb.TagNumber(30)
  set output(ToolOutput value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasOutput() => $_has(13);
  @$pb.TagNumber(30)
  void clearOutput() => $_clearField(30);
  @$pb.TagNumber(30)
  ToolOutput ensureOutput() => $_ensure(13);
}

class ToolOutput extends $pb.GeneratedMessage {
  factory ToolOutput({
    $core.String? text,
    $core.bool? isError,
    $core.int? omittedLines,
  }) {
    final result = ToolOutput._();
    if (text != null) result.text = text;
    if (isError != null) result.isError = isError;
    if (omittedLines != null) result.omittedLines = omittedLines;
    return result;
  }

  ToolOutput._();

  factory ToolOutput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ToolOutput()..mergeFromBuffer(data, registry);
  factory ToolOutput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ToolOutput()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ToolOutput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ToolOutput.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOB(2, _omitFieldNames ? '' : 'isError')
    ..aI(3, _omitFieldNames ? '' : 'omittedLines')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToolOutput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToolOutput copyWith(void Function(ToolOutput) updates) =>
      super.copyWith((message) => updates(message as ToolOutput)) as ToolOutput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ToolOutput() / ToolOutput.new instead')
  static ToolOutput create() => ToolOutput._();
  static $pb.GeneratedMessage $_createMessage() => ToolOutput._();
  @$core.override
  ToolOutput createEmptyInstance() => ToolOutput._();
  @$core.pragma('dart2js:noInline')
  static ToolOutput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ToolOutput>(ToolOutput.$_createMessage);
  static ToolOutput? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isError => $_getBF(1);
  @$pb.TagNumber(2)
  set isError($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsError() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsError() => $_clearField(2);

  /// Lines dropped from the middle of text.
  @$pb.TagNumber(3)
  $core.int get omittedLines => $_getIZ(2);
  @$pb.TagNumber(3)
  set omittedLines($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOmittedLines() => $_has(2);
  @$pb.TagNumber(3)
  void clearOmittedLines() => $_clearField(3);
}

class ShellCard extends $pb.GeneratedMessage {
  factory ShellCard({
    $core.String? shell,
    $core.String? command,
    $core.String? description,
  }) {
    final result = ShellCard._();
    if (shell != null) result.shell = shell;
    if (command != null) result.command = command;
    if (description != null) result.description = description;
    return result;
  }

  ShellCard._();

  factory ShellCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShellCard()..mergeFromBuffer(data, registry);
  factory ShellCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShellCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShellCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ShellCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'shell')
    ..aOS(2, _omitFieldNames ? '' : 'command')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShellCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShellCard copyWith(void Function(ShellCard) updates) =>
      super.copyWith((message) => updates(message as ShellCard)) as ShellCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShellCard() / ShellCard.new instead')
  static ShellCard create() => ShellCard._();
  static $pb.GeneratedMessage $_createMessage() => ShellCard._();
  @$core.override
  ShellCard createEmptyInstance() => ShellCard._();
  @$core.pragma('dart2js:noInline')
  static ShellCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShellCard>(ShellCard.$_createMessage);
  static ShellCard? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get shell => $_getSZ(0);
  @$pb.TagNumber(1)
  set shell($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShell() => $_has(0);
  @$pb.TagNumber(1)
  void clearShell() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get command => $_getSZ(1);
  @$pb.TagNumber(2)
  set command($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommand() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommand() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);
}

class EditCard extends $pb.GeneratedMessage {
  factory EditCard({
    $core.String? path,
    $core.String? unifiedDiff,
    $core.int? added,
    $core.int? removed,
  }) {
    final result = EditCard._();
    if (path != null) result.path = path;
    if (unifiedDiff != null) result.unifiedDiff = unifiedDiff;
    if (added != null) result.added = added;
    if (removed != null) result.removed = removed;
    return result;
  }

  EditCard._();

  factory EditCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EditCard()..mergeFromBuffer(data, registry);
  factory EditCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EditCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: EditCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'unifiedDiff')
    ..aI(3, _omitFieldNames ? '' : 'added')
    ..aI(4, _omitFieldNames ? '' : 'removed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditCard copyWith(void Function(EditCard) updates) =>
      super.copyWith((message) => updates(message as EditCard)) as EditCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EditCard() / EditCard.new instead')
  static EditCard create() => EditCard._();
  static $pb.GeneratedMessage $_createMessage() => EditCard._();
  @$core.override
  EditCard createEmptyInstance() => EditCard._();
  @$core.pragma('dart2js:noInline')
  static EditCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditCard>(EditCard.$_createMessage);
  static EditCard? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get unifiedDiff => $_getSZ(1);
  @$pb.TagNumber(2)
  set unifiedDiff($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUnifiedDiff() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnifiedDiff() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get added => $_getIZ(2);
  @$pb.TagNumber(3)
  set added($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAdded() => $_has(2);
  @$pb.TagNumber(3)
  void clearAdded() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get removed => $_getIZ(3);
  @$pb.TagNumber(4)
  set removed($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRemoved() => $_has(3);
  @$pb.TagNumber(4)
  void clearRemoved() => $_clearField(4);
}

class WriteCard extends $pb.GeneratedMessage {
  factory WriteCard({
    $core.String? path,
    $core.String? preview,
    $core.int? lines,
  }) {
    final result = WriteCard._();
    if (path != null) result.path = path;
    if (preview != null) result.preview = preview;
    if (lines != null) result.lines = lines;
    return result;
  }

  WriteCard._();

  factory WriteCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteCard()..mergeFromBuffer(data, registry);
  factory WriteCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: WriteCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'preview')
    ..aI(3, _omitFieldNames ? '' : 'lines')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteCard copyWith(void Function(WriteCard) updates) =>
      super.copyWith((message) => updates(message as WriteCard)) as WriteCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WriteCard() / WriteCard.new instead')
  static WriteCard create() => WriteCard._();
  static $pb.GeneratedMessage $_createMessage() => WriteCard._();
  @$core.override
  WriteCard createEmptyInstance() => WriteCard._();
  @$core.pragma('dart2js:noInline')
  static WriteCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WriteCard>(WriteCard.$_createMessage);
  static WriteCard? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get preview => $_getSZ(1);
  @$pb.TagNumber(2)
  set preview($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPreview() => $_has(1);
  @$pb.TagNumber(2)
  void clearPreview() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get lines => $_getIZ(2);
  @$pb.TagNumber(3)
  set lines($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLines() => $_has(2);
  @$pb.TagNumber(3)
  void clearLines() => $_clearField(3);
}

class ReadCard extends $pb.GeneratedMessage {
  factory ReadCard({
    $core.String? path,
    $core.int? offset,
    $core.int? limit,
  }) {
    final result = ReadCard._();
    if (path != null) result.path = path;
    if (offset != null) result.offset = offset;
    if (limit != null) result.limit = limit;
    return result;
  }

  ReadCard._();

  factory ReadCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReadCard()..mergeFromBuffer(data, registry);
  factory ReadCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReadCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReadCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: ReadCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aI(2, _omitFieldNames ? '' : 'offset')
    ..aI(3, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadCard copyWith(void Function(ReadCard) updates) =>
      super.copyWith((message) => updates(message as ReadCard)) as ReadCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReadCard() / ReadCard.new instead')
  static ReadCard create() => ReadCard._();
  static $pb.GeneratedMessage $_createMessage() => ReadCard._();
  @$core.override
  ReadCard createEmptyInstance() => ReadCard._();
  @$core.pragma('dart2js:noInline')
  static ReadCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReadCard>(ReadCard.$_createMessage);
  static ReadCard? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

class SearchCard extends $pb.GeneratedMessage {
  factory SearchCard({
    $core.String? pattern,
    $core.String? path,
    $core.String? glob,
  }) {
    final result = SearchCard._();
    if (pattern != null) result.pattern = pattern;
    if (path != null) result.path = path;
    if (glob != null) result.glob = glob;
    return result;
  }

  SearchCard._();

  factory SearchCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchCard()..mergeFromBuffer(data, registry);
  factory SearchCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: SearchCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pattern')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..aOS(3, _omitFieldNames ? '' : 'glob')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchCard copyWith(void Function(SearchCard) updates) =>
      super.copyWith((message) => updates(message as SearchCard)) as SearchCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SearchCard() / SearchCard.new instead')
  static SearchCard create() => SearchCard._();
  static $pb.GeneratedMessage $_createMessage() => SearchCard._();
  @$core.override
  SearchCard createEmptyInstance() => SearchCard._();
  @$core.pragma('dart2js:noInline')
  static SearchCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchCard>(SearchCard.$_createMessage);
  static SearchCard? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pattern => $_getSZ(0);
  @$pb.TagNumber(1)
  set pattern($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPattern() => $_has(0);
  @$pb.TagNumber(1)
  void clearPattern() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get glob => $_getSZ(2);
  @$pb.TagNumber(3)
  set glob($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGlob() => $_has(2);
  @$pb.TagNumber(3)
  void clearGlob() => $_clearField(3);
}

class Todo extends $pb.GeneratedMessage {
  factory Todo({
    $core.String? content,
    Todo_Status? status,
    $core.String? activeForm,
  }) {
    final result = Todo._();
    if (content != null) result.content = content;
    if (status != null) result.status = status;
    if (activeForm != null) result.activeForm = activeForm;
    return result;
  }

  Todo._();

  factory Todo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Todo()..mergeFromBuffer(data, registry);
  factory Todo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Todo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Todo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: Todo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'content')
    ..aE<Todo_Status>(2, _omitFieldNames ? '' : 'status',
        enumValues: Todo_Status.values)
    ..aOS(3, _omitFieldNames ? '' : 'activeForm')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Todo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Todo copyWith(void Function(Todo) updates) =>
      super.copyWith((message) => updates(message as Todo)) as Todo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Todo() / Todo.new instead')
  static Todo create() => Todo._();
  static $pb.GeneratedMessage $_createMessage() => Todo._();
  @$core.override
  Todo createEmptyInstance() => Todo._();
  @$core.pragma('dart2js:noInline')
  static Todo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Todo>(Todo.$_createMessage);
  static Todo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get content => $_getSZ(0);
  @$pb.TagNumber(1)
  set content($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => $_clearField(1);

  @$pb.TagNumber(2)
  Todo_Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(Todo_Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get activeForm => $_getSZ(2);
  @$pb.TagNumber(3)
  set activeForm($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveForm() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveForm() => $_clearField(3);
}

class TodoCard extends $pb.GeneratedMessage {
  factory TodoCard({
    $core.Iterable<Todo>? todos,
  }) {
    final result = TodoCard._();
    if (todos != null) result.todos.addAll(todos);
    return result;
  }

  TodoCard._();

  factory TodoCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TodoCard()..mergeFromBuffer(data, registry);
  factory TodoCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TodoCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TodoCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: TodoCard.$_createMessage)
    ..pPM<Todo>(1, _omitFieldNames ? '' : 'todos',
        subBuilder: Todo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TodoCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TodoCard copyWith(void Function(TodoCard) updates) =>
      super.copyWith((message) => updates(message as TodoCard)) as TodoCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TodoCard() / TodoCard.new instead')
  static TodoCard create() => TodoCard._();
  static $pb.GeneratedMessage $_createMessage() => TodoCard._();
  @$core.override
  TodoCard createEmptyInstance() => TodoCard._();
  @$core.pragma('dart2js:noInline')
  static TodoCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TodoCard>(TodoCard.$_createMessage);
  static TodoCard? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Todo> get todos => $_getList(0);
}

class AgentCard extends $pb.GeneratedMessage {
  factory AgentCard({
    $core.String? description,
    $core.String? subagentType,
    $core.String? prompt,
  }) {
    final result = AgentCard._();
    if (description != null) result.description = description;
    if (subagentType != null) result.subagentType = subagentType;
    if (prompt != null) result.prompt = prompt;
    return result;
  }

  AgentCard._();

  factory AgentCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCard()..mergeFromBuffer(data, registry);
  factory AgentCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: AgentCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'description')
    ..aOS(2, _omitFieldNames ? '' : 'subagentType')
    ..aOS(3, _omitFieldNames ? '' : 'prompt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCard copyWith(void Function(AgentCard) updates) =>
      super.copyWith((message) => updates(message as AgentCard)) as AgentCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentCard() / AgentCard.new instead')
  static AgentCard create() => AgentCard._();
  static $pb.GeneratedMessage $_createMessage() => AgentCard._();
  @$core.override
  AgentCard createEmptyInstance() => AgentCard._();
  @$core.pragma('dart2js:noInline')
  static AgentCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCard>(AgentCard.$_createMessage);
  static AgentCard? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get description => $_getSZ(0);
  @$pb.TagNumber(1)
  set description($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDescription() => $_has(0);
  @$pb.TagNumber(1)
  void clearDescription() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get subagentType => $_getSZ(1);
  @$pb.TagNumber(2)
  set subagentType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubagentType() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubagentType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get prompt => $_getSZ(2);
  @$pb.TagNumber(3)
  set prompt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrompt() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrompt() => $_clearField(3);
}

class WebCard extends $pb.GeneratedMessage {
  factory WebCard({
    $core.String? url,
    $core.String? query,
  }) {
    final result = WebCard._();
    if (url != null) result.url = url;
    if (query != null) result.query = query;
    return result;
  }

  WebCard._();

  factory WebCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WebCard()..mergeFromBuffer(data, registry);
  factory WebCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WebCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WebCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: WebCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aOS(2, _omitFieldNames ? '' : 'query')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WebCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WebCard copyWith(void Function(WebCard) updates) =>
      super.copyWith((message) => updates(message as WebCard)) as WebCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WebCard() / WebCard.new instead')
  static WebCard create() => WebCard._();
  static $pb.GeneratedMessage $_createMessage() => WebCard._();
  @$core.override
  WebCard createEmptyInstance() => WebCard._();
  @$core.pragma('dart2js:noInline')
  static WebCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WebCard>(WebCard.$_createMessage);
  static WebCard? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get query => $_getSZ(1);
  @$pb.TagNumber(2)
  set query($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuery() => $_clearField(2);
}

class GenericCard extends $pb.GeneratedMessage {
  factory GenericCard({
    $core.String? inputJson,
  }) {
    final result = GenericCard._();
    if (inputJson != null) result.inputJson = inputJson;
    return result;
  }

  GenericCard._();

  factory GenericCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenericCard()..mergeFromBuffer(data, registry);
  factory GenericCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenericCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenericCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tether.v1'),
      createEmptyInstance: GenericCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'inputJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenericCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenericCard copyWith(void Function(GenericCard) updates) =>
      super.copyWith((message) => updates(message as GenericCard))
          as GenericCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenericCard() / GenericCard.new instead')
  static GenericCard create() => GenericCard._();
  static $pb.GeneratedMessage $_createMessage() => GenericCard._();
  @$core.override
  GenericCard createEmptyInstance() => GenericCard._();
  @$core.pragma('dart2js:noInline')
  static GenericCard getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenericCard>(
          GenericCard.$_createMessage);
  static GenericCard? _defaultInstance;

  /// Pretty-printed tool input.
  @$pb.TagNumber(1)
  $core.String get inputJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set inputJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInputJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearInputJson() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
