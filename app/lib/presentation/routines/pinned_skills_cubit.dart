import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/usecases.dart';

/// The skills the owner pinned from the Skills screen, shown as chips under
/// the start box on Home. Kept on the device.
class PinnedSkillsCubit extends Cubit<List<String>> {
  PinnedSkillsCubit(this._store) : super(const []);

  final Drafts _store;
  static const _key = 'pinned-skills';

  Future<void> load() async {
    final text = await _store.load(_key);
    if (!isClosed) emit([for (final l in text.split('\n')) if (l.trim().isNotEmpty) l.trim()]);
  }

  Future<void> toggle(String name) async {
    final next = state.contains(name) ? [...state.where((n) => n != name)] : [...state, name];
    emit(next);
    await _store.save(_key, next.join('\n'));
  }
}
