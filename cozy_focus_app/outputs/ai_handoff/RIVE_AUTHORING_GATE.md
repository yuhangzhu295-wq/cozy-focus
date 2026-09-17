# Rive Authoring Gate

Date: 2026-09-18
Baseline SHA: 2697b5b64fb2fe312a5b408eaac8cd7760890169
Review roles: DeepSeek discovery, Gemini tooling proof, Claude senior gate review.

## Decision

RIVE_AUTHORING_GATE = BLOCKED_PENDING_DISTRIBUTION_LICENSE_DECISION

There is no authentic Mochi Rive asset or editable Rive source in the repository or supplied V4.1 package. A verified local CLI route can build and validate a real Rive binary without login, but the project has no recorded decision establishing that such CLI output may be distributed with this app. The Rive editor documentation and pricing language identified during discovery make that entitlement non-obvious.

No .riv may be added to assets/animations/mochi.riv until the product owner records an explicit distribution-rights decision. This gate does not change the existing Flutter fallback, which remains the production-safe renderer.

## Senior Review Findings

| Priority | Finding | Required Resolution |
|---|---|---|
| P0 | Distribution rights for a CLI-built Rive asset are not documented. | Product owner records an explicit license or entitlement decision before an asset is committed. |
| P1 | IPetRiveRenderer does not carry focusProgress or craftProgress although the active contract requires those inputs. | A future Gemini-only integration slice explicitly extends the reviewed adapter contract and tests the data path. |
| P1 | Historical and active documents use conflicting artboard/state-machine names. | Future authoring uses the active contract (Mochi, State Machine 1) and records any deliberate rename across adapter and contract together. |

## Permitted Work While Blocked

- Preserve and test the Flutter fallback path.
- Keep companion presentation mapping independent from business authority.
- Prepare reviewed documentation and test plans that do not ship or claim a Rive asset.
- Continue non-Rive release-polish work when it does not invent acquisition rules or change protected core behavior.

## Prohibited Work While Blocked

- Commit a CLI-built, Marketplace, placeholder, or fabricated .riv as Mochi.
- Enable Rive on a production call site.
- Claim real companion completion or release acceptance based on the disposable tooling proof.
- Treat the licensing uncertainty as an authentication issue that can be bypassed.
