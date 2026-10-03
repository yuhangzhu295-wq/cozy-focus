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
