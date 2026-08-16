# 75 Adaptive — web app

A 75 Hard / Medium / Soft tracker that adapts the daily rules to the person
doing them, with age and mobility as the primary inputs rather than an
afterthought.

Standalone Vite + React app. It shares this repo's Express + SQLite backend and
its login, so one account covers both this and the project dashboard.

> **Not medical advice.** The app adapts a fitness challenge; it doesn't know
> anyone's medical history. It says so on the first screen, prompts a clinician
> conversation whenever the profile warrants one, and generates a one-page plan
> summary designed to be taken to an appointment.

## Running it

```bash
# terminal 1
cd backend && npm install && npm run dev     # http://localhost:5000

# terminal 2
cd web && npm install && npm run dev         # http://localhost:5174
```

Create an account on first load (or sign in with your existing dashboard
account — it's the same user table).

```bash
cd web     && npm test    # 49 engine tests
cd backend && npm test    # 15 recipe-importer tests
```

For production, set `VITE_API_BASE_URL` to wherever the backend is deployed and
`npm run build`; serve `web/dist` as static files.

## What it does

### The interview

Ten steps of onboarding, and every question exists because the answer changes
the plan. Each shows a **"Why we ask"** disclosure — people answer honestly
about pain and falls when they can see what the answer is for.

| Question | What it changes |
|---|---|
| Birth year | Workout duration floor, fluid ml/kg, whether balance work is added, protein emphasis, deload floor |
| Weight | Water target (per-kg, not a flat gallon) |
| Mobility level | Exercise modality — seated circuits replace walks, floor work is removed |
| Joint pain | Duration multiplier, whether impact is allowed |
| Balance confidence + falls in the last year | Balance training, and whether the outdoor rule moves to level ground |
| How long you can stay on your feet | Whether sessions split into chunks, and which recipes you're shown |
| Health considerations | Intensity caps, impact restrictions, and a hard cap on fluids for kidney/heart/fluid-restricted users |
| Equipment + outdoor access | Which exercise options appear; how the outdoor requirement is honoured |
| Minutes available per day | Hard ceiling on what the plan may ask for |
| Diet + reading format | Recipe filtering; pages convert to minutes for audiobook users |
| Why you're doing this + three rewards | Replayed on hard days; seeds the reward economy |

The last step recommends a tier, explains its reasoning, and previews the exact
generated rules — with every adaptation and its justification — before anything
is saved.

### Daily tracking

- **Morning check-in** — sleep, pain (0–10), energy, soreness. Produces a scale
  factor between the age-appropriate floor and 100%, and shows the before/after
  targets immediately. A scaled day counts as a completed day; that's what
  replaces "push through or reset".
- Task cards with 52px completion targets and 44px steppers, partial logging,
  split-session support, per-task adaptation notes and safety flags.
- Progress photos downscaled to 1200px before upload, stored per-account, and
  excluded from the boot payload so it stays small.
- Missed days route to a tier-appropriate resolution: restart (Hard), grace day
  (Medium), or streak break (Soft) — each stating its consequence plainly.

### Meals

- 24 bundled recipes, each tagged with **`standingMinutes`** — the honest answer
  to "how long will I be on my feet?" — plus seated-prep, one-handed,
  soft-texture, low-knife-skill and batch flags.
- **Web import** with no API key: the server fetches the page and parses the
  schema.org `Recipe` JSON-LD that virtually every recipe site publishes for
  Google's recipe cards. This has to be server-side — a browser can't fetch
  cross-origin — which is one of the reasons the app has a backend.
- Automatic week generation favouring batch recipes, so a week costs two cooking
  sessions rather than twenty-one.
- Shopping list merged across recipes, scaled by planned servings, sorted in
  supermarket walking order, with check-offs that persist. Rebuilding replaces
  generated lines and leaves hand-added ones alone.
- **Batch prep session** — longest cook first, chopping grouped into one seated
  block, and sit-down breaks inserted automatically when accumulated standing
  time passes what the user said they can manage.

### Rewards & gamification

Grit Coins (10/day, +15 weekly, +2 for finishing a scaled day), XP with a capped
streak multiplier, ten levels, 22 badges, freeze tokens, milestone unlocks and a
user-authored reward shop. Coins are earned only on *complete* days, so the shop
can't be farmed by half-finishing.

Badges deliberately reward what predicts finishing: *Five Hard Mornings* — five
heavily scaled days finished rather than skipped — is worth three times *Well
Watered*.

## How it's put together

```
web/src/
  engine/     Pure logic, no React and no network:
              constants, hydration, mobility, tiers, dayScaler, progress, mealPlanner
  data/       Recipe library, achievement and reward catalogues
  components/ Onboarding, Today, Meals, Rewards, Progress, Settings, ui primitives
  ChallengeContext.jsx   The only place challenge state is mutated
  api.js      fetch wrapper + client-side image downscaling

backend/
  challengeSchema.js   Tables (all user-scoped), kept separate from db.js
  challengeRoutes.js   /api/challenge/*, behind the existing authMiddleware
  recipeImport.js      JSON-LD fetch + parse, with an SSRF guard
```

The engine layer has no React or network dependency, which is why it's directly
testable. The tests assert the things that matter for safety: nobody is asked
for more than 4 L of water, fluid-restricted users are capped and told to ask a
clinician, plans never exceed the stated time budget, scaling never drops below
the age floor, and seated users are only ever offered seated exercises.

### Where state lives

The adaptation engine runs in the browser, because onboarding has to show the
plan changing as you answer. The server stores the rule set it produces and the
progress against it, which makes the client authoritative for gameplay numbers —
the right trade for a personal tracker, where the only person who could cheat is
the person the streak belongs to. The server still enforces what matters: you
can only touch your own rows, and you can't spend coins you don't have.

The day endpoint is an idempotent upsert of the whole day rather than a patch,
so a dropped request costs nothing — the next tap resends full state.

Each entry stores the target it was judged against, so re-adapting the plan
mid-run can't retroactively fail a day someone already finished.

## Design decisions worth knowing

**A gallon is not a universal target.** The classic rule is 3785 ml regardless
of body size, age or kidney function. For a 55 kg eighty-year-old on a diuretic
that's a hyponatraemia risk, so the target is built per-kg, adjusted by age band
and tier, capped at 4 L for anyone, and capped at 1.5 L for anyone reporting
kidney disease, heart failure or a fluid restriction — with the caveat that the
real number must come from their clinician.

**Adaptation changes a task's shape, never removes it.** A wheelchair user still
works out daily; it becomes a seated circuit. Someone who can't get outside
safely still has a second session; the outdoor requirement becomes a doorstep
one. The challenge stays intact.

**Balance training is added, not inherited.** The original challenge trains
nothing that prevents falls, and falls — not cardio capacity — are what end
independence. It becomes a required daily rule for anyone 55+, with a fall
history, or with osteoporosis.

**`seatedPrep` and `standingMinutes` are different questions.** The first is
"can this be prepped at a table", the second is "how long are you on your feet
regardless". Mason jars are assembled sitting down but still need twelve minutes
at a hob. The prep-session break logic keys on the minutes, not the flag.

## Not affiliated

75 Hard is a challenge created by Andy Frisella. This app is an independent
implementation and is not affiliated with or endorsed by it. Medium and Soft are
community variants.
