# P39 — Full Hardening

Branch `recovery/v4.2.1-rebuild`.

**Status: COMPLETE for everything that does not need a person or credentials.**

1510/1510 tests, format clean, analyze clean, worktree clean.

## What was added in this phase

| item | result |
|---|---|
| damaged-pack recovery | 8 tests + a device pass |
| accessibility on the import screen | 4 tests |
| sprite-cache bound | `maxFramesPerAction = 64`, 2 tests |
| release APK / AAB | 30.1 MB / 48.6 MB, both building |
| shipped asset integrity | 3 packs, 147 frames, none missing, all contracted |

## What was already covered, and checked rather than assumed

The list is worth recording because "we ran the hardening phase" is not evidence:

- **process death mid-session** — `persistence_recovery_test` covers an active
  session, a pause, and a session while finishing; `golden_flow_test` covers the
  abandoned `finishing` session a kill leaves behind, settling it exactly once.
- **migration** — the v1→v2→v3→v4 chain, including "the full v1 to v4 chain
  preserves every row" and "an already-current database is left alone".
- **leaks and performance** — `companion_lifecycle_leak_test` and
  `performance_lifecycle_budget_test`.
- **reduced motion** — honoured for a custom companion *by construction*: it is
  the same director and the same context, with no per-companion branch, which
  `custom_companion_first_class_test` asserts. No new test could add anything a
  branch-free design does not already give.
- **both golden flows** — the built-in one in `golden_flow_test`, the local custom
  pet one walked on the device in P36.

## The two things this phase found

### A memory bound that was missing

The player precaches the active sequence **in full**, deliberately, so an
animation does not stutter while its frames decode. That is right for a companion
animation and wrong for an action declaring thousands of frames: the archive
policy allows 4096 entries and a decoded 512×512 RGBA frame is about a megabyte,
so an unbounded action was a pack that exhausts memory *by being well formed*.

`maxFramesPerAction = 64`, refused at import rather than trimmed, with the bound
named in the refusal. 64 is generous rather than tight — the shipped packs use
between two and six frames per action, and at 8fps that is an eight-second
animation. One test asserts over-the-bound is refused; another asserts
at-the-bound is accepted, so the cap cannot refuse the thing it exists to allow.

### A finding I had to withdraw

I recorded that an already-alive `companionCatalogProvider` did not recompute
after a pack became unreadable, and left it open rather than writing an assertion
that did not describe it. Chasing it properly showed it **does** recompute: a
traced diagnostic prints two emits, `[dog,cat,rabbit,mimi]` then
`[dog,cat,rabbit,other]`.

The earlier observation was an artifact of the test — a provider that is only
`read` is not invalidated when its dependency changes, which is a fact about
`read`, not about the catalog. The test now subscribes the way a widget does.

That is the second false finding this phase produced by test methodology rather
than by the app; the first was `publish()` being a no-op without a revision bump.
Both are in the process notes. The lesson is narrow and worth keeping: **before
recording a finding about a provider, check that the test is watching it the way
production does.**

## The device pass over the damaged-pack cases

With an installed pack's `manifest.json` removed underneath the running app, then
a cold start:

- recovery dropped the pack and **removed the record file** rather than leaving a
  record for nothing;
- the home page came up on **Mochi** with the dog sprite — the app degraded to a
  built-in rather than showing a broken or blank companion;
- the player's **2 分钟 and 1 天 streak were untouched**, which is the shared-growth
  rule holding when a companion disappears;
- logcat had no exceptions.

One observation recorded because it looks alarming in a file dump and is not:
the selection *file* still reads `mimi` afterwards. An unknown stored id is
ignored on read and the file is rewritten on the next select, so it is a stale
preference rather than a stale behaviour.

## What is not covered

- **A device pass over the accessibility work.** The assertions are widget-level;
  a TalkBack pass would be the real check and needs a person listening.
- **A sustained performance run** with several installed packs. The budget test
  covers one companion's lifecycle, not a room full of custom ones.
- **Cloud-specific flows** — `NOT_ENABLED`. See P38.
