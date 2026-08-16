# 75 Adaptive — iOS app

A native SwiftUI app for the 75 Hard / Medium / Soft challenge that adapts the
rules to the person doing them, with age and mobility as the primary inputs
rather than an afterthought.

> **Not medical advice.** The app adapts a fitness challenge; it does not know
> anyone's medical history. It says so on the first screen, prompts a clinician
> conversation whenever the profile warrants one, and generates a one-page plan
> summary designed to be taken to an appointment.

## Running it

Requires **Xcode 16** or later (the project uses file-system-synchronised
groups, `objectVersion = 77`) and targets **iOS 17**.

```bash
open ios/SeventyFive.xcodeproj
# ⌘R to run, ⌘U to test
```

There are no dependencies, no package resolution step, and no server. Everything
is on-device.

## What it does

### The interview

Ten steps of onboarding, and every question exists because the answer changes the
plan. Each one shows a **"Why we ask"** disclosure — people answer honestly about
pain and falls when they can see what the answer is for.

| Question | What it changes |
|---|---|
| Birth year | Workout duration floor, fluid ml/kg, whether balance work is added, protein emphasis |
| Weight | Water target (per-kg, not a flat gallon) |
| Mobility level | Exercise modality — seated circuits replace walks, floor work is removed |
| Joint pain | Duration multiplier, impact allowed or not |
| Balance confidence + falls in the last year | Balance training, and whether the outdoor rule moves to level ground |
| How long you can stay on your feet | Whether sessions split into chunks (3 × 15 min counts the same as 45) |
| Health considerations | Intensity caps, impact restrictions, and a hard cap on fluids for kidney/heart/fluid-restricted users |
| Equipment + outdoor access | Which exercise options are offered; how the outdoor requirement is honoured |
| Minutes available per day | Hard ceiling on what the plan may ask for |
| Diet + reading format | Recipe filtering; pages convert to minutes for audiobook users |
| Why you're doing this + three rewards | Replayed on hard days; seeds the reward economy |

The last screen recommends a tier, explains its reasoning, and previews the exact
generated rules — with every adaptation and its justification — before anything
is written to disk.

### Daily tracking

- **Morning check-in** — sleep, pain (0–10), energy, soreness. Produces a scale
  factor between the age-appropriate floor and 100%, and the user *sees the
  before/after targets* immediately. A scaled day counts as a completed day; that
  is the mechanism that replaces "push through or reset".
- Task cards with 52pt completion targets and 44pt steppers, partial logging,
  split-session support, per-task adaptation notes, and safety flags.
- Progress photos stored with `.externalStorage`, never uploaded.
- Missed days route to a tier-appropriate resolution sheet: restart (Hard), grace
  day (Medium), or streak break (Soft) — each stating its consequence plainly.

### Meals

- 24 bundled recipes, offline from launch, each tagged with **`standingMinutes`** —
  the honest answer to "how long will I be on my feet?" — plus seated-prep,
  one-handed, soft-texture, low-knife-skill and batch flags.
- **Web import** with no API key: parses the schema.org `Recipe` JSON-LD that
  virtually every recipe site publishes for Google's recipe cards, including
  `@graph` nesting, `HowToSection`, ISO 8601 durations and free-text nutrition.
  Ingredient lines are parsed into structured quantities so imports feed the
  shopping list like the built-ins.
- Automatic week generation that favours batch recipes so a week costs two
  cooking sessions, not twenty-one.
- Shopping list merged across recipes, scaled by planned servings, sorted in
  supermarket walking order, with persistent check-offs.
- **Batch prep session** — longest cook first, all chopping grouped into one
  seated block, and sit-down breaks automatically inserted for anyone whose
  standing tolerance is short.

### Rewards & gamification

Grit Coins (10/day, +15 weekly, +2 for finishing a scaled day), XP with a capped
streak multiplier, ten levels, 22 badges, freeze tokens, milestone unlocks and a
user-authored reward shop. Coins are earned only on *complete* days, so the shop
can't be farmed by half-finishing.

Badges deliberately reward the behaviour that predicts finishing — "Five Hard
Mornings" (five heavily scaled days finished rather than skipped) is worth three
times "Well Watered".

## Layout

```
SeventyFive/
  App/          SeventyFiveApp, RootView, ChallengeStore (the only mutator)
  Models/       SwiftData models + TaskRule/RuleSet value types
  Engine/       TierEngine, HydrationCalculator, MobilityAdaptation,
                DayScaler, ProgressEngine, MealPlanner, RecipeImporter
  Data/         Recipe library, achievement and reward catalogues
  Views/        Onboarding, Today, Meals, Rewards, Progress, Settings, Shared
  Support/      Design system, notifications, haptics
SeventyFiveTests/
  EngineTests.swift   ~40 swift-testing cases over the pure engine layer
```

The engine layer is pure Foundation with no SwiftData or SwiftUI dependency,
which is why it is directly testable — the tests assert the things that matter
for safety: nobody is asked for more than 4 L of water, fluid-restricted users
are capped and told to ask a clinician, plans never exceed the stated time
budget, scaling never drops below the age floor, and seated users are only ever
offered seated exercises.

## Design decisions worth knowing

**A gallon is not a universal target.** The classic rule is 3785 ml regardless of
body size, age or kidney function. For a 55 kg eighty-year-old on a diuretic that
is a hyponatraemia risk, so the target is built per-kg, adjusted by age band and
tier, and hard-capped at 1500 ml for anyone reporting kidney disease, heart
failure or a fluid restriction — with the caveat that the real number must come
from their clinician.

**Adaptation changes the shape of a task, never removes it.** A wheelchair user
still does a workout every day; it becomes a seated circuit. Someone who can't
get outside safely still has a second session; the outdoor requirement becomes a
doorstep or fresh-air one. The challenge stays intact.

**Balance training is added, not inherited.** The original challenge contains
nothing that trains balance, and falls — not cardio capacity — are what end
independence. It becomes a required daily rule for anyone 55+, with a fall
history, or with osteoporosis.

**Data stays on the device.** No account, no server, no analytics, no photo
upload. Deleting the app deletes everything.

## Not affiliated

75 Hard is a challenge created by Andy Frisella. This app is an independent
implementation and is not affiliated with or endorsed by it. Medium and Soft are
community variants.
