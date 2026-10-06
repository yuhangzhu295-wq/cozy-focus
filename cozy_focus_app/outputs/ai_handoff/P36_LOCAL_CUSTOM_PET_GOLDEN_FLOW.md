# P36 — Local Custom Pet Golden Flow

Pack-first roadmap (`P31_P40_PACK_FIRST_ROADMAP.md`). Branch
`recovery/v4.2.1-rebuild`.

**Status: COMPLETE.**

```
LOCAL_CUSTOM_PET_GOLDEN_FLOW = PASS
```

Walked on a Pixel 7 API 34 emulator, **offline**, from a freshly cleared app
(`pm clear`) — no seeded database rows, no developer UI, no network.

## The flow, and what verified each leg

Every claim below is checked against the filesystem, the install record, the
selection file or the SQLite database. Screenshots are recorded as what was
*seen*; they are not the evidence.

| leg | result | verified against |
|---|---|---|
| build a `.cozy_pet` with the CLI | 4 actions, 17 frames, 432 kB | the builder's own report |
| import through the real file picker | preview reads **动作 4 / 13** | the preview + the importer |
| install | `companion_packs/mimi/` with 17 frames + manifest | `ls` on the device |
| select without a restart | `{"selectedCompanionId":"mimi"}` | the selection file |
| Home | 和 咪咪 一起专注吧！with the cat from the pack's own frames | screenshot |
| Focus | the cat **reading a book** — `focus_read` from the pack | screenshot |
| Pause | 已暂停, 咪咪 暂停中, elapsed preserved | screenshot |
| Resume | 专注中, 03:57 | screenshot |
| Complete | **+10 咪咪 XP** — the custom companion's own name | screenshot |
| Room | 咪咪 的小房间, vitals shown, the cat asleep on the floor | screenshot |
| restart | selection `mimi`, checksum `e5bab2f4` unchanged | the selection file + the record |
| export | the share sheet offers `mimi.cozy_pet` | screenshot |
| delete | pack gone, record file removed, selection repaired to `dog` | `ls` + both files |
| re-import | installed again, **same checksum `e5bab2f4`** | the record |
| works again | 咪咪 with 10 XP and 2 分钟 intact | the growth page |

No Flutter exceptions in logcat across the whole walk.

## Three things the database proved that the screen could not

### The session arithmetic reconciles exactly

`focus_sessions` holds one row: `planned_seconds: 300`, `start_at` →
`end_at` = **251 seconds wall clock**, with one pause interval of **122
seconds**. 251 − 122 = **129 seconds = 2:09**, which is precisely what the
completion screen displayed, and `total_focus_minutes: 2` and
`experience_points: 10` match the +10 咪咪 XP shown.

This is worth stating because it is the same arithmetic the open P32 §31A
question is about (a displayed 30:00 settling at 29:55). Here the elapsed
truth and the display agree to the second once the pause is subtracted, which
narrows that question: the discrepancy is not a general drift in how elapsed
time is computed.

### The digest survives the whole round trip

`mimi` imports at checksum `e5bab2f4`, exports, is deleted, and re-imports at
`e5bab2f4` again. So the digest is over the pack's contents rather than over
an archive's bytes or a timestamp, and a re-import is recognised as the same
pack rather than as a conflict.

### Deleting a companion does not touch the player's progress

After the delete-and-re-import the growth page reads **10 XP, 2 分钟** — the
progress earned during the session, still there. The pack was removed and
re-added; the shared `PetProgress` was never involved. That is the shared-growth
rule holding under the harshest version of the test, and it is the thing a
per-companion economy would have broken.

## A limitation, stated rather than glossed

**The furniture-action leg was not exercised on this walk.** The room was empty
— a freshly cleared app owns no furniture, and crafting one needs materials the
2-minute session did not earn — so the room honestly said 房间空空的 and offered
no action. The capability path it would have exercised is covered by
`room_capability_wiring_test.dart`, which drives the real
`RoomSimulationController` with a real installed pack and a real sofa in the
database, and asserts both directions: a pack that cannot sit gets no action and
no effect, and a pack that can, does.

That is a test rather than a device walk, and it is the one leg of this phase
where the two differ.

## What the walk showed about "first class"

The custom companion is not a guest anywhere it was seen: the home header, the
focus page, the pause badge, the completion reward, the room title and the
picker all name 咪咪, and every one of them reads the catalog rather than
hard-coding a name. The focus page drew `focus_read` from the pack's own frames,
and the room's autonomous routine put the cat to sleep using the pack's `sleep`
frames — the same director, the same player, the same routine as a built-in.

## Environment notes worth keeping

- **The emulator window can be minimised**, and a minimised window is at
  `-32000` in the window bounds. Clicks then go nowhere and every tap "fails"
  with no error. `getScreenshot` restores it on Windows. Two rounds of
  apparently-dead buttons were this.
- **Neither tap method is universal.** `adb shell input tap` at scaled device
  coordinates reached the install button that CUA clicks missed; CUA clicks
  reached the import bar and the ⋯ menu that adb taps missed. When one fails,
  the other is worth trying before concluding the control is broken.
- **The device's screen is 1080×2400 and the CUA raster 561×1280**, so the
  scale is about 1.925.
- **A soft keyboard covers the bottom of the screen** and will eat taps meant
  for a button below the field. Dismiss it at the Android level (`input keyevent
  4`) rather than by tapping, which can land in the field and type.
