# P28 — Furniture Action Truth

READ-ONLY architecture audit at `recovery/v4.2.1-rebuild` @ `226922f`.

**P28 was already implemented** in `43f58dd`, `759c6af` and `2cc48eb` (P29 and P30 also
landed). So this audit reviews the code as it stands rather than planning greenfield
work, and it found four things the implementation's own documentation got wrong or
left open. They are recorded here rather than quietly fixed, because three of them
change what "P28 PASS" is allowed to mean.

---

## CURRENT_STATE

- **Companion runtime: partially closed.** The simulation records action, cause,
  anchor, deadline and the player commitment; the page hands the decided
  `companionAction` to the director instead of letting the ambient recipe choose
  again. An ordinary tick, and a forced evaluation while the furniture is still
  usable, can no longer displace an unexpired player commitment.
  (`room_simulation.dart:316-352,385-425`, `room_page.dart:583-603`,
  `companion_behavior_director.dart:417-445`)
- **Furniture: data-driven selection exists, but "selectable" is not "visible".**
  Five items, ten actions in the catalog. The panel hides `room_sit` on capability,
  but the runtime routine can still choose it. (`furniture_catalog.dart:38-44,50-239`,
  `furniture_use_panel.dart:61-70,175-185`)
- **Animation: not a mere image player, but visual acceptance is unfinished.** There
  is a data-driven state projection, sit/stand/walk transitions and a per-frame
  player that honours the manifest's fps, loop mode, backgrounding and reduced
  motion. The code can prove frame files exist and that sequences differ in bytes.
  It cannot prove each action is distinguishable on a phone.
- **Growth: boundaries are clean.** Stage derives from real `PetProgress` and affects
  behaviour modifiers and micro-motion; the animation layer writes no XP, no
  settlement, no craft record.

---

## ROOT_CAUSE_EVIDENCE

**The original mechanism is confirmed.** `requestAction` immediately calls a forced
`_evaluate`; the decision commits and clears the one-shot `request` in the same
`copyWith`; ordinary evaluation has the `endsAt` guard and forced evaluation crosses
it. Without the new commitment guard the next forced evaluation would fall through to
focus/rest/routine/idle with `request == null`, which is enough to replace `sofa/sit`
before its ~14 s expired. (`room_simulation.dart:263-270,322-350,364-383,413-425`,
`furniture_action_resolver.dart:200-230,420-433`)

**The fix closes one class of path.** The guard returns when
`force && owesDwell && playerCommitmentItemId != null`, the entry point is not in
`{request, focusPause}` and the furniture is still usable. So on the *same* placed,
owned, visible item, `evaluateNow` and `setArranging(false)` no longer re-choose.
Regression tests cover those calls. (`room_simulation.dart:346-352,436-452`,
`player_request_authority_test.dart:152-199,267-330`)

**Paths that can still end a commitment early, or make it look ended:**

1. **A clock jump past the deadline — high priority.** `_tick` adds
   `DateTime.now().difference(_lastTick)` to `elapsedSinceStart` with **no upper
   bound**. If the timer arrives late by more than the remaining dwell — background,
   jank, a clock change — the next tick treats the commitment as expired and
   re-chooses. What the code guarantees is accumulated duration, not that the player
   watched 14 seconds. `stop()`/`start()` resets `_lastTick`, so background time is
   not always accumulated; the device behaviour needs measuring rather than
   asserting. (`room_simulation.dart:190-203,294-303,322-326`, `room_page.dart:133-161`)
2. **The commitment is validated by `itemId`, not by the placed instance — high
   priority.** `_commitmentIsStillUsable` only requires that *some* item of that kind
   is owned and visible. With two sofas, removing or hiding the one the player tapped
   leaves the guard satisfied by the other. The activity points at a generic
   `sofa_anchor`, and the page looks up that id, falling back to the floor anchor — so
   the status can say "resting on the sofa" while the picture is somewhere else. The
   request path likewise resolves an anchor by `roomItemId` without checking that its
   `itemId` matches the requested one. (`room_simulation.dart:446-452`,
   `furniture_action_resolver.dart:235-253`, `anchor_point.dart:126-156,160-173`,
   `room_page.dart:541-544,620-628`)
3. **Deliberately permitted preemption.** A different `requestAction` and
   `setFocusPaused(true)` may force a re-choice; so may `evaluateNow` once the
   furniture genuinely becomes unusable. A repeated request for the *same* action is
   short-circuited and neither renews the dwell nor re-applies the effect.
   `setFocusPaused(false)` does not evaluate immediately.
   (`room_simulation.dart:236-270,279-292,342-352,438-452`)
   Note `setFocusPaused(true)` only checks that the boolean changed — it does **not**
   verify that a real session is paused; the page's value comes from session state,
   but a test or another caller can trigger it directly. (`room_page.dart:239-241,261-268`)

**Effect semantics: once per *decision start*, not once per player intent.**
`copyWithEffect` runs only when `_evaluate` commits a non-neutral decision. A tick
inside the dwell, a guard-blocked forced evaluation and a repeated tap on the same
action do not re-apply it. **But after expiry, if the routine or idle re-selects the
same action, that is a new decision and the effect is applied again** — the code
allows that loop. Different actions requested in quick succession stack their own
effects. `knowledge` is declared in the catalog but is not applied by
`copyWithEffect`. (`room_simulation.dart:249-261,322-326,385-425`,
`companion_vitals.dart:87-93`, `player_request_authority_test.dart:201-235`)

---

## ACTION_MATRIX

Code and asset-contract classification — **not** human device acceptance. All three
packs list dedicated sequences for every action below except `room_sit`, and the frame
files exist with non-identical bytes within a sequence. Whether they read clearly is
still unverified.

| Action | Classification | Drawable by |
|---|---|---|
| sofa/sit | **NO_REAL_VISUAL_ACTION** | none of the three can draw a recognisable sustained sit |
| sofa/rest | VISUALLY_DISTINCT (asset path) | all three — `pause_rest` |
| desk/write | VISUALLY_DISTINCT (asset path) | all three — `focus_write` |
| desk/study | VISUALLY_DISTINCT (relative to its desk siblings) | all three — `focus_think` |
| desk/craft | VISUALLY_DISTINCT (asset path) | all three — `craft_work` |
| bookshelf/read | VISUALLY_DISTINCT (asset path) | all three — `focus_read` |
| bookshelf/search | **VISUALLY_AMBIGUOUS** | all three — shares `focus_think` with desk/study |
| bed/sleep | VISUALLY_DISTINCT (asset path) | all three — `sleep` |

`sofa/nap` has **no `playerTap` trigger** yet the panel still offers it, because the
panel filters on drawability alone. That is a demonstrable catalog/UI drift.
(`furniture_catalog.dart:85-93`, `furniture_use_panel.dart:65-70,175-185`)

**`room_sit`, layer by layer.** The catalog points sofa/sit and rug/sit at `room_sit`;
the status bar prints 正在坐下 / 坐一会儿. All three manifests have
`semanticFallback: room_sit → idle` and **no** `drawAliases` entry for it; the Dart
mirror matches. Capability lists it as schedulable-but-fallback, and the director can
hold the `roomSit` semantic. The animation projection is `room_sit → idle` (standing);
the dog's layered rig changes only `earRotation: 0.06`; cat and rabbit have no
`room_sit` drawing and fall back to their non-sitting art. `sit_down` frames exist but
are the *transition into* a seated state, not a sustained sit, so their existence
cannot be counted as the sit action having shipped.
(`furniture_use_panel.dart:290-299`, `dog/manifest.json:230-258`,
`companion_action_manifest_data.dart:213-242,431-460,649-678`,
`animation_state_machine_data.dart:27-41,80-94`, `mochi_pose_spec.dart:109-112,181-183`)

**The matrix is mixed, not end-to-end measured.**
`furniture_action_matrix_test.dart:92-108,109-173` does drive the simulation and check
the immediate decision, the nominal dwell, one forced re-evaluation and exit past the
maximum dwell. But visual capability is inferred from manifests — never rendered, never
compared by eye. `reachedIntendedAnchor` only checks the anchor string is non-empty.
`effectAppliedOnce` compares three vitals after a single re-evaluation without
confirming the initial expected delta. And **the summary field `offeredByPanel`
actually counts actions *without* a `playerTap` trigger** — its value `1` is
`sofa/nap`, not the number the panel shows — while the same file marks that action
`reachableByPlayerTap: true`. The committed JSON can therefore drift from the product,
and its summary is already misleading. (test `:225-247`, JSON `:5-14,111-153`)

---

## DESIGN

**Effective precedence has to be read in layers, not from the `RoomDecisionCause`
enum's order:**

1. **Simulation admission.** While arranging, an ordinary tick does not choose; an
   unexpired ordinary tick does not choose; an unexpired player commitment on still-
   usable furniture blocks forced `evaluateNow` / `arranging` re-choices. A new
   `request`, `focusPause` and furniture invalidation are outside that guard.
   (`room_simulation.dart:312-352,429-452`)
2. **Once choosing is allowed, the resolver's order is** valid `playerRequest` →
   focus running when a desk exists → focus paused / break when a seat exists →
   night or low-energy rest → daily routine → deterministic idle furniture action or
   floor idle; falling through when furniture is missing. The pause rest reports cause
   `tired`, not a distinct pause cause. Focus running derives from
   `home.hasActiveSession && !focusPaused`, so when a real session reaches the
   simulation depends on the page's sync too. (`furniture_action_resolver.dart:200-230,256-343,362-418`,
   `room_simulation.dart:364-382`)
3. **Presentation has its own precedence and does not change the simulation's
   commitment.** A forced celebration precedes the room's committed macro, which
   precedes the ambient recipe; a short overlay covers the macro's pose and then
   restores it; while travelling, the animation target `walk` precedes the behaviour
   pose until the transition ends. So the status bar saying 休息 while the picture
   briefly walks or reacts does not by itself mean the simulation preempted — and
   conversely, a status bar saying 坐下 does not prove a sit was drawn.
   (`companion_behavior_director.dart:394-445,605-629`,
   `companion_animation_controller.dart:204-250`)

**Product judgements.**

- **P0: establish what the device's early hand-off actually was** — a simulation
  re-choice, a clock jump, travel/overlay covering, or a page rebuild. The logic fix
  cannot be declared to have removed a device symptom on unit tests alone.
- **P1: hiding sofa/sit and rug/sit is the right interim choice**, consistent with
  "do not ship fake choices". But the rug has only that one catalog action, so its
  panel now reads 这件家具现在没有能做的动作 — an explicit product regression in
  furniture interaction that cannot be called a complete fix. And the routine and
  idle can still select `rug/sit` and the routine can still select `sofa/sit`, so the
  fake visual action has **not** disappeared from the game — only from the panel.
  (`furniture_use_panel.dart:110-121,157-185`, `furniture_catalog.dart:215-239`,
  `daily_routine.dart:109-127`) Reopening it is only legitimate after approved real
  sit art or a sustained action exists, or after the rug's honest purpose is
  redefined; status text or an ear twitch cannot stand in.
- **P1: fix the panel-vs-catalog trigger contract and the commitment's placement
  identity.** Today `sofa/nap` becomes a clickable option, and with several items of
  one kind both the guard and the anchoring are imprecise.
- **P2: decide whether 学习 and 找一本书 may share `focus_think`.** Within one object
  the alternatives are distinguishable, but search has no searching motion — it is
  thinking. If the product promises both behaviours as visually separate, the current
  assets do not deliver it. `knowledge`, and any copy read as real crafting, must also
  be reconciled with what actually happens.

---

## TEST_PLAN

Verification still owed — none of this was executed in the audit.

**Device timeline first.** Record, correlated: monotonic and wall clock, the raw
`elapsed`, remaining `endsAt`, `via`, `force`, old and new cause/action, `itemId` and
`roomItemId`, overlay and travel state — at player tap, every `_tick`, every forced
entry point, guard hit/commit, `setFocusPaused`, page `start`/`stop`, and every
presentation pose or animation-state change. The existing `RoomDecisionTrace` records
only *committed* decisions: not uncommitted ticks, not guard hits, not page
lifecycle, and it has no `requestAt` or real time. It cannot, on its own, explain the
device's 2–4 seconds. (`room_simulation.dart:63-115,155-171,294-303,396-411`)

**Then:** normal foreground 2 s ticks; a 15 s late tick; background resume and system
clock change; same-action double tap and different-action re-choice; pause start and
resume; scale/move/hide/remove on the tapped sofa, **specifically with two sofas of
the same kind**; a request whose `roomItemId` and `itemId` disagree; and whether the
routine re-selecting the same action after expiry matches product intent. Add panel
tests covering all five items, all three companions and the trigger contract rather
than asserting on the sofa alone. The matrix should verify the committed artifact, the
real target anchor and the effect delta, and should separate "playable per manifest"
from "distinguishable on device".

The device material is
`outputs/ai_handoff/android_v1_runtime/p28_rest_status_over_time.png`,
`p28_rest_action_held_on_sofa.png` and `p28_sofa_panel_real_actions_only.png`.
**The audit could not resolve those images' pixels or OCR**, so it could not
independently confirm the status text, the frame intervals, or that they came from the
same build. The reported "status gave way early" is therefore a device observation
awaiting correlated logs, **not** proof that the implemented fix failed. And even a
confirmed status change would only show that the displayed state changed — the
timeline above is what would say who changed it.

---

## FILES_TO_TOUCH

**Nothing was touched in this audit.** If an approved implementation phase follows,
these existing files are the candidates — not new systems:

- Clock and commitment/instance validation:
  `lib/presentation/companion/room/room_simulation.dart`,
  `lib/presentation/companion/room/furniture_action_resolver.dart`,
  `test/presentation/companion/room/player_request_authority_test.dart`
- Player offerability, honest copy and matrix verification:
  `lib/presentation/companion/room/furniture_use_panel.dart`,
  `lib/presentation/companion/room/furniture_catalog.dart`,
  `test/architecture/furniture_action_matrix_test.dart`
- Only after approved real motion assets or a scheduling-rule change: the three
  existing `manifest.json` files, their Dart mirror, the animation projection and the
  routine data — keeping the existing parity tests rather than adding a second action
  source.

## FILES_NOT_TO_TOUCH

- `outputs/ai_handoff/FURNITURE_ACTION_MATRIX.json` — never hand-edited to make a test
  pass; it is a generated artifact and its generation is what must be fixed.
- The `p28_*.png` device originals.
- `lib/presentation/companion/runtime/companion_sprite_player.dart` — not replaced with
  a new image player.
- Focus settlement and growth business data — not rewritten for furniture presentation
  effects.
