# P37 — AI Generation Spike

Pack-first roadmap (`P31_P40_PACK_FIRST_ROADMAP.md`). Branch
`recovery/v4.2.1-rebuild`.

**Status: COMPLETE as far as it can be.**

```
PROVIDER_ABSTRACTION:        PASS
REQUEST_RESPONSE_CONTRACT:   PASS
PROMPT_TEMPLATES:            PASS
PACK_OUTPUT_CONTRACT:        PASS
DETERMINISTIC_HARNESS:       PASS (test-only)
COST_AND_RETRY_POLICY:       PASS
TECHNICAL_TESTS:             PASS (23)
REAL_PROVIDER_GENERATION:    BLOCKED_EXTERNAL
IDENTITY_OWNER_GATE:         OWNER_INPUT_REQUIRED
```

## What was built

`lib/presentation/companion/pack/generation/` — four files, no dependencies.

| file | what it fixes |
|---|---|
| `companion_generation_contract.dart` | the request, the result, and the status |
| `companion_generation_prompt.dart` | what would be sent, and the contract stated around it |
| `companion_generation_policy.dart` | retry, backoff and the cost ceiling |
| `unconfigured_generation_provider.dart` | the provider this build actually has |

## The status is the important part

A generation path that can only report success is one that will eventually report
a fake one. So `blockedExternal` is a first-class outcome, and
`CompanionGenerationResult` **carries no bytes unless the status is `generated`** —
a caller cannot install a placeholder by ignoring the status, because there is
nothing to install.

`UnconfiguredGenerationProvider` returns exactly that, and the runner reports it
without calling the provider at all: there is nothing to attempt, and a failure
would misdescribe a missing capability as a broken one.

**Nothing in this phase fabricates a generation.** The deterministic harness that
builds a real `.cozy_pet` lives in the test file, named as a harness, and cannot be
reached from the app. Wiring it in would make a companion appear and convince
whoever saw it that the feature worked — which is the fake success the brief
forbids. `REAL_PROVIDER_GENERATION = BLOCKED_EXTERNAL` is the honest result.

## The prompt states the contract, not just the wish

A request carries the player's sentence — "a sleepy grey cat who likes rain". If
that were the whole prompt, the provider would be free to invent the canvas, the
anchors, the action names and the frame counts, and the result would be a pack
that cannot be installed.

So the template states them: 512×512, ground contact at y=458, centre at x=255,
the requested action vocabulary, at least two distinct frames per action, the
`<action>_<index>.png` naming, and an explicit "do not produce frames for actions
that were not requested".

The vocabulary and frame counts are **read from the app's own production
contract**, not written into the template, so a prompt cannot promise a companion
the app has no way to play. A test asserts the prompt says `idle (6 frames)`
because the dog's contract does.

## The policy is one object, not one per provider

A provider that retried itself would decide how many times and when to stop
spending, and each integration would decide differently — one retrying six times
against a rate limit while another gives up on the first 503. So a provider makes
**one attempt** and reports what it cost; `CompanionGenerationRunner` holds the
rules.

- backoff doubles, because the failures worth retrying are the ones a fixed short
  delay makes worse;
- a refusal or a missing capability is **not** retried — asking again does not
  change either, and it would cost money to be refused twice;
- the cost ceiling is part of the contract rather than a setting someone has to
  remember: a retry loop without one is a bug that bills the user.

A generation is the only operation in this app that spends money per call, which
is why the ceiling is here and not left to the caller.

## The output contract is a real pack

The test that matters is not the harness; it is that the **contract is complete**.
The harness builds a `.cozy_pet` from the request shape, and that pack goes through
the real `CompanionPackImporter` — the same reader, the same validator, the same
install rules as a file a user picked. It inspects clean, reports `2 / 13`, and a
generated pack claiming a built-in id is refused with `pack_id_reserved`.

If the request, the result or the pack shape were missing a field, the harness
could not produce an installable pack and the test would fail. That is the whole
point of building one.

It also demonstrates the P31 rule holding for the newest origin: nothing in the
install path knows or asks where the bytes came from. `CompanionPackSource
.cloudGenerated` reaches the install plan as a recorded value and changes nothing.

## The two things that need someone else

**`REAL_PROVIDER_GENERATION = BLOCKED_EXTERNAL`.** No credentials, no project, no
`gcloud`. Nothing in this phase can change that, and the abstraction is complete
enough that adding one is a provider class plus a `ProviderScope` override.

**`IDENTITY_OWNER_GATE = OWNER_INPUT_REQUIRED`.** A generation aimed at "my cat"
needs photographs of that cat, and there are none. A generation aimed at a
description works without them, so this gate blocks the *likeness* path rather
than the feature.

## What P38 may and may not claim

A provider-neutral backend can be implemented and tested without credentials — the
request, the result, the policy and the pack contract are all above. What cannot
be claimed is that cloud generation works. `P38 = PARTIAL / BLOCKED_EXTERNAL` is
the honest outcome unless real credentials appear, and the local custom pet is
complete without any of it.
