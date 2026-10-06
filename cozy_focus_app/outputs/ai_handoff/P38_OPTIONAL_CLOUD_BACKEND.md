# P38 — Optional Cloud Generation Backend

Branch `recovery/v4.2.1-rebuild`.

```
P38 = BLOCKED_EXTERNAL
```

## Why nothing was built

The brief allows implementing a provider-neutral backend "only if it is
independently useful and testable", and says the honest outcome may be
`PARTIAL / BLOCKED_EXTERNAL`. This is that outcome, and the reason is worth
stating rather than hiding behind the classification.

**The provider-neutral architecture already exists.** P37 delivered the request,
the result, the status vocabulary, the prompt template, the pack-output contract
and the retry/cost policy — and the property that matters most: a pack produced
through this path goes through the **same** reader, validator and install rules as
a file a user picked, so nothing in the app knows or asks where the bytes came
from. `CompanionPackSource.cloudGenerated` reaches the install plan as a recorded
value and changes nothing.

What is missing is not architecture. It is a backend to talk to, and credentials
to talk to it with. Neither exists.

## What a backend would add, and why building it now would be worse than not

An HTTP client, a request/response mapping, an auth path and a job-polling flow.
Every one of those is **unverifiable here**: no endpoint to call, no credential to
call it with, no response to map. Code written against an imagined API is code
whose only test is its own author's belief, and it would ship as *looks finished*.

The specific failure to avoid is the one the brief names: **do not claim cloud
generation PASS**. A backend module that exists, compiles and passes unit tests
against a fake HTTP layer is very easy to describe as "implemented", and it would
be a lie — nothing would have generated anything.

## What would unblock it, precisely

1. A Google Cloud project with the Vertex AI API enabled.
2. A service account with `aiplatform.endpoints.predict`, and its key available
   to the build.
3. A decision about where the credential lives — the app cannot hold one, so this
   needs a server, which is the "cloud backend" the phase is named for.

Then the work is: one `CompanionGenerationProvider` implementation, one
`ProviderScope` override, and the P37 tests re-run against it. The contract does
not change.

## `IDENTITY_OWNER_GATE = OWNER_INPUT_REQUIRED`

Separate from the credential problem and not fixed by it. A generation aimed at
*"my cat"* needs photographs of that cat; there are none in the repository and
none can be invented. A generation aimed at a description — "a sleepy grey cat who
likes rain" — works without them, so this gate blocks the **likeness** path rather
than the feature.

## What this does not affect

Nothing the product ships depends on it. The local custom pet path — build a pack
with `tools/cozy_pet_builder`, import it, and live with it — is complete, was
walked end to end offline on a device in P36, and needs no cloud at all. That was
the point of moving AI from P31 to P37 in the first place.
