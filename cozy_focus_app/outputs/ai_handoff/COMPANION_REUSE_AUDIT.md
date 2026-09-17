# Companion Reuse Audit

Date: 2026-09-18
Baseline SHA: 2697b5b64fb2fe312a5b408eaac8cd7760890169
Scope: AUTO-0B / AUTO-3 discovery. No application source or asset was changed.

## Asset Truth

- REAL_RIVE_ASSET_STATUS = BLOCKED_PENDING_AUTHORING.
- The repository and supplied V4.1 material contain no .riv, .rev, .rml, or editable Rive project source.
- assets/animations contains only .gitkeep, which explicitly prohibits fake .riv files.
- The existing Mochi material is the V4.1 motion-reference PNG set under docs/cozy_focus_v4_1/designs/motion. It is art direction, not layered or riggable source art.
- The shipping renderer remains the truthful Flutter fallback. enableRive defaults to false and no production call site enables it.

## Candidate Assessment

| Candidate | License | Maintenance | Relevance | Can Reuse | Decision |
|---|---|---|---|---|---|
| Official rive Flutter runtime | MIT | Active | High | Yes, when a real asset is approved | Repo uses the 0.13-era runtime; 0.14+ is a breaking migration and is not implied by this audit. |
| Official rive-flutter examples | MIT | Active | High | Yes, as patterns | Inputs, lifecycle, reduced-motion, and pause/play patterns may inform a future reviewed integration. |
| Official rive-runtime | MIT | Active | Medium | Patterns only | The Flutter package remains the application integration point. |
| Rive CLI 1.0.4 and RML | Tool terms require confirmation | Active | High | Tooling only | Verified locally outside this repository; it is not a license decision for distributing output. |
| Rive Marketplace assets | CC BY 4.0 stated by Rive | Active | Low | Conditional | No maintained, license-safe, Mochi-suitable asset was identified. Attribution and export terms would still require review. |
| V4.1 motion PNGs | Project material | N/A | High | Reference only | Flat visual specifications cannot be relabeled as Rive source art. |

## Verified Tooling Proof

A Gemini implementation subagent performed a disposable proof outside the repository using the official Windows Rive CLI release.

- CLI: rive 1.0.4.
- Official release manifest: https://releases.rive.app/cli/latest/manifest.json.
- Windows artifact checksum verified: 651110eb3b041b84948bfeea83e0b861e848a73b9698729fc3d0775d85153547.
- Without login, the CLI successfully created a project, verified it, compiled a genuine Rive binary, inspected its AST, and produced a headless screenshot.
- The disposable proof file had the RIVE binary header and was not copied into this repository.
- whoami reported Not logged in; publish, rev, and cloud push require login.

This proves a local authoring and verification route exists. It does not prove that a CLI-built asset is licensed for product distribution.

## Runtime Compatibility

- This repository declares rive: ^0.13.17 and resolves 0.13.20.
- Current Rive releases use a newer, breaking C++-backed Flutter API and favor data binding over legacy state-machine input access.
- The existing adapter uses the 0.13-era APIs. Do not upgrade the runtime or modify production enablement until a real approved asset requires a separately reviewed integration slice.

## Contract Reconciliation Required

outputs/PET_ANIMATION_ARCHITECTURE.md is historical architecture material and names mochi_main / mochi_state_machine. The active asset contract at outputs/ai_handoff/RIVE_COMPANION_ASSET_CONTRACT.md, and the current adapter default, use Mochi / State Machine 1.

For future authoring, the active asset contract is the source of truth. The historical document must not be used to choose asset names. Any authoring proposal must also specify how the adapter receives focusProgress and craftProgress; it currently has no production data path for those inputs.

## Non-Goals

- No fake binary, placeholder Rive file, or renamed non-Rive file.
- No unlicensed third-party companion asset.
- No new pet economy, outfit acquisition rule, or persisted equipment model.
- No production change to enableRive or the Flutter fallback.
