# P17 — Runtime gate: WALK

The last unblocked item from the video-to-sprite brief. `P16` recorded
`RUNTIME_GATE_WALK: NOT_RUN` because a walk needs the companion to travel between
anchors, which needs placed furniture, and the database had been reset for the P14
verification.

**Result: PASS.** Both halves of the brief's requirement are shown on the release
build — *"Sprite腿在走 AND 角色位置由Locomotion改变"*.

---

## 1. Getting the precondition

A walk is a **travel between anchors**. The room had none, and crafting one is
gated on real focus time (the cheapest catalog item, the rug, costs 30 focus
minutes — recipes carry `ingredientCostsJson: '{}'`, so they cost *time*, not
materials). Thirty minutes of wall clock to reach a verification is a poor trade,
so the precondition was seeded directly instead.

The seed is a **test fixture, not a shortcut in the thing under test**: two
catalog items (rug, sofa) are marked owned and placed so the companion has a
second anchor to travel to. Everything after that — the decision, the travel, the
sprite, the anchoring — is the shipping code on the release build.

### The route, and the three things that went wrong

Seeding needed `run-as`, which needs a **debuggable** build, so the debug APK was
installed (same package, same debug signing key, so app data survives), the
database edited, and the **release** APK reinstalled for the actual verification.

1. **Pulled the database without its `-wal`.** Drift runs in WAL mode, so the
   committed rows live in `cozy_focus.sqlite-wal`, not the main file. The pull
   took only `.sqlite`, the edit saw an almost-empty database, and the push wiped
   the pet. The app then showed 暂未领养宠物. Fixed by pulling `.sqlite`,
   `-wal` and `-shm` together — SQLite replays the WAL on open, so the edit sees
   the real state (`pragma integrity_check` → `ok`).
2. **Pushed a database while its journals existed, then deleted them.** That is a
   documented way to corrupt a WAL database, and it did: `database disk image is
   malformed`. Fixed by checkpointing and switching to `journal_mode=DELETE`
   locally, so the file pushed is self-contained, and only then removing the
   device-side journals.
3. **`adb shell "cat > file"` truncated the file** — 108574 bytes arrived from a
   139264-byte source, corrupting it again. Fixed by piping through `base64 -d`,
   which survives a text channel. The device file then matched the source exactly.

Each failure looked like the previous one from the outside — "the app lost its
data" — and only checking the **byte size on the device** distinguished them.

## 2. The walk

Triggered by tapping the sofa in the room's use panel and choosing 让 Mochi 坐下,
which sets a player request for a *different anchor*. The companion walks from the
rug (x ≈ 0.28) to the sofa (x ≈ 0.62).

Ten frames were captured as fast as `screencap` allows (~0.5 s apart), which is
enough to bracket the travel.

### The gait, close up

`p16_walk_gait.png`:

| frame | what it shows |
|---|---|
| **w_0** | standing **on the floor at the rug**, legs apart in a stride — a walking pose, not the seated one |
| **w_1** | mid-stride, further right, legs in a *different* stride position |
| **w_2** | arriving at the sofa, settling |
| **w_9** | seated on the sofa, eyes closed, content |

So the sprite's legs are demonstrably animating through a gait, and the companion
is drawn at a different screen position in each — the two halves of the
requirement.

### Measured, not just looked at

Occupancy against the final state, in two regions:

| frame | diff @ LEFT (rug) | diff @ RIGHT (sofa) |
|---|---|---|
| w_0 | **3.01** | 3.66 |
| w_1 | 1.55 | 4.36 |
| w_2 | **0.00** | 1.49 |
| … | 0.00 | 1.46 – 3.06 |
| w_9 | 0.00 | 0.00 |

The LEFT region goes to **exactly 0.00** from w_2 onward — the companion has left
it, and nothing remains. The RIGHT region keeps differing until the companion
settles. That is the travel, measured.

A second, independent signal: within the **floor band** (below the floor line at
y = 1641) the companion's body is detectable only in **w_0**, at x ≈ 348 — the
rug. From w_1 on it is not in that band at all, because it is elevated on the sofa
cushion. Standing on the floor, then not on the floor.

### No double displacement

The brief's rule is that `LocomotionController` owns world position and the sprite
owns the gait. That is what the frames show: the sprite renders a striding,
**in-place** gait — its feet stay planted on the floor line within its own frame —
while its screen position is what advances. If the sprite were also sliding inside
its own frame, the two would compose and the companion would appear to skate. It
does not.

---

## 3. Status

```
RUNTIME_GATE_IDLE:        PASS      (P16)
RUNTIME_GATE_TRANSITION:  PASS      (P16)
RUNTIME_GATE_WALK:        PASS      <- this document
WALK_IN_PLACE:            PASS      (in-place gait, position from Locomotion)
DOUBLE_DISPLACEMENT:      NONE      (sprite stays planted; screen position advances)
```

Every runtime gate the brief asks for is now measured on the release build.

### Still blocked, and unchanged

`FLOW_GENERATION` remains **BLOCKED** (`P15` §6) — no video surface is reachable,
and Flow's own banner reports video generation degraded. That blocks producing
*new* art from video; it does not block verifying the art that ships, which is
what this document does.

---

## 4. A note on what was seeded

For the record, so the fixture is not mistaken for product state: the seeded
database contains a pet row, a pet-progress row, and two owned+placed catalog
items (rug, sofa). No product code was changed, and `assets/companions/` is
untouched. The seeding exists only to reach a room in which a walk is possible.
