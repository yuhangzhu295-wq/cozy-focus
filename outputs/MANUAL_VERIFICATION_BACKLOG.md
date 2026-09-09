# Manual Verification Backlog

Items in this file require real device / GUI and cannot be automated in the current
Windows-only Codex environment.

| ID      | Screen        | What to verify                                                                 | Reference      | Status   |
|---------|---------------|--------------------------------------------------------------------------------|----------------|----------|
| MAN-001 | 09A Craft List | Visual match vs designs/09A -- recipe list, progress card, empty state       | designs/09A    | PENDING  |
| MAN-002 | 09B Craft Detail | Progress bar accuracy, cancel button, remaining time display                | designs/09B    | PENDING  |
| MAN-003 | 09C Inventory | Quantity display, place button routing, empty state                            | designs/09C    | PENDING  |
| MAN-004 | 09 Room       | Real drag-and-drop feel, boundary clamping on physical device                  | designs/09     | PENDING  |
| MAN-005 | 08A Wrapped   | Save to gallery on real Android -- verify MediaStore write shows in Photos app | designs/08A    | PENDING  |
| MAN-006 | iOS build     | Full build -- NOT_RUN (Windows environment, no macOS/Xcode)                    | N/A            | NOT_RUN  |
| MAN-007 | iOS gallery   | Photos permission flow + gallery save -- NOT_RUN (Windows environment)         | N/A            | NOT_RUN  |
| MAN-008 | End-to-end craft flow | Start craft -> multiple focus sessions -> complete -> inventory -> room placement -> app restart -> verify persistence | Full flow | PENDING |
| MAN-009 | Room zIndex   | Visual layer ordering when items overlap -- no reorder UI implemented yet      | designs/09     | PENDING  |
| MAN-010 | Emoji artwork | Confirm emoji fallback icons render acceptably until real assets land          | N/A            | PENDING  |

## Note

Items MAN-001 through MAN-010 are blocked only by the absence of a real device /
Android emulator in the current automated environment, not by code defects.
All automated tests (166/166) and Android APK build pass.

The items above must be verified by the developer on a real Android device before
the project can claim full PHASE_4_REVIEW_APPROVED for manual coverage.
