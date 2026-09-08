# Cozy Focus App

Flutter source for the **Cozy Focus** productivity app.

## Status

Phase 1 complete — Domain + Data Layer (Drift local DB, FocusSessionEngine, RewardService).
Phase 2 (Focus Core UI) pending user approval.

## Architecture

`
UI (Riverpod widgets)
  ↓
Controller / ViewModel (Riverpod providers)
  ↓
UseCase / Service (FocusSessionEngine, RewardService, SyncEngine)
  ↓
Repository interface (IFocusSessionRepository, ...)
  ↓
Drift (local, primary) / Supabase (remote, Phase 7)
`

## Running

`ash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
`

## Platform targets

- Android (scaffold in ndroid/)
- iOS (scaffold in ios/)

Build and device testing require Android Studio / Xcode respectively.