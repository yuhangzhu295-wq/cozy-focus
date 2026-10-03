# FLOW ASSET PROMPTS — rabbit

Archive of every Google Flow generation attempt for the rabbit sprite pack.

**Status: UNBLOCKED. Master and `idle` frame 1 are generated and accepted.**
The block below was self-inflicted and is now understood — see §6.

---

## 1. Audit — the rabbit has no artwork anywhere

Unlike the cat, whose pack existed in a project of its own, the rabbit has
**nothing**:

| Where | Result |
|---|---|
| `assets/companions/` | only `dog/` and `cat/` |
| The repo | no rabbit frame, no rabbit master, no rabbit prompt archive before this file |
| Flow project `Cozy Focus Companion Production` (`2f518015`) | dog tiles only |
| Flow project `Oct 01 - 01:20` (`49593efa`) | kitten tiles only |
| Flow project `7de657e6` (9月 21) | unrelated — portrait/photography prompts, a ChatGPT image |
| Flow project `38b91b0c` (9月 12) | unrelated — an infographic motion video, ChatGPT screenshots |

All four projects were opened and listed. So the rabbit's pack is not "partially
produced"; it was never started.

### How the rabbit renders today

Through `RabbitVisualProvider` and the procedural rig, which is a **real
drawing**, not a fake animation — the pack does not exist, so the runtime falls
back to the rig and the multi-companion test asserts it "must not claim art it
does not have". The rabbit is therefore *degraded, not broken*.

### Its design is already specified in code

`lib/presentation/companion/procedural_companion_art.dart`:

```dart
static const CompanionSilhouette rabbit = CompanionSilhouette(
  earShape: CompanionEarShape.long,
  earLength: 1.05,
  earSplay: 0.14,
  hasWhiskers: false,
  tail: CompanionTailShape.puff,
  furColor: Color(0xFFF6EFE6),
  innerEarColor: Color(0xFFEBC3C3),
);
```

Long upright ears, no whiskers, a puff tail, cream fur, dusty-pink inner ear.
That is a spec, not a blank page — the master prompt below is written to it.

---

## 2. The blocker — the generate control cannot be triggered

The master prompt was written, entered, and the generate control was pressed
four different ways. **None of them submitted.**

Measured state of the control at the time of each attempt:

```
ariaLabel: "Start generation"   disabled: false
display: inline-flex            visibility: visible
opacity: 1                      pointerEvents: auto
inViewport: true                tiles loaded: 24
```

So the control was genuinely live. What was tried:

| Attempt | Result |
|---|---|
| `getByRole("button", { name: "Start generation" }).click()` | locator timed out — never resolved |
| `getByRole(...).click({ force: true })` | locator timed out on `count()` and `isVisible()` too |
| `cua.click({ x: 975, y: 893 })` — the control's own centre | no effect; prompt unchanged |
| `evaluate(() => button.click())` on the real `<button>` | no effect; prompt unchanged |
| `cua.keypress({ keys: ["Enter"] })` with the editor focused | no effect; prompt unchanged |

Two structural findings that may explain it:

- `document.elementsFromPoint` at the control's centre returns
  `FLOW-GENERATE-ICON-BUTTON`, the **custom-element wrapper**, and never the
  inner `BUTTON.mdc-icon-button`. The wrapper and the button report the same
  32×32 rect at the same centre, so the button is not the hit target at its own
  centre.
- The page reports a `[role="status"]` "Loading…" region continuously, before and
  after a reload, with 24 tiles already rendered. That is probably a persistent
  aria-live region rather than a real loading state, but it is the one signal
  that never settles.

This is the same class of outcome as the rate-limit block recorded in the cat
archive: an external UI refusing to proceed, reported rather than worked around
by faking a result.

---

## 3. A technique that DOES work on this Flow build (worth keeping)

The prompt editor rejects Playwright's normal input path, but this works
reliably:

```js
// 1. focus and select the editor's contents through a DOM Range
await tab.playwright.evaluate(() => {
  const e = document.querySelector(".ProseMirror");
  e.focus();
  const r = document.createRange();
  r.selectNodeContents(e);
  const s = window.getSelection();
  s.removeAllRanges();
  s.addRange(r);
});
// 2. type with the coordinate/type path
await tab.cua.type({ text: prompt });
```

What does **not** work on the same editor:

- `locator(".ProseMirror").click()` — times out on actionability (the editor is
  only 20 px tall)
- `cua.click` at the editor's centre — does not focus it
- `cua.keypress({ keys: ["Control+a"] })` then Delete — does not clear it
- `getByRole("button", { name: "Clear prompt" })` — does not resolve

Selecting through a DOM Range and typing over it replaces the contents
correctly. Verified: the editor went from 4 chars to a 1589-char prompt and
`Start generation` flipped from `disabled: true` to `disabled: false`.

---

## 4. The master prompt — written, verified as entered, never generated

This is the prompt that reached the editor. It is the first thing to run when
generation is unblocked.

```text
Create a character for a 2D mobile companion game, drawn in a soft, rounded,
low-saturation children's illustration style.

Full body visible. Fixed straight-on camera. Centred on a square canvas. Clean
isolated character. No text. No arrows. No UI. No additional characters.
No environment. No scene. No dramatic perspective. No redesign.

CRITICAL: absolutely no shadow of any kind. No drop shadow, no ground shadow,
no contact shadow, no grey ellipse. The background must be pure flat white with
nothing but the character on it.

CHARACTER: a small white chibi rabbit.
- Fur: soft warm off-white cream, with a slightly warmer cream belly.
- Ears: two LONG, tall, upright ears rising well above the top of the head,
  clearly taller than the head is tall, standing up straight with only a very
  slight outward splay. The inner ear is a soft dusty pink.
- Face: two large round dark brown eyes with a small white highlight each, a
  tiny pink nose, and a small gentle closed smile. There are NO whiskers at all.
- Body: compact chibi proportions, head round and roughly as wide as the body,
  short rounded limbs.
- Tail: one small round fluffy puff tail at the back.
- Accessory: a single small green two-leaf sprout growing from the top of the
  head between the ears.
- Outline: a soft warm brown outline of even weight, rounded line ends, no sharp
  corners.

POSE: sitting upright and still, facing the viewer, front paws together in front
of the chest, both feet flat on a level ground line near the bottom of the frame.
Calm, gentle expression.

Plain pure white background, no shadow, no scene, no furniture.
```

**Deliberately generated with no character reference attached.** The dog's
floppy ears are the exact opposite of the rabbit's long upright ones, and the
cat's triangular ears are wrong too; anchoring on either risks the model copying
the reference's ears. The prompt carries the silhouette from the code spec
instead, and `tools/productionise.py` normalises scale and ground line onto the
canvas, so no reference is needed for framing.

**Needs owner approval before it is treated as canonical.** The cat and dog
masters were both approved by the owner; a third companion's design is a product
decision even when the silhouette is already specified in code.

---

## 5. Plan once generation is unblocked

The pipeline is ready and now emits at the **512** canvas, so the rabbit is
authored at the right size from the start.

1. Generate the master above; verify it is a rabbit and not a dog by silhouette
   (long upright ears, no whiskers, puff tail), the same way the cat master was
   verified by fetching its image and comparing.
2. Stage at `.asset_staging/flow/rabbit/idle/idle_000.jpg`.
3. Build the pack in the same order the cat used, which is the order of player
   visibility: `idle` (6) → `walk` (6) → `sit_down` (4) + `stand_up` (4) →
   `craft_work` (4) → `focus_read`/`focus_think`/`focus_write` → `celebrate` (5)
   → `tap_react` (3) + `pet_react` (3) → `sleep` (2) + `pause_rest` (2).
   Target: the dog and cat shape, **13 actions / 49 frames**.
4. `python tools/productionise.py rabbit` → `tools/manifest.py rabbit` →
   `tools/gen_manifest_dart.py` → `flutter test`.
5. Add `CompanionPose` entries to `catPosesWithArt`-style expectations in
   `multi_companion_test`, which will fail loudly until they are updated — that
   is the test doing its job.

---

# 6. The block, solved — how to click this Flow build

The owner clicked once and the master appeared, which proved the page was fine.
The block was in how the click was aimed.

## What was actually wrong

The input path was never the problem. Instrumenting the button with capture-phase
listeners and clicking its centre showed a **complete, trusted** event sequence
arriving on the right element:

```
pointerdown -> mousedown -> pointerup -> mouseup -> click   (isTrusted: true, x/y exact)
```

The problem was **which element** those events reached.

`document.elementFromPoint` at the button's bounding-box centre returned
`FLOW-GENERATE-ICON-BUTTON`, the **custom-element wrapper**, which carries no
handler. A point a few pixels higher returned `MAT-ICON`, the icon **inside** the
`<button>` — and a click there works.

Two compounding details:

- The wrapper and the inner button report the **same 32×32 rect at the same
  centre**, so the bounding box cannot tell you which one is on top.
- The control's rect **moves as the prompt box grows**. A coordinate computed from
  an earlier rect is stale by the time the click lands. This is why the same
  centre worked once and failed another time.

## The method that works

**Hit-test before clicking.** Pick a point that `elementFromPoint` confirms is the
target or a descendant of it, and only then click.

```js
const pt = await tab.playwright.evaluate(() => {
  const el = document.querySelector('button[aria-label="Start generation"]');
  if (!el || el.disabled) return { error: "not clickable" };
  const r = el.getBoundingClientRect();
  for (const fy of [0.5, 0.4, 0.3, 0.6, 0.2]) {
    for (const fx of [0.5, 0.4, 0.6]) {
      const x = Math.round(r.x + r.width * fx);
      const y = Math.round(r.y + r.height * fy);
      const top = document.elementFromPoint(x, y);
      if (top && (top === el || el.contains(top))) return { x, y, hit: top.tagName };
    }
  }
  return { error: "no point hit-tests to the element" };
});
await tab.cua.click({ x: pt.x, y: pt.y });
```

Verified end to end: this submitted a generation and the prompt box cleared
(`promptLen: 0`, button back to `disabled`).

## Two more input techniques this build requires

**Typing into the prompt box.** Playwright's locator path fails here (the editor
is only 20 px tall, so the actionability check times out), `cua.click` on it does
not focus it, and `Control+a`/Delete does not clear it. What works:

```js
await tab.playwright.evaluate(() => {
  const e = document.querySelector(".ProseMirror");
  e.focus();
  const r = document.createRange();
  r.selectNodeContents(e);
  const s = window.getSelection();
  s.removeAllRanges();
  s.addRange(r);
});
await tab.cua.type({ text: prompt });
```

**Typing into an Angular input** (the asset search box). Assigning `.value` does
not notify Angular; use the native setter plus an input event:

```js
const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
setter.call(input, "rabbit");
input.dispatchEvent(new Event("input", { bubbles: true }));
```

## The lesson

`getByRole` and coordinate clicks both failed, and neither reported why. The
instrumentation did: the events were arriving, just on the wrong node. **When a
click silently does nothing, record the events that actually land and check their
`target` — before concluding the surface is broken.**

An earlier wrong conclusion of mine is worth recording too: I searched the
`get_visible_dom()` node list for `"generate"` and found nothing, and briefly
believed the control was unreachable. The label is `"Start generation"` — which
does not contain `"generate"`. A substring filter is not a search.

## 7. Accepted

| Action | Frame | Reference | Attempts | Tile name |
|---|---|---|---|---|
| master | — | none (prompt carries the silhouette) | owner clicked; 1 generation | White chibi rabbit sitting |
| `idle` | 000 | — | — | the master |
| `idle` | 001 | master (ingredient, UUID-verified) | 1 | Rabbit breathing idle pose |

The master was checked against the code spec before use: long upright ears,
**no whiskers**, puff tail, cream fur, dusty-pink inner ear, green sprout, seated
on the ground line. It is unmistakably not the dog (floppy ears) and not the cat
(triangular ears and whiskers).

`idle_001` was verified against the master: identity, camera, scale and placement
hold; only the breath differs.

## 8. Remaining

`idle` 002–005, then the rest of the 13-action / 49-frame contract, in the order
of player visibility: `walk` (6) → `sit_down` (4) + `stand_up` (4) →
`craft_work` (4) → `focus_read`/`focus_think`/`focus_write` → `celebrate` (5) →
`tap_react` (3) + `pet_react` (3) → `sleep` (2) + `pause_rest` (2).

The pipeline is ready and emits at the **512** canvas, so the rabbit is authored
at the right size from the start.

---

# 9. Session 2 — the idle loop

## Accepted

| Frame | Tile name | Attempts |
|---|---|---|
| `idle_000` | White chibi rabbit sitting (the master) | 1 |
| `idle_001` | Rabbit breathing idle pose | 1 |
| `idle_002` | Rabbit idle pose variation | 1 |
| `idle_003` | Rabbit character exhaling pose | 1 |
| `idle_004` | Rabbit exhaling idle pose variation | 1 |
| `idle_005` | Rabbit returning to rest pose | 1 |

Six for six on the first attempt, all generated by the hit-tested click in §6.
Each frame attached the master as the ingredient and the UUID was checked
against `39c6616e…` before every generation.

A six-frame contact sheet was checked before import: identity, palette, camera
and placement hold across the cycle, and `idle_005` is a near-neighbour of
`idle_000`, so the loop closes without a jump. The long ears trail the breath,
which is the movement the loop is meant to carry.

## Imported

`python tools/productionise.py rabbit` → `tools/manifest.py rabbit` →
`tools/gen_manifest_dart.py`. The pack is declared in `pubspec.yaml` — Flutter
does not recurse, and a missing declaration renders as an empty box rather than
an error, which is exactly how the cat pack was silently invisible once.

**rabbit: 1 action / 6 frames.**

## Three tests had to change, and each was right to fail

- `multi_companion_test` asserted the rabbit "ships no production art at all
  yet". It now has `idle`, so the rabbit joined the per-pose expectation loop
  with `rabbitPosesWithArt = {idle}`. The test also gained a stricter
  companion: every companion's *claimed* poses are now asserted to be a subset
  of its declared set, so no pack can quietly claim art it does not have.
- `companion_pack_completeness_test` asserted `forCompanion('rabbit')` is null.
  It is now non-null, so the absence assertion moved to an unknown id and a new
  test pins the rabbit's pack as present, partial, and honest about it.
- `companion_lifecycle_leak_test` selected the rabbit and asserted the
  **procedural** channel draws it. With `idle` shipping, the rabbit takes the
  sprite channel instead. The invariant was rewritten to what it actually means:
  the companion is still drawn *and* nothing is animating under reduced motion —
  true of either channel.

## Remaining

`walk` (6) → `sit_down` (4) + `stand_up` (4) → `craft_work` (4) →
`focus_read` (3) / `focus_think` (3) / `focus_write` (4) → `celebrate` (5) →
`tap_react` (3) + `pet_react` (3) → `sleep` (2) + `pause_rest` (2).
Target: the dog and cat shape, **13 actions / 49 frames**.

---

# 10. Session 3 — the walk cycle

## A standing master had to come first

The rabbit's approved master is seated and walk is a standing action, so a
standing master was generated from it (one attempt, "Rabbit standing on all
legs", UUID `5af4d19b…`). Identity, palette, camera and ground line carried
over; the long ears, puff tail, sprout and the absence of whiskers all held.
Every walk frame then attached **that** tile rather than the seated master.

## Accepted

| Frame | Tile name | Attempts |
|---|---|---|
| `walk_000` | Rabbit walking frame one | 2 |
| `walk_001` | (passing) | 1 |
| `walk_002` | (opposite contact) | 1 |
| `walk_003` | (passing, mirrored) | 1 |
| `walk_004` | (return) | 1 |
| `walk_005` | (close) | 1 |

`walk_000` took two attempts because the first was generated while the reference
was unverified — see below.

## A verification lesson: a mismatch means "not yet"

The first `walk_000` was generated after a check reported
`standing master attached: false`. The generation was submitted anyway, and the
result was discarded.

The check was wrong, not the attachment. The search returned exactly one option
— "Rabbit standing on all legs" — and its thumbnail pointed at the right UUID.
Re-reading the ingredient a few seconds later gave `5af4d19b…` and matched.

**The ingredient `src` is not populated the instant the option is clicked.**
Reading it too early reports a false negative. So a mismatch must be treated as
"not yet readable" and re-checked, never as "wrong reference" — and a generation
must not be submitted on an unverified reference.

This is the mirror of the earlier lesson: there, a wrong reference was caught by
checking; here, a correct one was nearly thrown away by checking too soon. The
rule that covers both is: **verify, and if the answer is not what you expect,
find out why before acting either way.**

## A test that was pinning a count

`companion_pack_completeness_test` gained a rabbit assertion last session that
pinned `actionIds.length == 1`. Adding walk broke it — correctly, but for the
wrong reason: it was guarding a number that changes every session rather than an
invariant.

It now asserts what actually matters: **every action the rabbit declares is
complete**, has frames, and meets its frame count. That survives the pack
growing, and it still fails if an action is ever declared without art.

## Imported

`python tools/productionise.py rabbit` → `tools/manifest.py rabbit` →
`tools/gen_manifest_dart.py`.

**rabbit: 2 actions / 12 frames** — `idle` 6/6, `walk` 6/6.

## Remaining

`sit_down` (4) + `stand_up` (4) → `craft_work` (4) → `focus_read` (3) /
`focus_think` (3) / `focus_write` (4) → `celebrate` (5) → `tap_react` (3) +
`pet_react` (3) → `sleep` (2) + `pause_rest` (2).
Target: the dog and cat shape, **13 actions / 49 frames**.

---

# 11. Session 4 — sit_down

## Accepted

| Frame | Reference | Attempts |
|---|---|---|
| `sit_down_000` | standing master | 2 |
| `sit_down_001` | standing master | 1 |
| `sit_down_002` | standing master | 1 |
| `sit_down_003` | seated master (`39c6616e…`) | 1 |

Frame 4 uses the **seated** master, not frame 3, because the animation hands over
from `sit_down` to `idle` — the last transition frame must match the pose it
hands over to.

## A sequence that ran backwards, caught by looking at it

The first `sit_down_000` came back **seated**, not standing, even though the
standing master was attached and verified and the prompt asked for a standing
rabbit. `sit_down_001` then came back standing. The pair read as a sit *up*.

The contact sheet is what caught it: the frames were in the wrong order, and at
thumbnail size that is easy to misread as "fine". Rendering frames 0 and 1 at
full size made it unambiguous — frame 0 was seated with its front paws together,
frame 1 was up on four straight legs.

Regenerated frame 0 with the standing requirement stated twice, once as its own
CRITICAL paragraph:

```
CRITICAL: the rabbit must be STANDING on all four legs, exactly as in the
attached reference. It must NOT be sitting.
```

and rephrased the action so it is explicitly a *near-neighbour of the reference*
rather than a description of a lower pose. The regenerated frame is standing,
and the sequence now runs standing → lowering → settled → seated.

**The lesson:** a verified reference does not guarantee the instructed pose. The
model can return the right character in the wrong posture, and only looking at
the frames in order catches it.

## Imported

**rabbit: 3 actions / 16 frames** — `idle` 6/6, `walk` 6/6, `sit_down` 4/4.

## Remaining

`stand_up` (4) → `craft_work` (4) → `focus_read` (3) / `focus_think` (3) /
`focus_write` (4) → `celebrate` (5) → `tap_react` (3) + `pet_react` (3) →
`sleep` (2) + `pause_rest` (2).
Target: the dog and cat shape, **13 actions / 49 frames**.

---

# 12. Session 5 — stand_up

## Accepted

| Frame | Reference | Attempts |
|---|---|---|
| `stand_up_000` | seated master (`39c6616e…`) | 1 |
| `stand_up_001` | seated master | 1 |
| `stand_up_002` | **standing** master | 1 |
| `stand_up_003` | **standing** master | 1 |

Frames 3 and 4 use the **standing** master rather than the seated one. The cat's
stand_up used the seated master through frame 3, but this pack had already shown
that a verified reference does not guarantee the instructed posture (§11), so
frames 3 and 4 were biased toward the pose they must land on and the prompt
carried the requirement twice:

```
CRITICAL: the rabbit must be STANDING on all four legs … It must NOT be sitting.
```

The sequence was checked in order before import: seated → seated with the chest
just lifting → rising with the hindquarters off the ground → nearly standing →
standing, with frame 4 matching the standing master.

## The transition pair is complete

With `sit_down` and `stand_up` both shipping, the room's whole seating chain
closes: walk to a seat → sit down → idle → stand up → walk away. Before this the
rabbit hard-cut between standing and seated, because the state machine's posture
hops had nothing to play.

## Imported

**rabbit: 4 actions / 20 frames** — `idle` 6/6, `walk` 6/6, `sit_down` 4/4,
`stand_up` 4/4.

## Remaining

`craft_work` (4) → `focus_read` (3) / `focus_think` (3) / `focus_write` (4) →
`celebrate` (5) → `tap_react` (3) + `pet_react` (3) → `sleep` (2) +
`pause_rest` (2).
Target: the dog and cat shape, **13 actions / 49 frames**.

---

# 13. Session 6 — craft_work and focus_read

## Accepted

**craft_work** — frame 1 introduces the props from the seated master (the pack's
prop law: a prop-carrying action cannot be varied from a prop-free reference);
frames 2-4 use frame 1 as the edit base with a do-not-change list.

| Frame | Reference | Attempts | Beat |
|---|---|---|---|
| `craft_work_000` | seated master | 1 | mallet raised overhead, block in front |
| `craft_work_001` | `craft_work_000` | 1 | mallet striking the block |
| `craft_work_002` | `craft_work_000` | 1 | mallet resting on the block |
| `craft_work_003` | `craft_work_000` | 1 | mallet lowered, inspecting the block |

**focus_read** — frame 1 introduces an open book from the seated master; frames
2-3 are eye and page movements over it.

| Frame | Reference | Attempts |
|---|---|---|
| `focus_read_000` | seated master | 1 |
| `focus_read_001` | `focus_read_000` | 1 |
| `focus_read_002` | `focus_read_000` | 2 |

## Flow began throttling

`focus_read_002` failed silently once — the progress bar finished and produced no
tile, the failure mode already recorded twice in this archive. The retry
succeeded.

Then `focus_think` frame 1 failed silently **twice in a row**, and after a page
reload the ingredient picker stopped opening at all (the add button hit-tests
correctly, the click lands, and no picker appears). That is the rate limit the
cat archive describes: the workaround is a reload plus a quiet wait of a minute
or more, and it did not clear within this session.

**No frame was invented and no frame was accepted unverified.** The seven
remaining actions are recorded below rather than approximated.

## Imported

**rabbit: 6 actions / 27 frames** — `idle` 6/6, `walk` 6/6, `sit_down` 4/4,
`stand_up` 4/4, `craft_work` 4/4, `focus_read` 3/3.

## Remaining, blocked on the throttle

`focus_think` (3), `focus_write` (4), `celebrate` (5), `tap_react` (3),
`pet_react` (3), `sleep` (2), `pause_rest` (2) — 22 frames. All of it is
mechanical: the click method, the master references, the prop technique and the
import pipeline are all recorded above.

---

# 14. Session 7 — focus_think, and the throttle returns

## Accepted

**focus_think** — frame 1 from the seated master (paw to chin, head tilted,
eyes up and away); frames 2-3 are head and eye movements over it.

| Frame | Reference | Attempts | Tile name |
|---|---|---|---|
| `focus_think_000` | seated master | 1 | Rabbit thinking pose variation |
| `focus_think_001` | `focus_think_000` | 1 | Rabbit thinking pose variation |
| `focus_think_002` | `focus_think_000` | 2 | — |

Frame 3 failed silently once and succeeded on the retry, the same pattern as
`focus_read` frame 3.

## The throttle came back and did not clear

After `focus_think` imported cleanly, `focus_write` frame 1 generated on the
first attempt ("Rabbit writing in notebook"), and then **frame 2 failed silently
twice in a row** — the progress bar finished and no tile appeared, twice.

The picker also began returning an empty option list for a term that had worked
moments earlier, which is the same degradation the cat archive records.

**No frame was invented and none was accepted unverified.**

## A partial action would break the gate

`focus_write` had one of four frames. Importing it would have declared an action
that is short of its frame count, and the pack-completeness test asserts every
declared action is complete — so a half-finished action is a red gate, not a
partial win.

The single accepted frame is therefore **set aside, not imported**, at
`.asset_staging/refs/rabbit_focus_write_partial/write_000.jpg`. Moving the
staging directory out of `.asset_staging/flow/rabbit/` is what keeps it out of
the import; `productionise.py` treats every directory under there as an action.

## Also worth recording

A search that returns **zero** options makes the option hit-test return
`{error}`, and the click then fails with "click requires ref or (x,y)". The cause
was reading the option list before it had rendered — the same term returned three
options a few seconds later. **Wait for the list, then hit-test.**

## Imported

**rabbit: 7 actions / 30 frames** — `idle` 6/6, `walk` 6/6, `sit_down` 4/4,
`stand_up` 4/4, `craft_work` 4/4, `focus_read` 3/3, `focus_think` 3/3.

## Remaining

`focus_write` (1 of 4 staged), `celebrate` (5), `tap_react` (3), `pet_react` (3),
`sleep` (2), `pause_rest` (2). All mechanical: the click method, the master
references, the prop technique and the import pipeline are recorded above.

---

# §15 — Session 2026-10-03 (later): Flow degraded, rabbit paused at 7 actions

## What was attempted

`focus_write` frames 2 and 3 generated and downloaded successfully:

- `write_001.jpg` — the pencil moving across the page
- `write_002.jpg` — the end of the stroke

Frame 4 (the pencil lifting clear of the page) was submitted and **dropped
silently**: the editor cleared, and the tile count did not change. That is the
same no-tile failure §14 records.

## The difference this time

Previously the throttle presented as a no-tile failure that a reload and a quiet
wait would clear. This time the **reload did not restore the editor's controls**.
After reloading:

- the project grid, the prompt editor and both buttons
  (`Add ingredients to the prompt box`, `Start generation`) are all present in the
  DOM and enabled;
- `document.elementsFromPoint` at the ingredient button's centre returns that
  button as the topmost element — **nothing is overlaying it**;
- clicking it at its true hit point, via `tab.cua.click`, **never opens the
  picker**, and `input[aria-label="Search assets"]` never appears, across six
  polls over twelve seconds.

The UI renders and the backend refuses. This is a **degraded session**, not
merely a rate limit, and no browser-side workaround recovers it.

`tab.click(selector)` was also tried and fails with
`ref ... not found (take a fresh snapshot() first)` — the selector path needs a
prior `snapshot()`, which is worth knowing but was not the cause here.

## Alternatives checked and ruled out

The remaining frames need reference-conditioned generation, so that the pencil
and notebook keep their exact drawing. A text-only generator cannot hold that,
and would produce a rabbit that no longer matches the 30 frames already shipped.

- **xAI** (`grok-imagine-image-pro`, `/v1/images/edits`, up to 3 input images) is
  exactly the right shape of tool — but `XAI_API_KEY` is **not set** on this
  machine, so it cannot be called.
- **OpenAI** (`gpt-image-1`, `/v1/images/edits`) — `OPENAI_API_KEY` is set but
  **expired**; the endpoint returns `401 invalid_api_key`.
- Every other local skill (`image-vision`, `qwen-vision`, `anime-cel-style`,
  `ab-agents-vision-minimax`, `vision-*`) is **analysis-only** and offers no
  generation.

So Flow is the only available generator, and it is currently unusable.

## State left behind

Staged, deliberately outside the import path, at
`.asset_staging/refs/rabbit_focus_write_partial/`:

| file | content |
|---|---|
| `write_000.jpg` | frame 1 — approved, generated earlier |
| `write_001.jpg` | frame 2 — pencil moving across the page |
| `write_002.jpg` | frame 3 — end of the stroke |

**Three of four frames.** Frame 4 is the only one missing from this action.

`write_000.jpg` is also the verified edit base for the action: search
`"Rabbit writing"` in the ingredient picker and confirm the attached ingredient's
`src` contains `d0898a97` before generating anything.

## To resume

1. Confirm Flow's editor is functional again — the ingredient button must open
   the picker and the search box must render. **Do not start generating until
   that is true**; a degraded session produces silent drops that look like
   successes.
2. Generate `focus_write` frame 4 from the `write_000` base (`d0898a97`): the
   pencil lifted a small distance off the page, tip clear of the paper, the
   holding paw following upward, everything else identical.
3. Move all four frames into `.asset_staging/flow/rabbit/focus_write/`, then run
   `python tools/productionise.py rabbit` → `tools/manifest.py rabbit` →
   `tools/gen_manifest_dart.py`.
4. Add `CompanionPose.focusWrite` to `rabbitPosesWithArt` in
   `test/presentation/companion/multi_companion_test.dart`.
5. Then the five remaining actions: `celebrate` (5), `tap_react` (3),
   `pet_react` (3), `sleep` (2), `pause_rest` (2).

Target: **13 actions / 49 frames**, matching the dog and the cat.

## Why the pack is not left half-imported

The pack-completeness test asserts that **every declared action ships its full
frame count**. Importing a 3-of-4 `focus_write` would turn a green suite red for
a cosmetic reason and would ship an action that visibly stutters. A partial
action is a red gate, not partial progress — so it stays staged.

---

# §16 — Session 2026-10-03 (later still): Flow recovered, focus_write landed

## Outcome

**rabbit: 8 actions / 34 frames.** `focus_write` is complete at 4/4 and the
manifest declares `4/4 loop 5 fps`, matching `ACTION_SPEC` in `tools/manifest.py`.

The four frames are the rabbit holding the open notebook with the pencil at
slightly different points along the page. Same character, same props, same
palette, no shadow, flat white background — checked on a contact sheet of all
four before import.

## The failure was mine, not the model's

Five frames were generated across this session and **all five were correct**.
Four of them were reported as failures — "the model dropped the notebook and the
pencil, drew a bare rabbit" — and that report was wrong.

What actually happened: the tile grid contains the rabbit's **idle and walk
frames, which legitimately have no props**. The download picked `imgs[last]`,
which was one of those pre-existing bare tiles, not the frame that had just been
generated. The conclusion "the model removed the props" was drawn from four
images that were never the model's output for this action.

This is the same class of mistake §14 records twice — a contact sheet indexed
wrongly, and a search returning my own output — and the lesson generalises:

> **A download is not verified until you can say why it is the new file.** The
> tile grid is not ordered by recency, so "the last tile" is a guess.

Three attempts were wasted on prompt rewrites aimed at a failure that did not
exist, including two rewrites that made the prompt worse by piling on
"the notebook must stay" clauses.

## How the new tile is actually identified

Two reliable methods, both used here:

1. **Set difference.** Record every tile `src` before submitting, then poll for a
   `src` that was not in that set. This is exact and needs no ordering
   assumption. It only works if the before-set is captured in the same script
   run as the poll.
2. **Signed-URL expiry.** Tiles served from `flow-content.google/image/<uuid>`
   carry `?Expires=<unix>`. A newer generation has a later expiry, so sorting by
   `Expires` descending puts the newest tile first. The six flow-content tiles
   at the time of writing ordered cleanly.

## Two download traps

- **`=s1024` only applies to `flow.google.com/asb/...` URLs.** Those are
  thumbnails (`=s512-rw`) and accept a size suffix; the recompressed result is
  ~78 KB. The `flow-content.google/image/...` URLs are **already full
  resolution** and have no size suffix — appending `=s1024` makes them fail with
  `TypeError: Failed to fetch`. The full-resolution file is ~240 KB, which is the
  size to expect for an accepted frame.
- **The signed URLs need the browser's session.** `curl` gets a 302 to an HTML
  page, which looks like a successful download until `PIL` refuses to open it
  (`<!doctype html` is not a JPEG). Fetch inside the page context instead:
  `fetch(url)` in `tab.playwright.evaluate`, return base64, write with `fs`.

## Also worth recording

- `ACTION_SPEC` in `tools/manifest.py` authors `focus_write` as **4 frames for
  every companion**. A target is production intent, not a transcription of the
  disk — `companion_pack_completeness_test.dart` has a test whose whole purpose
  is to fail when a target is lowered to match the frames on hand. Lowering it to
  3 to fit what had been produced would have been exactly that failure.
- The rabbit's pack test is stricter than the dog's or cat's: it asserts **every
  declared action is complete**. So a 3-of-4 import is a red gate, which is why
  the frames were staged rather than imported in §15.
- `tab.reload` does not exist; reloading is `tab.reload()`. `tab.click(selector)`
  needs a prior `snapshot()`.

## Imported

**rabbit: 8 actions / 34 frames** — `idle` 6/6, `walk` 6/6, `sit_down` 4/4,
`stand_up` 4/4, `craft_work` 4/4, `focus_read` 3/3, `focus_think` 3/3,
`focus_write` 4/4.

## Remaining

`celebrate` (5), `tap_react` (3), `pet_react` (3), `sleep` (2), `pause_rest` (2).
All mechanical, and none of them involve a prop the model might drop. Target:
**13 actions / 49 frames**, matching the dog and the cat.

---

# §17 — Session 2026-10-03 (end): celebrate attempted, the throttle returned

## What was attempted

`celebrate` frame 1 of 5 (anticipation — the rabbit crouches to jump), from the
**"Rabbit standing on all legs"** reference. Two attempts:

1. Submitted, and then **no tile appeared over 54 seconds** across nine polls.
2. Re-attached, submitted again, and **no tile appeared over 70 seconds** across
   eleven polls.

Both submissions cleared the editor, which is what a successful submit looks
like, and both produced nothing. A search for `Rabbit crouch` afterwards
returned **zero options**, confirming no asset was created rather than created
and merely not rendered.

This is the §14/§15 silent drop, back. Between the two attempts it was working:
`focus_write`'s four frames generated and downloaded without trouble earlier in
the same session.

## The reference labels, for the next session

Searched from the ingredient picker, which is how the base pose is chosen. The
labels matter because several assets share a near-identical name and only some
are the right pose.

| Search term | Useful results |
|---|---|
| `Rabbit standing on all legs` | the standing base — the one to use for a hop |
| `Rabbit standing up pose` | also standing |
| `White chibi rabbit sitting` | the bare seated base — **this is the asset that was repeatedly mistaken for a bad generation in §16** |
| `Rabbit sitting down` | seated |
| `Rabbit writing in notebook` | the `focus_write` base (`d0898a97`) |

## Remaining

`celebrate` (5), `tap_react` (3), `pet_react` (3), `sleep` (2), `pause_rest` (2) —
**15 frames**, target 13 actions / 49 frames.

None of them involve a prop, so the §16 download trap is the only hazard, and the
method for avoiding it is recorded there. Bases: `celebrate` from the standing
rabbit; `tap_react`, `pet_react`, `sleep` and `pause_rest` from the seated one.

## Where this leaves the pack

**8 actions / 34 frames**, all complete, all imported, all reachable at runtime:
`idle` 6/6, `walk` 6/6, `sit_down` 4/4, `stand_up` 4/4, `craft_work` 4/4,
`focus_read` 3/3, `focus_think` 3/3, `focus_write` 4/4.

The pack is honest at every point: everything it declares is finished, and every
pose it does not have falls back to the procedural silhouette rather than
borrowing another companion's art. The remaining five actions are blocked on an
external service, not on anything in the repository.

---

# §18 — Correction: §17's "silent drop" was mostly a polling bug

## The correction

§17 concludes that Flow was "dropping submissions silently" again. That
conclusion is **wrong, or at least unproven**, and it is corrected here because
it would send the next session looking for a server-side problem that is not
there.

The measurement that overturns it: a generation that succeeds now takes
**~60-70 seconds** to appear as a tile. Earlier in the same session it took
**~15 seconds**. §17 polled for **54 seconds** and then **70 seconds** before
concluding nothing had been created. Both windows sit at or *below* the real
latency.

So the two §17 attempts were most likely **slow successes** that I stopped
watching too early. The follow-up search for `Rabbit crouch` returning zero
options is not evidence either: it was run while the generation would still have
been in flight.

> **Rule: poll for at least 120 seconds before calling a submission dropped.**

This is the third time in this archive that a "the tool is broken" conclusion
turned out to be a measurement error — §16 was a bad download, §17 was a short
poll, and §14 was a stale reference read. The pattern is worth naming: **when
the same operation succeeds and then "fails" with no change in inputs, suspect
the observation before the tool.**

## What was actually attempted for celebrate

Reference: **"Rabbit standing on all legs"**, verified by rendering it — a
correct full-body standing rabbit on white, 512×512. (Confirmed separately,
because §14's lesson is that a verified id is not a verified image.)

| Attempt | Outcome |
|---|---|
| 1 | **Landed** (`adb7b83d`, 226 750 bytes) but the rabbit is **zoomed in** — only an ear, the sprout and part of the head, filling the frame. No full body, no crouch. **Rejected.** |
| 2 | Prompt strengthened with an explicit framing paragraph ("keep that framing… do NOT zoom in… if any part is cut off by the edge the result is wrong"). **No tile after ~100 s.** Outcome unknown — it may still have been in flight. |

Attempt 1 is a genuine model failure, not a measurement error: the framing
instruction was too weak. `celebrate` is a hop, and the pose descriptions that
worked for `focus_write` said "same canvas placement, same body scale" as a
passing clause; that is evidently not enough when the requested pose changes the
body's height.

**Next session should lead with the framing, not the pose.** Attempt 2's prompt
is the shape to use; give it a 120 s poll.

## State

Unchanged at **8 actions / 34 frames**. Nothing from `celebrate` was imported:
attempt 1 was zoomed and attempt 2 never produced a frame to judge.

## Also worth recording

- The ingredient picker sometimes needs the "Add ingredients" button clicked
  **twice** before the search box appears. A single click that does nothing is
  not a broken session; retry it.
- `flow-content.google/image/<uuid>?Expires=<unix>` remains the most reliable
  way to identify a new asset: sort by `Expires` descending. New generations in
  this project land as `flow-content` tiles with the latest expiry.

---

# §19 — celebrate landed: 9 actions / 39 frames

## Outcome

`celebrate` is complete at **5/5**, declared `once`, 8 fps — the count
`ACTION_SPEC` authors. The rabbit now ships **9 actions / 39 frames**.

## The technique that made it work

Every frame was generated from the **same standing reference**
(`Rabbit standing on all legs`), not by chaining frame to frame. The prompt leads
with the framing and only then describes the pose:

```text
Keep the framing of the attached image exactly. In the attached image the whole
rabbit stands on all four legs and is SMALL in the middle of a white square...

THE FRAMING IS THE MOST IMPORTANT REQUIREMENT. The output must show the WHOLE
rabbit, from the tips of its ears to its feet, at the same small size, in the
same place... Do NOT zoom in. Do NOT crop... If any part of the rabbit touches
or is cut off by the edge of the image, the result is wrong.

Then, keeping that framing, change only the pose: <pose>
```

This is the fix §18 identified. §18's attempt 1 put the framing in a passing
clause and got a zoomed crop of one ear; leading with it produced a correctly
framed full body every time.

## Scale drift is real and does not matter

The model's subject size varied enormously between frames — ink heights of
**376, 876, 435, 733, 871** px on the same 1024 canvas. That is a ~2.3× spread.

It is harmless: `tools/productionise.py` crops each frame to its ink bounding box
and rescales so the subject height is `canvas * SUBJECT_H` (capped by width at
96%). Every frame lands normalised, so the model's scale is absorbed. **Do not
reject a frame for being the wrong size** — check the pose, the framing
completeness, and the absence of a shadow instead.

## One frame was rejected and redone

Frame 4 ("just landed") came back as a **belly-flop** — lying down, legs splayed
to the sides, and with a noticeably larger head than the rest of the sequence.
It read as a fall rather than a happy landing, and it was off-model.

Regenerated with the pose spelled out negatively as well as positively
("STANDING UP on all four legs… clearly upright and standing, **not lying down
and not splayed out**… keep the head the same size relative to the body"). The
retry is a clean upright landing pose.

The other four were accepted first time. No frame was accepted without being
looked at on a contact sheet of the whole sequence.

## Timing, confirmed

Successful generations took **52–90 s** in this run. §18's rule holds: **poll for
at least 120 s before calling a submission dropped.** Every frame here arrived
between poll 6 and poll 11 of a 7.5 s loop.

## Remaining

`tap_react` (3), `pet_react` (3), `sleep` (2), `pause_rest` (2) — **10 frames**.
Target: **13 actions / 49 frames**.

None involve a prop. Bases: the seated reference (`White chibi rabbit sitting`)
for all four. The framing-first prompt above is the template; the `celebrate`
poses are recorded in this section's git history if a worked example is wanted.

---

# §20 — sleep landed: 10 actions / 41 frames

## Outcome

`sleep` is complete at **2/2**, `loop`, 3 fps. The rabbit ships **10 actions /
41 frames**.

## The framing prompt, corrected again

§19's framing text said the rabbit is **"SMALL in the middle of a white square"**
and to keep it "at the same small size". Used verbatim for `sleep`, the model
obeyed literally: the sleeping rabbit came back with an ink height of **109 px on
a 1024 canvas**, which `productionise.py` would have had to upscale **3.66×** to
reach its 399 px subject height. That is visible blur beside every other frame.

The word "small" was the bug — it describes the *reference* incidentally, but the
model reads it as an instruction about the *output*.

Rewritten to anchor to the reference's own size rather than to an adjective:

```text
The output must show the WHOLE rabbit, from the tips of its ears to its feet, at
the SAME SIZE and in the SAME POSITION as in the attached image. Do NOT zoom in.
Do NOT crop. Do NOT make the rabbit smaller. Do NOT make the rabbit larger.
```

The retry came back at **544 px**, a 0.73× *down*scale — sharp, and the best
result of the session. **Use this wording; do not reintroduce "small".**

## A pose that is wider than it is tall

The sleeping rabbit's ink box is **821 wide × 544 tall**. `productionise.py`
caps the scale by width at 96 % of the canvas, so the width cap binds and the
sleeping rabbit ends up shorter in the final sprite than the standing frames.

That is correct, not a defect: a rabbit lying down *is* shorter than one
standing. Worth knowing so it is not "fixed" later.

## Verifying the right reference was attached

Two assets now match the search `Sleeping rabbit` — the accepted frame and the
rejected tiny one. Attaching the wrong one would have produced a frame 2 that did
not match frame 1.

They were told apart by **ink height** (544 vs 109), not by label: both labels
are auto-generated from the prompt and are near-identical
(`Sleeping rabbit image framing in…` / `Sleeping rabbit on white background`).
Cheap and decisive — measure the candidate and compare with the frame already
accepted.

## A test that had to move, not be weakened

`companion_pack_completeness_test.dart` asserted
`resolveFor('rabbit', sleep) == null`, using `sleep` as its example of an
unshipped pose. That assertion is now false. It was moved to `rest` — still
unshipped for the rabbit — and a **positive** assertion was added that `sleep`
now resolves, so the swap cannot quietly become a no-op if `sleep` is ever
removed again.

## Remaining

`tap_react` (3), `pet_react` (3), `pause_rest` (2) — **8 frames**. Target:
**13 actions / 49 frames**.

All three are seated-pose variations; `White chibi rabbit sitting` is the base.

---

# §21 — pause_rest landed: 11 actions / 43 frames

## Outcome

`pause_rest` is complete at **2/2**, `pingpong`, 3 fps. The rabbit ships
**11 actions / 43 frames**.

Both frames measure **730 × 587** px ink — identical boxes, with the second
differing only in the set of the ears and a touch of body rise. That is what a
two-frame breathing loop should look like, and identical ink boxes are a cheap
way to confirm a "subtle variation" request was honoured rather than a whole new
pose being invented.

## Finding the reference by measurement, again

`pause_rest` frame 2 needed frame 1 as its base. The library labels are
auto-generated from the prompt and are useless for this: the accepted frame is
called `Resting rabbit image framing`, and searching `Rabbit` returns 15 entries
whose labels overlap heavily with the sleeping and celebrate ones.

So the frame was identified by **downloading the candidates and measuring their
ink boxes** against the frame already accepted (730 × 587), then confirming the
attached chip's `src` contained `b531e39c` before generating. The same technique
as §20, now the default for "attach the frame I just made".

## A test that moves each time the pack grows

`companion_pack_completeness_test.dart` uses one unshipped rabbit pose as its
"missing pose returns null" example. It has now moved twice — `sleep`, then
`rest`, now `tap_react` — because the pack keeps growing underneath it.

Each move carries forward a **positive** assertion for the poses that left, so
the example cannot quietly become a no-op. That is deliberate: the test is a
moving target by nature, and the guard is what keeps it honest rather than
routine.

## Remaining

`tap_react` (3), `pet_react` (3) — **6 frames**. Target: **13 actions / 49
frames**.

Both are seated-pose reactions; `White chibi rabbit sitting` is the base, and the
framing-first prompt of §20 is the template.

---

# §22 — tap_react landed: 12 actions / 46 frames

## Outcome

`tap_react` is complete at **3/3**, `once`, 8 fps. The rabbit ships **12 actions /
46 frames**.

The three frames read as a reaction: startled (ears snapped up, eyes wide, small
"oh") → a taller bob with a paw lifted → settled and pleased. Ink widths are
identical at 461 px across all three, so the framing held; heights rise and fall
(873 → 926 → 871), which is the bob doing its job.

Frames 2 and 3 were generated from the frame before them rather than from the
seated base, so the reaction stays continuous.

## A wrong assertion caught before it shipped

Moving the unshipped-pose example to `greeting`, the first version asserted
`resolveFor('dog', greeting)` is **not null**, on the assumption that the dog
covers every pose. It does not — the dog's thirteen actions are `idle`, `walk`,
`stand_up`, `sit_down`, `focus_read`, `focus_write`, `focus_think`,
`pause_rest`, `tap_react`, `pet_react`, `craft_work`, `celebrate`, `sleep`, and
`greeting` is not among them. That assertion would have failed.

The cross-check was replaced with the honest one: the same lookup for poses the
rabbit *does* ship must return a spec, which proves the null belongs to the
rabbit rather than to a broken resolver — and needs no assumption about the dog.

## A churn note

The unshipped-pose example has now moved three times in three batches. It is
settled on `greeting` because that belongs to the overlay vocabulary rather than
the behaviour pack, so it should stay unshipped once the pack is complete.

## Remaining

`pet_react` (3) — **3 frames**. Target: **13 actions / 49 frames**, matching the
dog and the cat exactly.

---

# §23 — pet_react landed: the rabbit pack is COMPLETE

## Outcome

`pet_react` is complete at **3/3**, `once`, 6 fps.

**The rabbit now ships 13 actions / 49 frames — exactly matching the dog and the
cat.** The three frames read as: blissful (eyes closed, ears drooped) → melting
(a wider smile, head tilted, body settled lower) → settled and grateful (eyes
open, ears upright, warm smile).

## The pack, end to end

| Action | Frames | Mode |
|---|---|---|
| `idle` | 6/6 | loop |
| `walk` | 6/6 | loop |
| `sit_down` | 4/4 | once |
| `stand_up` | 4/4 | once |
| `craft_work` | 4/4 | loop |
| `focus_read` | 3/3 | pingpong |
| `focus_think` | 3/3 | pingpong |
| `focus_write` | 4/4 | loop |
| `celebrate` | 5/5 | once |
| `tap_react` | 3/3 | once |
| `pet_react` | 3/3 | once |
| `sleep` | 2/2 | loop |
| `pause_rest` | 2/2 | pingpong |

## A new test that says the packs are the same shape

A test was added asserting all three companions ship the **same action set and
the same frame count**, and that none declares anything incomplete. That is
deliberately stronger than "the rabbit has made progress": it means a companion
cannot quietly fall behind and still look finished.

The old test's name — *"the rabbit pack is present and partial, and says so"* —
was also corrected. Its invariant was never a fixed count, and it held at seven
actions and holds at thirteen; but the word "partial" had stopped being true.

## Attaching a frame by id

Frame 2 needed frame 1 as its base, and the option could not be found by clicking
a guessed position — an earlier attempt landed on the wrong row and attached
nothing. It was attached by searching the frame's own auto-generated label
(`Rabbit being petted`), which returns exactly one option.

The label is discoverable: search `Rabbit` and read the list. Every generated
frame's label is derived from its prompt, and they are distinctive enough to
search once you know them.

## What is left

Nothing in the rabbit pack. `P10` is done for all three companions.

P12 (AI personality) remains optional and unstarted, and the two owner-blocked
items — the release keystore and the launcher icon — are unchanged.

---

# §24 — Device verification of the completed pack

Debug APK built from `b664fe5`, installed on `emulator-5554`
(`sdk_gphone64_x86_64`), application id `com.yuhangzhu295.cozyfocus`.

| Check | Result |
|---|---|
| Build + install + launch | OK |
| The rabbit renders production sprites in the room | Yes — drawn from the pack, not the procedural silhouette |
| `adb logcat` filtered for `exception\|error\|assert\|failed` | **Nothing** |
| Evidence | `android_v1_runtime/p10_rabbit_complete_room.png` |

## One check that did not work, and why it does not matter

Tapping the rabbit in the room did **not** play a `tap_react` reaction, so this
does not verify that action on the device. The likely reason is that the room
page does not wire companion taps to the overlay — `tap_react` is driven from
the home avatar's own tap handling, not from the room. That is a plausible
design and not a defect introduced here, but it is **unverified** rather than
verified, and is recorded as such.

The remaining twelve actions were not exercised on the device either. What the
device check establishes is narrower than "all thirteen play correctly": the app
builds and runs with the enlarged pack, the rabbit draws real sprites, and
nothing errors. The per-action wiring is covered by
`companion_pack_completeness_test.dart`, which asserts every shipped pose
resolves to a spec.

## The room's label can disagree with the sprite

The capture shows the label `小兔 在房间里晃悠` (the idle fallback) while the
rabbit is drawn reading a book. The cause is that `_activityLabel` resolves the
furniture from the anchor id to name the action, and a companion standing on the
**floor anchor** has no furniture to look up — so it falls through to the
cause-based sentence even though a `companionAction` is playing.

Pre-existing and cosmetic, not a regression from this work, and recorded so the
next session does not re-discover it as a new bug.
