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

**3. A Semantics wrapper over a child that names itself.**

```dart
Semantics(
  button: true,
  label: '$name $state',
  child: CompanionSpritePlayer(semanticLabel: '$name $state', ...),
)
```

Same merge as shape 1, but the child is not a `Text`, so the text-shaped rule
above cannot see it. Found on the device the moment a companion came from an
imported pack: the home avatar switched to the sprite renderer and its node read
`小猫 空闲\n小猫 空闲, 点一下会回应，长按可以摸摸头`. The rule here is the
statically checkable half — a wrapper with a `label` and no `excludeSemantics`
whose body also contains a `semanticLabel:`.

## A warning about this tool

It looks for shapes it knows, and it has missed real cases: the second shape
above was invisible to it until the device tree was read directly. Treat
`tools/qa/a11y_dump.py`, which reads the tree the platform actually receives, as
the authority, and this as a fast first pass.

Usage:
    python tools/find_doubled_semantics_labels.py
    python tools/find_doubled_semantics_labels.py --verbose
    python tools/find_doubled_semantics_labels.py --self-test
"""

from __future__ import annotations

import argparse
import re
import sys
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

    Whitespace, a trailing `!`, and the surrounding quotes. Each of the three was
    needed to see something the device tree was showing:

    * whitespace, because formatting moves it;
    * a trailing `!` — the task list's filter chips are `label: _labels[filter]`
      over `Text(_labels[filter]!)`, and the null-assertion hid three doubled
      labels;
    * the quotes — the rest page's duration chips are `label: '$minutes 分钟'`
      over `Text('$minutes')`, and because the unit lives inside the label's own
      string the quotes sit in different places, so the substring was never
      found even though a screen reader hears `5 分钟, 5, 分钟`.
    """
    return re.sub(r"\s+", "", expression).rstrip("!").strip("'\"")


def _has_plain(haystack: str, needle: str) -> bool:
    """Whether [haystack] interpolates [needle] in the `$name` form.

    The trailing character must not continue the identifier, so `$displayTime`
    matches while `$displayTimeRemaining` does not.

    Only **ASCII** characters count as continuing an identifier, which is the
    whole point of spelling it out. `str.isalnum()` is true for CJK, so
    `'$minutes 分钟'` looked like one long name and the rest page's four duration
    chips — `5 分钟 / 5 / 分钟` — went unflagged until the device tree showed
    them. A Dart identifier cannot contain 分.
    """
    def continues(ch: str) -> bool:
        return ch == "_" or ("a" <= ch <= "z") or ("A" <= ch <= "Z") or ch.isdigit()

    start = 0
    while True:
        at = haystack.find(needle, start)
        if at < 0:
            return False
        after = haystack[at + len(needle) : at + len(needle) + 1]
        if not after or not continues(after):
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

        # A child wrapped in `ExcludeSemantics` is already kept out of the
        # wrapper's node, so it cannot be read twice. That is the other sanctioned
        # way to avoid the doubling, and it is the one the companion card needs:
        # it excludes its own text so the card's name is not read twice, while
        # leaving the overflow menu *outside* the exclusion — `excludeSemantics`
        # on the wrapper would have taken the menu out of the tree with it.
        excluded_regions: list[tuple[int, int]] = []
        for excl in re.finditer(r"(?<![\w.])ExcludeSemantics\(", body):
            excl_close = _match_paren(body, excl.end() - 1)
            if excl_close >= 0:
                excluded_regions.append((excl.start(), excl_close))

        for text_call in re.finditer(r"(?<![\w.])Text\(\s*", body):
            if any(lo <= text_call.start() <= hi for lo, hi in excluded_regions):
                continue
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
            # The child may be the expression itself (`Text(displayTime)`) or the
            # interpolation of it (`Text('$minutes')`). Prefixing the second one
            # again gives `$$minutes`, which is in nothing — that is how the rest
            # page's four duration chips stayed hidden.
            plain = (
                normalised_value
                if normalised_value.startswith("$")
                else "$" + normalised_value
            )
            if normalised_value == wanted or braced in wanted or _has_plain(
                wanted, plain
            ):
                line = source.count("\n", 0, open_index) + 1
                findings.append((line, open_index, label, value))
                break

        # Shape 3: the child names itself and is not a Text.
        #
        # The text rule above cannot see this — a sprite player, a rig or an icon
        # carries its name in `semanticLabel`, and the wrapper's label merges with
        # it the same way. The statically checkable half is that the body contains
        # a `semanticLabel:` the wrapper has not excluded.
        if not any(f[1] == open_index for f in findings):
            for named in re.finditer(r"(?<![\w.])semanticLabel\s*:", body):
                if any(lo <= named.start() <= hi for lo, hi in excluded_regions):
                    continue
                line = source.count("\n", 0, open_index) + 1
                findings.append((line, open_index, label, "a child's semanticLabel"))
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


def self_test() -> int:
    """Prove the scanner can see the shapes it is supposed to see.

    A scanner that reports nothing looks exactly like a codebase with nothing
    wrong. This project has had four scanners that were wrong in a way only a
    device tree revealed, so each one carries the cases it must discriminate.
    """
    import tempfile

    cases = {
        # Reported: the wrapper's label is the text it wraps.
        "plain.dart": """
Widget a() => Semantics(
  button: true,
  label: '标签 ${category.label}',
  child: Text(category.label),
);
""",
        # Not reported: the wrapper supplies the whole name.
        "excluded.dart": """
Widget b() => Semantics(
  excludeSemantics: true,
  label: '标签 ${category.label}',
  child: Text(category.label),
);
""",
        # Not reported: the text is kept out of the wrapper's node by
        # ExcludeSemantics, which is how the companion card keeps its menu.
        "child_excluded.dart": """
Widget c() => Semantics(
  label: '${profile.displayName}',
  child: Row(children: [
    ExcludeSemantics(child: Text(profile.displayName)),
    PopupMenuButton<String>(itemBuilder: (c) => []),
  ]),
);
""",
        # Reported: adding a word does not stop the merge, so the node says
        # `删除 生活` and then `生活` again.
        "prefix_label.dart": """
Widget d() => Semantics(
  button: true,
  label: '删除 $name',
  child: Text(name),
);
""",
        # Reported: the child names itself and the wrapper names it again, with
        # no Text anywhere — the shape the sprite renderer had.
        "child_names_itself.dart": """
Widget e() => Semantics(
  button: true,
  label: '$name $state',
  child: CompanionSpritePlayer(semanticLabel: '$name $state', spec: spec),
);
""",
        # Not reported: the same, with the child excluded.
        "child_names_itself_excluded.dart": """
Widget f() => Semantics(
  excludeSemantics: true,
  label: '$name $state',
  child: CompanionSpritePlayer(semanticLabel: '$name $state', spec: spec),
);
""",
    }
    expected = {
        "plain.dart": True,
        "excluded.dart": False,
        "child_excluded.dart": False,
        "prefix_label.dart": True,
        "child_names_itself.dart": True,
        "child_names_itself_excluded.dart": False,
    }

    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        for name, source in cases.items():
            path = Path(tmp) / name
            path.write_text(source, encoding="utf-8")
            found = bool(scan(path))
            mark = "ok " if found == expected[name] else "FAIL"
            if found != expected[name]:
                ok = False
            print(f"  {mark} {name}: reported={found} expected={expected[name]}")
    print("self-test:", "ok" if ok else "FAILED")
    return 0 if ok else 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        sys.exit(self_test())

    total = 0
    for path in sorted(LIB.rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        relative = path.relative_to(REPO).as_posix()

        hits: list[str] = []
        for line, _offset, label, value in scan(path):
            hits.append(f"  {line:5d}  label {label}  and {value}")
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
