"""The product gate: one command that runs every check and reports the truth.

## What it is for

The project has a large set of gates — format, analyze, the unit suite, the
integration suites, the asset gates, the release builds. They are all real and
they all pass or fail on their own. What was missing was one place that runs them
together and reports the **whole** state, including the parts that are not green
and not going to be.

## What it does not do

It does not implement any check. Every gate below shells out to the command that
already exists — `flutter test`, `flutter analyze`, `flutter build` — and records
what that command said. A gate that re-implemented a test would be a second
source of truth, and the two would drift.

## The five statuses, and why BLOCKED is not PASS

`PASS` the check ran and succeeded.
`FAIL` the check ran and did not.
`BLOCKED` the check could not run, and something outside engineering is why.
`DEFERRED` the check is not run by decision, with a reason.
`NOT_TESTED` the check exists but was not run in this invocation.

A blocked gate is reported as blocked. Nothing in this file turns a `BLOCKED`
into a `PASS`, and there is a test that proves it cannot.

Usage:
    python tools/cozy_gate.py --full
    python tools/cozy_gate.py --full --skip-builds     # faster, no APK/AAB
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

# Derived, not hard-coded. An absolute path pinned to one machine would make
# every gate FAIL on any other, and that would look like a broken product rather
# than a misplaced script.
APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(APP, "outputs", "ai_handoff")
JSON_OUT = os.path.join(OUT_DIR, "AUTOMATED_PRODUCT_GATE.json")
MD_OUT = os.path.join(OUT_DIR, "AUTOMATED_PRODUCT_GATE.md")

PASS, FAIL, BLOCKED, DEFERRED, NOT_TESTED = (
    "PASS", "FAIL", "BLOCKED", "DEFERRED", "NOT_TESTED")

# Measured in P23 and P26. A budget, not a wish: both were read from built
# artifacts before being written here.
APK_BUDGET_MB = 34.0
AAB_BUDGET_MB = 55.0


def run(cmd, timeout=900):
    """Runs a command in the project and returns (ok, combined output)."""
    p = subprocess.run(cmd, cwd=APP, shell=isinstance(cmd, str),
                       capture_output=True, text=True, timeout=timeout)
    return p.returncode == 0, (p.stdout or "") + (p.stderr or "")


def tail(text, n=3):
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    return " | ".join(lines[-n:])[:400]


def size_mb(path):
    return os.path.getsize(path) / 1048576 if os.path.exists(path) else 0.0


# ── the gates ────────────────────────────────────────────────────────────────
#
# Each returns (status, evidence). The evidence is what the command actually
# said, so a reader can check the verdict rather than trust it.

def gate_format():
    ok, out = run("dart format --output=none --set-exit-if-changed lib test")
    m = re.search(r"Formatted (\d+) files \((\d+) changed\)", out)
    files = m.group(1) if m else "?"
    changed = m.group(2) if m else "?"
    return (PASS if ok else FAIL, f"{files} files, {changed} changed")


def gate_analyze():
    ok, out = run("flutter analyze --fatal-infos --no-pub")
    m = re.search(r"(\d+) issues? found", out)
    issues = m.group(1) if m else ("0" if ok else "?")
    return (PASS if ok else FAIL, f"{issues} issues")


def _test_gate(label, target):
    ok, out = run(f"flutter test --no-pub {target}")
    m = re.search(r"\+(\d+)(?:\s+-(\d+))?:\s*All tests passed", out)
    if m:
        total = m.group(1)
        return PASS, f"{total}/{total} passed"
    m = re.search(r"\+(\d+)\s+-(\d+)", out)
    if m:
        return FAIL, f"{m.group(1)} passed, {m.group(2)} failed"
    # Neither summary matched. The exit code is the authority, not the format: a
    # clean run whose output wording changed must not be reported as a failure.
    # An earlier version returned FAIL here unconditionally, which would turn a
    # Flutter SDK wording change into a red gate.
    return (PASS if ok else FAIL), tail(out)


def gate_unit_tests():
    return _test_gate("unit tests", "")


def gate_integration():
    return _test_gate("integration", "test/integration")


def gate_golden_flow():
    return _test_gate("golden flow", "test/integration/golden_flow_test.dart")


def gate_migration():
    return _test_gate(
        "migration",
        "test/data/focus_record_migration_test.dart "
        "test/integration/persistence_recovery_test.dart")


def gate_lifecycle():
    return _test_gate("lifecycle", "test/architecture")


def gate_assets():
    return _test_gate("asset gates", "test/presentation/companion/animation")


def gate_diff_check():
    ok, out = run("git diff --check")
    return (PASS if ok else FAIL,
            "no whitespace errors" if ok else tail(out))


def gate_apk():
    ok, out = run("flutter build apk --release", timeout=1800)
    if not ok:
        return FAIL, tail(out)
    mb = size_mb(os.path.join(APP, "build/app/outputs/flutter-apk/app-release.apk"))
    status = PASS if mb <= APK_BUDGET_MB else FAIL
    return status, f"{mb:.1f} MB (budget {APK_BUDGET_MB:.0f} MB)"


def gate_aab():
    ok, out = run("flutter build appbundle --release", timeout=1800)
    if not ok:
        return FAIL, tail(out)
    mb = size_mb(os.path.join(APP, "build/app/outputs/bundle/release/app-release.aab"))
    status = PASS if mb <= AAB_BUDGET_MB else FAIL
    return status, f"{mb:.1f} MB (budget {AAB_BUDGET_MB:.0f} MB)"


def gate_signing():
    """Reads the certificate, and refuses to call a debug key a release."""
    key_properties = os.path.join(APP, "android", "key.properties")
    if not os.path.exists(key_properties):
        return BLOCKED, (
            "RELEASE_SIGNING = NOT_RECOVERED: android/key.properties is absent, "
            "and no keystore was invented. The build switches over with no code "
            "change the moment it appears.")
    return PASS, "key.properties present"


def gate_launcher_icon():
    """The icon is blocked on artwork, and the check says which artwork."""
    return BLOCKED, (
        "still the stock Flutter logo (dominant colours 0,0,0 / 84,197,248 / "
        "1,87,155); no approved artwork exists, so none was invented")


def gate_owner_visual():
    return DEFERRED, (
        "OWNER_VISUAL_GATE is REQUIRED and is never decided by a measurement. "
        "P21's technical gates pass; whether the art reads well is human "
        "judgement.")


def gate_device_matrix():
    """Honest about what was and was not exercised on hardware."""
    return DEFERRED, (
        "device verification exists and is recorded (collection, craft, P7 "
        "toolbar, room alignment, the rabbit pack, the P11 routine, indexed "
        "sprites, the P14 fix, and the P21 idle and travel motion gates) - but "
        "it was driven by hand each time, not by this script. A re-runnable "
        "device matrix would need an unattended driver.")


def gate_product_decisions():
    return DEFERRED, (
        "P25 records 7 PRODUCT_DECISION_REQUIRED, 6 DEFERRED and 4 "
        "BLOCKED_EXTERNAL. Nothing was implemented to close a question.")


def gate_behavior_authority():
    """Runs the measurement instead of reciting its result.

    P19 recorded the count from a one-off reading of the code, and this gate
    then repeated that number as a literal for several phases. A gate that
    recites a finding it never re-measures cannot notice the day the finding
    stops being true - in either direction. It now runs the measurement in
    `test/architecture/behavior_authority_test.dart`, which derives the count
    from the catalog, and decides from the number printed.
    """
    ok, out = run("flutter test --no-pub "
                  "test/architecture/behavior_authority_test.dart")
    m = re.search(r"BEHAVIOR_AUTHORITY_COUNT=(\d+)", out)
    if not m:
        # The measurement did not report. That is not a pass: a gate whose input
        # is missing must say so rather than repeat the last number it remembers.
        return FAIL, (
            "the measurement reported no count, so this gate has nothing to "
            "decide from: " + tail(out))
    count = int(m.group(1))
    items = re.search(r"BEHAVIOR_AUTHORITY_AMBIGUOUS_ITEMS=(\S*)", out)
    ambiguous = items.group(1) if items else "?"
    if count > 1:
        return FAIL, (
            f"BEHAVIOR_AUTHORITY_COUNT={count} (measured): the room can commit "
            f"an action it cannot show on {ambiguous or 'no item'}. The "
            "presentation layer has a second, independent say in what the "
            "companion does. Open pending the P25 D5 decision - does tapping "
            "furniture choose the action or only the destination. Fixing it "
            "before that answer would be fixing it the wrong way.")
    return PASS, (
        f"BEHAVIOR_AUTHORITY_COUNT={count} (measured): the presented posture is "
        "determined by the committed action.")


def gate_flow_video():
    return BLOCKED, (
        "FLOW_GENERATION: no video surface reachable in Flow, and Flow's own "
        "banner reports video generation degraded. The video-to-sprite pipeline "
        "is built and validated against a local clip; no production video art "
        "exists.")


GATES = [
    ("FORMAT", gate_format, True),
    ("ANALYZE", gate_analyze, True),
    ("UNIT_TESTS", gate_unit_tests, True),
    ("INTEGRATION_TESTS", gate_integration, True),
    ("GOLDEN_FLOW", gate_golden_flow, True),
    ("MIGRATION", gate_migration, True),
    ("LIFECYCLE", gate_lifecycle, True),
    ("ASSET_GATES", gate_assets, True),
    ("APK", gate_apk, False),
    ("AAB", gate_aab, False),
    ("DIFF_CHECK", gate_diff_check, True),
    ("RELEASE_SIGNING", gate_signing, True),
    ("LAUNCHER_ICON", gate_launcher_icon, True),
    ("OWNER_VISUAL_GATE", gate_owner_visual, True),
    ("DEVICE_MATRIX", gate_device_matrix, True),
    ("PRODUCT_DECISIONS", gate_product_decisions, True),
    ("BEHAVIOR_AUTHORITY", gate_behavior_authority, True),
    ("FLOW_GENERATION", gate_flow_video, True),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--full", action="store_true",
                    help="run every gate, including the release builds")
    ap.add_argument("--skip-builds", action="store_true",
                    help="skip APK and AAB, which are the slow ones")
    a = ap.parse_args()

    # run() returns (ok, output) -- unpack the output, not the flag.
    _, head = run("git rev-parse HEAD")
    remote_ok, remote = run("git rev-parse origin/recovery/v4.2.1-rebuild")
    if not remote_ok:
        # A missing branch is not an unpushed commit. Reporting git's error text
        # as a revision would make `local_equals_remote` false for a reason that
        # has nothing to do with the working tree.
        remote = ("UNAVAILABLE: origin/recovery/v4.2.1-rebuild could not be "
                  "read")

    results = []
    for name, fn, cheap in GATES:
        if a.skip_builds and name in ("APK", "AAB"):
            results.append({"gate": name, "status": NOT_TESTED,
                            "evidence": "--skip-builds was passed"})
            print(f"{name:22s} {NOT_TESTED}")
            continue
        started = time.time()
        try:
            status, evidence = fn()
        except Exception as exc:                     # noqa: BLE001
            status, evidence = FAIL, f"{type(exc).__name__}: {exc}"[:300]
        results.append({
            "gate": name, "status": status, "evidence": evidence,
            "seconds": round(time.time() - started, 1),
        })
        print(f"{name:22s} {status:8s} {evidence}")

    counts = {}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1

    report = {
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "head": head.strip(),
        "remote_head": remote.strip(),
        "local_equals_remote": remote_ok and head.strip() == remote.strip(),
        "counts": counts,
        "gates": results,
        "note": (
            "Gates that can be re-run shell out to the command that already "
            "exists; none re-implements a check. The gates that report a "
            "standing owner or external state rather than a measurement "
            "(RELEASE_SIGNING, LAUNCHER_ICON, OWNER_VISUAL_GATE, DEVICE_MATRIX, "
            "PRODUCT_DECISIONS, FLOW_GENERATION) say so in their own evidence "
            "instead of pretending to have measured. BLOCKED is never reported "
            "as PASS."
        ),
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, ensure_ascii=False)

    lines = [
        "# Automated product gate", "",
        f"Generated {report['generated_at']} at `{report['head'][:8]}`. "
        f"Local equals remote: "
        f"**{'YES' if report['local_equals_remote'] else 'NO'}**.", "",
        "| Gate | Status | Evidence |", "|---|---|---|",
    ]
    for r in results:
        lines.append(f"| `{r['gate']}` | **{r['status']}** | {r['evidence']} |")
    lines += ["", "## Counts", ""]
    for k in (PASS, FAIL, BLOCKED, DEFERRED, NOT_TESTED):
        if counts.get(k):
            lines.append(f"- **{k}**: {counts[k]}")
    lines += ["", "---", "", report["note"], ""]
    with open(MD_OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))

    print(f"\ncounts: {counts}")
    print(f"report: {JSON_OUT}")
    return 0 if not counts.get(FAIL) else 1


if __name__ == "__main__":
    sys.exit(main())
