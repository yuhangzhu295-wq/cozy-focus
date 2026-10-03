# FLOW ASSET PROMPTS — rabbit

Archive of every Google Flow generation attempt for the rabbit sprite pack.

**Status: `ASSET_GENERATION_BLOCKED` at the master. Nothing was generated.**

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
