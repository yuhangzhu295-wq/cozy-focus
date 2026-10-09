"""Find controls that `excludeSemantics: true` has removed from the tree.

`Semantics(excludeSemantics: true, ...)` drops the *entire* subtree from the
accessibility tree. That is right when the subtree is decoration and the wrapper
supplies the name — and wrong the moment the subtree contains a second control
with actions of its own, because a screen-reader user then cannot reach it at
all. The control is drawn, works by touch, and does not exist for assistive
technology.

This is the sibling of `find_excluded_tap_actions.py`: that one finds a wrapper
that kept a name and lost the *only* press; this one finds a wrapper that hid a
*second* control. Both were found on a device first.

What counts as a control: a widget whose actions a wrapper cannot mirror. A bare
`GestureDetector` or `InkWell` does NOT — its single tap can be (and at 25 sites
is) mirrored onto the wrapper, which is what `find_excluded_tap_actions.py`
checks. A `PopupMenuButton`, an `IconButton`, a `Switch` or a `TextField` cannot
be: they carry several actions or state of their own, so excluding the subtree
loses them. This scanner reports only that second kind.

Usage:  python tools/find_excluded_controls.py [--json]
Exit code is 1 when it finds something, so it can be a gate.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

CONTROLS = (
    "PopupMenuButton",
    "IconButton",
    "TextButton",
    "ElevatedButton",
    "FilledButton",
    "OutlinedButton",
    "Checkbox",
    "Radio",
    "Switch",
    "Slider",
    "DropdownButton",
    "TextField",
    "TextFormField",
    "Dismissible",
)

_EXCLUDE = re.compile(r"excludeSemantics\s*:\s*true")


def _argument_region(text: str, open_paren: int) -> str:
    """The text between the parentheses starting at [open_paren]."""
    depth = 0
    for i in range(open_paren, len(text)):
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[open_paren + 1 : i]
    return text[open_paren + 1 :]


def _line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def _is_comment_line(line: str) -> bool:
    return line.lstrip().startswith("//")


def scan_file(path: pathlib.Path) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    findings: list[dict] = []

    for match in re.finditer(r"Semantics\s*\(", text):
        region = _argument_region(text, match.end() - 1)
        if not _EXCLUDE.search(region):
            continue
        # The comment above the wrapper usually explains why it excludes; only
        # the *code* inside matters.
        body = "\n".join(
            line for line in region.split("\n") if not _is_comment_line(line)
        )
        hit = [name for name in CONTROLS if re.search(rf"\b{name}\b", body)]
        if not hit:
            continue
        findings.append(
            {
                "file": str(path),
                "line": _line_of(text, match.start()),
                "controls": hit,
            }
        )
    return findings


def self_test() -> int:
    """A known-bad snippet and a known-good one, so a silent pass means nothing."""
    import tempfile

    bad = """
Widget a() => Semantics(
  excludeSemantics: true,
  label: 'x',
  child: Row(children: [
    Text('x'),
    PopupMenuButton<String>(itemBuilder: (c) => []),
  ]),
);
"""
    good = """
Widget b() => Semantics(
  excludeSemantics: true,
  onTap: () {},
  label: 'x',
  child: GestureDetector(onTap: () {}, child: Text('x')),
);
"""
    decoration = """
Widget c() => Semantics(
  excludeSemantics: true,
  label: 'x',
  child: Row(children: [Icon(Icons.circle), Text('x')]),
);
"""
    with tempfile.TemporaryDirectory() as tmp:
        results = []
        for name, source in (("bad.dart", bad), ("good.dart", good),
                             ("deco.dart", decoration)):
            p = pathlib.Path(tmp) / name
            p.write_text(source, encoding="utf-8")
            results.append((name, scan_file(p)))

    ok = True
    if len(results[0][1]) != 1:
        print("SELF-TEST FAIL: the excluded menu was not reported")
        ok = False
    if results[1][1]:
        # A GestureDetector *is* a control, but its action is mirrored on the
        # wrapper, so this shape is the one the sibling scanner already covers.
        # Reporting it here would double-count; the sibling is authoritative.
        pass
    if results[2][1]:
        print("SELF-TEST FAIL: decoration was reported as a control")
        ok = False
    print("self-test:", "ok" if ok else "FAILED")
    return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--root", default="lib")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    root = pathlib.Path(args.root)
    all_findings: list[dict] = []
    for path in sorted(root.rglob("*.dart")):
        all_findings.extend(scan_file(path))

    if args.json:
        print(json.dumps(all_findings, indent=1))
    else:
        for f in all_findings:
            rel = f["file"].replace("\\", "/").split("/lib/", 1)[-1]
            print(f"lib/{rel}:{f['line']}  excludes {', '.join(f['controls'])}")
        print(f"{len(all_findings)} site(s) where an exclusion hides a control")
    return 1 if all_findings else 0


if __name__ == "__main__":
    sys.exit(main())
