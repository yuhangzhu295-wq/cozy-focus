# CozyFocus — P28→P40 Program Roadmap

Saved verbatim from the program brief. This is the governing document for P28 through P40:
roles, protocols, per-phase scope, gates and report templates.

```text
PROJECT = COZY_FOCUS

PROGRAM = P28_TO_P40_CUSTOM_COMPANION_AND_RELEASE

MODE = MULTI_AGENT_INCREMENTAL_PRODUCTION

==================================================
0. 项目身份
==================================================

项目：

CozyFocus

产品：

Flutter Pomodoro
+
2D Companion
+
Growth
+
Room
+
Craft
+
Collection
+
Memory
+
Daily Life


Git Root:

C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat


Flutter App:

C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app


AI handoff:

C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app\outputs\ai_handoff


Specs:

C:\Users\zyu33\Documents\CozyFocus-Specs\V4_1

C:\Users\zyu33\Documents\CozyFocus-Specs\V4_2_1


Backup:

C:\Users\zyu33\Documents\CozyFocus-Backups\cozy-focus-recovery_c367f8a.bundle


Working Branch:

recovery/v4.2.1-rebuild


Latest remotely observed HEAD at handoff time:

15c02fb94e7e1db052169b27507627cf0fbd7808


IMPORTANT:

DO NOT trust this SHA blindly.

Before every phase verify:

git symbolic-ref HEAD
git rev-parse HEAD
git status --short
git log --oneline -10
git show-ref
git reflog -10

and remote recovery SHA.

==================================================
1. 当前已经完成，不要重建
==================================================

Existing architecture includes approximately:

CompanionContext

CompanionBehaviorDirector

BehaviorRecipe

CompanionPresentationIntent

CompanionRenderer

CompanionAnimationController

AnimationStateMachine

LocomotionController

CompanionSpritePlayer

SpriteAnimationManifest

CompanionActionAvailabilityResolver

CompanionEvent

PresentationVitals

CompanionVitals

GrowthStage

Emotion presentation logic

FurnitureEntity

FurnitureAction

FurnitureAnchorRegistry

FurnitureActionResolver

RoomSimulationController

RoomItem placement persistence

CraftRecipe

CraftJob

Inventory

Collection

Companion Memory

Daily Routine

dog / cat / rabbit production packs

video_to_sprite pipeline

debug-only QA fixture harness

Focus core

Reward settlement

Statistics

P14 completion-page save fix.


Audit actual code names before relying on this list.

Do NOT create duplicate systems merely because
the roadmap uses a different conceptual name.

==================================================
2. 核心架构边界
==================================================

BUSINESS TRUTH:

FocusSession
FocusRecord
RewardLedger
Settlement
XP
Coin / existing reward resource
CraftJob
CraftRecipe
Inventory
Room ownership
Statistics

        ↓ READ

PRESENTATION / COMPANION:

Behavior
Animation
Emotion
Daily Routine
Room Life
Memory-driven presentation
Dialogue


Presentation may read business truth.

Presentation MUST NOT:

award XP
award coins
complete Focus
settle session
complete Craft
invent Inventory
change ownership
rewrite Statistics.

==================================================
3. 保护核心
==================================================

Do NOT alter business semantics without a
reproduced release-blocking defect:

FocusClock

FocusSessionEngine

RewardLedger

SettlementDao

StatisticsEngine

CraftEngine

Inventory ownership

Room persistence

RoomGeometry

reward calculation

Focus settlement.


Animation and AI must never own these.

==================================================
4. 产品价值观
==================================================

CozyFocus must remain:

supportive

low-pressure

non-guilt

local-first where possible

Focus-first.


Forbidden unless explicitly approved:

pet death

hunger punishment

illness

neglect punishment

lost XP due to absence

dependency manipulation

"你怎么这么久不来看我"

"我一直在等你"

"不要离开我"

streak shame.

==================================================
5. 当前最重要产品问题
==================================================

Technical gates being green does NOT prove
the user-facing product is complete.

Current user-visible gaps include:

A.
Furniture actions may exist as IDs/status text
without a visually meaningful action.

B.
Player-requested furniture action may be replaced
before promised minDwell.

C.
Collection shows locked items but does not clearly
teach how they are acquired.

D.
A user may not be able to discover the full
Craft → Focus → Inventory → Room loop
without developer knowledge.

These are P28-P30.

==================================================
6. 多模型角色
==================================================

--------------------------------
architecture-reviewer
--------------------------------

Preferred model:

global:hy4-preview


ROLE:

READ ONLY

architecture audit

product state analysis

data ownership

game-system design

risk analysis.


Before implementation output:

CURRENT_STATE

CONFIRMED_GAPS

EXISTING_EQUIVALENTS

PROPOSED_DESIGN

FILES_TO_TOUCH

FILES_NOT_TO_TOUCH

SOURCE_OF_TRUTH

TEST_PLAN

RUNTIME_PLAN

RISKS

NON_GOALS.


Never edit production code by default.


--------------------------------
code-implementer
--------------------------------

Preferred model:

global:deepseek-v4.1-flash


ROLE:

ONLY normal writer.

Production source

Tests

Small refactor

QA scripts

Runtime fixes

Git operations.


One writer per coherent slice.


--------------------------------
code-reviewer
--------------------------------

Preferred model:

claude-sonnet-4-6


ROLE:

READ ONLY independent review.


Review actual diff.

Look specifically for:

duplicate source of truth

business leaks

dead code

fake buttons

status-text-only features

silent fallbacks

Timer leaks

Ticker leaks

async races

unseeded random tests

direct DateTime.now()

page-level business writes

species branching

test weakness

vacuous PASS

security mistakes

privacy mistakes

unbounded storage.


Return:

P0

P1

P2

with exact evidence.


--------------------------------
final-gate
--------------------------------

Preferred model:

gpt-6-sol


USE VERY SPARINGLY.

Only:

major architecture dispute

or

P40 final release candidate.


Do not call on every phase.

==================================================
7. 多模型协调规则
==================================================

Correct:

HY4 audit
↓
DeepSeek implement
↓
Focused tests
↓
Runtime evidence
↓
Claude review
↓
DeepSeek fixes only real P0/P1
↓
Full gates
↓
Commit
↓
Push
↓
Verify remote


Incorrect:

HY4 and DeepSeek editing the same files simultaneously.

==================================================
8. 自证协议
==================================================

Every important claim must have evidence.

--------------------------------------------------
A. REPRODUCE
--------------------------------------------------

Before fixing a defect:

reproduce it.

Record:

INPUT

EXPECTED

OBSERVED

EVIDENCE.


--------------------------------------------------
B. LOAD-BEARING TEST
--------------------------------------------------

Critical regression test should fail
before the fix where feasible.


--------------------------------------------------
C. NEGATIVE PROOF
--------------------------------------------------

For critical gates temporarily break contract.

Examples:

remove asset registration
→ gate must fail

break minDwell
→ action truth must fail

make unavailable collection item clickable
→ acquisition gate must fail

duplicate settlement
→ idempotency gate must fail

break custom pet manifest
→ pack gate must fail.


Restore immediately.

Never commit deliberately broken state.


--------------------------------------------------
D. FOCUSED TESTS
--------------------------------------------------

Run focused tests first.


--------------------------------------------------
E. FULL TESTS
--------------------------------------------------

Run fresh:

flutter test --no-pub


Never reuse historical count.


--------------------------------------------------
F. STATIC
--------------------------------------------------

dart format --output=none --set-exit-if-changed lib test

flutter analyze --fatal-infos --no-pub

git diff --check


--------------------------------------------------
G. BUILD
--------------------------------------------------

Where runtime/product affected:

flutter build apk --debug

flutter build apk --release

and eventually AAB.


--------------------------------------------------
H. RUNTIME
--------------------------------------------------

Motion claims require:

multiple timed frames

or recording

or deterministic diagnostics.


One screenshot does not prove animation.


--------------------------------------------------
I. PERSISTENCE
--------------------------------------------------

state change
→ restart
→ verify persisted state.


--------------------------------------------------
J. BUSINESS ISOLATION
--------------------------------------------------

snapshot business state

exercise presentation feature

snapshot again

no unauthorized mutations.


--------------------------------------------------
K. REVIEW
--------------------------------------------------

Claude reviews actual diff.


--------------------------------------------------
L. GIT
--------------------------------------------------

Explicit stage only intended files.

Never:

git add .
git add -A

Commit coherent slice.

Push recovery branch.

Verify:

LOCAL_HEAD == REMOTE_HEAD.

==================================================
9. PASS 语义
==================================================

Allowed:

PASS

FAIL

BLOCKED

PARTIAL

ASSET_GAP

PRODUCT_DECISION_REQUIRED

VISUAL_REVIEW_REQUIRED

NOT_TESTED

DEFERRED.


Never convert BLOCKED into PASS.

Never write PASS because:

"看起来没问题"

"理论上支持"

"代码路径存在".

==================================================
==================================================
P28 — FURNITURE ACTION TRUTH
==================================================
==================================================

GOAL:

Every player-facing furniture action must
actually happen.

Definition:

PLAYER REQUEST
→ decision accepted
→ correct target anchor
→ locomotion
→ correct visual action
→ visually meaningful
→ minDwell respected
→ effect applied once
→ clean exit.

Action ID or status text alone is NOT success.

==================================================
P28.1 Reproduce premature override
==================================================

Known observation:

sofa sit has:

minDwell ≈ 14 sec

but appeared to revert after about 2–4 sec.

Do not guess.

Instrument:

requestAt
decisionAt
endsAt
tickAt
elapsed
cause
actionId
anchorId
replacementCause
previousDecision
nextDecision.


Find the exact owner that replaces the action.

==================================================
P28.2 Player authority
==================================================

Valid player-requested furniture action
must not be preempted before minDwell by:

idle

daily routine

ambient emotion

room idle choice.


Only stronger explicitly-approved context
may interrupt.

Document precedence.

==================================================
P28.3 Action matrix
==================================================

Enumerate all exposed playerTap furniture actions.

Expected examples:

sofa:
sit
rest

desk:
write
study
craft

bookshelf:
read
search

bed:
sleep

rug:
sit


For each verify:

owned requirement

placed requirement

anchor

semantic action

visual capability

movement

arrival

minDwell

effect once

clean recovery.

Output:

FURNITURE_ACTION_MATRIX.json

==================================================
P28.4 Visual truth
==================================================

Classify every exposed action:

VISUALLY_DISTINCT

VISUALLY_AMBIGUOUS

NO_REAL_VISUAL_ACTION.


If two user-facing actions look effectively identical:

do NOT ship two fake choices.

Either:

add approved real asset/action

or

hide/collapse unsupported choice.


Status text cannot substitute for motion.

==================================================
P28.5 Effect truth
==================================================

Player-facing text such as:

恢复精神
心情变好
更专注
认识新事物

must correspond to real presentation effect.


If not meaningful in runtime:

remove the promise.

Do not invent economy/business mechanics
to justify copy.

==================================================
P28 Gate
==================================================

PLAYER_REQUEST_MIN_DWELL:
PASS / FAIL

PREEMPTION:
PASS / FAIL

ACTION_MATRIX:
x/x

REAL_VISUAL_ACTIONS:
x

AMBIGUOUS_ACTIONS:
<list>

FAKE_ACTION_BUTTONS:
0 required

EFFECT_TRUTH:
PASS / FAIL

==================================================
==================================================
P29 — COLLECTION ACQUISITION UX
==================================================
==================================================

GOAL:

A player looking at a locked item must know:

how to obtain it

how much progress is required

current state

next action.

==================================================
P29.1 Do not duplicate truth
==================================================

CollectionCatalog must NOT copy:

recipe duration

recipe cost

CraftJob state

Inventory truth.


Resolve using itemId against real data.

Prefer presentation model equivalent to:

CollectionAcquisitionViewModel

with derived state only.

==================================================
P29.2 Derived states
==================================================

Derive:

UNAVAILABLE

CRAFTABLE

CRAFTING

OWNED

PLACED.


Do not persist as second business state.

==================================================
P29.3 Card interaction
==================================================

Obtainable locked card:

tap
→ acquisition detail.


Show:

获取方式

real recipe

需要专注 X 分钟

actual material requirement

current CraftJob

current ownership.

==================================================
P29.4 CTA matrix
==================================================

UNAVAILABLE:

显示:
当前版本尚未开放

CTA:
none


CRAFTABLE:

显示:
需要专注 X 分钟

CTA:
开始制作


CRAFTING:

显示:
current / target

CTA:
继续专注


OWNED:

显示:
已拥有 xN

CTA:
去房间摆放


PLACED:

显示:
已摆放

CTA:
查看房间

==================================================
P29.5 First-time explanation
==================================================

Make loop explicit:

选择想制作的家具
→ 开始制作
→ 专注时间转化为制作进度
→ 完成后进入库存
→ 房间摆放.


Do not imply random drops.

==================================================
P29.6 Unavailable entries
==================================================

Items without actual acquisition path:

未开放

excluded from obtainable denominator

no fake CTA.

==================================================
P29 Tests
==================================================

changing recipe duration
must automatically change collection detail.

No edit to CollectionCatalog required.

Verify:

recipe resolution

duration

CraftJob progress

ownership

placement.

==================================================
==================================================
P30 — USER GOLDEN FLOW
==================================================
==================================================

GOAL:

A fresh user can discover and complete the real loop
without developer knowledge.

==================================================
P30 flow
==================================================

Fresh data
→ open collection
→ choose locked obtainable item
→ understand acquisition
→ start CraftJob
→ start Focus
→ Focus progresses CraftJob
→ complete
→ Inventory ownership
→ Collection owned
→ Room placement
→ tap furniture
→ companion walks
→ real visual action
→ minDwell
→ restart
→ state persists.

==================================================
P30 restrictions
==================================================

No direct SQLite modification.

No adb granting target furniture.

No fixture completing target Craft.

No hidden developer route.


Injected clock may accelerate time.

Fixture may establish onboarding only.

==================================================
P30 discoverability evidence
==================================================

For each screen record:

SCREEN

ACTION

EXPECTED

OBSERVED

NEXT_ACTION_VISIBLE.

==================================================
P30 Gate
==================================================

USER_GOLDEN_FLOW:
PASS / FAIL

COLLECTION_TO_CRAFT:
PASS / FAIL

CRAFT_TO_FOCUS:
PASS / FAIL

FOCUS_TO_INVENTORY:
PASS / FAIL

INVENTORY_TO_ROOM:
PASS / FAIL

ROOM_TO_ACTION:
PASS / FAIL

RESTART_PERSISTENCE:
PASS / FAIL

==================================================
==================================================
P31 — CUSTOM PET TECHNICAL SPIKE
==================================================
==================================================

GOAL:

Prove one real user pet can become
a working CozyFocus companion.

Do not build entire backend first.

==================================================
P31 scope
==================================================

V1 supported species:

dog
cat
rabbit


Input:

minimum 1 photo

recommended 3 photos:

front
3/4
side/full body.


First prototype only:

idle

walk

sit / room_sit.


Do NOT generate all 13 actions yet.

==================================================
P31 proof
==================================================

One real pet:

photos
→ identity master
→ idle
→ walk
→ sit
→ sprite pack
→ Flutter runtime.


Gate:

IDENTITY_RECOGNIZABLE:
OWNER_REVIEW_REQUIRED

STYLE_MATCH:
PASS / FAIL

IDLE:
PASS / FAIL

WALK:
PASS / FAIL

SIT:
PASS / FAIL

RUNTIME:
PASS / FAIL

==================================================
==================================================
P32 — CUSTOM PET UPLOAD + IDENTITY MASTER
==================================================
==================================================

GOAL:

Create a stable stylized representation
of the user's actual pet.

==================================================
P32 architecture
==================================================

Production must use backend APIs.

Do NOT depend on browser automation against
Google Flow in production.

Flow may remain a manual R&D tool.

Backend provider must be abstracted.

Suggested logical interfaces:

PetIdentityProvider

PetMotionProvider

GeneratedAssetStorage

GenerationQueue

GeneratedPackCompiler.

==================================================
P32 upload quality gate
==================================================

Validate:

supported MIME

actual file signature

file size

image decode

minimum resolution

pet visible

reasonable crop

not completely blurred.


Strip EXIF metadata.

Reject malformed files.

==================================================
P32 pet identity
==================================================

Generate canonical masters:

front

3/4

side

sitting

as needed.


Goal:

preserve:

fur colour

markings

ear shape

face shape

tail characteristics

body proportions.


Transform to CozyFocus 2D style.

==================================================
P32 species
==================================================

Classify only into:

dog

cat

rabbit

for V1.


Unknown/unsupported species:

UNSUPPORTED_CUSTOM_SPECIES.


Do not force snake/bird/fish
into dog/cat/rabbit motion topology.

==================================================
P32 provider strategy
==================================================

Provider implementation may use
an image model capable of pet subject consistency.

Keep provider adapter independent from game/runtime.

Do not leak provider-specific IDs
into Flutter domain.

==================================================
P32 output
==================================================

GeneratedPetIdentity:

customPetId

species

displayName

master assets

styleVersion

generationVersion

status.

==================================================
==================================================
P33 — MOTION TEMPLATE TRANSFER
==================================================
==================================================

GOAL:

Existing built-in actions become motion templates.

User pet identity becomes appearance reference.

Do NOT paste a photo over existing frames.

==================================================
P33 concept
==================================================

Built-in action:

MOTION TEMPLATE


User uploaded pet:

IDENTITY TEMPLATE


Generation:

IDENTITY
+
MOTION SPEC
→
NEW CUSTOM PET ACTION.

==================================================
P33 motion source
==================================================

Reuse species-matched motion semantics:

cat → cat template

dog → dog template

rabbit → rabbit template.


No dog walk for rabbit unless
explicitly proven acceptable.

==================================================
P33 preferred generation
==================================================

Continuous actions should preferably use:

short generated video
→ sprite extraction.


Examples:

idle

walk

focus_read

focus_write

focus_think

craft_work

sleep

celebrate

tap_react

pet_react.


Transitions may use:

start frame
+
end frame
+
video generation.

Examples:

stand_up

sit_down.

==================================================
P33 walk rule
==================================================

Generated video must be:

WALK IN PLACE.


No world-space translation.

No camera movement.

No zoom.

No pan.


Flutter LocomotionController owns world movement.

==================================================
P33 transition rule
==================================================

stand_up:

sitting master
→ standing master.


sit_down:

standing master
→ sitting master.


Do not automatically derive sit_down
by reversing stand_up
when independent generation is available.

==================================================
==================================================
P34 — VIDEO TO SPRITE COMPILER
==================================================
==================================================

GOAL:

Turn generated clips into production-compatible
CozyFocus sprite packs.

==================================================
P34 reuse
==================================================

Audit and extend existing:

tools/video_to_sprite.py

productionise.py

manifest.py

PNG probe

asset QA.


Do NOT create a duplicate compiler.

==================================================
P34 pipeline
==================================================

input video

→ ffprobe validation

→ ffmpeg decode

→ candidate sampling

→ blur rejection

→ duplicate rejection

→ segmentation/background removal

→ alpha cleanup

→ bbox

→ scale normalization

→ center alignment

→ baseline alignment

→ target keyframe selection

→ PNG optimization

→ manifest generation

→ QA report.

==================================================
P34 frame target
==================================================

Output semantic sprite frames,
not every video frame.

Examples:

idle:
6

walk:
6

stand_up:
4

sit_down:
4

focus_read:
3+

focus_write:
4+

etc.


Follow current production action contract.

==================================================
P34 automated QA
==================================================

Per frame:

decode valid

alpha valid

canvas valid

baseline valid

center valid

sharpness valid

not duplicate.


Per action:

frame count

motion difference

loop seam if loop

transition ordering if once

identity consistency signal.

==================================================
P34 machine identity limit
==================================================

Automated similarity may detect obvious drift.

It may NOT claim:

"this definitely looks like the user's pet".


Final identity approval belongs to user.

==================================================
==================================================
P35 — GENERATED COMPANION RUNTIME
==================================================
==================================================

GOAL:

Custom pets plug into current runtime
without new page-level species logic.

==================================================
P35 rule
==================================================

Do NOT create:

User123VisualProvider
User456VisualProvider.


Create/reuse generic:

GeneratedCompanionVisualProvider


Input:

GeneratedCompanionProfile

downloaded manifest

local asset directory.

==================================================
P35 runtime
==================================================

Built-in:

dog
cat
rabbit

Generated:

custom/<packId>


All flow through shared:

CompanionVisualRegistry

BehaviorDirector

AnimationController

SpritePlayer

Locomotion

Room

Growth

Emotion

Memory

Daily Routine.

==================================================
P35 local cache
==================================================

Download:

manifest

sprite assets

checksums.


Verify before activating.

If corrupt:

do not select pack.

Fallback to previous valid companion.

==================================================
P35 offline
==================================================

After pack is downloaded:

Home

Focus

Room

animation

must work offline.

AI generation is not required during gameplay.

==================================================
P35 selection
==================================================

selected custom pet must survive restart.

Deleting it must safely switch
to valid fallback companion.

==================================================
==================================================
P36 — CUSTOM PET USER FLOW
==================================================
==================================================

GOAL:

Make generation easy and inexpensive.

==================================================
P36 UX
==================================================

Growth / Companion page:

+ 添加我的宠物

→ upload photos

→ pet name

→ validation

→ identity generation

→ preview actions

→ user approval

→ full pack generation

→ READY

→ use companion.

==================================================
P36 preview-first
==================================================

DO NOT generate all actions immediately.

First generate:

idle

walk

sit.


Show:

“这是你的宠物吗？”


Choices:

确认并继续

重新生成

重新上传照片.

==================================================
P36 after approval
==================================================

Generate remaining action pack.

Show status:

3 / 13

7 / 13

13 / 13.


User may keep using built-in pet
while generation runs.

==================================================
P36 generation states
==================================================

Recommended:

UPLOADED

VALIDATING

IDENTITY_GENERATING

PREVIEW_GENERATING

PREVIEW_READY

USER_APPROVED

FULL_PACK_GENERATING

QA

READY

FAILED_INPUT

FAILED_IDENTITY

FAILED_ACTION

FAILED_RETRYABLE

DELETED.

==================================================
==================================================
P37 — BACKEND / PRIVACY / DELETE
==================================================
==================================================

GOAL:

Make custom-pet feature operable and safe.

==================================================
P37 recommended architecture
==================================================

Flutter App

↓ authenticated upload

Backend API

↓

Object Storage

↓

Generation Queue

↓

Worker

├ Identity Provider
├ Motion Provider
├ FFmpeg
├ Sprite Compiler
└ QA

↓

Object Storage

↓

metadata DB

↓

Flutter downloads validated pack.


Implementation may use:

Cloud Run

Cloud Storage

Firestore / another real metadata DB

Cloud Tasks / PubSub

or equivalent.


Keep vendor details behind adapters.

==================================================
P37 job design
==================================================

Do not hold one mobile HTTP request
open for long generation.

Use asynchronous jobs.

Flutter asks:

GET generation status

or receives event/poll result.

==================================================
P37 data model
==================================================

Prefer concepts equivalent to:

CustomPet

SourceUpload

PetIdentity

GenerationJob

ActionGenerationJob

GeneratedPack

PackVersion.


Do not duplicate business game state.

==================================================
P37 API shape
==================================================

Conceptual endpoints:

POST /custom-pets

POST /custom-pets/{id}/uploads

POST /custom-pets/{id}/preview

POST /custom-pets/{id}/approve

POST /custom-pets/{id}/generate

GET /custom-pets/{id}

GET /generation-jobs/{id}

GET /custom-pets/{id}/packs/latest

DELETE /custom-pets/{id}


Exact API may differ.

==================================================
P37 privacy
==================================================

Original upload:

retain only as long as product requires.

Intermediate generated video:

delete after sprite QA unless needed for regeneration.

Master identity assets:

retain if user keeps custom pet
and regeneration depends on them.

Sprite pack:

retain while custom pet exists.


User delete must remove:

source uploads

identity assets

intermediate generation assets

sprite packs

metadata

client cache.

==================================================
P37 photo guidance
==================================================

Tell user:

upload photos you have the right to use.

Prefer pet-only photo.

Avoid unrelated people in frame.


Do not retain unnecessary EXIF.

==================================================
P37 deletion proof
==================================================

DELETE

→ backend metadata gone

→ storage objects gone

→ client cache gone

→ selected companion falls back safely.

==================================================
==================================================
P38 — COST / QUEUE / RETRY / OPERATIONS
==================================================
==================================================

GOAL:

Avoid unlimited generation cost.

==================================================
P38 preview cost control
==================================================

First stage:

only 3 actions.

No full pack until user confirms identity.

==================================================
P38 retry
==================================================

Per action:

max approximately 2–3 automatic attempts.

After limit:

FAILED_ACTION.


Do not loop forever.

==================================================
P38 lazy generation
==================================================

Optional production strategy:

Priority pack:

idle
walk
sit
focus_write
sleep
celebrate


Then fill remaining actions in background.


Do not activate incomplete pack as FULL_READY
unless runtime capability-gating supports it honestly.

==================================================
P38 dedupe
==================================================

Same generation request should use
an idempotency key.

Network retry must not start
two expensive jobs.

==================================================
P38 quotas
==================================================

Track:

generation count per user

failed attempts

provider cost

queue time

action retry count.


Never hardcode unlimited retries.

==================================================
P38 monitoring
==================================================

Need operational signals:

job latency

provider failures

asset QA rejection rate

pack completion rate

user preview rejection rate

storage usage.

==================================================
==================================================
P39 — FULL PRODUCT HARDENING
==================================================
==================================================

GOAL:

Prove both built-in pets and custom pets
work through the entire product.

==================================================
P39.1 Golden Business Flow
==================================================

Fresh user

→ choose companion

→ start Focus

→ Pause

→ Resume

→ Complete

→ exactly-one settlement

→ FocusRecord

→ reward

→ Growth

→ Craft

→ Inventory

→ Collection

→ Room placement

→ anchor

→ walk

→ furniture action

→ Emotion

→ Memory

→ restart

→ Daily Routine

→ next Focus.


Any required link fails:

GOLDEN_FLOW = FAIL.

==================================================
P39.2 Custom Pet Golden Flow
==================================================

Real pet photos

→ upload

→ validation

→ identity

→ preview

→ user approve

→ full generation

→ QA

→ download

→ activate

→ Home

→ Focus

→ Pause

→ Complete

→ Room

→ Walk

→ Furniture Action

→ restart

→ custom pet still selected

→ offline

→ still works.


Any required link fails:

CUSTOM_PET_GOLDEN_FLOW = FAIL.

==================================================
P39.3 Persistence
==================================================

Test process death/restart during:

Focus

Pause

finishing

Craft

Room movement

custom-pet download

generation-status polling.


No duplicate settlement.

No duplicate generation job.

==================================================
P39.4 Built-in parity
==================================================

Dog

Cat

Rabbit

must still use shared architecture.

Page species branches target:

0.

Generic renderer species branches target:

0.

==================================================
P39.5 Custom pack parity
==================================================

Generated pack must expose same semantic contract
or explicit capability subset.

No fake fallback counted as complete.

==================================================
P39.6 Performance
==================================================

Measure:

CPU

memory

image decode

sprite cache

timer/ticker count

background/foreground

APK/AAB size

downloaded custom pack size.


Do not preload every action.

==================================================
P39.7 Reduced Motion
==================================================

Built-in and custom pets
must remain semantically understandable.

==================================================
P39.8 Accessibility
==================================================

Custom pet name

furniture

actions

must remain accessible.

Do not expose sprite frames individually.

==================================================
==================================================
P40 — FINAL RELEASE CANDIDATE
==================================================
==================================================

FEATURE FREEZE.

Only reproduced:

P0

P1

release-blocking P2

may change.

==================================================
P40.1 unresolved product decisions
==================================================

Classify each:

APPROVED

DEFERRED

PRODUCT_DECISION_REQUIRED

BLOCKED_EXTERNAL.


Likely items:

material economy

coin sink

collection naming

long-session threshold

AI Personality

launcher icon

release signing

visual owner review.

==================================================
P40.2 Launcher icon
==================================================

Stock Flutter icon is a release blocker.

Require approved CozyFocus icon.

==================================================
P40.3 Signing
==================================================

Do NOT generate a fake production keystore.

If unavailable:

RELEASE_SIGNING =
NOT_RECOVERED.


That means:

STORE_READY = NO.

==================================================
P40.4 Build
==================================================

Fresh:

dart format --output=none --set-exit-if-changed lib test

flutter analyze --fatal-infos --no-pub

flutter test --no-pub

integration tests

flutter build apk --debug

flutter build apk --release

flutter build appbundle --release

git diff --check.

==================================================
P40.5 Inspect artifact
==================================================

Verify built APK/AAB:

applicationId

versionName

versionCode

app label

launcher icon

SDK

permissions

debuggable flag

signing certificate

asset inclusion.

==================================================
P40.6 Claude final review
==================================================

Review release candidate diff.

Require:

P0 = 0

P1 = 0.


Document P2.

==================================================
P40.7 GPT-6 Sol final gate
==================================================

Run exactly once unless blocker repair requires rerun.

Provide:

architecture audit

business Golden Flow

custom pet Golden Flow

migration evidence

runtime evidence

performance evidence

privacy/delete evidence

backend reliability

asset QA

Claude findings

exact commit SHA

CI evidence

unresolved external blockers.


Ask only:

BLOCKER

NON_BLOCKER

DEFERRED_PRODUCT_DECISION.

Do not redesign the app.

==================================================
P40.8 Git
==================================================

Require:

LOCAL_HEAD == REMOTE_HEAD

on:

recovery/v4.2.1-rebuild.


Create/reuse PR:

recovery/v4.2.1-rebuild

→

release/android-v1.


Do NOT auto merge.

Do NOT push main.

Do NOT publish store.

==================================================
==================================================
AUTOMATED PRODUCT GATE
==================================================
==================================================

Create/reuse one orchestration tool:

tools/cozy_gate.py --full


It must orchestrate existing tests/checks.

Do not reimplement all tests inside the script.


Output:

outputs/ai_handoff/AUTOMATED_PRODUCT_GATE.json

and:

outputs/ai_handoff/AUTOMATED_PRODUCT_GATE.md

==================================================
AUTOMATED GATE SECTIONS
==================================================

ARCHITECTURE

BEHAVIOR_AUTHORITY

BUSINESS_ISOLATION

ACTION_TRUTH

ACQUISITION_UX

USER_GOLDEN_FLOW

FOCUS_IDEMPOTENCY

REWARD_IDEMPOTENCY

CRAFT

COLLECTION

ROOM

GROWTH

EMOTION

MEMORY

DAILY_ROUTINE

DOG

CAT

RABBIT

CUSTOM_PET_BACKEND

CUSTOM_PET_IDENTITY

CUSTOM_PET_PACK

CUSTOM_PET_GOLDEN_FLOW

PERSISTENCE

MIGRATION

LIFECYCLE

PERFORMANCE

ASSET_INTEGRITY

VISUAL_TECHNICAL

OWNER_VISUAL

PRIVACY_DELETE

BACKEND_RETRY

COST_GUARD

RELEASE_BUILD

SIGNING

LAUNCHER_ICON.

==================================================
GATE STATUS
==================================================

Each entry only:

PASS

FAIL

BLOCKED

DEFERRED

NOT_TESTED

VISUAL_REVIEW_REQUIRED

PRODUCT_DECISION_REQUIRED.

==================================================
MASTER BUSINESS FLOW
==================================================

Fresh User
↓
Select Companion
↓
Focus Setup
↓
Start Focus
↓
Companion Focus Behavior
↓
Pause
↓
Rest Behavior
↓
Resume
↓
Complete
↓
Save
↓
Exactly-One Settlement
↓
FocusRecord
↓
Reward
↓
Growth
↓
Craft
↓
Inventory
↓
Collection
↓
Room Placement
↓
Furniture Anchor
↓
Walk
↓
Furniture Action
↓
Emotion
↓
Memory
↓
Restart
↓
Persistence
↓
Daily Routine
↓
Next Focus.


Required step broken:

GOLDEN_FLOW = FAIL.

==================================================
CUSTOM PET BUSINESS FLOW
==================================================

Upload Photos
↓
Validate
↓
Species
↓
Identity Master
↓
3-Action Preview
↓
User Approval
↓
Full Action Generation
↓
Video-to-Sprite
↓
Automated QA
↓
Pack
↓
Download
↓
Checksum
↓
Activate
↓
Home
↓
Focus
↓
Room
↓
Walk
↓
Furniture Action
↓
Restart
↓
Offline
↓
Still Works.


Required step broken:

CUSTOM_PET_GOLDEN_FLOW = FAIL.

==================================================
CUSTOM PET AUTOMATIC QA
==================================================

INPUT:

photo validity

species supported

identity generation completed.


ASSET:

manifest valid

all paths valid

checksum valid

PNG valid

alpha valid

canvas valid

baseline

center

frame count.


MOTION:

not duplicate

sharpness

walk gait

no internal world translation

loop seam

transition ordering.


RUNTIME:

provider registration

SpritePlayer

Locomotion

Room

Focus

fallback.


USER:

identity preview approved.


Automatic metrics cannot replace user identity approval.

==================================================
CUSTOM PET FAILURE POLICY
==================================================

Bad input:

FAILED_INPUT.


Cannot preserve identity:

FAILED_IDENTITY.


Individual action fails after retry limit:

FAILED_ACTION.


Provider temporary error:

FAILED_RETRYABLE.


Do not silently ship broken asset.

Do not fall back to built-in pet
while claiming generated action succeeded.

==================================================
BACKEND PROVIDER ABSTRACTION
==================================================

Do not couple the product permanently to:

Google Flow web UI

one specific image model

one specific video model.


Use:

PetIdentityProvider

PetMotionProvider.


Provider can be replaced
without changing Flutter runtime contract.

==================================================
RUNTIME CONTRACT
==================================================

Backend's final responsibility is NOT
to provide a video player.

It must ultimately provide:

Companion-compatible Sprite Pack.


Example structure:

custom_pet_<id>/
  manifest.json
  idle_000.png
  ...
  walk_000.png
  ...
  focus_read_000.png
  ...

Flutter remains a Sprite runtime.

==================================================
SECURITY
==================================================

Do not expose provider API keys to Flutter.

Keys remain server side.

Uploads must use authenticated/signed mechanisms.

Validate actual MIME bytes.

Use bounded upload size.

Strip unnecessary metadata.

Do not log raw pet images.

Do not expose private storage URLs indefinitely.

==================================================
GIT POLICY
==================================================

Never:

git reset --hard

git clean unknown work

force push

push main

push release directly

git add .

git add -A.


Every coherent slice:

focused tests
full gates
explicit stage
commit
push recovery
verify remote.

==================================================
HANDOFF FILES
==================================================

Each phase creates:

outputs/ai_handoff/P28_ACTION_TRUTH.md

P29_ACQUISITION_UX.md

P30_USER_GOLDEN_FLOW.md

P31_CUSTOM_PET_SPIKE.md

P32_CUSTOM_PET_IDENTITY.md

P33_CUSTOM_PET_MOTION.md

P34_CUSTOM_PET_SPRITE_COMPILER.md

P35_CUSTOM_PET_RUNTIME.md

P36_CUSTOM_PET_UX.md

P37_CUSTOM_PET_BACKEND_PRIVACY.md

P38_CUSTOM_PET_OPERATIONS.md

P39_FULL_HARDENING.md

P40_RELEASE_CANDIDATE.md

==================================================
PHASE START TEMPLATE
==================================================

Before every phase output:

PROJECT:
COZY_FOCUS

PHASE:
Px

START_SHA:

REMOTE_SHA:

WORKTREE:

CURRENT_STATE:

CONFIRMED_GAPS:

SOURCE_OF_TRUTH:

FILES_EXPECTED_TO_CHANGE:

PROTECTED_FILES:

TEST_PLAN:

NEGATIVE_TEST_PLAN:

RUNTIME_PLAN:

NON_GOALS:

PRODUCT_DECISIONS_REQUIRED:


Then architecture-reviewer runs.

Do not implement before the audit.

==================================================
PHASE END TEMPLATE
==================================================

PROJECT:
COZY_FOCUS

PHASE:
Px

START_SHA:
<sha>

END_SHA:
<sha>

REMOTE_SHA:
<sha>

LOCAL_EQUALS_REMOTE:
YES / NO

ARCHITECTURE:
PASS / FAIL

IMPLEMENTATION:
PASS / PARTIAL / BLOCKED

DUPLICATE_TRUTH:
NO / YES

BUSINESS_ISOLATION:
PASS / FAIL

FOCUSED_TESTS:
x/x

FULL_TESTS:
x/x

INTEGRATION_TESTS:
x/x

FORMAT:
PASS / FAIL

ANALYZE:
PASS / FAIL

DEBUG_APK:
PASS / FAIL / NOT_REQUIRED

RELEASE_APK:
PASS / FAIL / NOT_REQUIRED

DEVICE_RUNTIME:
PASS / PARTIAL / NOT_RUN

NEGATIVE_PROOF:
PASS / FAIL / NOT_APPLICABLE

CLAUDE_P0:
<count>

CLAUDE_P1:
<count>

CLAUDE_P2:
<count>

KNOWN_ASSET_GAPS:
<list>

PRODUCT_DECISIONS_REQUIRED:
<list>

BLOCKERS:
<list>

PHASE_GATE:
PASS / PARTIAL / BLOCKED

NEXT_PHASE:
Px

Then STOP.

==================================================
FINAL PROGRAM REPORT
==================================================

PROJECT:
COZY_FOCUS

P28_ACTION_TRUTH:
PASS / FAIL

P29_ACQUISITION:
PASS / FAIL

P30_USER_GOLDEN_FLOW:
PASS / FAIL

P31_CUSTOM_PET_SPIKE:
PASS / FAIL

P32_IDENTITY_PIPELINE:
PASS / FAIL

P33_MOTION_TRANSFER:
PASS / FAIL

P34_SPRITE_COMPILER:
PASS / FAIL

P35_CUSTOM_RUNTIME:
PASS / FAIL

P36_CUSTOM_PET_UX:
PASS / FAIL

P37_PRIVACY_BACKEND:
PASS / FAIL

P38_OPERATIONS:
PASS / FAIL

P39_HARDENING:
PASS / FAIL

P40_RELEASE_GATE:
PASS / BLOCKED

GOLDEN_FLOW:
PASS / FAIL

CUSTOM_PET_GOLDEN_FLOW:
PASS / FAIL

DOG:
PASS / FAIL

CAT:
PASS / FAIL

RABBIT:
PASS / FAIL

CUSTOM_PET:
PASS / FAIL / NOT_ENABLED

BEHAVIOR_AUTHORITIES:
<count>

ROOM_SOURCES_OF_TRUTH:
<count>

INVENTORY_SOURCES_OF_TRUTH:
<count>

FAKE_ACTIONS:
<count>

FAKE_CTAS:
<count>

BUSINESS_ISOLATION:
PASS / FAIL

PERSISTENCE:
PASS / FAIL

MIGRATION:
PASS / FAIL

REDUCED_MOTION:
PASS / FAIL

ACCESSIBILITY:
PASS / FAIL

LIFECYCLE:
PASS / FAIL

PERFORMANCE:
PASS / FAIL

PRIVACY_DELETE:
PASS / FAIL

BACKEND_RETRY:
PASS / FAIL

CUSTOM_PET_COST_GUARD:
PASS / FAIL

FORMAT:
PASS / FAIL

ANALYZE:
PASS / FAIL

UNIT_TESTS:
x/x

INTEGRATION_TESTS:
x/x

DEBUG_APK:
PASS / FAIL

RELEASE_APK:
PASS / FAIL

AAB:
PASS / FAIL

OWNER_VISUAL_GATE:
PASS / REQUIRED

CUSTOM_PET_IDENTITY_OWNER_GATE:
PASS / REQUIRED

LAUNCHER_ICON:
PASS / BLOCKED

RELEASE_SIGNING:
AVAILABLE / NOT_RECOVERED

CLAUDE_P0:
<count>

CLAUDE_P1:
<count>

GPT6_FINAL_GATE:
PASS / BLOCKED / NOT_RUN

LOCAL_HEAD:
<sha>

REMOTE_HEAD:
<sha>

LOCAL_EQUALS_REMOTE:
YES / NO

PR:
<number / NOT_CREATED>

EXACT_SHA_CI:
PASS / FAIL / NOT_TRIGGERED

READY_FOR_OWNER_MERGE_DECISION:
YES / NO

READY_FOR_STORE:
YES / NO

MERGED_TO_RELEASE:
NO

PUSHED_TO_MAIN:
NO

STORE_SUBMITTED:
NO

Then STOP.```
