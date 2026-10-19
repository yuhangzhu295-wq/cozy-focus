# 08 — Release blockers

**`STORE_RELEASE_READY = NO`.** Nothing below is an engineering task that was
skipped; each is either the owner's decision, the owner's secret, or hardware
this machine does not have.

| # | Blocker | State | Why it is not engineering's to close |
|---|---|---|---|
| 1 | **Release signing** | `BLOCKED` | `android/key.properties` is absent, so a release build silently falls back to debug signing. No keystore was generated and no private key was written anywhere. The owner must create it outside the repo and back it up. The exact `keytool` command is in `outputs/final_product_qa/RELEASE_READINESS_AUDIT.md` §C1. The build switches over with no code change. |
| 2 | **Launcher icon** | `BLOCKED` | `android/` still carries the stock Flutter logo. A six-size candidate in the app's palette exists at `outputs/launcher_icon_candidate/`, but **the owner has not approved it**, so nothing under `android/` was touched. Blocked on approval, not on artwork. |
| 3 | **`OWNER_VISUAL_APPROVED`** | `BLOCKED` | The gate marks it `REQUIRED` and it is never decided by a measurement — but it has not run, and the reason is external: **no image-capable reviewer channel exists on this machine.** Blocked, not deferred: deferring would read as "not run by decision". Per-channel evidence in `05_VISUAL_COMPARISON.md`. The implementer did not self-approve. |
| 4 | **Board-level visual review** | `WAITING_FOR_INDEPENDENT_REVIEW` | No available reviewer accepts Flutter screenshots: `visual-judge` is scoped to pptx/docx/xlsx/pdf/poster/chart. The 16 screens have device screenshots and per-element comparison, but not an independent visual sign-off. |
| 5 | **Physical-device performance** | `NOT_MEASURED` | All numbers are from an AVD with `ro.hardware.egl=emulation` (swiftshader). The **build** timings transfer (Dart CPU); the **raster** timings do not. A real GPU device is required before quoting frame times to the store. |
| 6 | **TalkBack / accessibility walk** | `NOT_MEASURED` | The widget-level semantic contracts pass and duplicate announcements were fixed, but no TalkBack pass was run on the device this round. |
| 7 | **Flow / video-to-sprite pipeline** | `BLOCKED_EXTERNAL` | No reachable video surface; no production video art exists. The pipeline is validated against a local clip only. |
| 8 | **Cloud sync** | **Not a blocker — not implemented by decision** | D7: local-first, and nothing claims to sync. The data page says so. |
| 9 | **White noise / system notifications** | **Not implemented** | `flutter_local_notifications` is a dependency and is imported nowhere in `lib/`. Both screens now say so in their own words rather than showing a dead switch. |
| 10 | **Dress / equipment** | **Deferred by product decision** | `DRESS_PRODUCT_DECISION.md`; the dress page says the system is not connected and offers no wearable. |

## What is *not* a blocker any more

- **Data export/restore** — implemented, tested and walked on the device this
  round. It was previously listed as absent.
- **Route coverage** — 34/34 walked (the earlier "33" was a miscount).
- **Frame time** — measured on the emulator with Flutter's own timings; the
  remaining limitation is the GPU, listed above.
- **The room pet's ground line** — fixed for both renderers, and the candidate's
  rug plane was corrected after the device walk.

## What must not be claimed

- `DEBUG_BUILD_PASS` is not `STORE_RELEASE_READY`.
- `ENGINEERING_COMPLETE` is not `OWNER_VISUAL_APPROVED`.
- A candidate room that passes every automated check is not an approved room.
