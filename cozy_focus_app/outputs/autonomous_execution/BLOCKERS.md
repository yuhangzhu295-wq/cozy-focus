# BLOCKERS — what code cannot resolve

Statuses here are `BLOCKED_EXTERNAL` or `NOT_VERIFIED`. Full detail in
`outputs/final_product_qa/08_RELEASE_BLOCKERS.md`; this is the working list.

| id | what | status | why code cannot resolve it |
|---|---|---|---|
| RELEASE_SIGNING | `android/key.properties` absent, release falls back to debug signing | BLOCKED_EXTERNAL | a real keystore and its passwords; inventing one is forbidden |
| LAUNCHER_ICON | stock Flutter icon | BLOCKED_EXTERNAL | needs owner-approved artwork |
| OWNER_VISUAL_GATE | `OWNER_VISUAL_APPROVED` | NOT_VERIFIED | the owner's own judgement; AI may only produce objective comparison |
| TALKBACK | real screen-reader pass | BLOCKED_EXTERNAL | this emulator image has no TalkBack service (only `accessibilitymenu`); needs a real device |
| WHITE_NOISE_ASSETS | the design's 白噪音 control | BLOCKED_EXTERNAL | no audio in the repo; a toggle that plays nothing is the fake control the contract forbids |
| ROOM_SCENE_ART | designs 01/04/10 draw a photographic room | BLOCKED_EXTERNAL | no such asset; the contract forbids using the design board as UI and forbids inventing art |
| ROOM_SIT_FRAMES | a sustained sit pose | BLOCKED_EXTERNAL | no pack ships one; three layers fall back to idle |
| SOFT_SHIPPED_FRAMES | 4 of 147 shipped frames below the builder's rule | BLOCKED_EXTERNAL | replacing frames is artwork; recorded with a ratchet test |
| EMULATOR_ANR | system ANRs after repeated resize/install | NOT_VERIFIED | environment; prefer widget-test measurement over device fights |
