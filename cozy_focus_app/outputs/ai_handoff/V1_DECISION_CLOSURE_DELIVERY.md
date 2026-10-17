# CozyFocus 2.0 — V1 decision closure and final visual candidate: delivery

**Git HEAD: `aa3d866`** on `recovery/v4.2.1-rebuild`.
The room candidate lives on `visual/room-candidate` (`beaa899`), which is **local
only** — pushing a new branch was not covered by the standing authorisation.

Everything below is measured. Where something was not done, it says so.

---

## 1. The six product decisions — what each one actually required

The honest headline: **four of the six needed no code at all.** The product
already behaved as decided; what the decisions changed was the *meaning* — an
unfinished feature became an intended rule. The two that did need work are exactly
the two where the code disagreed with the intent.

| | decision | code change | guard |
|---|---|---|---|
| D1 | no material economy; crafting costs time | **none** — already true | a test reads the seeded recipes and fails if any gains a material cost |
| D2 | keep the coin ledger, no sink in V1 | **none** — already true | the router has no shop/store/mall/exchange/redeem/buy path |
| D3 | the recipe is the furniture's user-facing name | **2 furniture labels + 8 collection names** | `furniture_name_agreement_test.dart` reads the *seeded database* and asks both display surfaces to agree |
| D4 | `long_session` at 50 minutes | **type + threshold + rule + both settlement paths** | 6 cases pin the boundary (49:59 no, 50:00 yes) and that a 50-minute session reaches the DB through both real paths |
| D6 | 100 XP/level, cap 30, no reset | **none** — doc status only | `growth_curve_v1_test.dart` pins the numbers as literals |
| D7 | local-first; nothing claims to sync | **none** — already honest | a real enqueue + flush leaves the outbox entry pending |

Each guard was **reverse-proved** by restoring the pre-decision behaviour: D3 fails
three of four, D4 fails four including the both-paths case, D7 fails with "would
let the UI show a synced state for a sync that never happened".

### D3 detail, because it was larger than the record said

The same id carried up to **three** names. The earlier audit compared two of them
and reported "2 of 5". Measured across all three surfaces, **seven of the eight**
recipe-backed collection items disagreed too (`温馨布艺沙发` vs `温馨沙发`,
`专注写字台` vs `窗边书桌`, …). All now read the recipe name.

**The database was not touched.** The recipe names were already the canonical ones,
so nothing is migrated, existing installs keep their ids and their progress, and
`schemaVersion` stays at 11.

### D4 detail

`PetMemoryType.longSession` added to the closed set (a test already asserts every
written type belongs to it). `CompanionMemory.longSessionThreshold = 50 * 60`
declared beside the only rule that reads it. Both settlement paths now pass the
session's own length — the same seconds settlement uses for coins and XP, so a
memory cannot describe a session the ledger disagrees with. Dedup, the
exactly-once transaction gate and local-only privacy are the existing machinery.
The memory names the session's own length, so 90 minutes does not read as "50".

### Also fixed: two screens claiming features that are not implemented

Found while auditing the release blockers, not part of the six decisions, and a
contract violation either way. On `focus_setup_page`:

* **白噪音** showed `森林  >` — a current value *and* a drill-in chevron for a
  picker that does not exist, on a row with no `onTap`. `森林` was an invented
  "current sound".
* **专注结束提醒** showed a real `Switch`, working `setState`, **defaulting to ON**,
  backed by a bool that never left the page. `flutter_local_notifications` is in
  `pubspec.yaml` and has never been imported in `lib/`. This is the worse of the
  two: the control moves, so the user believes reminders are armed.

Both now state what is true, in the settings page's own words. Guard:
`focus_setup_honest_rows_test.dart`, reverse-proved.

---

## 2. The hand-drawn room candidate

`outputs/visual_qa/compare/room_candidate_THREE_WAY.png` — shipped room + Mochi,
candidate room + Mochi as a real Flutter composite, and board 01's phone UI. Both
device panels are the same companion in the same pose, so the room is the only
variable.

### The image tool was blocked, and no candidate was invented to hide it

Doubao binds and reads correctly — window, model selector, image-generation mode
all present — but Windows' foreground was held by `ShellHost`'s *快速设置* panel,
so no app could be activated and every raw-input path was rejected. The prompt
field is an Electron `contenteditable` exposed as a non-settable `Group`, so there
is no accessibility path either. Volcano Ark returns 401 (the env var holds an
access-key id, not a bearer token), OpenAI returns 401, and the local CLI proxy
wants a key that is not mine to read and may bill — not touched.

So the route was implemented by hand, which is a fair reading of the brief: the
requirement is *a high-precision 2D hand-drawn room*, and the tool was the
preferred means rather than the requirement.

### Verdict

**The candidate clearly improves the room and leaves the fusion roughly where it
was.** Against board 01 it gains the rug under the pet, furniture, floor depth and
a window that is a way out — none of which the shipped room has. It does not close
the largest gap, because the board's pet is a 3D plush *in* the room and the brief
forbids swapping the 2D Mochi for an inconsistent 3D.

Three revisions were needed; the first two failures were the same mistake twice —
light with a visible outline reads as geometry laid over the scene. A perspective
light pool plus a hard-edged shaft tiled the frame with diagonals; floor
cross-seams added a lattice; and radiating the floorboard seams from the vanishing
point produced a sunburst under the pet. All three are recorded in the file.

**Recommendation: present it, do not adopt it on engineering's own authority.**
The brief's condition is that it *clearly* improves; it does not clear that bar.

### Performance, measured — and the instrument is the limit

| run | build p50 | raster p50 | late frames |
|---|---|---|---|
| shipped room | 1032 µs | 14460 µs | 2 |
| candidate, run 1 | 306 µs | 3300 µs | 2 |
| candidate, run 2 | 1419 µs | 12535 µs | 3 |

**Two runs of the same candidate build differ by ~4× on raster p50.** The
defensible claims are that the candidate is inside the 16.67 ms budget and shows
no consistent regression. The apparent "3× faster" is recorded as **not a
finding** so it is not quoted later.

Separately: the **shipped** room measured raster p50 **14.46 ms**, close to budget.
Pre-existing, on a software rasteriser, and worth the real-device pass.

---

## 3. Unresolved visual problems

| # | problem | where |
|---|---|---|
| V1 | the candidate's **left bookshelf is unreadable** — it sits in the blurred far layer and reads as a smudge with green streaks | candidate only |
| V2 | the candidate's **side-wall wedge** shows as a dark diagonal band at the top left that reads as a shadow, not a wall | candidate only |
| V3 | the candidate's **window is smaller and less luminous** than the shipped one, which is the shipped room's strongest element | candidate only |
| V4 | ~~in both rooms the pet's feet land on the desk line~~ **room fixed** (`a5d8ab4`); home/focus/growth are unchanged *by design* — the pet stands on the desk there | room: fixed · others: intended |
| V5 | the board's pet is a **3D plush in the room**; both options draw a flat sprite | neither can close this — the brief forbids the swap |
| V6 | `room_sit` has **no sprite sequence** in any pack; the rig carries it | shipped, unchanged |
| V7 | **no photographic-room path** — settled as "worse, not impossible", with a side-by-side probe as evidence | settled |

---

## 4. Release readiness checklist

| item | state | note |
|---|---|---|
| Android release signing | **BLOCKED** | `key.properties` absent → debug signing. No keystore generated, deliberately. `.gitignore` proven to block it; owner's `keytool` command written out in `RELEASE_READINESS_AUDIT.md` §C1 |
| Launcher icon | **BLOCKED** | stock Flutter logo. Candidate drawn (6 sizes); nothing under `android/` touched; blocked on **approval**, not on artwork existing |
| System notifications | **not implemented** | package present, 0 imports. UI now honest on both screens that mention it |
| White noise | **not implemented** | no audio package, 0 audio files. UI now honest |
| Data export / restore | **absent** | audited, not invented — new feature, and restore semantics are product decisions |
| Route coverage | **34 / 34 device-walked** | the earlier "33" was my own miscount |
| Frame time | **measured** | 697–698 frames, build p50 1.0–1.4 ms, raster p50 12.5–14.5 ms, inside budget |
| `OWNER_VISUAL_GATE` | **DEFERRED** | never decided by a measurement |
| `FLOW_GENERATION` | **BLOCKED** | no video surface reachable in Flow |

---

## 5. Real test results

```
tools/cozy_gate.py --full --with-device
  FORMAT            PASS   471 files, 0 changed
  ANALYZE           PASS   0 issues
  UNIT_TESTS        PASS   2107/2107
  INTEGRATION_TESTS PASS   51/51
  GOLDEN_FLOW       PASS   6/6
  MIGRATION         PASS   16/16
  LIFECYCLE         PASS   81/81
  ASSET_GATES       PASS   75/75
  DEVICE_MATRIX     PASS   697 frames, build p50 1426us / p90 2222us, 0 over budget
  APK               PASS   32.0 MB (budget 34)
  AAB               PASS   50.5 MB (budget 55)
  DIFF_CHECK        PASS   no whitespace errors
  RELEASE_SIGNING   BLOCKED
  LAUNCHER_ICON     BLOCKED
  OWNER_VISUAL_GATE DEFERRED
  PRODUCT_DECISIONS PASS    P25 reads CLOSED, 0 open
  BEHAVIOR_AUTHORITY PASS   count = 1, measured
  FLOW_GENERATION   BLOCKED

counts: {'PASS': 14, 'BLOCKED': 3, 'DEFERRED': 1}   FAIL: 0
```

---

## 6. The minimal list needing the owner

1. **Approve or reject the launcher icon candidate** (`outputs/launcher_icon_candidate/`).
   Until then the app ships the Flutter logo.
2. **The release keystore.** Generate it yourself, store it outside the repo, back
   it up somewhere that is not this machine. The build switches over with no code
   change.
3. **Choose the room**: keep the shipped one, or pursue the hand-drawn one. If
   pursuing it, whether V1–V3 above are the right first fixes, and whether the room
   should stay this busy or return toward the shipped room's calm.
4. **The visual gate** (`OWNER_VISUAL_APPROVED`) — I cannot claim it, and have not.
5. **A decision on data export/restore**, since uninstalling currently loses
   everything and the app does not claim otherwise.

Nothing above is blocked on engineering.

---

## 7. What this round did not do

* No production art was replaced. The shipped room painter, the shipped icon and
  every device-verified screen are as they were.
* No feature was invented to close a decision. D1, D2 and D7 were confirmed as
  already-true rather than built; white noise, notifications and data export were
  left unimplemented.
* No keystore was generated and no private key was committed.
* `OWNER_VISUAL_APPROVED` and `STORE_RELEASE_READY` were not claimed.
* No scheduled task or recurring automation was created.
