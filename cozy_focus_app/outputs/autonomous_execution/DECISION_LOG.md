# DECISION_LOG

Key engineering decisions, in the order they were made. No owner approval is
requested for these; they are recorded so the next window does not relitigate them.

## D1 — the design boards are the reference of record, not the auto-crops

The 16 designs are boards: a phone mockup with annotation callouts around it, so
only the screen region may be compared. Six detection criteria were tried to
isolate it (dark-pixel bounding box, longest bright run, narrow dark runs either
side of the middle row, longest flat-colour run, dark bands recurring across
sampled rows, and the largest bright component enclosed by the bezel). Each found
the board's background, a card inside the screen, or a content edge; about half
the boards crop correctly. **Decision:** compare against the board, keep the crops
as reference material, and say so in the matrix rather than presenting a wrong crop
as the reference.

## D2 — the ring drains with what is left, and an open-ended mode gets no arc

Reference 04 shows 25:00 inside a full ring, so the arc is `remaining / target`. A
count-up or deep-focus session has no target; drawing a fraction would invent one
the user never set, so it draws the track alone. Tested as a decision
(`remaining == null`), not as an absence.

## D3 — the ring's size comes from the screen height

A fixed 224pt ring pushed 暂停 and 提前结束 past the bottom at 360×800 (labels at
y 790–808 in an 800pt viewport). The page scrolls, so they were reachable, but the
design draws the ring and the controls on one screen. **Decision:** size the ring
from the screen height, capped at the design's 220pt, and scale the number with
it. This keeps the design's proportion on the phone it was drawn for and gives up
size only where the room is missing.

## D4 — the sprout on the ring is drawn, not imported

The design puts a sprout on the ring's top. It is the app's own motif (it is on
the pet's head and in the palette's copy) and it is a stem with two leaves, not a
character, so drawing it fakes no sprite asset. Recorded because "do not invent
art" is a contract rule and this is the line I drew.

## D5 — the design's category labels are example data, not a vocabulary change

Design 02 shows 工作/学习/健康/生活/习惯/成长. The app ships four (生活/学习/工作/
其他) shared with the distraction inbox. The contract says the designs' sample data
must not become production fact, and the vocabulary is a domain decision, so the
labels are not copied. The chip's *appearance* is matched.

## D6 — 白噪音 is not implemented

Design 04 has four controls including 白噪音, and the callout lists five sound
sources. The repo has no audio. The contract forbids a control that looks like it
works and does nothing, so the control is absent rather than fake. Logged as
BLOCKED_EXTERNAL.
