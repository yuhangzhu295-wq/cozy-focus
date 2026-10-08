import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide Pet;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/controllers/growth_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// The adopted pet and the selected companion are two records of one fact.
///
/// ## Found by deleting a pack on a device
///
/// Removing the pack the user was using repairs the *selection* — that is what
/// `CompanionSelectionRepair` is for, and it works. It does not touch the `pets`
/// row, which names the companion too. So after deleting 咪咪二号 the app drew the
/// fallback companion while the growth and dress pages still called it 咪咪二号:
/// one screen reading **咪咪二号 的衣橱** above a picture of Mochi, with the segment
/// chip beside it saying Mochi.
///
/// `GrowthController.syncWithSelection` is that repair, and the removal path calls
/// it. It is deliberately *not* part of loading: the selection restores from its
/// store asynchronously and reads as the default until it has, so reconciling on
/// load would rewrite the user's companion to the default on a slow start. The
/// first version of this did that, and the control test below is what caught it —
/// a stored `cat` came back as `Mochi`.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';

  /// The adopted pet, written straight into the table.
  Future<void> seedPet({
    required String characterId,
    required PetSpecies species,
    required String name,
  }) async {
    await db.petDao.upsertPet(Pet(
      id: 'mochi_pet_id',
      userId: userId,
      characterId: characterId,
      species: species,
      name: name,
      adoptedAt: DateTime(2026, 10, 1),
    ));
  }

  Future<Pet?> petRow() => db.petDao.findPetByUser(userId);

  Future<void> pumpWithSelection(String selected) async {
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(userId),
      // The store carries the selection, which is what the provider reads. A
      // pre-set store is how the other picker tests choose one.
      companionSelectionStoreProvider.overrideWithValue(
          InMemoryCompanionSelectionStore(CompanionId(selected))),
    ]);
    addTearDown(container.dispose);

    // Wait for the selection to settle on the stored id. The provider restores
    // asynchronously *and* is rebuilt when the installed packs finish loading, so
    // one turn is not enough — and a caller has to let that finish before asking
    // anything to agree with it, which is why the reconciliation is an explicit
    // call rather than part of loading. See `GrowthController.syncWithSelection`.
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (container.read(companionSelectionProvider).value == selected) break;
    }
    expect(container.read(companionSelectionProvider).value, selected,
        reason: 'the harness could not settle the selection on "$selected", so '
            'this test would be asserting the wrong thing');

    // `autoDispose` keeps the controller alive while the subscription is held.
    container.listen(growthControllerProvider, (_, __) {});
    await container.read(growthControllerProvider.notifier).syncWithSelection();
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('a pet left over from a deleted pack follows the selection', () async {
    // The device state: the pack is gone, the selection fell back to the dog, and
    // the row still names the pack.
    await seedPet(
      characterId: 'mimi2',
      species: PetSpecies.cat,
      name: '咪咪二号',
    );

    await pumpWithSelection('dog');

    final row = await petRow();
    expect(row!.characterId, 'dog');
    expect(row.name, 'Mochi');
    expect(row.species, PetSpecies.dog);
    expect(container.read(growthControllerProvider).pet!.name, 'Mochi',
        reason: 'the screen reads this, so it has to be the repaired row');
  });

  test('a pet whose companion still exists is left alone', () async {
    // The narrower rule, and the reason for it: a picker sets the selection and
    // then adopts, so the two differ for a moment. Repairing that difference would
    // undo the adoption — which the wider rule did, and the confirm-path tests
    // caught. A companion the app can still draw is not a leftover.
    await seedPet(
      characterId: 'cat',
      species: PetSpecies.cat,
      name: '小猫',
    );

    await pumpWithSelection('dog');

    final row = await petRow();
    expect(row!.characterId, 'cat',
        reason: 'the cat exists, so the row is not stale');
    expect(row.name, '小猫');
  });

  test('a pet that already agrees keeps the name it has', () async {
    // The control, and the one that matters for a user's own name: the import
    // screen asks what to call a pack, so a row whose id already matches the
    // selection must not be rewritten from the profile. Renaming 我的猫猫 to the
    // catalog's name would be the same defect pointing the other way.
    //
    // The id here is a built-in because an installed pack needs a pack root on
    // disk; what is being pinned is the comparison, and it is the same one that
    // protects an imported pack's chosen name.
    await seedPet(
      characterId: 'cat',
      species: PetSpecies.cat,
      name: '我的猫猫',
    );

    await pumpWithSelection('cat');

    final row = await petRow();
    expect(row!.name, '我的猫猫',
        reason: 'the ids agree, so there is nothing to reconcile');
    expect(row.characterId, 'cat');
  });

  test('a load that beats the selection restore writes nothing', () async {
    // The hazard the guard exists for, and the reason the reconciliation is not
    // simply part of loading: `CompanionSelection` reads as the *default* until its
    // store answers, so a load that ran first would rewrite the user's companion to
    // the default. Held open here so the ordering is a state, not a race.
    await seedPet(
      characterId: 'mimi2',
      species: PetSpecies.cat,
      name: '咪咪二号',
    );

    final store = _HeldSelectionStore(const CompanionId('cat'));
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(userId),
      companionSelectionStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    container.listen(growthControllerProvider, (_, __) {});

    await container.read(growthControllerProvider.notifier).loadPetGrowth();

    expect((await petRow())!.name, '咪咪二号',
        reason: 'the selection had not been read yet, so there is nothing to '
            'agree with and nothing to write');

    // Once it has been read, the same load does reconcile.
    store.release();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await container.read(growthControllerProvider.notifier).loadPetGrowth();

    expect((await petRow())!.name, '小猫',
        reason: 'the selection is the cat, so the pet follows it');
    expect((await petRow())!.characterId, 'cat');
  });

  test('and a pet the app never had is not invented', () async {
    // No row at all: the home controller creates the default pet, and this must
    // not race it by writing one of its own.
    await pumpWithSelection('cat');

    expect(await petRow(), isNull);
  });
}

/// A store whose read can be held open, so "the selection has not been read yet"
/// is a state a test can stand in rather than race for.
class _HeldSelectionStore implements CompanionSelectionStore {
  _HeldSelectionStore(this._id);

  final CompanionId _id;
  final Completer<CompanionId?> _read = Completer<CompanionId?>();

  /// Lets the pending read finish.
  void release() => _read.complete(_id);

  @override
  Future<CompanionId?> read() => _read.future;

  @override
  Future<void> write(CompanionId id) async {}
}
