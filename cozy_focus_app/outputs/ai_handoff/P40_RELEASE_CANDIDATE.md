# P40 — Release Candidate

Branch `recovery/v4.2.1-rebuild`.

```
READY_FOR_STORE = NO
```

Two of the three reasons are things nobody in this environment can supply. The
third was a real gap in my own work, and it is fixed.

## The gate

| gate | result |
|---|---|
| `flutter analyze --fatal-infos` | PASS, 0 issues |
| `flutter test` | PASS, 1513/1513 |
| `dart format --set-exit-if-changed lib test` | PASS, 325 files, 0 changed |
| five Python tooling proofs | PASS |
| release APK / AAB | build: 30.1 MB / 48.6 MB |
| AAB artifact inspection | PASS — no keystore, key file, `.env`, Python tooling, `test/` tree, handoff docs or credential files; all three shipped companion manifests present |
| git | clean, HEAD == origin |

A final-gate review was run against the tree and produced the blockers below.

## Why it is not ready

### 1. The release artifacts are debug-signed

`flutter build appbundle --release` **succeeds and produces a debug-signed
bundle** when `android/key.properties` is absent, because
`android/app/build.gradle.kts:61–69` falls back to the debug signing config. The
build file documents this honestly, and the artifact's certificate reads
`CN=Android Debug`.

`android/key.properties` is absent and no keystore may be invented, so
`RELEASE_SIGNING = NOT_RECOVERED` stands. **A successful release build is not a
store-signing pass**, and my earlier reporting of the AAB as a PASS was about
building rather than about readiness. That distinction is now stated wherever the
artifact is mentioned.

### 2. A hostile pack can cost memory before it is refused — **partly closed**

The picker reads the whole selected file into memory, and the reader decodes the
ZIP and accesses entry content *before* the policy sees the sizes. The policy
enforces 4096 entries, 8 MiB per entry and 128 MiB total — but those limits bound
what is **written**, not what is read.

**What is now closed.** `PackArchiveLimits.maxInputBytes = 64 MB` is applied in two
places, both *before* the decoder: the picker refuses an oversized file by its
declared length without reading it, and the reader refuses an oversized buffer
before decoding. That is the only place a limit can bound what is *read* rather
than what is written, and it keeps the decoder away from a file chosen by accident
or by malice. A real pack is about a megabyte, so nothing a person builds is
refused.

**The bomb vector is now closed too.** The archive package exposes no way to read
a ZIP's central directory on its own — `decodeBytes` and `decodeStream` both
decompress — so `companion_pack_zip_directory.dart` reads it directly. A ZIP's
directory is a table at the end of the file that states every entry's compressed
and uncompressed size, and reading it costs a few hundred bytes of parsing and no
decompression at all.

So the limits are now applied twice: **before** the decoder, against what the
directory declares, and afterwards, against the real entries. The pre-flight can
only refuse earlier — it can never cause an archive to be accepted that the policy
would have refused — and when it cannot parse a directory (ZIP64, a truncated
tail) it returns null and the reader proceeds exactly as before, so the worst case
of a bug in it is yesterday's behaviour.

The test that makes this a proof rather than an assertion is a **lying directory**:
an entry's declared uncompressed size is patched to 500 MB inside a real 64-byte
entry. The reader refuses it — and the *same bytes* decode cleanly under permissive
limits, which is what shows the refusal came from the directory and not from the
entries.

**Verified:** the ordering, the directory read, both pre-flight refusals, and that
an ordinary pack is untouched. **Not verified:** whether a particular crafted
archive exhausts a device — that needs a device run, and the refusal now happens
before the memory would be spent, so the value of that run is lower than it was.

### 3. Frames were bounded by count, not by pixels — fixed here

The P39 frame cap bounded *how many* frames an action may carry, and the memory a
pack costs is *canvas pixels × frames*. A pack could declare a 512×512 canvas and
ship 8000×8000 frames, and the manifest check could not see it because it reads
the declaration rather than the images.

The importer now reads each referenced PNG's **IHDR dimensions** and refuses a
frame larger than the declared canvas. That is a header read, not a decode: width
and height are four bytes each at a fixed offset. Two tests, one over the canvas
and one at it, so the bound cannot refuse the thing it exists to allow.

**What is still not bounded, stated rather than implied:** nothing verifies a
frame *decodes*, only that it declares a sane size. A well-formed header over
corrupt data remains a render-time failure, which the player turns into a blank
rather than a crash.

## Claims the gate found stronger than their evidence

The review was asked specifically for these, and it found two — both mine.

- **P39 said its memory bound bounded memory.** It bounded a list length. Now
  corrected in the document, and the real bound is in the code.
- **P39 said reduced motion was established "by construction".** The first-class
  guard inspects provider names and source tokens; nothing asserts that a custom
  companion's animation actually slows under the platform setting. The document
  now says it is an argument from the design rather than a test of playback.
- **P37 said a result carries no bytes unless it was generated.** True of the two
  named constructors and not of the general one. Now an assertion on the
  constructor, with a test.

The reviewer also confirmed P32 was *appropriately* candid about the decoder-level
symlink and duplicate-entry gaps rather than overclaiming them.

## What remains, and what it needs

| item | needs |
|---|---|
| store signing | the owner's legitimate key. `RELEASE_SIGNING = NOT_RECOVERED` |
| launcher icon | approved artwork. `LAUNCHER_ICON = BLOCKED` |
| the owner's visual judgement of the companion | a person. `OWNER_VISUAL_GATE = REQUIRED` |
| crafted-archive memory test | work, not a person — see blocker 2 |
| decoder-level symlink and duplicate entries | a real crafted ZIP |
| TalkBack listening pass | a person |
| sustained multi-pack performance | a device run |
| cloud generation | a backend and credentials. `VERTEX_AI = BLOCKED_EXTERNAL` |

## What is genuinely releasable

Everything the product ships as a **local** feature is complete and was walked on
a device: build a pack with the CLI, import it through the file picker, install,
select, focus with it, rest, restart, export, delete, fall back, re-import. The
capability gating is honest, the damaged-pack recovery is honest, and the player's
progress survives a companion being deleted and re-added.

The three blockers above are about **shipping to a store** and about **hostile
input**, not about whether the feature works. `READY_FOR_STORE = NO` is the honest
answer; `LOCAL_CUSTOM_PET = PASS` remains true.
