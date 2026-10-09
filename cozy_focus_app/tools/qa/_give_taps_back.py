"""One-off: give every excluding wrapper the tap action it was hiding.

`excludeSemantics: true` drops the child's semantics *including its tap action*,
so a wrapper that supplies a label that way produces a button a screen reader can
find and cannot press. Measured in a probe: `button=true tapAction=false` for the
shipped shape, `tapAction=true` once the wrapper carries an `onTap` of its own.

The wrapper's `onTap` mirrors the child's existing callback, so a touch still goes
through the gesture and an accessibility tap goes through the wrapper. Neither is
invoked twice.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

REPO = Path(r"C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app")

spec = importlib.util.spec_from_file_location(
    "scanner", REPO / "tools" / "find_excluded_tap_actions.py"
)
scanner = importlib.util.module_from_spec(spec)
sys.modules["scanner"] = scanner
spec.loader.exec_module(scanner)


def first_action(body: str) -> str | None:
    """The child's own tap expression, up to the next top-level comma."""
    match = scanner.re.search(r"(?<![\w.])(onTap|onPressed)\s*:\s*", body)
    if not match:
        return None
    start = match.end()
    depth = 0
    i = start
    while i < len(body):
        ch = body[i]
        if ch in "'\"":
            i = scanner._skip_string(body, i)
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            if depth == 0:
                break
            depth -= 1
        elif ch == "," and depth == 0:
            break
        i += 1
    return body[start:i].strip()


def semantis_open_index(source: str, line: int) -> int | None:
    """The offset of the `(` of the `Semantics(` that starts at [line]."""
    for match in scanner.re.finditer(r"(?<![\w.])Semantics\(", source):
        if source.count("\n", 0, match.start()) + 1 == line:
            return match.end() - 1
    return None


changed = 0
for path in sorted((REPO / "lib").rglob("*.dart")):
    if path.name.endswith(".g.dart"):
        continue
    source = path.read_text(encoding="utf-8")
    findings = scanner.scan(path)
    if not findings:
        continue

    edits: list[tuple[int, str]] = []
    for line, _label in findings:
        open_index = semantis_open_index(source, line)
        if open_index is None:
            print(f"  ! could not locate the Semantics at {path.name}:{line}")
            continue
        close_index = scanner._match_paren(source, open_index)
        body = source[open_index + 1 : close_index]
        action = first_action(body)
        if action is None:
            print(f"  ! no action found at {path.name}:{line}")
            continue
        if action == "null":
            # A disabled control has nothing to press; leaving it unpressable is
            # the point.
            continue
        marker = "excludeSemantics: true,"
        at = body.index(marker) + len(marker)
        edits.append((open_index + 1 + at, f"\n            onTap: {action},"))

    for offset, text in sorted(edits, key=lambda e: e[0], reverse=True):
        source = source[:offset] + text + source[offset:]
    if edits:
        path.write_text(source, encoding="utf-8")
        changed += len(edits)
        print(f"{path.relative_to(REPO).as_posix()}  +{len(edits)}")

print(f"\n{changed} wrapper(s) given their tap back")
