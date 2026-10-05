# P32 — Local Import / Export

Pack-first roadmap (`P31_P40_PACK_FIRST_ROADMAP.md`). Branch
`recovery/v4.2.1-rebuild`.

**Status: PARTIAL.** The decision layer and the archive reader are complete and
committed; nothing writes a file yet, and nothing changes how the runtime resolves
a companion. Latest slice `59b5cdd`, 1333/1333 tests.

### The archive reader (`59b5cdd`)

Decodes a `.cozy_pet` and applies the policy, stopping one step short of the disk:
it returns the files it *would* write. The code that touches the filesystem stays
separate and small, and everything above it is testable without one — the tests
build hostile archives in memory (traversal, absolute paths, oversized entries,
too many entries, disallowed file types, a truncated archive) and assert each is
refused. A refusal always returns zero files, so a caller cannot write half of a
bad pack.

**Three limits on this slice, stated rather than papered over:**

1. **Symlink rejection is NOT verified through the reader.** `ZipEncoder` does not
   carry `symbolicLink` through an encode/decode round trip, so a symlink cannot be
   built in a test and `isSymbolicLink` comes back false. The policy's
   `non_regular_entry` refusal is covered directly, but whether the *decoder*
   reports a real symlink is unverified. Treat `SYMLINKS: REJECTED` as
   *policy-level only* until a real symlink-bearing archive is tested.
2. **Duplicate-name entries cannot be built** with this encoder — `Archive`
   de-duplicates on add. The rule is covered directly in the policy test.
3. **The expansion-ratio bomb check is inert on this path.** The decoder exposes no
   trustworthy compressed size, and a fabricated one would make the ratio
   meaningless, so the reader passes zero ("not known") and the policy skips the
   ratio while still enforcing the per-entry and total byte caps.

```
DECISION_LAYER:  PASS   (3 pure components, 54 tests)
INSTALL_LAYER:   NOT_STARTED
EXPORT:          NOT_STARTED
```

## The shape this phase settled on

Importing a pack is four questions asked in order, and the first three are
answered by pure code with no disk and no dependency:

| Order | Question | Component |
|---|---|---|
| 1 | Is the archive safe to extract? | `CompanionPackArchivePolicy` |
| 2 | Is the pack coherent? | `CompanionPackValidator` |
| 3 | May it be installed, and as what? | `CompanionPackInstallRules` |
| 4 | Write it. | **not built** |

That ordering is the point. Unzipping is the only step where a mistake writes
outside the sandbox, so everything that could go wrong is decided *before*
anything is written, and the eventual extractor becomes a thin shell with no
policy of its own.

### 1. `companion_pack_archive_policy.dart` (`83ab5c3`)

Refuses the cases that are **well formed and hostile**, which is the class a
malformed-file check misses: a name that climbs out of the sandbox, an absolute
path, a drive letter, a null byte; too many entries; a single entry that extracts
too large; a total over the cap; a **compression bomb** (one entry expanding
hundreds of times over, which the total cap alone misses because it can stay just
under the byte limit); a non-regular entry, because a pack needs files and a
symlink is how an archive reaches somewhere it was not invited; and a duplicate
name, because then which copy wins is undefined.

Limits live in `PackArchiveLimits.standard` and are generous for a real pack,
tight for a hostile one.

### 2. `companion_pack_validator.dart` (`aa93aec`)

The line this file sits on, from P31's audit: `CompanionActionManifest.fromJson`
is deliberately **lenient** — it defaults a missing canvas, missing anchors and an
unknown loop mode — because it reads data compiled in by us. That is right there
and wrong for untrusted input, where *"the parser accepted it"* only means the
parser did not have to guess quite as much. So validation is a separate, strict
step that **refuses rather than fills in defaults**.

Refuses: a missing or mismatched `companionId`; a missing or undersized canvas;
anchors outside the canvas; an empty action set; a single-frame action, because a
still image is not an animation; non-positive fps; an unknown loop mode, rather
than defaulting one and silently changing how the pack animates; a frame the pack
does not contain, or one listed twice; absolute paths, drive letters, directory
escapes and null bytes; a pack with no decodable `idle`; and a
`semanticFallback` or `drawAliases` entry pointing at an action that does not
exist.

Two deliberate omissions: it does **not** require the production action set (a
pack with `idle` and `walk` alone is valid — that is P33's premise, and a test
asserts it so the requirement cannot creep back in), and it adds **no checksum
field yet**, because a checksum written but never verified is decoration and the
verifier is what reads it.

### 3. `companion_pack_install_plan.dart` (`ece716d`)

Refuses rather than escapes. The id reaches the filesystem, so it is
`^[a-z0-9][a-z0-9_-]{0,63}$` — which rejects a separator, a dot, a space and a
colon, and makes `..` unspeakable. A built-in id is refused, because two
companions answering to `dog` would make the persisted selection ambiguous. A
re-install of an existing id is refused rather than shadowing it. Species must be
one of the three; the name must be non-empty.

`CompanionPackSource` (`built_in` / `local_import` / `local_compile` /
`cloud_generated`) is **recorded and consulted by nothing** — a test asserts all
four produce the same plan, which is the architecture rule made executable.

## What is not built, and what it has to solve

**The extractor.** A shell around `CompanionPackArchivePolicy`, writing only
inside the sandbox. Needs an archive dependency the project does not have —
**this is the only new dependency P32 introduces and it is the decision to make
first**, because it changes the build.

**The install path.** Sandbox → validate → install into app-private storage →
register → select. The hard part is not the writing, it is that the runtime
resolves companions *statically* today:

- the action manifest is a **Dart const mirror compiled into the binary**
  (`companion_action_manifest_data.dart`), not read from disk;
- frames are read by `AssetImage` / `Image.asset`, so a directory cannot simply
  be handed to the existing player;
- `CompanionActionAvailabilityResolver` reads that mirror and the director caches
  the result (`companion_behavior_director.dart:71-82`);
- `CompanionAvatar` reads the catalog and registry **once at init**
  (`companion_avatar.dart:189-197, 433-438`), so a newly installed pack would not
  appear until restart.

So installing a pack is not only a write; it is a decision about when those
caches are rebuilt, and that decision belongs to P35 (the generic runtime) as much
as to P32. It is also what `FileCompanionSelectionStore` does *not* solve — it
stores the selected id and nothing else, and `companionSelectionProvider` only
accepts an id present in the static `CompanionManifestData.profiles`.

**Export.** An installed pack written back out as `.cozy_pet`. The entry list it
would produce is exactly what `CompanionPackArchivePolicy` already knows how to
judge, so export and import can share one vocabulary.

## Carried forward from P31, still open

- **`manifest.py` certifies itself**: it derives `groundBaseline` and
  `centerAnchor` from the mean of the *output frames' own* `bottomY` / `centerX`,
  so a uniformly drifted set would have its manifest and its images agree with
  each other while both are wrong. Anchors must be validated against an
  independently declared contract.
- **`docs/companion_assets.md` is stale**: it claims a 1024×1024 canvas with
  919/511 anchors and that every pack must be added to `pubspec.yaml`, while the
  real JSON is 512×512 with ~458/255.
- **P33's test scoping**: `multi_companion_parity_test.dart` forces every profile
  to the dog's thirteen actions. Right for the built-in packs, wrong as an
  admission requirement for a user's partial pack.

## Process note

Three times in this session a shell heredoc silently truncated file content — a
commit message and two file writes. Every file in this phase was written with the
file tool and landed first time, through two rounds of lint fixes. **No file
content through a heredoc in this shell.**
