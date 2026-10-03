# P16 — Runtime gate, and the sit_down / stand_up audit

Two items from the video-to-sprite brief that did **not** depend on Flow video
generation, so they could be done while §6 of `P15` is blocked.

---

## 1. §15 Runtime gate — the animation is proven, not assumed

The brief is explicit: *"真机/模拟器：idle / walk / transition 分别录制或截取多个时间点。一个截图不能证明动画。"*

So the companion was sampled at **12 time points** on the release build and the
rendered pixels measured, rather than photographed once and declared animated.

### The control that makes the number mean something

A difference between two screenshots only proves animation if the capture path
can produce a difference at all. So the same captures were measured over a
region that must be static — the timer card:

| region | mean difference between consecutive samples |
|---|---|
| **static control** (timer card) | **0.000** |
| **subject** (companion) | **19.87** |

The control is **exactly zero**, so there is no capture noise floor: any
difference in the subject region is the app rendering different content.

### The change is the animation, not a glitch

- Confined to x 301–773, y 485–803 — the companion and nothing else.
- Concentrated **along the outlines** (11,602 px differing by >40 between two
  samples), which is the signature of a breathing scale motion on line art.
- Distance from the first sample **oscillates** — `[0, 23.3, 8.3, 19.1, 23.4,
  12.0, 15.0, 22.7, 22.9, 8.5, 22.0, 21.9]` — returning toward zero and rising
  again. A frozen still stays at 0; a one-way drift would climb monotonically.
  This is a **cycle**.

### This is the sprite player, not the layered rig

Worth confirming, because the brief is about sprite playback:
`companion_visual_registry.dart` registers `MochiVisualProvider` for the dog →
`MochiVisualProvider.build` returns `PetAvatarWidget` → `PetAvatarWidget._poseVisual`
uses `CompanionSpritePlayer` when `spriteSpec` is non-empty, and the dog has a
full 13-action pack. So the sampled motion **is** the shipped sprite sequence.

### Transition

Sampled across a real context change (idle → focus session):

| | mean difference |
|---|---|
| within idle (animation jitter) | 14.66 |
| within focus (animation jitter) | 2.54 |
| **idle vs focus (pose change)** | **24.19** |

The pose moves further than the animation jitters, and the two states have
visibly different internal motion. Confirmed by eye: idle shows the companion's
face and ears; focus shows it settled into a different pose lower in frame.

### Verdict

| | result |
|---|---|
| `IDLE` runtime gate | **PASS** — advances and cycles, against a zero-noise control |
| `TRANSITION` runtime gate | **PASS** — pose changes with the context |
| `WALK` runtime gate | **NOT_RUN** — see below |

**`WALK` was not measured, and the reason is a real gap rather than an
oversight.** A walk only happens when the companion travels between anchors,
which needs placed furniture; this build's database was reset for the P14
verification, so the room is empty and the companion sits on the floor anchor
with no activity. Reaching a walk means crafting furniture first. That is
reachable but long, and it is recorded as not-run rather than inferred.

### One process note

The first attempt at the transition measurement returned **all zeros**. That was
not a frozen companion: a `BACK` keypress had exited the app, and the "before"
and "after" captures were both the **Android launcher**. The zero was the tell —
a static control and a static subject together mean the subject is not on screen.
The measurement was redone with the foreground activity confirmed via
`dumpsys activity` first.

---

## 2. §12 — is `sit_down` just `reverse(stand_up)`?

The brief says not to default to that, and to require a visual comparison if it
was done. So it was measured rather than assumed: each `sit_down` frame against
the **reversed** `stand_up` sequence, with the forward order as the control.

| companion | vs REVERSED stand_up | vs FORWARD stand_up | own inter-frame spread | verdict |
|---|---|---|---|---|
| **dog** | **0.0021** | 0.1025 | 0.0863 | **is a reverse** |
| cat | 0.0926 | 0.1086 | 0.1162 | independent |
| **rabbit** | **0.0193** | 0.0624 | 0.0530 | **is a reverse** |

For the dog the reversed match (0.0021) is **40× tighter** than its own
inter-frame spread — it is the same frames, reversed. The rabbit is the same with
one mid-transition frame differing more (0.068); visually it still reads as a
reversal. The cat's `sit_down` is genuinely its own motion.

### The visual comparison the brief requires

`dog_sit_stand.png` and `rabbit_sit_stand.png` place both sequences side by side:
`sit_down[i]` equals `stand_up[3-i]` exactly. The reversed motion reads correctly
as sitting down — standing → lowering → seated — with no reversed follow-through
in the ears or tail that would betray it at four frames.

### Honest limit on the verdict

The brief's condition is *"除非人工视觉比较证明倒放版本更好"* — prove the reversed
version is **better**. That cannot be proven here, and it is not being claimed:

- It is **not defective**: the reversal reads correctly and no artifact is visible.
- It is **not proven better than an independently generated version**, because
  generating one needs a video, which is Flow-blocked (`P15` §6).

So the correct statement is: *the dog's `sit_down` is a reverse, it is visually
acceptable, and the comparison that would settle "better" is blocked.* Going
forward, new companions should get their own `sit_down` clip — which is exactly
what `video_to_sprite.py --action sit_down` now makes possible.

---

## 3. Status of the brief's remaining items

```
RUNTIME_GATE_IDLE:        PASS
RUNTIME_GATE_TRANSITION:  PASS
RUNTIME_GATE_WALK:        NOT_RUN   (needs placed furniture; DB reset for P14)

SIT_DOWN_IS_REVERSED:
  dog:                    YES  (0.0021 vs own spread 0.0863)
  rabbit:                 YES  (0.0193, one mid-frame outlier 0.068)
  cat:                    NO   (independent)
SIT_DOWN_VISUAL_REVIEW:   DONE    (reads correctly; not proven "better")
SIT_DOWN_INDEPENDENT:     BLOCKED (needs a video; Flow video generation is down)
```
