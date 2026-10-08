"""Find IconButtons that carry no accessible name, with enough context to judge.

## What actually names an IconButton

**Not `tooltip`.** This file said the opposite for a long time, and the rule was
wrong in a way that hid a real defect on the task list. Measured two ways:

* in Flutter, `IconButton(tooltip: '新建任务', ...)` gives a node with
  `label == ''` and `tooltip == '新建任务'` — the string lands in a different
  field;
* on the device, `uiautomator` reports that button as
  `content-desc="" text=""`, and the dump contains no `tooltip=` attribute at
  all. The string never reaches the platform.

So a screen reader announces "button" and nothing else. What does name it is
either a `semanticLabel` on the `Icon` inside, or a `Semantics` wrapper carrying
a `label`.

The wrapper is why this prints context: `Semantics(label: ..., child:
IconButton(...))` is a name the IconButton itself does not carry, so a scan that
only reads the IconButton's own arguments reports it as unnamed. The three lines
above each hit say whether a wrapper is there.
"""

import pathlib
import re

ROOT = pathlib.Path("lib")


def call_body(src, open_paren_index):
    depth = 0
    for i in range(open_paren_index, len(src)):
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                return src[open_paren_index + 1 : i]
    return src[open_paren_index + 1 :]


def main():
    hits = []
    for path in sorted(ROOT.rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        src = path.read_text(encoding="utf-8")
        for match in re.finditer(r"\bIconButton\(", src):
            body = call_body(src, match.end() - 1)
            if "semanticLabel" in body:
                continue
            line = src[: match.start()].count("\n") + 1
            before = src[: match.start()].split("\n")[-9:]
            wrapped = any("Semantics(" in b for b in before)
            icon = re.search(r"Icon\(\s*([^)\n]*)", body)
            tooltip_only = "tooltip" in body
            hits.append(
                (
                    "wrapped" if wrapped else "BARE",
                    path.as_posix(),
                    line,
                    icon.group(1).strip() if icon else "?",
                    tooltip_only,
                    " / ".join(b.strip() for b in before if b.strip()),
                )
            )

    bare = [h for h in hits if h[0] == "BARE"]
    print(
        "candidates: %d   of which not inside a Semantics wrapper: %d"
        % (len(hits), len(bare))
    )
    for kind, path, line, icon, tooltip_only, context in bare:
        note = "  (tooltip only — that is NOT a name)" if tooltip_only else ""
        print("  %s:%d  %s%s" % (path, line, icon, note))
        print("      above: %s" % context)


if __name__ == "__main__":
    main()
