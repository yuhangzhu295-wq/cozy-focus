# CozyFocus — Context Compact

Read this first in a fresh session. It is the whole state; nothing else needs
reading before working.

## What the project is

Flutter 番茄钟 + 2D 宠物陪伴 App. Focus time becomes craft progress; crafted
furniture goes in the room; the companion walks to it and uses it. Branch
`recovery/v4.2.1-rebuild`. Repo root `C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat`,
app in `cozy_focus_app`.

## Where it stands

```
P28 action truth        PASS   (device-verified)
P29 acquisition UX      PASS   (device-verified)
P30 user golden flow    PASS   (device-walked, database-verified)
P31 pack standard       PASS
P32 local import/export implementation COMPLETE, no UI to reach it
P33..P40                NOT STARTED
```

Head `b48dece`. 1387/1387 tests, format and analyze (`--fatal-infos`) clean.
Debug APK 141.9 MB, release APK 29.6 MB.

## P32 — what exists

The whole chain is built, tested and committed:

- **archive policy** — refuses traversal, bombs, entry count, symlinks, duplicates,
  disallowed file types, a manifest not at the root
- **strict validator** — refuses rather than defaulting; reads the nested `canvas`
  shape the runtime parses
- **install rules** — safe pack id, built-in collision, species
- **archive reader** — decode + policy, returns bytes rather than writing
- **atomic installer** — staging → re-validate what landed → rename
- **registry + revision** — `installedPacksProvider`, the single observable signal
- **`installedPackProfilesProvider`** — reads installed manifests once per change,
  exposes a synchronous map (the catalog is synchronous)
- **`CompanionFrameSource`** — one player for bundled assets and installed files
- **`PackBackedCompanionVisualProvider`** — one generic class per pack
- **avatar + catalog + registry + selection** — all observe the revision, so a pack
  installed while the app runs appears with no restart
- **exporter** — deterministic `.cozy_pet`, pack files only, round-trips
- **removal** — selection repaired before the pack goes; metadata before files

**Negative proof run by hand:** dropping `ref.watch(installedPackProfilesProvider)`
from `companionCatalogProvider` fails 2 of the 4 `hot_install_test.dart` tests.

## P32 — what is missing, and it is one thing

**No UI reaches any of it.** The engine is done; the door is not. Needed: a file
picker for `.cozy_pet` (new dependency — `file_selector` or `file_picker`), a
preview, the install action wired to reader → validator → installer → controller,
and export/delete on an installed companion. Only then can the device flow run.

## Traps, each learned the hard way

1. **Never write file content through a shell heredoc here.** It silently
   truncated a commit message and two files. Use the file tool, then verify.
2. **Prefer rewriting a file whole over matching long anchors.** `dart format`
   rewraps and breaks anchors silently — several edits "succeeded" without
   applying. If a python replace asserts, check the anchor before trusting it.
3. **The screen is not evidence for state.** Two corrections this program came
   from the device database and the instrumented decision trace, both times
   contradicting what a screenshot appeared to show.
4. **`adb shell input tap` does not reach Flutter gesture detectors** on this
   emulator — it arrives as a pan. Use Computer Use real-pointer clicks.
5. **A test that hangs is worse than one that fails.** Rendering waits on the
   image stream; assert resolution instead of pumping where that is enough.

## Owner decisions still open

1. A displayed 30-minute session settles **29:55** — five seconds under a 1800s
   recipe. Reproduce to root cause first; fix if a defect, else decide between
   elapsed truth and planned-duration grace.
2. The **rug's purpose** now that its only action (`sit`) is hidden, because
   `room_sit` has no drawing.
3. Whether `bookshelf/search` may share `focus_think` with `desk/study`.

## External blockers, carried to P40

`RELEASE_SIGNING = NOT_RECOVERED` · `LAUNCHER_ICON = BLOCKED` ·
`OWNER_VISUAL_GATE = REQUIRED` · `VERTEX_AI = BLOCKED_EXTERNAL` (P37 only).

## Known asset and tooling gaps

- `room_sit` has no sprite in any pack; sofa/sit and rug/sit are hidden from the
  panel but the routine and idle still select `room_sit`.
- `cat` and `rabbit` have **no geometry contract** (`animation_manifest.json` is
  dog-only), so `manifest.py` now refuses them until one is written each.
- `tools/productionise.py` `measure()` reads `split()[-1]` as alpha; on the indexed
  PNGs the packs ship that is the palette index. `audit_pack_geometry.py` converts
  to RGBA first; `productionise` itself was not changed.
- `docs/companion_assets.md` is stale (claims 1024×1024 / 919 / 511; real is
  512×512 / ~458 / 255).
- `multi_companion_parity_test` forces every profile to the dog's 13 actions —
  right for built-ins, wrong as an admission requirement for a user partial pack.
  P33 must scope the two contracts.
- The room's travel ticker starts immediately and `_onCompanionAnimationChanged`
  is empty, so the comment claiming movement waits for `stand_up` describes
  behaviour the code does not implement.

## Resume

```
git symbolic-ref HEAD; git rev-parse HEAD
git rev-parse origin/recovery/v4.2.1-rebuild; git status --short
```

Then read `AUTONOMOUS_STATE.json` (the machine-readable state) and this file.
Continue from the P32 import UI. Do not rebuild anything listed as existing.
