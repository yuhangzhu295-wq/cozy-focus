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
| ROOM_SCENE_ART | designs 01/04/10 draw a photographic room | RESOLVED_AS_NOT_NEEDED | **不再是"缺素材"**：并排试验证明照片房间配 App 的 2D 宠物 = 贴纸贴在照片上，而简报禁止把 2D Mochi 换成不一致的 3D，所以房间只能与宠物同画风。上一版这条连"生成通路其实通着"都漏了（所有者桌面豆包可达）。详见 `08_RELEASE_BLOCKERS.md` 第 5 条与 `README.md` 2a-1 |
| ROOM_SIT_FRAMES | a sustained sit pose | BLOCKED_EXTERNAL | no pack ships one; three layers fall back to idle |
| SOFT_SHIPPED_FRAMES | 4 of 147 shipped frames below the builder's rule | BLOCKED_EXTERNAL | replacing frames is artwork; recorded with a ratchet test |
| EMULATOR_ANR | system ANRs after repeated resize/install | NOT_VERIFIED | environment; prefer widget-test measurement over device fights |
