# P26 — Release Readiness

Artifacts built and inspected with `aapt2`, `apksigner` and direct bundle
inspection. Everything below is read from the built files, not from configuration.

```
P26_RELEASE_BUILD:  PASS
RELEASE_SIGNING:    NOT_RECOVERED
LAUNCHER_ICON:      BLOCKED
```

---

## 1. The APK, as built

| Field | Value |
|---|---|
| package | `com.yuhangzhu295.cozyfocus` |
| versionCode / versionName | `1` / `1.0.0` |
| minSdk | **21** |
| targetSdk | **35** |
| compileSdk | 35 |
| application-label | `Cozy Focus` (all 80 locales) |
| icon | `@mipmap/ic_launcher` — **stock Flutter logo** |
| native ABIs | arm64-v8a, armeabi-v7a, **x86, x86_64** |
| size | **29.5 MB** |

The APK is a **universal** APK, so it carries emulator ABIs (x86, x86_64) that no
real device uses. That is a property of building an APK rather than a bundle, and
it is part of why the file is 29.5 MB while the sprite packs are only 3.5 MB of
it. **The AAB is unaffected** — Play delivers per-device splits — which is why the
store artifact is the bundle.

## 2. Permissions

Explicitly declared by the app:

| Permission | Why |
|---|---|
| `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=28`) | saving the shareable PNG on API ≤ 28 |
| `READ_MEDIA_IMAGES` | **see below** |
| `READ_EXTERNAL_STORAGE` (`maxSdkVersion=28`) | **implied**, not declared — `aapt2` reports it as `requested WRITE_EXTERNAL_STORAGE` |

Contributed by plugins: `ACCESS_NETWORK_STATE`, `VIBRATE`, `POST_NOTIFICATIONS`,
and the internal `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.

### A finding: `READ_MEDIA_IMAGES` is broader than the feature

The app's gallery feature is a **save**, not a read. Verified:

- `wrapped_export_service.dart` calls only `Gal.putImageBytes` — no read API, and
  not `Gal.hasAccess` / `Gal.requestAccess`.
- `gal` 2.3.3's own `AndroidManifest.xml` declares **no** permissions.
- `gal`'s README lists `WRITE_EXTERNAL_STORAGE` (with `maxSdkVersion`) as its
  Android requirement, not `READ_MEDIA_IMAGES`.
- The app declares `READ_MEDIA_IMAGES` **itself**, in
  `android/app/src/main/AndroidManifest.xml` — it is not inherited.

`READ_MEDIA_IMAGES` grants read access to the user's photos. Requesting a
sensitive permission a feature does not use is a store-review and privacy
consideration, and it is the kind of thing that draws a policy question.

**Not changed here, deliberately.** I could not confirm the package never needs
it on some API level without running the share flow on a device, and removing a
permission that a save path turns out to need would break the feature in the
field. It is recorded as a release-readiness item to confirm before submission,
not as a defect I am entitled to fix unilaterally.

## 3. Signing

```
apksigner verify --print-certs app-release.apk
  Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
  Signer #1 certificate SHA-256: 4d9c3c3df843d21876aa23a8078a7a449eac7edf0a018618bf200de8fc0321d4
```

**`RELEASE_SIGNING = NOT_RECOVERED`.** The artifact is debug-signed.

`android/key.properties` is absent, and the build config already reads it and
switches over with no code change:

```kotlin
val releasePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = releaseStoreFile != null && ...
```

**No keystore was generated.** A fabricated signing key would be worse than none:
it would produce an artifact that cannot be updated by the real key later, and it
would misrepresent the release as signed. The consequence, stated plainly:

> This APK is **`LOCAL_RELEASE_VERIFY_ONLY`**. It installs and runs — verified on
> the emulator across P14, P18 and P21 — and it must not be uploaded to a store,
> because a debug-signed artifact cannot be re-signed by the owner's key without
> the user reinstalling.

## 4. The bundle

| Field | Value |
|---|---|
| entries | 613, single `base` module |
| module manifest | `base/manifest/AndroidManifest.xml` |
| native libs | 4 ABIs, split per device by Play |
| size | **48.1 MB** (the upload; per-device downloads are smaller) |

The bundle carries the same application id, version and label as the APK, and its
signing status is the same — `bundletool` signs with the debug key for a local
build.

## 5. Verdict

```
P26_RELEASE_BUILD:            PASS
RELEASE_SIGNING:              NOT_RECOVERED
LAUNCHER_ICON:                BLOCKED
LOCAL_RELEASE_VERIFY_ONLY:    YES
STORE_READY:                  NO
```

**The build is sound and the artifact is not shippable**, and those are different
statements. Everything under the owner's control that engineering can verify
checks out: the right application id, a coherent version, SDK 35 with minSdk 21,
the correct label in every locale, a well-formed bundle, and an APK that installs
and runs on a device.

What blocks a store submission is exactly the two owner-supplied items the
program has carried since P13, plus one item to confirm:

| Blocker | Owner action |
|---|---|
| **Signing** | supply `android/key.properties` + the keystore |
| **Icon** | supply approved launcher artwork |
| `READ_MEDIA_IMAGES` | confirm the gallery save needs it, or drop it |

None of the three is an engineering task.
