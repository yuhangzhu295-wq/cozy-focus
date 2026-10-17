# 05 — Visual comparison: shipped room vs hand-drawn candidate

**The candidate is not approved and is not production.** It is reachable only
with `--dart-define=ROOM_CANDIDATE=true`; a normal build, every test and the
release artifact draw the shipped painter. The owner's visual gate is untouched.

## The three routes

| route | what it is | verdict |
|---|---|---|
| Shipped | flat vector room: wall, window, shelf, desk, mat | in production |
| Photographic | board 01's room as a photo behind the 2D pet | **rejected** — the pet reads as a sticker on a photo; the brief forbids swapping the 2D Mochi for an inconsistent 3D |
| Hand-drawn candidate | same illustration language, with depth, materials and light | **candidate, awaiting the owner** |

## Same device, same session, same pet

All screenshots are real Flutter composites on `emulator-5554`, not mock-ups.

| | shipped | candidate |
|---|---|---|
| Home | `device/20_shipped_home.png` | `device/10_candidate_home.png` |
| Room | `device/21_shipped_room.png` | `device/11_candidate_room.png` |
| Focus | (previous rounds' `04_focus_current.png`) | `device/12_candidate_focus.png` |

### What the candidate clearly adds

- **A third dimension**: a side wall with a corner, floorboards with direction,
  and a floor plane the furniture sits on. The shipped room is a backdrop.
- **A window with a view** — frame, mullions, sill, curtain, sky and greenery —
  and light that comes *from* it. The shipped window is a bright rectangle.
- **Furniture**: a desk with legs and thickness, a lamp, a mug with steam, a
  plant in a pot, books, and a woven rug with fringe. The shipped room has none
  of these on the room page.
- **A readable shelf**: after V1, the books have silhouettes and colour
  separation instead of a blurred smudge.
- **A rug the pet actually rests on**: after the device walk found the rug's
  plane 200px below the paws, the candidate now centres the rug on the same
  expression as the shipped `kCozyRoomMatCentre`. `device/11_candidate_room.png`
  shows the pet on the rug.

### What it does not close

- **The pet is still a flat 2D sprite.** Board 01's pet is a 3D plush *in* the
  room. Neither route can close that without violating the brief's prohibition
  on replacing Mochi with inconsistent 3D art.
- **The shelf is cropped at the top edge** in the 2400px room band: the top
  board runs off-frame. It is readable, but it reads as "a shelf continuing out
  of shot" rather than a composed object.
- **The window view is very soft** (2.6 sigma on the far plane). The green
  crowns are blobs. That is the depth-of-field choice, but it is less defined
  than the shipped window's clean panes.
- **On the focus page the pet sits on the desk**, because that page composes the
  pet against the desk line rather than the floor anchor. The rug is behind the
  desk there. That is a page-composition decision, not a grounding defect.

## The three defects fixed in this round, and how they were measured

The guards are pixel-level and calibrated between the two versions:

| defect | fixed painter | original | threshold |
|---|---|---|---|
| V2 side-wall band | top-strip luma **135.9** | **150.7** | `< 143` |
| V3 window area | bright fraction **0.563** | **0.427** | `> 0.49` |
| V1 shelf readability | **127** colour bins | **92** | `> 108` |

Replacing the candidate file with the branch's original fails all three; the
fixed file passes. The reverse proof is recorded in the test file's comments.

## Performance

The candidate's own frame-time runs from the previous round measured build p50
0.3–1.4 ms and raster p50 3.3–12.5 ms, with two runs of the *same* build
differing by ~4× on raster. The defensible claim is **inside the 16.67 ms budget
and no consistent regression**; the apparent 3× speedup is recorded as not a
finding. This round did not re-run the candidate performance harness, so no new
number is claimed.

## What the owner has to decide

1. Keep the shipped room, or adopt the candidate.
2. If adopting: are the shelf crop and the soft window view the first fixes, or
   is the room already busy enough?
3. The final `OWNER_VISUAL_APPROVED` gate — engineering cannot claim it, and has
   not.
