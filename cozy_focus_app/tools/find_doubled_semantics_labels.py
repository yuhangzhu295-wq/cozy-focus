"""Find widgets that make a screen reader say the same thing twice.

## The two shapes

**1. A Semantics wrapper that repeats the text it wraps.**

```dart
Semantics(
  button: true,
  label: '标签 生活',
  child: ... Text('生活') ...,
)
```

`Semantics` does not exclude the semantics of what it wraps, so the wrapper's
label and the child's own text merge into one node. Measured on the device, that
chip's `contentDescription` came back as `标签 生活\n生活` — a screen reader reads
it out twice. The fix is `excludeSemantics: true` when the wrapper is supplying
the whole name, or dropping the redundant label.

**2. An icon that names itself where something else already names it.**

```dart
BottomNavigationBarItem(
  icon: Icon(Icons.home_rounded, semanticLabel: '首页'),
  label: '首页',
)
```

The destination's `label` already names it, and the icon's label merges into the
same node, so every tab announced itself twice — the device tree read
`首页\n首页\nTab 1 of 3`. A `semanticLabel` is only for an icon that nothing
else names; adding one where a label already exists is the mirror image of the
unnamed-icon-button problem fixed earlier in this project.

## A warning about this tool

It looks for shapes it knows, and it has missed real cases: the second shape
above was invisible to it until the device tree was read directly. Treat
`tools/qa/a11y_dump.py`, which reads the tree the platform actually receives, as
the authority, and this as a fast first pass.

Usage:
    python tools/find_doubled_semantics_labels.py
    python tools/find_doubled_semantics_labels.py --verbose
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
LIB = REPO / "lib"


def _skip_string(source: str, index: int) -> int:
    """Return the index just past the string literal starting at [index]."""
    quote = source[index]
    # A triple-quoted string.
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
        # An unterminated single-quoted string cannot span a line.
        if source[i] == "\n":
            return i
        i += 1
    return len(source)


def _match_paren(source: str, open_index: int) -> int:
    """Index of the `)` matching the `(` at [open_index], or -1."""
    depth = 0
    i = open_index
    while i < len(source):
        ch = source[i]
        if ch in "'\"":
            i = _skip_string(source, i)
            continue
        if ch == "/" and i + 1 < len(source) and source[i + 1] == "/":
            nl = source.find("\n", i)
            i = len(source) if nl < 0 else nl
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _arg_value(body: str, name: str) -> str | None:
    """The source text of the named argument's value, up to the next top-level comma."""
    match = re.search(rf"(?<![\w.]){re.escape(name)}\s*:\s*", body)
    if not match:
        return None
    start = match.end()
    depth = 0
    i = start
    while i < len(body):
        ch = body[i]
        if ch in "'\"":
            i = _skip_string(body, i)
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


def _normalise(expression: str) -> str:
    """Strip what does not change which value an expression names.

    Whitespace, and a trailing `!`. The task list's filter chips are written
    `label: _labels[filter]` over `Text(_labels[filter]!)`, and the null-assertion
    was enough to hide three doubled labels from this scan while the device tree
    showed all three — `今天`, `进行中` and `已完成`, each announced twice.
    """
    return re.sub(r"\s+", "", expression).rstrip("!")


def _has_plain(haystack: str, needle: str) -> bool:
    """Whether [haystack] interpolates [needle] in the `$name` form.

    The trailing character must not continue the identifier, so `$displayTime`
    matches while `$displayTimeRemaining` does not.
    """
    start = 0
    while True:
        at = haystack.find(needle, start)
        if at < 0:
            return False
        after = haystack[at + len(needle) : at + len(needle) + 1]
        if not after or not (after.isalnum() or after == "_"):
            return True
        start = at + 1


def scan(path: Path) -> list[tuple[int, int, str, str]]:
    """(line, offset of the Semantics `(`, label, the text it repeats)."""
    source = path.read_text(encoding="utf-8")
    findings: list[tuple[int, int, str, str]] = []

    for match in re.finditer(r"(?<![\w.])Semantics\(", source):
        open_index = match.end() - 1
        close_index = _match_paren(source, open_index)
        if close_index < 0:
            continue
        body = source[open_index + 1 : close_index]

        label = _arg_value(body, "label")
        if not label:
            continue
        # Only the wrapper-supplied-name case; a wrapper that adds words is fine.
        if "excludeSemantics: true" in body:
            continue

        wanted = _normalise(label)
        if not wanted:
            continue

        for text_call in re.finditer(r"(?<![\w.])Text\(\s*", body):
            # Read Text's first argument, up to the next top-level comma.
            start = text_call.end()
            depth = 0
            i = start
            while i < len(body):
                ch = body[i]
                if ch in "'\"":
                    i = _skip_string(body, i)
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
            value = body[start:i].strip()
            normalised_value = _normalise(value)
            if not normalised_value:
                continue
            # Either the label is exactly the text, or it is a string that
            # interpolates the same expression — `'标签 ${category.label}'` around
            # `Text(category.label)` still says the label twice, which is the case
            # measured on the device.
            #
            # Both interpolation forms count. `'专注计时 $displayTime，当前专注中'`
            # around `Text(displayTime)` slipped past an earlier version of this
            # check that only looked for `${...}`, and the device tree showed the
            # timer announcing itself three times.
            braced = "${" + normalised_value + "}"
            plain = "$" + normalised_value
            if normalised_value == wanted or braced in wanted or _has_plain(
                wanted, plain
            ):
                line = source.count("\n", 0, open_index) + 1
                findings.append((line, open_index, label, value))
                break

    return findings


NAMED_BY_LABEL = (
    "BottomNavigationBarItem",
    "NavigationDestination",
    "NavigationRailDestination",
)


def scan_nav_items(path: Path) -> list[tuple[int, str, str]]:
    """Widgets whose icon names itself while the widget's own label does too."""
    source = path.read_text(encoding="utf-8")
    findings: list[tuple[int, str, str]] = []

    for name in NAMED_BY_LABEL:
        for match in re.finditer(rf"(?<![\w.]){name}\(", source):
            open_index = match.end() - 1
            close_index = _match_paren(source, open_index)
            if close_index < 0:
                continue
            body = source[open_index + 1 : close_index]

            label = _arg_value(body, "label")
            if not label:
                continue
            wanted = _normalise(label)

            for icon in re.finditer(r"(?<![\w.])Icon\(\s*", body):
                icon_body = body[icon.end() :]
                depth = 0
                end = 0
                while end < len(icon_body):
                    ch = icon_body[end]
                    if ch in "'\"":
                        end = _skip_string(icon_body, end)
                        continue
                    if ch == "(":
                        depth += 1
                    elif ch == ")":
                        if depth == 0:
                            break
                        depth -= 1
                    end += 1
                semantic = _arg_value(icon_body[:end], "semanticLabel")
                if semantic and _normalise(semantic) == wanted:
                    line = source.count("\n", 0, open_index) + 1
                    findings.append((line, name, label))
                    break

    return findings


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    total = 0
    for path in sorted(LIB.rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        relative = path.relative_to(REPO).as_posix()

        hits: list[str] = []
        for line, _offset, label, value in scan(path):
            hits.append(f"  {line:5d}  label {label}  also passed to Text({value})")
        for line, widget, label in scan_nav_items(path):
            hits.append(
                f"  {line:5d}  {widget} label {label}  also on its icon's "
                f"semanticLabel"
            )
        if not hits:
            continue

        print(relative)
        for hit in hits:
            print(hit)
            total += 1
        if args.verbose:
            print()

    print(f"\n{total} place(s) that name the same thing twice")


if __name__ == "__main__":
    main()
