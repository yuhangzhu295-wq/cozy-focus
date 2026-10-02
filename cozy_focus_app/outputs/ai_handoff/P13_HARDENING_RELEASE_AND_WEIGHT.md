# P13 — Production Hardening: Release Build + Sprite Weight

- Branch: `recovery/v4.2.1-rebuild`
- HEAD at this record: `83c7044` + the downscale commit
- Scope: the two hardening items that could be settled by measurement — the
  release artifact, and the app's single largest weight.

---

## 1. Release build closure

### Identity — verified from the built artifact, not from the source

```
aapt2 dump badging app-release.apk
  package: name='com.yuhangzhu295.cozyfocus' versionCode='1' versionName='1.0.0'
  targetSdkVersion:'35'
  application-label:'Cozy Focus'
```

`CURRENT_STAGE.json` records that the previously stored release artifacts were
built under `com.example.cozy_focus_app` and are stale. They are: the current
build carries `com.yuhangzhu295.cozyfocus`, which matches
`android/app/build.gradle.kts` (`namespace` and `applicationId`).

Both artifacts build:

| Artifact | Size |
|---|---|
| `app-release.apk` | 40.4 MB |
| `app-release.aab` | 58.9 MB |

### Signing — `RELEASE_SIGNING = NOT_RECOVERED`

**Measured, not assumed:**

```
apksigner verify --print-certs app-release.apk
  V2 Signer: certificate DN: C=US, O=Android, CN=Android Debug
```

The release artifact is **debug-signed**. `android/key.properties` does not
exist, no keystore is present anywhere in the tree, and none was generated —
`.gitignore` excludes `key.properties`, `*.jks` and `*.keystore`, and the only
tracked file is `android/key.properties.example`.

The build config already implements the honest behaviour and says so in a
comment:

```kotlin
release {
    // Debug signing enables local build verification only; it is not
    // production/store signing when android/key.properties is absent.
    signingConfig = if (hasReleaseSigning) { … } else { signingConfigs.getByName("debug") }
}
```

So a keystore dropped in locally flips it to real signing with no code change,
and until then the status is `NOT_RECOVERED` rather than a fabricated keystore.
**This is a valid terminal state, not a blocker**: the artifact installs and can
be verified, which is what local gates need.

### Launcher icon — P1, still open

The launcher icon is still the **stock Flutter logo**. Measured from the
dominant colours of `mipmap-*/ic_launcher.png`: `(84, 197, 248)` and
`(1, 87, 155)` — Flutter blue. No approved Cozy Focus artwork exists, so none was
invented. This stays open until artwork is supplied.

---

## 2. Sprite weight — the app's single largest cost

### The finding

The two companion packs shipped **98 frames at 1024×1024, mean 476 KB, totalling
45.6 MB** — about 60% of the 75.5 MB release APK. The companion is drawn at
**92–150 logical px** (the room uses `size = 92.0`), so a 1024 square is roughly
seven times the linear resolution any device asks for.

### The change

`tools/productionise.py` had `CANVAS = 1024`. It is now `512`, and both packs
were regenerated from the staged sources — so the canvas has one source of truth
and future frames (the rabbit) are authored at the right size from the start.

Everything that carried the old geometry moved with it:

| Artifact | Change |
|---|---|
| `tools/productionise.py` | `CANVAS = 512`, with the reason recorded |
| `assets/companions/{dog,cat}/manifest.json` | regenerated; canvas 512, groundBaseline 458, centerAnchor 255 |
| `assets/companions/dog/animation_manifest.json` | the sprite contract source, updated to match |
| `SpriteAnimationManifestData.mochi` | the Dart mirror, updated to match |

The new geometry was **derived from the regenerated art** by
`tools/manifest.py`, not chosen: it measures each frame's alpha bounds and
averages the ground line and centre.

### The measured result

| | before | after | change |
|---|---|---|---|
| dog pack | 25 MB | 7.7 MB | −69% |
| cat pack | 22 MB | 6.5 MB | −70% |
| both packs | 45.6 MB | 14.2 MB | **−31.4 MB** |
| release APK | 75.5 MB | **40.4 MB** | **−46%** |
| release AAB | 94.5 MB | **58.9 MB** | **−38%** |

### Verification

- The integrity gate measures every shipped frame against the contract and all
  328 companion tests pass — so the art genuinely stands on the declared ground
  line and centre at the new canvas.
- The full suite is green at 1091/1091.
- **Device check, because a canvas change is exactly the kind that misaligns
  silently**: rebuilt, installed on `emulator-5554`, and the room was inspected.
  Mochi's feet sit *on* the sofa cushion with no float and no sink
  (`p13_room_512.png`), and the home page renders unchanged
  (`p13_home_512.png`).

### A note on what this does NOT touch

The frames were regenerated from the same staged sources, so the art is the same
art — no pose, expression or prop changed. The render path is
resolution-independent: the sprite player draws at `size` px and the placement
maths work in normalised coordinates, so nothing in `lib/` needed a pixel value
updated.

---

## 3. Also closed in P13

The shared global router, which leaked navigation location between tests in a
file, is fixed in `83c7044` — see `FLAKY_TEST_CLASSIFICATION.md` §Class 2 for the
measurement, the fix, and the test it exposed.

---

## 4. P13 items still open

| # | Item | Status |
|---|---|---|
| 1 | Release signing | `NOT_RECOVERED` — needs a keystore from the owner; cannot be invented |
| 2 | Launcher icon | P1 — needs approved artwork |
| 3 | Store submission | blocked on 1 and 2 |
| 4 | Rabbit sprite pack | P10 scope, not hardening |
