"""Find IconButtons that carry no accessible name, with enough context to judge.

An `IconButton` gets its semantics label from `tooltip`. Without one - and
without a `Semantics` wrapper - a screen reader announces "button" and nothing
else.

The wrapper is the reason this prints context: `Semantics(label: ..., child:
IconButton(...))` is a label the IconButton itself does not carry, so a scan
that only reads the IconButton's own arguments reports it as unnamed. The three
lines above each hit say whether a wrapper is there.
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
            if "tooltip" in body or "semanticLabel" in body:
                continue
            line = src[: match.start()].count("\n") + 1
            before = src[: match.start()].split("\n")[-9:]
            wrapped = any("Semantics(" in b for b in before)
            icon = re.search(r"Icon\(\s*([^)\n]*)", body)
            hits.append(
                (
                    "wrapped" if wrapped else "BARE",
                    path.as_posix(),
                    line,
                    icon.group(1).strip() if icon else "?",
                    " / ".join(b.strip() for b in before if b.strip()),
                )
            )

    bare = [h for h in hits if h[0] == "BARE"]
    print("candidates: %d   of which not inside a Semantics wrapper: %d"
          % (len(hits), len(bare)))
    for kind, path, line, icon, context in bare:
        print("  %s:%d  %s" % (path, line, icon))
        print("      above: %s" % context)


if __name__ == "__main__":
    main()
