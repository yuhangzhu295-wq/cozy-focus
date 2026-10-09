"""Find Semantics wrappers that exclude their child's tap action.

## The defect this looks for

```dart
Semantics(
  excludeSemantics: true,
  button: true,
  label: '暂停',
  child: GestureDetector(onTap: ..., child: ...),   // <- the only tap
)
```

`excludeSemantics: true` drops the child's semantics **including its tap
action**, so the node is announced as a button with nothing to press. Measured in
a probe: that shape gives `button=true tapAction=false`, while the same wrapper
with its own `onTap:` gives `tapAction=true`.

This is the third time in this project that `excludeSemantics` has bitten, and the
first time in the other direction — the earlier work added it to *stop* a doubled
announcement, and adding it is exactly what removed the action. Both are the same
mistake: `Semantics` does not do what its name suggests to the subtree, and the
only reliable check is the tree the platform receives.

## What it reports

A `Semantics` with `excludeSemantics: true`, no `onTap` of its own, and a child
that carries a tap (`GestureDetector`, `InkWell`, `IconButton`, `FilledButton`,
`ElevatedButton`, `TextButton`, `OutlinedButton`) or an `onPressed`.

Usage:
    python tools/find_excluded_tap_actions.py
"""

from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
LIB = REPO / "lib"

TAPPABLE = (
    "GestureDetector(",
    "InkWell(",
    "IconButton(",
    "FilledButton",
    "ElevatedButton",
    "TextButton",
    "OutlinedButton",
    "onPressed:",
)


def _skip_string(source: str, index: int) -> int:
    quote = source[index]
    if source.startswith(quote * 3, index):
        end = source.find(quote * 3, index + 3)
        return len(source) if end < 0 else end + 3
    i = index + 1
    while i < len(source):
        if source[i] == "\\":
            i += 2
            continue
        if source[i] == quote:
            return i + 1
        if source[i] == "\n":
            return i
        i += 1
    return len(source)


def _match_paren(source: str, open_index: int) -> int:
    depth = 0
    i = open_index
    while i < len(source):
        ch = source[i]
        if ch in "'\"":
            i = _skip_string(source, i)
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def scan(path: Path) -> list[tuple[int, str]]:
    source = path.read_text(encoding="utf-8")
    findings: list[tuple[int, str]] = []

    for match in re.finditer(r"(?<![\w.])Semantics\(", source):
        open_index = match.end() - 1
        close_index = _match_paren(source, open_index)
        if close_index < 0:
            continue
        body = source[open_index + 1 : close_index]
        if "excludeSemantics: true" not in body:
            continue
        # The wrapper's own tap makes it pressable; without one, the action has
        # to come from the child it just excluded.
        head = body.split("child:", 1)[0]
        if "onTap:" in head or "onPressed:" in head:
            continue
        if any(token in body for token in TAPPABLE):
            line = source.count("\n", 0, open_index) + 1
            label = re.search(r"label:\s*([^,\n]+)", body)
            findings.append((line, label.group(1).strip() if label else "?"))

    return findings


def main() -> None:
    total = 0
    for path in sorted(LIB.rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        findings = scan(path)
        if not findings:
            continue
        print(path.relative_to(REPO).as_posix())
        for line, label in findings:
            total += 1
            print(f"  {line:5d}  label {label}  — the tap lives on the excluded child")
    print(f"\n{total} wrapper(s) that exclude the only tap they have")


if __name__ == "__main__":
    main()
