# P32 — Local Import / Export

Pack-first roadmap (`P31_P40_PACK_FIRST_ROADMAP.md`). Branch
`recovery/v4.2.1-rebuild`.

**Status: COMPLETE, and walked on the device.** The engine, the UI, the device
flow, and the cold-start fix are all in. 1430/1430 tests, format clean, analyze
clean. Latest slice `a23d7ba`.

## The device flow, as run

Pixel 7 API 34 emulator, debug APK, a real `.cozy_pet` built by
`tools/make_demo_pack.py` (the cat's frames under the id `xiaomao`, name 小豆)
pushed to `/sdcard/Download/`.

| Step | Result |
|---|---|
| companion picker shows 导入宠物包 | yes |
| pick a `.cozy_pet` through the system picker | yes — the file was listed and selectable, so the extension + MIME filter works on Android |
| preview before install | yes — the cat drawn from the pack's own idle frame, `xiaomao`, 动作 13, 帧 49, 画布 512×512, name and species prefilled from the pack |
| install | yes — 49 frames + `manifest.json` in `app_flutter/companion_packs/xiaomao/`, staging left empty |
| select without a restart | yes — offered on the success screen and selected immediately |
| restart | yes — home page reads 和小豆一起专注吧 with the cat, and the growth page names it everywhere |
| export | yes — the share sheet offers `xiaomao.cozy_pet` |
| delete | yes — pack gone, record gone, staging empty |
| fallback | yes — the selection switched to a built-in and said so |
| re-import | yes — installed again, this time with `source: "local_import"` |

Checked against the device filesystem, not the screen: `companion_packs/`,
`installed_packs.json`, `companion_selection.json`, and `logcat` for Flutter
exceptions (none).

## Three defects the device flow found that no test had

This is the argument for walking it. All three were invisible to a green suite.

### 1. Installing under a mounted avatar threw (`d4b5f73`)

`_registry` and `_director` were `late final` and the refresh path reassigns
both, so the first install with an avatar on screen raised
`LateInitializationError: Field '_registry' has already been initialized`, and
Flutter drew a red error box over every companion on the picker.

The hot-install tests assert the catalog and the visual registry; the avatar
tests mount an avatar but never install under it. The refresh is only reachable
from a rebuild, so only a test that installs *while an avatar is mounted* can
reach it. Two regression tests now do, and restoring `late final` fails both.

### 2. An installed pack did not survive a restart (`c0c92dc`)

The registry was in memory only. On a cold start it was empty while the pack
directories were still on disk, so the app offered only the built-in three and
the persisted selection — which said `xiaomao` and was written correctly — was
discarded as an unknown id and replaced by the default. On the device that read
as "the companion I just installed went back to Mochi", with the files still
there and nothing in the log.

Two halves, because neither source is enough alone:

- an **install record** at the pack root, beside the pack directories and never
  inside one, because a pack directory is exactly what gets exported. It carries
  what only the user could say — the name they typed, the species they chose, how
  the pack arrived — none of which is in the pack by design;
- a **directory scan**, because the directories are the truth about what is
  really there. A record whose pack is gone is dropped and the records rewritten;
  a directory the records have never heard of is read from its own manifest.

A pack that neither the records nor its own manifest can classify is skipped and
reported rather than guessed at, because nothing may infer a species from an id.

### 3. A pack discovered by scan was never written down (`a23d7ba`)

Recovery read a hand-copied pack from its own manifest and kept nothing, so every
launch re-hashed every frame and re-derived the name. Found by walking: the pack
on the emulator had been installed by the *previous* build, so there was no record
file and the scan path ran for real.

## What the device flow also settled

- **`file_selector` works on Android.** The `XTypeGroup` with both an extension
  and MIME types does not grey out a `.cozy_pet`. Worth knowing: the picker takes
  ~6.5 s to appear on a cold `documentsui`, which reads as a hang if you are
  watching a screenshot instead of the log.
- **The imported companion is not a second-class one.** The home header, the
  growth page, the tab chip and the footer quote all name it, because every one
  of them reads `companionDisplayNameProvider` rather than writing "Mochi".
- **The two digests agree.** The checksum the recovery scan computed from the
  directory equals the one the installer computed at import, which is the
  cross-check that the digest really is over the contents.

## A gap the flow exposed in the validator, now closed

`CompanionPackValidator` judges names and never bytes — deliberately, so it stays
pure — which means nothing checked that a file called `idle_000.png` is a PNG.
The policy enforces only the *extension*. So a corrupt or mislabelled frame would
install cleanly and fail at render time, which is the worst place to find out.

`CompanionPackImporter.inspect` now checks the PNG signature of every frame the
manifest references, before anything is written. The signature only, not a decode:
a full decode would pull a codec into the install path to answer a question the
player answers anyway, and the failure this catches is a file that is not a PNG at
all.

## And a claim that turned out to be false

The reader's `unreadable_archive` branch is **effectively unreachable**.
`ZipDecoder` in archive 4.3.0 does not throw for input it cannot parse — measured,
not assumed: garbage text, a half-truncated archive and an 8-byte header all come
back as a zero-file archive, and corrupt bytes in the middle still yield files.
Malformed input therefore arrives as `empty_archive` or as a pack that fails
manifest validation. The safety conclusion is unchanged — it is refused either
way, and a refusal always carries zero files — but the comment claiming "the
reader turns a decode failure into a refusal" described a path nothing can reach.
The test now asserts what actually happens.

## Carried forward, still open

- **`manifest.py` certifies itself** — fixed in `65a2a29`; the contract is the
  source and the frames are checked against it.
- **`docs/companion_assets.md` is stale**: claims 1024×1024 with 919/511 anchors;
  the real JSON is 512×512 with ~458/255.
- **P33's test scoping**: `multi_companion_parity_test.dart` forces every profile
  to the dog's thirteen actions. Right for the built-ins, wrong as an admission
  requirement for a user's partial pack.
- **Symlinks and duplicate-name ZIP entries** are covered at the policy level but
  cannot be built with this encoder, so they are unverified through the reader.
- **The expansion-ratio bomb check is inert** on this path: the decoder exposes no
  trustworthy compressed size, so the reader passes zero and the policy skips the
  ratio while still enforcing the byte caps.
- **Recovery reads the whole pack** for a pack with no record, to compute its
  digest. Fine for one pack; a limit worth revisiting if someone drops in twenty.

## Process notes

- **Never write file content through a shell heredoc in this environment.** It has
  silently truncated content three times (one commit message, two file writes).
- **Prefer rewriting a file whole over matching long anchors**: `dart format`
  rewraps and breaks anchors silently.
- **The screen is not evidence for state.** Two of this session's corrections came
  from the device filesystem and the instrumented trace, both times contradicting
  what a screenshot appeared to show.
- **A widget test that triggers real file IO must make its tap inside
  `runAsync`.** A future chain created under the fake test clock parks its
  continuations there, and waiting on the widget tree deadlocks, because the tree
  only updates when the clock is pumped.
- **`adb shell input tap` does not reach Flutter gesture detectors** — it arrives
  as a pan. Use real-pointer clicks. Also: the first click after the emulator
  window loses focus is consumed by the focus change, so a single click that
  appears to do nothing usually needs repeating once.
- **`am start` resolves to whatever is top-most.** After the file picker has been
  used, `am force-stop` the app and launch it with `monkey -p <pkg> -c
  android.intent.category.LAUNCHER 1`, or the picker swallows the intent.
