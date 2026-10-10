"""Controller methods that nothing in the UI calls.

The subtask card was built, tested at the repository and domain layers, and
unreachable, because no screen ever called `TaskDetailController.addSubtask`. That
is a defect class that no test can catch - every test passed, the page rendered
correctly, and the missing thing was one call edge. This looks for the same shape
elsewhere.

Reported, not asserted: a controller method with no call site may be dead, or may
be reachable from a route this scan does not see. It is a list to read, not a
verdict.

Usage:
    python tools/find_uncalled_controller_methods.py
    python tools/find_uncalled_controller_methods.py --self-test
"""
import argparse
import os
import re
import sys

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTROLLERS = os.path.join(APP, "lib", "presentation", "controllers")
UI_ROOTS = [
    os.path.join(APP, "lib", "presentation", "pages"),
    os.path.join(APP, "lib", "presentation", "widgets"),
    os.path.join(APP, "lib", "presentation", "companion"),
    os.path.join(APP, "lib", "presentation", "animations"),
    os.path.join(APP, "lib", "presentation", "navigation"),
]

# A method that only reads is not interesting: the question is whether a *write*
# the UI could offer is offered. These prefixes are the writes.
WRITE_PREFIXES = (
    "add", "insert", "create", "update", "set", "toggle", "delete", "remove",
    "save", "start", "stop", "pause", "resume", "complete", "finish", "claim",
    "select", "adopt", "install", "uninstall", "import", "export", "schedule",
    "unschedule", "cancel", "reset", "clear", "mark", "rename", "move",
)

METHOD = re.compile(
    r"^\s{2}Future<[^>]*>\s+([a-z][A-Za-z0-9_]*)\s*\(", re.MULTILINE)


def dart_files(root):
    for base, _dirs, names in os.walk(root):
        for name in names:
            if name.endswith(".dart") and not name.endswith(".g.dart"):
                yield os.path.join(base, name)


def scan(root=APP):
    ui_text = {}
    for r in UI_ROOTS:
        for path in dart_files(r):
            with open(path, encoding="utf-8", errors="replace") as fh:
                ui_text[path] = fh.read()

    findings = []
    for path in dart_files(CONTROLLERS):
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        cls = re.search(r"class\s+([A-Za-z0-9_]+)", text)
        owner = cls.group(1) if cls else os.path.basename(path)
        for name in METHOD.findall(text):
            if not name.startswith(WRITE_PREFIXES):
                continue
            # A call, OR a tear-off. `onToggle: controller.toggleSubtask` passes
            # the method without parentheses, and the first version of this scan
            # reported it as uncalled - a false positive, which for a scanner is
            # worse than a miss, because someone acts on it.
            call = re.compile(
                r"[.\s]" + re.escape(name) + r"\s*\("
                r"|[.\s]" + re.escape(name) + r"\b(?!\s*\()")
            called = [
                p for p, body in ui_text.items() if call.search(body)
            ]
            if not called:
                findings.append((owner, name, os.path.relpath(path, APP)))
    return findings


def self_test():
    """The scanner must be able to see a call, and must see its absence."""
    import tempfile
    ok = True

    with tempfile.TemporaryDirectory() as tmp:
        ctrl = os.path.join(tmp, "controllers")
        pages = os.path.join(tmp, "pages")
        os.makedirs(ctrl)
        os.makedirs(pages)
        with open(os.path.join(pages, "p.dart"), "w", encoding="utf-8") as fh:
            fh.write("void f() { c.addThing('x'); }\n"
                     "void g() { use(c.updateThing); }\n"
                     "void h() { c.setOther(1); }\n")
        with open(os.path.join(ctrl, "c.dart"), "w", encoding="utf-8") as fh:
            fh.write("class C {\n"
                     "  Future<void> addThing(String t) async {}\n"
                     "  Future<void> updateThing(String t) async {}\n"
                     "  Future<void> setOther(int n) async {}\n"
                     "  Future<int> readThing() async => 0;\n"
                     "}\n")

        original = (CONTROLLERS, UI_ROOTS)
        globals()["CONTROLLERS"] = ctrl
        globals()["UI_ROOTS"] = [pages]
        try:
            found = {name for _owner, name, _path in scan(tmp)}
        finally:
            globals()["CONTROLLERS"], globals()["UI_ROOTS"] = original

    # updateThing is passed as a tear-off and must NOT be reported: that false
    # positive is what the first version of this scan produced.
    for name, expect in (("addThing", False), ("updateThing", False),
                         ("setOther", False)):
        got = name in found
        mark = "ok " if got == expect else "FAIL"
        if got != expect:
            ok = False
        print(f"  {mark} {name}: reported={got} expected={expect}")
    # A read method is not a finding at all.
    if "readThing" in found:
        ok = False
        print("  FAIL readThing: reported=True expected=False (reads are not writes)")
    print("self-test:", "ok" if ok else "FAILED")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()

    findings = scan()
    if not findings:
        print("\n0 controller write methods with no UI call site")
        return 0
    print(f"\n{len(findings)} controller write method(s) with no UI call site:\n")
    for owner, name, path in sorted(findings):
        print(f"  {owner}.{name}()  <-  {path}")
    print("\nEach is a question, not a defect: it may be dead, or reachable from "
          "a route this scan does not read.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
