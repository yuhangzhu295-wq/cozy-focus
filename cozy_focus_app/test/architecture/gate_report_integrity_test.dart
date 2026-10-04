import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The automated gate report must not lie about itself.
///
/// ## Why this is a test and not a convention
///
/// `tools/cozy_gate.py` produces `AUTOMATED_PRODUCT_GATE.json`, and the brief's
/// rule is absolute: **never convert `BLOCKED` into `PASS`**. That rule is easy
/// to keep while everything is green and easy to lose the moment a gate is
/// inconvenient — a summary that counts a blocked gate as passing, a gate
/// function that returns `PASS` because it could not run, a report whose counts
/// stop matching its own rows.
///
/// So the artifact is checked rather than trusted. This reads the committed
/// report and verifies it against itself.
void main() {
  late Map<String, dynamic> report;
  late List<dynamic> gates;

  setUpAll(() {
    final file = File('outputs/ai_handoff/AUTOMATED_PRODUCT_GATE.json');
    expect(file.existsSync(), isTrue,
        reason: 'the gate report must be committed; run '
            'python tools/cozy_gate.py --full');
    report = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    gates = report['gates'] as List<dynamic>;
  });

  test('the counts match the gates they summarise', () {
    // The arithmetic lie: a summary that disagrees with its own rows.
    final counted = <String, int>{};
    for (final g in gates) {
      final s = (g as Map)['status'] as String;
      counted[s] = (counted[s] ?? 0) + 1;
    }
    final declared = Map<String, dynamic>.from(report['counts'] as Map);
    expect(declared, counted,
        reason: 'the summary must be the count of its own rows, not a '
            'separate number that can drift');
  });

  test('no blocked, deferred or untested gate is reported as passing', () {
    // The rule the brief states outright. A gate that could not run is not a
    // gate that passed, and the difference is the whole point of the report.
    for (final g in gates) {
      final row = g as Map;
      final name = row['gate'] as String;
      final status = row['status'] as String;
      expect(
        ['PASS', 'FAIL', 'BLOCKED', 'DEFERRED', 'NOT_TESTED'],
        contains(status),
        reason: '$name has a status outside the agreed vocabulary',
      );
      if (status != 'PASS') {
        expect(row['evidence'], isA<String>());
        expect((row['evidence'] as String).trim(), isNotEmpty,
            reason: '$name is not passing and must say why');
      }
    }
  });

  test('the gates known to be blocked are not green', () {
    // Named explicitly, because these are the three the program has carried for
    // several phases. If one of them ever reports PASS, either it was genuinely
    // resolved or the report is wrong — and the reader deserves to be told which
    // by this failing.
    final byName = {
      for (final g in gates) (g as Map)['gate'] as String: g,
    };
    for (final name in const [
      'RELEASE_SIGNING',
      'LAUNCHER_ICON',
      'FLOW_GENERATION',
    ]) {
      expect(byName, contains(name), reason: '$name must appear in the report');
      expect(byName[name]!['status'], 'BLOCKED',
          reason: '$name was blocked on an owner or an external service. If it '
              'is green now, this test should be updated deliberately rather '
              'than the report quietly changing');
    }
  });

  test('the behaviour-authority gate is present and reports its status', () {
    // This gate was `FAIL` from P19 until D5 was answered, and this test used to
    // assert that literal — so greening it required editing this test on
    // purpose rather than the report changing quietly. That is what happened:
    // P25 D5 decided the room is action-authoritative, the presentation now
    // presents the committed action, and the measured count fell from 2 to 1.
    //
    // It asserts the gate is *present* rather than pinning a status, because
    // what this file exists to protect is that the report never drops or
    // misreports a gate — the verdict itself belongs to the measurement, which
    // `behavior_authority_test.dart` computes.
    final byName = {
      for (final g in gates) (g as Map)['gate'] as String: g,
    };
    expect(byName['BEHAVIOR_AUTHORITY'], isNotNull,
        reason: 'the architecture gate must not be dropped from the report to '
            'make it look cleaner');
    expect(
      ['PASS', 'FAIL'],
      contains(byName['BEHAVIOR_AUTHORITY']!['status']),
      reason: 'this gate is measured, so it is either passing or failing',
    );
  });

  test('the report states whether local matches remote', () {
    expect(report['local_equals_remote'], isA<bool>());
    expect(report['head'], isA<String>());
    expect((report['head'] as String).trim(), isNotEmpty,
        reason: 'a gate report without the revision it describes cannot be '
            'acted on');
  });

  test('a gate that can be measured says it measured', () {
    // The specific lie this report told for several phases: BEHAVIOR_AUTHORITY
    // returned `FAIL` with a hard-coded count, so the gate could never notice
    // the day the count changed. It now runs
    // `test/architecture/behavior_authority_test.dart` and reports the number
    // that measurement printed.
    //
    // The word "measured" is the marker. It is not decoration: it is the claim
    // that a number was derived at run time rather than remembered, and a
    // future edit that goes back to a literal has to delete the word to do it.
    final byName = {
      for (final g in gates) (g as Map)['gate'] as String: g,
    };
    final evidence = byName['BEHAVIOR_AUTHORITY']!['evidence'] as String;
    expect(evidence, contains('measured'),
        reason: 'BEHAVIOR_AUTHORITY must report a measured count, not a '
            'remembered one: $evidence');
    expect(evidence, contains('BEHAVIOR_AUTHORITY_COUNT='),
        reason: 'the evidence must name the count it decided from: $evidence');
  });

  test('a standing gate does not claim to have measured anything', () {
    // The other half of the same honesty rule. These gates report an owner or
    // external state; they cannot be re-run and must not imply otherwise.
    final byName = {
      for (final g in gates) (g as Map)['gate'] as String: g,
    };
    for (final name in const [
      'OWNER_VISUAL_GATE',
      'DEVICE_MATRIX',
      'PRODUCT_DECISIONS',
      'FLOW_GENERATION',
    ]) {
      final evidence = byName[name]!['evidence'] as String;
      expect(evidence, isNot(contains('measured')),
          reason: '$name reports a standing state, so it must not claim a '
              'measurement it did not take: $evidence');
    }
  });
}
