# Android V1 Release Decision

## Scope

- TARGET: ANDROID_V1
- NORMAL_FEATURE_DEVELOPMENT: PAUSED
- REVIEW_MODE: SINGLE_AGENT
- RELEASE_BRANCH: release/android-v1
- DIRECT_PUSH_MAIN: NO
- AUTO_MERGE: NO
- AUTO_STORE_SUBMIT: NO

## Companion Renderer

- PRODUCTION_PET_RENDERER: FLUTTER_FALLBACK
- RIVE_RELEASE_DEPENDENCY: REMOVED
- RIVE_ASSET_STATUS: DEFERRED_OPTIONAL
- DRESS_FEATURE: DEFERRED

Android V1 does not ship a Rive runtime dependency or a Rive asset. The
existing Flutter fallback remains the production Mochi renderer. The
renderer-neutral presentation boundary accepts business-derived focus and craft
progress values, clamps visual inputs to the inclusive 0.0 through 1.0 range,
and does not create a timer, mutate business state, or invoke settlement.

## Release Boundaries

No real Rive asset has been represented as completed. No dress, equipment,
economy, cloud, or other product feature work is included. No production
application identifier, signing material, or launcher artwork has been
invented.
