import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/profile/data/entities/user_profile_entity.dart';
import 'package:total_tracker/features/profile/data/repositories/user_profile_repository.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('crea il profilo predefinito se manca', () async {
    final database = await openTestDatabase();
    final repository = UserProfileRepository(database.store);

    final profile = repository.createDefaultProfileIfMissing();

    expect(profile.id, greaterThan(0));
    expect(profile.isActive, isTrue);
    expect(profile.defaultStepGoal, 8000);
    expect(repository.getActiveProfile(), isNotNull);
  });

  test('la seconda esecuzione non crea un duplicato', () async {
    final database = await openTestDatabase();
    final repository = UserProfileRepository(database.store);

    final first = repository.createDefaultProfileIfMissing();
    final second = repository.createDefaultProfileIfMissing();
    final profiles = database.store.box<UserProfileEntity>().getAll();

    expect(second.id, first.id);
    expect(profiles.length, 1);
  });

  test('esiste al massimo un profilo attivo', () async {
    final database = await openTestDatabase();
    final repository = UserProfileRepository(database.store);

    repository.createDefaultProfileIfMissing();
    final replacement = repository.save(
      UserProfileEntity(
        uuid: 'replacement-profile',
        displayName: 'Replacement',
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
    );

    final activeProfiles = database.store
        .box<UserProfileEntity>()
        .getAll()
        .where((UserProfileEntity profile) => profile.isActive)
        .toList();

    expect(activeProfiles.length, 1);
    expect(activeProfiles.single.id, replacement.id);
  });
}
