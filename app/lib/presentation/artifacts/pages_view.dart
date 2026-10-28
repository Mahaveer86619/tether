import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../../injection.dart';
import '../hub/hub_cubit.dart';
import '../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

class PagesState extends Equatable {
  const PagesState({this.pages = const [], this.loading = true, this.failure, this.failureId = 0});

  final List<HostedPage> pages;
  final bool loading;
  final Failure? failure;
  final int failureId;

  @override
  List<Object?> get props => [pages, loading, failure, failureId];
}

/// View model for the pages sessions made, all of them or one session's.
class PagesCubit extends Cubit<PagesState> {
  PagesCubit({required this._artifacts}) : super(const PagesState());

  final Artifacts _artifacts;

  Future<void> load({String session = ''}) async {
    emit(PagesState(pages: state.pages, failureId: state.failureId));
    final result = await _artifacts.pages(session: session);
    result.fold(
      (f) => emit(PagesState(pages: state.pages, loading: false, failure: f, failureId: state.failureId + 1)),
      (pages) => emit(PagesState(pages: pages, loading: false, failureId: state.failureId)),
    );
  }
}

/// Pages sessions made, each with Open (in the browser) and Copy link.
class PagesList extends StatelessWidget {
  const PagesList({super.key, this.session = '', this.onSession, this.shrinkWrap = false});

  /// Only this session's pages, when set.
  final String session;
  final ValueChanged<String>? onSession;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<PagesCubit>()..load(session: session),
        child: BlocConsumer<PagesCubit, PagesState>(
          listenWhen: (a, b) => a.failureId != b.failureId && b.failure != null,
          listener: (context, s) => showFailure(context, s.failure!),
          builder: (context, s) {
            if (s.loading && s.pages.isEmpty) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
            }
            if (s.pages.isEmpty) {
              return const EmptyState(
                icon: Icons.web_rounded,
                title: 'No pages yet',
                body: 'Ask Claude to show you something as a web page; pages a session makes are hosted on the hub and listed here.',
              );
            }
            return ListView(
              shrinkWrap: shrinkWrap,
              physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
              children: [for (final p in s.pages) _PageTile(page: p, showSession: session.isEmpty, onSession: onSession)],
            );
          },
        ),
      );
}

class _PageTile extends StatelessWidget {
  const _PageTile({required this.page, required this.showSession, this.onSession});

  final HostedPage page;
  final bool showSession;
  final ValueChanged<String>? onSession;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final from = context.select<HubCubit, Session?>((h) => h.state.hub.sessions[page.session]);
    return ListTile(
      key: ValueKey('page-${page.session}-${page.name}'),
      leading: Icon(Icons.web_rounded, color: c.accent),
      title: Text(page.name),
      subtitle: Text(
        [
          '${page.files} ${page.files == 1 ? 'file' : 'files'}',
          if (page.updated != null) ago(page.updated),
          if (showSession && from != null) from.displayTitle,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: c.faint),
      ),
      onTap: showSession && from != null && onSession != null ? () => onSession!(page.session) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Copy link',
            icon: const Icon(Icons.link_rounded, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: page.url));
              showToast(context, 'Link copied · works for 7 days', icon: Icons.link_rounded);
            },
          ),
          FilledButton.tonalIcon(
            key: Key('open-page-${page.name}'),
            onPressed: () => launchUrl(Uri.parse(page.url), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

/// A session's pages, from its menu.
Future<void> showSessionPages(BuildContext context, String session) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Pages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              Flexible(child: PagesList(session: session, shrinkWrap: true)),
            ],
          ),
        ),
      ),
    );
