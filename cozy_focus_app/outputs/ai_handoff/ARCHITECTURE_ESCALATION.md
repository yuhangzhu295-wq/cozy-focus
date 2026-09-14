# Architecture Escalation: Missing Explicit PHASE-6D Specification

- **Project**: COZY_FOCUS (`cozy_focus_app`)
- **Remote**: `https://github.com/yuhangzhu295-wq/cozy-focus.git` (`origin/main`)
- **Current HEAD**: `d9ed57803f0856ddcb8d4bd12ddf45feedec4dee`
- **Current Gate State**: `CURRENT_STAGE=APPROVED`, `stage=PHASE-6C`, `next_stage=PHASE-6D`
- **Escalation Reason**: Missing explicit architecture and motion specification for `PHASE-6D`
- **Date**: 2026-09-14
- **Escalating Role**: COZY_FOCUS Lead Implementation Agent (11/gemini-3.8-flash-high)
- **Escalation Target**: Architecture Reviewer (Claude Sonnet / Terra)

---

## 1. Context & Background

1. **Previous Stages Completed & Approved**:
   - **Phase 6A**: Mochi Pet motion foundation, decoupled Rive architecture, safe fallback loop, idle micro-motions (Breathe, Sway, Blink, Ear Twitch, Tail Wag), reduced motion support (`PHASE_6A_FINAL_GATE.md`).
   - **Phase 6B**: Focus, Pause, Sleep dedicated motion controllers, curves, and visual fallback representations (`PHASE_6B_FINAL_GATE.md`).
   - **Phase 6C**: Celebrate, Craft, Greeting dedicated motion loops, micro-bounces, synchronized gaze/ear tilts, and reduced-motion baseline checks (`PHASE_6C_FINAL_GATE.md`).
   - Total test suite passing: 231/231; remote CI verified green on commit `df1ad82bb406f46fd23c08c86e175e1477d27e29`.
2. **Current State**:
   - `outputs/ai_handoff/CURRENT_STAGE.json` states: `"stage": "PHASE-6C", "status": "APPROVED", "next_stage": "PHASE-6D"`.
   - `outputs/ai_handoff/PHASE_6C_FINAL_GATE.md` confirms `NEXT_STAGE: PHASE-6D`.

---

## 2. Specification Discovery Audit

A comprehensive search was performed across all documentation directories (`docs/`, `outputs/`, `lib/`, `test/`) and Git commit history:

1. **Search for "6D" / "PHASE-6D"**:
   - The only occurrences of `PHASE-6D` in the entire repository are in `CURRENT_STAGE.json` and `PHASE_6C_FINAL_GATE.md` as the transition pointer.
   - There are zero specification documents, design tickets, or checklists defining the requirements for `PHASE-6D`.
2. **Search for Remaining Motion States**:
   - In `docs/cozy_focus_v4_1/reference/02_动效架构.md`, the motion states listed are:
     `Idle / Focus / Craft / Pause / Celebrate / Sleep / Greeting / Interact`
   - With Idle (6A), Focus/Pause/Sleep (6B), and Celebrate/Craft/Greeting (6C) complete, `Interact` (`triggerInteract`) remains as the only listed visual state without a dedicated motion loop.
   - However, unlike Phases 6A, 6B, and 6C, there are:
     - **No timing parameters** (e.g. cycle duration, pause duration, loop vs one-shot).
     - **No displacement / scale / rotation metrics** (e.g. bounce height, tilt angle, squish factor).
     - **No interaction contract** (tap/touch trigger binding, tap target area, state timeout / return-to-idle behavior).
     - **No scope confirmation** whether Phase 6D is strictly Pet Interact fallback motion, Pet motion wiring into Home / Room pages, or Rive asset handoff preparation.
3. **Execution Order Document**:
   - `docs/cozy_focus_v4_1/execution_order_v4_1.json` covers through `V4.1-4` and stops before Phase 5 / Phase 6.

---

## 3. Strict Directive Compliance & Action Taken

Per user directive:
> *"严格查找明确的 PHASE-6D 规格。若没有明确 6D 规格，生成 outputs/ai_handoff/ARCHITECTURE_ESCALATION.md，说明缺失规格并停止，不猜测、不改业务代码、不进入后续阶段。"*

- **No Guessing / Zero Hallucination**: The implementation agent has made no assumptions regarding Phase 6D's scope or motion constants.
- **No Business Code Changes**: Zero lines of code in `lib/` or `test/` have been modified.
- **Protected Core Safeguarded**: `FocusClock`, `FocusSessionEngine`, `RewardLedger`, `SettlementDao`, `StatisticsEngine`, schema/persistence, `CraftEngine`, inventory, room placement, and pet persistence are completely untouched.
- **Untracked Safeguard**: `COZY_RESCUE_RESULT.md` remains strictly untracked and untouched.
- **Rive Status Maintained**: `RIVE_ASSET_STATUS=PENDING_AUTHORING` (no fake `.riv` binaries).
- **No Self-Approval**: Halting immediately and requesting architectural review.

---

## 4. Required Inputs for Phase 6D Unblocking

To unblock Phase 6D, Claude Sonnet / Terra should provide a concrete specification including:
1. **Target Scope**:
   - Is Phase 6D dedicated to the `PetVisualState.interact` motion loop and trigger mechanism, or does it include UI integration / tap gesture recognition on `PetAvatarWidget` / `PetMotionView`?
2. **Motion Specifications** (if Interact motion is required):
   - Cycle or animation duration (e.g. one-shot vs repeating).
   - Keyframe parameters (displacement `dy`, scale `sx/sy`, ear/tail angle, facial feature/gaze scaling).
   - Behavior on completion (transition back to `idle` or previous state).
   - Reduced-motion behavior.
3. **Acceptance Criteria & Test Matrix**:
   - Expected widget / unit tests and lifecycle checks.
