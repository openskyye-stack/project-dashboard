import { useMemo, useState } from 'react';

import {
  emptyProfile, MOBILITY_LEVELS, PAIN_LEVELS, HEALTH_CONSIDERATIONS, EQUIPMENT,
  OUTDOOR_ACCESS, DIETARY, READING_FORMATS, TIERS, TIER_INFO, formatAmount, ageOf,
} from '../engine/constants.js';
import { buildRules, recommendTier } from '../engine/tiers.js';
import { REWARD_PROMPTS, REWARD_PROMPT_COSTS, REWARD_PROMPT_CATEGORIES } from '../data/rewards.js';
import { Card, Note, Option, Question, Stepper, Toggle, Bar } from './ui.jsx';

// The interview.
//
// This is the most important screen in the app. Every question exists because
// the answer changes the plan — nothing is asked for analytics, and nothing is
// asked twice. The order matters too: identity and body first, limits second,
// preferences third, motivation last, because people answer honestly about pain
// before they have been told what the app wants to hear.

const STEP_TITLES = [
  'Before we start', 'About you', 'Your body', 'Moving around', 'Pain & steadiness',
  'Health', "What you've got", 'Your day', 'Food & reading', 'Why', 'Your plan',
];

export default function Onboarding({ onStart }) {
  const [step, setStep] = useState(0);
  const [draft, setDraft] = useState(emptyProfile);
  const [rewardAnswers, setRewardAnswers] = useState(['', '', '']);
  const [chosenTier, setChosenTier] = useState(null);
  const [busy, setBusy] = useState(false);

  const set = (patch) => setDraft((current) => ({ ...current, ...patch }));

  const toggleIn = (key, id) =>
    set({
      [key]: draft[key].includes(id) ? draft[key].filter((v) => v !== id) : [...draft[key], id],
    });

  const canContinue = step !== 1 || draft.name.trim().length > 0;

  const submit = async (tier) => {
    setBusy(true);
    const rewards = rewardAnswers
      .map((answer, index) => ({ answer: answer.trim(), index }))
      .filter(({ answer }) => answer.length > 0)
      .map(({ answer, index }) => ({
        title: answer,
        detail: REWARD_PROMPTS[index],
        cost: REWARD_PROMPT_COSTS[index],
        category: REWARD_PROMPT_CATEGORIES[index],
        symbol: '🎁',
        isCustom: true,
      }));

    await onStart(tier, draft, rewards);
    setBusy(false);
  };

  return (
    <div className="app">
      <header className="topbar">
        <span className="topbar__title">{STEP_TITLES[step]}</span>
        <span className="tiny">
          Step {step + 1} of {STEP_TITLES.length}
        </span>
      </header>

      <div style={{ padding: '0 1rem' }}>
        <Bar value={(step + 1) / STEP_TITLES.length} />
      </div>

      <main className="app__body">
        {step === 0 && <Welcome />}
        {step === 1 && <Identity draft={draft} set={set} />}
        {step === 2 && <Body draft={draft} set={set} />}
        {step === 3 && <Mobility draft={draft} set={set} />}
        {step === 4 && <PainBalance draft={draft} set={set} />}
        {step === 5 && <Health draft={draft} set={set} toggleIn={toggleIn} />}
        {step === 6 && <Kit draft={draft} set={set} toggleIn={toggleIn} />}
        {step === 7 && <Schedule draft={draft} set={set} />}
        {step === 8 && <Preferences draft={draft} set={set} toggleIn={toggleIn} />}
        {step === 9 && (
          <Motivation draft={draft} set={set} rewardAnswers={rewardAnswers} setRewardAnswers={setRewardAnswers} />
        )}
        {step === 10 && (
          <Recommendation
            draft={draft}
            chosenTier={chosenTier}
            setChosenTier={setChosenTier}
            busy={busy}
            onStart={submit}
          />
        )}

        <div className="row" style={{ gap: '0.6rem', marginTop: '0.5rem' }}>
          {step > 0 && (
            <button type="button" className="btn" onClick={() => setStep((s) => s - 1)}>
              Back
            </button>
          )}
          {step < STEP_TITLES.length - 1 && (
            <button
              type="button"
              className="btn btn--primary"
              style={{ flex: 1 }}
              disabled={!canContinue}
              onClick={() => setStep((s) => s + 1)}
            >
              {step === 0 ? "Let's go" : 'Continue'}
            </button>
          )}
        </div>
      </main>
    </div>
  );
}

// --- steps ------------------------------------------------------------------

function Welcome() {
  return (
    <Card>
      <h1>Seventy-five days.</h1>
      <p>
        The original 75 Hard hands everyone the same rules: two 45-minute workouts, a gallon of water,
        no exceptions, restart if you slip. It works for some people and injures others.
      </p>
      <p>
        This app asks first. Your age, your joints, how long you can stay on your feet, what a bad
        morning actually feels like — then it builds the version of the challenge you can finish.
      </p>
      <Note variant="critical">
        This is a habit app, not medical advice. If you have a heart condition, take medication that
        affects fluid balance, or have had surgery recently, talk to your doctor before you start —
        and bring the plan this app generates with you.
      </Note>
      <ul className="muted" style={{ margin: 0, paddingLeft: '1.2rem' }}>
        <li>Ten questions. Under three minutes.</li>
        <li>You can change any answer later.</li>
        <li>Your progress photos stay in your own account and are never shown to anyone else.</li>
      </ul>
    </Card>
  );
}

function Identity({ draft, set }) {
  const years = useMemo(() => {
    const current = new Date().getFullYear();
    return Array.from({ length: 85 }, (_, i) => current - 16 - i);
  }, []);

  return (
    <Card>
      <Question question="What should we call you?" why="It shows up on your morning check-in. Nothing else.">
        <input
          className="input"
          value={draft.name}
          onChange={(e) => set({ name: e.target.value })}
          placeholder="Your name"
          autoComplete="given-name"
        />
      </Question>

      <Question
        question="What year were you born?"
        why="Age changes three things: how long each session should be, how much water is sensible, and whether balance training gets added. It is never used to tell you what you can't do."
      >
        <select className="select" value={draft.birthYear} onChange={(e) => set({ birthYear: Number(e.target.value) })}>
          {years.map((year) => (
            <option key={year} value={year}>
              {year}
            </option>
          ))}
        </select>
        <p className="tiny">That makes you {ageOf(draft)}.</p>
      </Question>
    </Card>
  );
}

function Body({ draft, set }) {
  return (
    <Card>
      <Toggle label="Use metric (kg / cm)" checked={draft.usesMetric} onChange={(v) => set({ usesMetric: v })} />

      <Question
        question="Roughly what do you weigh?"
        why="Your water target is calculated per kilogram of body weight. A fixed gallon is far too much for some people and not enough for others."
      >
        {draft.usesMetric ? (
          <Stepper
            label="weight"
            value={Math.round(draft.weightKg)}
            min={35}
            max={200}
            step={1}
            format={(v) => `${v} kg`}
            onChange={(v) => set({ weightKg: v })}
          />
        ) : (
          <Stepper
            label="weight"
            value={Math.round(draft.weightKg * 2.20462)}
            min={77}
            max={440}
            step={2}
            format={(v) => `${v} lb`}
            onChange={(v) => set({ weightKg: v / 2.20462 })}
          />
        )}
      </Question>

      <Question question="And your height?" why="Shown for context on your progress screen. It doesn't change any rule.">
        {draft.usesMetric ? (
          <Stepper
            label="height"
            value={Math.round(draft.heightCm)}
            min={120}
            max={220}
            step={1}
            format={(v) => `${v} cm`}
            onChange={(v) => set({ heightCm: v })}
          />
        ) : (
          <Stepper
            label="height"
            value={Math.round(draft.heightCm / 2.54)}
            min={47}
            max={87}
            step={1}
            format={(v) => `${Math.floor(v / 12)} ft ${v % 12} in`}
            onChange={(v) => set({ heightCm: v * 2.54 })}
          />
        )}
      </Question>
    </Card>
  );
}

function Mobility({ draft, set }) {
  return (
    <Card>
      <Question
        question="How would you describe getting around?"
        why="This decides the shape of every workout. Whatever you pick, you still do a workout every day — it just becomes the right kind."
      >
        {MOBILITY_LEVELS.map((level) => (
          <Option
            key={level.id}
            title={level.name}
            detail={level.detail}
            selected={draft.mobility === level.id}
            onClick={() =>
              set({
                mobility: level.id,
                // Someone who exercises seated has a realistic standing time of zero.
                continuousStandingMinutes: level.id === 'seated' ? 0 : draft.continuousStandingMinutes,
              })
            }
          />
        ))}
      </Question>
    </Card>
  );
}

function PainBalance({ draft, set }) {
  const balanceLabels = ['', 'Very unsteady', 'Unsteady', 'Reasonable', 'Good', 'Rock solid'];

  return (
    <Card>
      <Question
        question="On an average day, how much joint pain do you have?"
        why="Pain shortens sessions and rules out impact. Be honest here — the app can't adapt around something you hide from it."
      >
        {PAIN_LEVELS.map((level) => (
          <Option
            key={level.id}
            title={level.name}
            selected={draft.jointPain === level.id}
            onClick={() => set({ jointPain: level.id })}
          />
        ))}
      </Question>

      <Question
        question="How steady are you on your feet?"
        why="Falls end more challenges than motivation does. If you're unsteady, balance training gets added and the outdoor rule moves to level ground."
      >
        <input
          type="range"
          min={1}
          max={5}
          step={1}
          value={draft.balanceConfidence}
          onChange={(e) => set({ balanceConfidence: Number(e.target.value) })}
          aria-label={`Balance confidence: ${balanceLabels[draft.balanceConfidence]}`}
        />
        <p className="row row--between">
          <span className="tiny">Unsteady</span>
          <strong>{balanceLabels[draft.balanceConfidence]}</strong>
          <span className="tiny">Rock solid</span>
        </p>
      </Question>

      <Toggle
        label="I've fallen in the last year"
        detail="Including trips and near-misses you caught yourself from."
        checked={draft.hasFallenInLastYear}
        onChange={(v) => set({ hasFallenInLastYear: v })}
      />

      <Question
        question="How long can you keep going before you need to sit down?"
        why="If this is under your session length, the app splits the workout into chunks. Three ten-minute walks count exactly the same as one thirty-minute walk."
      >
        <Stepper
          label="standing tolerance"
          value={draft.continuousStandingMinutes}
          min={0}
          max={90}
          step={5}
          format={(v) => (v <= 0 ? 'I exercise seated' : `${v} minutes`)}
          onChange={(v) => set({ continuousStandingMinutes: v })}
        />
      </Question>
    </Card>
  );
}

function Health({ draft, set, toggleIn }) {
  return (
    <Card>
      <Question
        question="Does any of this apply to you?"
        why="These change real numbers: intensity caps, whether impact is allowed, and — for kidney or heart conditions — your water target, which can be dangerous if it's set by a slogan instead of a clinician."
      >
        {HEALTH_CONSIDERATIONS.map((item) => (
          <Option
            key={item.id}
            multi
            title={item.name}
            detail={draft.considerations.includes(item.id) ? item.note : undefined}
            selected={draft.considerations.includes(item.id)}
            onClick={() => toggleIn('considerations', item.id)}
          />
        ))}
      </Question>

      {draft.considerations.length > 0 && (
        <>
          <Note variant="critical">
            Take the plan the app builds to your next appointment. It's a page long and it's specific —
            that's a much better conversation than "I'm thinking of doing a fitness challenge".
          </Note>
          <Toggle
            label="A clinician has cleared me for exercise"
            checked={draft.clinicianCleared}
            onChange={(v) => set({ clinicianCleared: v })}
          />
        </>
      )}
    </Card>
  );
}

function Kit({ draft, set, toggleIn }) {
  return (
    <Card>
      <Question
        question="What have you got to work with?"
        why="Only exercises you can actually do get suggested. A sturdy chair is assumed — it's the most useful piece of equipment in the list."
      >
        {EQUIPMENT.map((item) => (
          <Option
            key={item.id}
            multi
            title={item.name}
            selected={draft.equipment.includes(item.id)}
            onClick={() => toggleIn('equipment', item.id)}
          />
        ))}
      </Question>

      <Question
        question="Can you get outside every day?"
        why="75 Hard demands an outdoor workout in any weather. If ice or transport makes that unsafe or impossible for you, the rule gets rewritten rather than quietly broken."
      >
        {OUTDOOR_ACCESS.map((item) => (
          <Option
            key={item.id}
            title={item.name}
            selected={draft.outdoorAccess === item.id}
            onClick={() => set({ outdoorAccess: item.id })}
          />
        ))}
      </Question>
    </Card>
  );
}

function Schedule({ draft, set }) {
  const hours = Array.from({ length: 24 }, (_, i) => i);
  const label = (hour) => new Date(2000, 0, 1, hour).toLocaleTimeString([], { hour: 'numeric' });

  return (
    <Card>
      <Question
        question="Realistically, how many minutes a day can you give this?"
        why="The plan is sized to this number. A plan you can finish beats a plan you admire."
      >
        <Stepper
          label="minutes per day"
          value={draft.availableMinutesPerDay}
          min={30}
          max={180}
          step={10}
          format={(v) => `${v} minutes`}
          onChange={(v) => set({ availableMinutesPerDay: v })}
        />
      </Question>

      <Question
        question="When does your day start and wind down?"
        why="Water reminders are spaced between these two, and stop two hours before wind-down so you're not up at 3am."
      >
        <label className="field">
          <span className="tiny">Up at</span>
          <select
            className="select"
            value={draft.preferredStartHour}
            onChange={(e) => set({ preferredStartHour: Number(e.target.value) })}
          >
            {hours.map((h) => (
              <option key={h} value={h}>{label(h)}</option>
            ))}
          </select>
        </label>
        <label className="field">
          <span className="tiny">Winding down at</span>
          <select
            className="select"
            value={draft.preferredWindDownHour}
            onChange={(e) => set({ preferredWindDownHour: Number(e.target.value) })}
          >
            {hours.map((h) => (
              <option key={h} value={h}>{label(h)}</option>
            ))}
          </select>
        </label>
      </Question>
    </Card>
  );
}

function Preferences({ draft, set, toggleIn }) {
  return (
    <Card>
      <Question
        question="Anything we should know about food?"
        why="Recipes are filtered to what you'll actually eat. 'Easy to chew' is in the list because dental work and dry mouth are common and rarely asked about."
      >
        {DIETARY.map((item) => (
          <Option
            key={item.id}
            multi
            title={item.name}
            selected={draft.dietary.includes(item.id)}
            onClick={() => toggleIn('dietary', item.id)}
          />
        ))}
      </Question>

      <Question
        question="How do you prefer to read?"
        why="Ten pages becomes fifteen minutes if you're listening. Same habit, honest conversion — audiobooks aren't cheating."
      >
        {READING_FORMATS.map((item) => (
          <Option
            key={item.id}
            title={item.name}
            selected={draft.readingFormat === item.id}
            onClick={() => set({ readingFormat: item.id })}
          />
        ))}
      </Question>

      <Question question="Anything to make the app easier to use?">
        <Toggle label="Larger text everywhere" checked={draft.wantsLargeText} onChange={(v) => set({ wantsLargeText: v })} />
        <Toggle label="Reduce animation" checked={draft.wantsReducedMotion} onChange={(v) => set({ wantsReducedMotion: v })} />
      </Question>
    </Card>
  );
}

function Motivation({ draft, set, rewardAnswers, setRewardAnswers }) {
  return (
    <>
      <Card>
        <Question
          question="Why are you doing this?"
          why="This gets shown back to you on day 41 at 9pm, when you're tired and looking for a reason to stop. Write the real one."
        >
          <textarea
            className="textarea"
            value={draft.whyStatement}
            onChange={(e) => set({ whyStatement: e.target.value })}
            placeholder="The honest reason"
          />
        </Question>
      </Card>

      <Card>
        <h3>Now name three rewards</h3>
        <p className="muted">
          You'll earn coins for completed days and spend them on these. A reward someone else picked
          has no pull, so pick your own.
        </p>
        {REWARD_PROMPTS.map((prompt, index) => (
          <label key={prompt} className="field">
            <span style={{ fontWeight: 600 }}>{prompt}</span>
            <input
              className="input"
              value={rewardAnswers[index]}
              onChange={(e) =>
                setRewardAnswers((current) => current.map((v, i) => (i === index ? e.target.value : v)))
              }
              placeholder="Your answer"
            />
          </label>
        ))}
      </Card>
    </>
  );
}

function Recommendation({ draft, chosenTier, setChosenTier, busy, onStart }) {
  const recommendation = useMemo(() => recommendTier(draft), [draft]);
  const tier = chosenTier ?? recommendation.tier;
  const ruleSet = useMemo(() => buildRules(tier, draft), [tier, draft]);
  const [showWhy, setShowWhy] = useState(false);

  return (
    <>
      <Card>
        <h1>{recommendation.headline}</h1>
        {recommendation.reasons.map((reason) => (
          <p key={reason} className="row" style={{ alignItems: 'flex-start' }}>
            <span aria-hidden="true">✓</span>
            <span>{reason}</span>
          </p>
        ))}
        {recommendation.cautions.map((caution) => (
          <Note key={caution}>{caution}</Note>
        ))}
      </Card>

      <Card>
        <h3>Pick your tier</h3>
        <p className="tiny">You can change this later without losing your history.</p>
        {[...TIERS].reverse().map((id) => (
          <Option
            key={id}
            title={`${TIER_INFO[id].name}${recommendation.tier === id ? ' · recommended' : ''}`}
            detail={TIER_INFO[id].blurb}
            selected={tier === id}
            onClick={() => setChosenTier(id)}
          />
        ))}
      </Card>

      <Card>
        <div className="row row--between">
          <h3>Your daily plan</h3>
          <button type="button" className="btn btn--ghost btn--small" onClick={() => setShowWhy((v) => !v)}>
            {showWhy ? 'Less' : 'Show why'}
          </button>
        </div>

        {ruleSet.rules.map((rule) => (
          <div key={rule.id} className="stack" style={{ gap: '0.25rem' }}>
            <div className="row row--between">
              <strong>{rule.title}</strong>
              <span className="task__amount">{formatAmount(rule.target, rule.unit)}</span>
            </div>
            <p className="tiny">{rule.detail}</p>
            {showWhy &&
              rule.adaptations.map((note) => (
                <p key={note} className="tiny">• {note}</p>
              ))}
            {showWhy &&
              rule.safetyFlags.map((flag) => (
                <p key={flag} className="tiny" style={{ color: 'var(--warning)' }}>⚠︎ {flag}</p>
              ))}
          </div>
        ))}

        {ruleSet.globalNotes.map((note) => (
          <Note key={note} variant={note.toLowerCase().includes('doctor') ? 'critical' : 'warning'}>
            {note}
          </Note>
        ))}
      </Card>

      <button type="button" className="btn btn--primary btn--block" disabled={busy} onClick={() => onStart(tier)}>
        {busy ? 'Setting up…' : 'Start day 1'}
      </button>
    </>
  );
}
