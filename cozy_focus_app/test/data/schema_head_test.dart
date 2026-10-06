import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, DistractionNote;

import '../support/schema_head.dart';

/// The head version the migration tests assert against is the app's real head.
///
/// ## Why this guard exists
///
/// [kSchemaHead] exists so adding a migration is a one-line change instead of six
/// — but a constant that nothing checks can silently stop matching the database,
/// and then six migration tests would be asserting a number the app does not
/// declare. This is the one place the two are compared, so the convenience cannot
/// turn into a false green.
void main() {
  test('kSchemaHead is the version AppDatabase declares', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(kSchemaHead, db.schemaVersion,
        reason: 'bump test/support/schema_head.dart when the schema changes');
  });
}
