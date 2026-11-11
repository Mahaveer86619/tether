import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/usecases/usecases.dart';
import 'package:tether/presentation/routines/pinned_skills_cubit.dart';

import '../helpers/fakes.dart';

void main() {
  test('pinned skills are kept in order, unpinned on a second tap, and survive a restart', () async {
    final settings = FakeSettingsRepository();
    final cubit = PinnedSkillsCubit(Drafts(settings));
    await cubit.toggle('build-apk');
    await cubit.toggle('weekly-report');
    expect(cubit.state, ['build-apk', 'weekly-report']);
    await cubit.toggle('build-apk');
    expect(cubit.state, ['weekly-report']);

    final again = PinnedSkillsCubit(Drafts(settings));
    await again.load();
    expect(again.state, ['weekly-report']);
    await cubit.close();
    await again.close();
  });
}
