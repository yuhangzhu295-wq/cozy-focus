# ROOM_V4_2_VISUAL_GAP

Project: COZY_FOCUS
Scope: room *visual scene quality* — explicitly NOT room interaction logic
Status: **ROOM_V4_2_LOGIC = PASS** · **ROOM_V4_2_VISUAL = ASSET_GAP**
Author: ZCode (single-model round; independent review deferred by owner)

---

## 1. The distinction this report exists to make

Room **interaction logic** and room **visual scene quality** are different
things, and conflating them is how a passing system gets reported as a failing
one or vice versa.

- **Logic** — which furniture the companion may use, when, and where it stands.
  This is implemented, data-driven and tested.
- **Visual** — what the room *looks like*. This is code-drawn placeholder art
  and does not match the V4.2.1 references.

This report covers only the second. **No room business logic was rewritten.**

---

## 2. Logic — complete

| Capability | Status | Evidence |
|---|---|---|
| Recipe-driven anchors (`sofa`/`rug`→seat, `bed`→lie, `bookshelf`→front, `desk`→work) | **LOGIC_COMPLETE** | `assets/companion/room_interaction_recipes.json` |
| `owned && placed && visible` gate declared as data | **LOGIC_COMPLETE** | `RoomInteractionResolver._meets`; an unknown predicate fails closed |
| Only catalogued items are eligible | **LOGIC_COMPLETE** | a wall decoration cannot become a seat |
| Deterministic selection when several qualify | **LOGIC_COMPLETE** | z-index → newer placement → larger id, tested |
| Seat-surface geometry (feet on cushions, not on the item's centre) | **LOGIC_COMPLETE** | `PetSeatPlacement`, measured constants, tested |
| Business coordinates stay authoritative | **LOGIC_COMPLETE** | the resolver returns an anchor and a row id, never a position |
| Companion behaviour follows the anchor | **LOGIC_COMPLETE** | `seat`→`room_sit`, `lie`→`room_sleep`, `front`→`room_read`, `work`→`room_work` |

Verified on device this round: the companion reports "在房间", resolves to the
newer of two placed sofas, and sits on it.

---

## 3. Visual — the gap

### 3.1 What exists

| Element | Implementation | Classification |
|---|---|---|
| Room background | `Container` with a `LinearGradient`, plus a wall/floor division, a window rectangle and a light shaft, drawn in `room_page.dart` | **ART_ASSET_MISSING** |
| Placed furniture | `CozyFurnitureArtwork` — a `CustomPainter` drawing each item from code, keyed by item id, with a `supportedItemIds` set | **ART_ASSET_MISSING** |
| Companion in the room | the shared runtime renderer, positioned by `PetSeatPlacement` | **LOGIC_COMPLETE** (art gap tracked separately) |

There are **no image assets for furniture or the room**. Everything visible is
vector drawing in Dart. It is consistent, on-palette and legible, and it is not
production art.

### 3.2 What the V4.2.1 references show

| Reference | Shows | Present today? |
|---|---|---|
| `designs/pages/09_房间_已布置.png` | a furnished living room: wall shelves with plants and books, a window with daylight, a rug, a lamp, warm decor, the companion lying on a cushion | **no** |
| `designs/motion/20E_制作工坊_场景参考.png` | a workshop scene with a desk and chair | **no** |
| `designs/motion/20F_房间库存面板_交互参考.png` | the inventory panel interaction | panel exists; its art does not |

The references are **scene compositions**, not asset sheets. There is no
transparent furniture set, no room background plate, and no cushion/desk/chair
art in either design package.

### 3.3 Gap table

| Item | V4.2 REFERENCE | CURRENT IMPLEMENTATION | STATUS | REQUIRED_ACTION |
|---|---|---|---|---|
| Room background plate | 09 (furnished wall, window, floor) | code gradient + shapes | **ART_ASSET_MISSING** | author a background plate per room style, or keep the code scene |
| Floor / rug | 09 | code | **ART_ASSET_MISSING** | author |
| Wall shelving + plants + books | 09 | absent | **LAYOUT_MISSING** | author + place |
| Window with daylight | 09 | code rectangle + light shaft | **ART_ASSET_MISSING** | author |
| Cushion | 09 | absent | **LAYOUT_MISSING** | author; note the seat list currently uses sofa/bed/rug because no cushion exists in the catalog |
| Desk and chair | 20E | absent | **LAYOUT_MISSING** | author; the `desk` anchor exists but has no matching scene |
| Lamp, decor, small props | 09 | absent | **ART_ASSET_MISSING** | author |
| Furniture set (sofa, table, bookshelf, bed, rug, lamp, cabinet, desk, plant) | 09, 11C | `CozyFurnitureArtwork` code painter | **ART_ASSET_MISSING** | author 9 transparent items against one artboard |
| Night / sleep variant (11E) | 11E | late-night behaviour modifier exists; the *scene* does not change | **ART_ASSET_MISSING** | author a night treatment |

---

## 4. Product decision

The brief's own priority rule (§31 of the reconstruction) puts the **V4.1 base
visual language above the V4.2 interaction art**. The shipped room therefore
keeps the V4.1 treatment — warm, minimal, code-drawn — and carries the V4.2
*interaction* on top.

That is a deliberate reading of the rule, not an oversight, and it is why this
gap is reported rather than treated as a defect. It becomes a real decision only
when someone asks for the V4.2 scene:

| Option | Cost | Consequence |
|---|---|---|
| **A. Keep the V4.1 treatment** (current) | none | consistent with the priority rule; the room reads as warm-minimal, not as the reference illustration |
| **B. Author the V4.2 scene** | a background plate + 9 furniture items + a cushion + desk/chair + decor + a night variant | matches `09`/`20E`/`11E`; needs art, and a room-layout pass |
| **C. Hybrid** | furniture items only | the companion sits on recognisable art while the room stays minimal |

`ROOM_V4_2_VISUAL = ASSET_GAP` — the logic is done, the art is not, and whether
the art is wanted is the owner's call.

---

## 5. What was NOT done, and why

- **Room business logic was not touched.** The task forbids it, and it passes.
- **No furniture or room art was generated.** Same rule as the companion poses:
  no crude programmer art to turn a gap into a pass.
- **Nothing was cropped out of `09_房间_已布置.png`.** It is a scene composition;
  a crop would carry wall, window and text with it.

---

## 6. Interaction between the two gaps

If the room scene is built, it should ship **with** the companion pose pack, not
before it. A furnished room containing a procedurally drawn cat would look more
unfinished than the current minimal room does, because the contrast between
finished and placeholder art is what reads as broken. The companion poses are
the higher-value half of the art work.
