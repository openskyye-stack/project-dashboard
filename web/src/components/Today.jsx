import { useRef, useState } from 'react';

import { useChallenge } from '../ChallengeContext.jsx';
import { compressImage } from '../api.js';
import { formatAmount, UNITS, TIER_INFO, displayName } from '../engine/constants.js';
import { evaluateCheckIn, NEUTRAL_CHECK_IN, scaledTarget } from '../engine/dayScaler.js';
import { entrySatisfied, entryFraction, dayCompletionFraction, levelFor, resolveMiss } from '../engine/progress.js';
import { exerciseOptions, STOP_SIGNS } from '../engine/mobility.js';
import { dailyFluidTarget } from '../engine/hydration.js';
import { Card, Note, Ring, Bar, Stepper, Modal, Pill, SectionTitle, Empty } from './ui.jsx';

const KIND_TINT = {
  workout: '#c25a3f',
  outdoorWorkout: '#c79a26',
  hydration: '#2f6396',
  nutrition: '#59a04d',
  reading: '#7367bf',
  progressPhoto: '#8c7367',
  balanceWork: '#3f9e99',
  reflection: '#9a7391',
};

export default function Today() {
  const {
    profile, run, days, ruleSet, today, todayNumber, stats,
    unresolvedMiss, logAmount, toggleRule, setPhoto, setReflection,
  } = useChallenge();

  const [checkInOpen, setCheckInOpen] = useState(false);
  const [detailRule, setDetailRule] = useState(null);
  const [missOpen, setMissOpen] = useState(false);
  const [showWhy, setShowWhy] = useState(false);
  const fileRef = useRef(null);

  if (!run || !todayNumber) {
    return (
      <Empty
        icon="🏁"
        title="This run has finished"
        message="Head to Settings to start another one — everything you did is kept."
      />
    );
  }

  const fraction = dayCompletionFraction(today ?? { entries: {} }, ruleSet);
  const level = levelFor(run.xp);
  const photoRule = ruleSet.rules.find((r) => r.id === 'photo');
  const reflectionRule = ruleSet.rules.find((r) => r.id === 'reflection');

  const onPickPhoto = async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    const dataUrl = await compressImage(file);
    await setPhoto(dataUrl);
    event.target.value = '';
  };

  return (
    <>
      <Card>
        <div className="row" style={{ gap: '1.25rem', alignItems: 'center' }}>
          <Ring value={fraction} label={`${Math.round(fraction * 100)}%`} caption="today" />
          <div className="stack" style={{ gap: '0.4rem', flex: 1 }}>
            <strong style={{ color: 'var(--accent)' }}>{TIER_INFO[run.tier].name}</strong>
            <span>🔥 <strong>{stats?.current ?? 0}</strong> <span className="tiny">day streak</span></span>
            <span>✅ <strong>{stats?.completedDays ?? 0}/{run.totalDays}</strong> <span className="tiny">complete</span></span>
            <span>⭐ <strong>Lv {level.index}</strong> <span className="tiny">{level.title}</span></span>
          </div>
        </div>
        <div className="stack" style={{ gap: '0.25rem' }}>
          <div className="row row--between tiny">
            <span>{level.title} · {run.xp} XP</span>
            {level.xpToNext !== null && <span>{level.xpToNext} XP to level {level.index + 1}</span>}
          </div>
          <Bar value={level.progress} tint="#7367bf" />
        </div>
      </Card>

      {unresolvedMiss && (
        <button type="button" className="card card--tinted" style={{ '--tint': 'var(--danger)', textAlign: 'left', border: '1.5px solid var(--danger)' }} onClick={() => setMissOpen(true)}>
          <strong>⚠️ Day {unresolvedMiss.dayNumber} ended incomplete</strong>
          <span className="tiny">Tap to decide what happens next.</span>
        </button>
      )}

      {!today?.checkIn ? (
        <button
          type="button"
          className="card card--tinted"
          style={{ '--tint': 'var(--warning)', textAlign: 'left' }}
          onClick={() => setCheckInOpen(true)}
        >
          <strong>🌅 Morning check-in</strong>
          <span className="tiny">
            Four questions. Today's targets adjust to your answers.
          </span>
        </button>
      ) : (
        today.scaleFactor < 1 && (
          <Card tint="var(--info)">
            <div className="row row--between">
              <strong>Scaled to {Math.round(today.scaleFactor * 100)}% today</strong>
              <button type="button" className="btn btn--ghost btn--small" onClick={() => setCheckInOpen(true)}>
                Redo
              </button>
            </div>
            <p className="tiny">{today.scaleReason}</p>
          </Card>
        )
      )}

      <SectionTitle title="Today's tasks" subtitle="Tap the circle to finish, plus to log part of it." />

      {ruleSet.rules
        .filter((rule) => rule.id !== 'photo' && rule.id !== 'reflection')
        .map((rule) => (
          <TaskCard
            key={rule.id}
            rule={rule}
            entry={today?.entries?.[rule.id]}
            onLog={(amount) => logAmount(rule, amount)}
            onToggle={() => toggleRule(rule)}
            onDetail={() => setDetailRule(rule)}
          />
        ))}

      {photoRule && (
        <Card>
          <SectionTitle title="Progress photo" subtitle="Only visible in your own account." />
          {today?.photo ? (
            <>
              <img className="photo-preview" src={today.photo} alt={`Progress photo for day ${todayNumber}`} />
              <button type="button" className="btn btn--danger" onClick={() => setPhoto(null)}>
                Remove
              </button>
            </>
          ) : (
            <>
              <input
                ref={fileRef}
                type="file"
                accept="image/*"
                capture="user"
                onChange={onPickPhoto}
                className="visually-hidden"
                id="photo-input"
              />
              <label htmlFor="photo-input" className="btn btn--block">
                📷 Add today's photo
              </label>
            </>
          )}
        </Card>
      )}

      {reflectionRule && (
        <Card>
          <SectionTitle title="One line about today" />
          <textarea
            className="textarea"
            style={{ minHeight: 64 }}
            defaultValue={today?.reflection ?? ''}
            onBlur={(e) => setReflection(e.target.value)}
            placeholder="What worked, what hurt, what you'd change"
          />
        </Card>
      )}

      {profile?.whyStatement?.trim() && (
        <Card>
          <button
            type="button"
            className="row row--between btn btn--ghost"
            style={{ padding: 0 }}
            onClick={() => setShowWhy((v) => !v)}
            aria-expanded={showWhy}
          >
            <span className="muted">Why you're doing this</span>
            <span aria-hidden="true">{showWhy ? '▾' : '▸'}</span>
          </button>
          {showWhy && <p>{profile.whyStatement}</p>}
        </Card>
      )}

      <Card>
        <details>
          <summary style={{ color: 'var(--danger)', fontWeight: 650, minHeight: 'var(--tap)', display: 'flex', alignItems: 'center' }}>
            Stop immediately if…
          </summary>
          <ul className="muted" style={{ paddingLeft: '1.2rem' }}>
            {STOP_SIGNS.map((sign) => (
              <li key={sign}>{sign}</li>
            ))}
          </ul>
          <p className="tiny">Any of these means stop and seek advice. No streak is worth a cardiac event.</p>
        </details>
      </Card>

      {checkInOpen && <CheckInModal onClose={() => setCheckInOpen(false)} />}
      {detailRule && <RuleDetailModal rule={detailRule} onClose={() => setDetailRule(null)} />}
      {missOpen && unresolvedMiss && <MissModal day={unresolvedMiss} onClose={() => setMissOpen(false)} />}
    </>
  );
}

// --- task card --------------------------------------------------------------

function TaskCard({ rule, entry, onLog, onToggle, onDetail }) {
  const target = entry?.target ?? rule.target;
  const done = entrySatisfied(entry, target);
  const fraction = entryFraction(entry, target);
  const tint = KIND_TINT[rule.kind] ?? 'var(--accent)';
  const step = UNITS[rule.unit]?.step ?? 1;

  return (
    <Card tint={done ? 'var(--success)' : undefined}>
      <div className="task">
        <div className="task__head">
          <button
            type="button"
            className="task__check"
            style={{ '--tint': tint }}
            aria-pressed={done}
            aria-label={done ? `${rule.title} complete. Tap to undo.` : `Mark ${rule.title} complete`}
            onClick={onToggle}
          >
            {done ? '✓' : fraction > 0 ? Math.round(fraction * 100) + '%' : ''}
          </button>

          <div className="task__body">
            <div className={`task__title ${done ? 'task__title--done' : ''}`}>
              {rule.title}
              {!rule.required && <Pill>optional</Pill>}
            </div>
            <p className="tiny">{rule.detail}</p>
            <span className="task__amount">
              {rule.unit === 'yesNo'
                ? done
                  ? 'Done'
                  : 'Not yet'
                : `${formatAmount(entry?.value ?? 0, rule.unit)} of ${formatAmount(target, rule.unit)}`}
            </span>
            {rule.maxSplits > 1 && rule.unit === 'minutes' && !done && (
              <span className="tiny">Counts as {rule.maxSplits} × {Math.round(target / rule.maxSplits)} min</span>
            )}
          </div>

          <button type="button" className="task__info" onClick={onDetail} aria-label={`Details for ${rule.title}`}>
            ⓘ
          </button>
        </div>

        {rule.unit !== 'yesNo' && (
          <>
            <Bar value={fraction} tint={tint} />
            <div className="task__steps">
              <button
                type="button"
                className="task__step"
                onClick={() => onLog(-step)}
                disabled={(entry?.value ?? 0) <= 0}
                aria-label={`Remove ${formatAmount(step, rule.unit)} from ${rule.title}`}
              >
                −
              </button>
              <button
                type="button"
                className="task__step"
                onClick={() => onLog(step)}
                aria-label={`Add ${formatAmount(step, rule.unit)} to ${rule.title}`}
              >
                +
              </button>
              <span className="tiny">± {formatAmount(step, rule.unit)}</span>
            </div>
          </>
        )}

        {rule.safetyFlags.slice(0, 2).map((flag) => (
          <p key={flag} className="tiny" style={{ color: 'var(--warning)' }}>
            ⚠︎ {flag}
          </p>
        ))}
      </div>
    </Card>
  );
}

// --- check-in ---------------------------------------------------------------

function CheckInModal({ onClose }) {
  const { profile, ruleSet, today, submitCheckIn, run, spendFreeze, todayNumber } = useChallenge();

  const [answers, setAnswers] = useState(() =>
    today?.checkIn ? { ...NEUTRAL_CHECK_IN, ...today.checkIn } : { ...NEUTRAL_CHECK_IN }
  );
  const [outcome, setOutcome] = useState(null);

  const set = (patch) => setAnswers((current) => ({ ...current, ...patch }));

  const submit = async () => {
    const result = evaluateCheckIn(answers, profile);
    setOutcome(result);
    await submitCheckIn(answers, result);
  };

  const painColour =
    answers.pain <= 2 ? 'var(--success)' : answers.pain <= 5 ? 'var(--warning)' : 'var(--danger)';

  return (
    <Modal title={outcome ? "Today's plan" : `How are you today, ${displayName(profile)}?`} onClose={onClose}>
      {!outcome ? (
        <>
          <p className="muted">Answer honestly. The plan bends to fit — that's the point.</p>

          <Card>
            <h3>How many hours did you sleep?</h3>
            <Stepper
              label="hours slept"
              value={answers.sleepHours}
              min={0}
              max={12}
              step={0.5}
              format={(v) => `${v.toFixed(1)} hours`}
              onChange={(v) => set({ sleepHours: v })}
            />
          </Card>

          <Card>
            <h3>Worst pain right now?</h3>
            <p className="tiny">
              Above five, the plan halves. Above seven, it becomes range-of-motion work only.
            </p>
            <input
              type="range"
              min={0}
              max={10}
              step={1}
              value={answers.pain}
              onChange={(e) => set({ pain: Number(e.target.value) })}
              aria-label={`Pain level ${answers.pain} out of 10`}
            />
            <div className="row row--between">
              <span className="tiny">None</span>
              <strong style={{ color: painColour, fontSize: '1.4rem' }}>{answers.pain}</strong>
              <span className="tiny">Unbearable</span>
            </div>
          </Card>

          <Card>
            <h3>Energy today?</h3>
            <FiveWay value={answers.energy} onChange={(v) => set({ energy: v })} low="Wiped out" high="Fresh" />
          </Card>

          <Card>
            <h3>How sore are you from yesterday?</h3>
            <FiveWay value={answers.soreness} onChange={(v) => set({ soreness: v })} low="Fine" high="Very sore" />
          </Card>

          <button type="button" className="btn btn--primary btn--block" onClick={submit}>
            See today's plan
          </button>
        </>
      ) : (
        <>
          <h1>{outcome.headline}</h1>
          <p className="muted">{outcome.reason}</p>

          {outcome.scaleFactor < 1 && (
            <Card tint="var(--info)">
              <SectionTitle title="Today's targets" />
              {ruleSet.rules
                .filter((rule) => scaledTarget(rule, outcome.scaleFactor) !== rule.target)
                .map((rule) => (
                  <div key={rule.id} className="row row--between">
                    <span>{rule.title}</span>
                    <span>
                      <s className="muted">{formatAmount(rule.target, rule.unit)}</s>{' '}
                      → <strong>{formatAmount(scaledTarget(rule, outcome.scaleFactor), rule.unit)}</strong>
                    </span>
                  </div>
                ))}
            </Card>
          )}

          {outcome.advice.length > 0 && (
            <Card>
              <SectionTitle title="For today" />
              {outcome.advice.map((line) => (
                <p key={line} className="muted">💡 {line}</p>
              ))}
            </Card>
          )}

          {outcome.suggestsRest && (
            <>
              <Note variant={outcome.suggestsClinician ? 'critical' : 'warning'}>
                Today looks like a rest day. A scaled day still counts — but if you'd rather protect the
                streak and rest properly, spend a freeze.
              </Note>
              {run.tier !== 'hard' && run.freezeTokens > 0 ? (
                <button
                  type="button"
                  className="btn btn--block"
                  onClick={async () => {
                    await spendFreeze(todayNumber);
                    onClose();
                  }}
                >
                  ❄️ Spend a freeze ({run.freezeTokens} left)
                </button>
              ) : run.tier === 'hard' ? (
                <p className="tiny">
                  75 Hard has no freezes. That's the bargain of the tier — if today is genuinely unsafe,
                  stepping down to 75 Medium in Settings keeps your progress.
                </p>
              ) : null}
            </>
          )}

          <button type="button" className="btn btn--primary btn--block" onClick={onClose}>
            Let's go
          </button>
        </>
      )}
    </Modal>
  );
}

// Five big buttons rather than a slider: easier to hit accurately and clearer at
// large text sizes.
function FiveWay({ value, onChange, low, high }) {
  return (
    <>
      <div className="scale-picker">
        {[1, 2, 3, 4, 5].map((n) => (
          <button key={n} type="button" aria-pressed={value === n} onClick={() => onChange(n)}>
            {n}
          </button>
        ))}
      </div>
      <div className="row row--between">
        <span className="tiny">{low}</span>
        <span className="tiny">{high}</span>
      </div>
    </>
  );
}

// --- rule detail ------------------------------------------------------------

function RuleDetailModal({ rule, onClose }) {
  const { profile, run, today, logAmount } = useChallenge();
  const [amount, setAmount] = useState(0);

  const isMovement = ['workout', 'outdoorWorkout', 'balanceWork'].includes(rule.kind);
  const options = isMovement ? exerciseOptions(profile, { outdoorOnly: rule.kind === 'outdoorWorkout' }) : [];
  const hydration = rule.kind === 'hydration' ? dailyFluidTarget(profile, run.tier) : null;
  const target = today?.entries?.[rule.id]?.target ?? rule.target;

  return (
    <Modal title={rule.title} onClose={onClose}>
      <Card tint={KIND_TINT[rule.kind]}>
        <h1>{formatAmount(target, rule.unit)}</h1>
        <p>{rule.detail}</p>
      </Card>

      {rule.adaptations.length > 0 && (
        <Card>
          <SectionTitle title="Why this number" subtitle="Adapted from the standard rule for your answers." />
          {rule.adaptations.map((note) => (
            <p key={note} className="muted">↳ {note}</p>
          ))}
        </Card>
      )}

      {isMovement && (
        <Card>
          <SectionTitle
            title="Ways to do this today"
            subtitle="Filtered to what's safe and possible with your equipment."
          />
          {options.length === 0 ? (
            <p className="muted">Anything continuous and conversational counts.</p>
          ) : (
            options.map((option) => (
              <div key={option.id} className="stack" style={{ gap: '0.2rem' }}>
                <strong>{option.title}</strong>
                <p className="tiny">{option.detail}</p>
                <div className="row row--wrap">
                  {option.seated && <Pill variant="info">seated</Pill>}
                  {option.lowImpact && <Pill variant="good">low impact</Pill>}
                </div>
              </div>
            ))
          )}
        </Card>
      )}

      {hydration && (
        <Card>
          <SectionTitle title="Your water target" />
          <p>
            {formatAmount(hydration.targetMl, 'milliliters')} — about {hydration.glasses} glasses.
          </p>
          {hydration.notes.map((note) => (
            <p key={note} className="tiny">• {note}</p>
          ))}
          {hydration.needsClinician && (
            <Note variant="critical">
              You told us your fluids are limited. This number is a conservative cap, not a prescription —
              get the real one from your clinician.
            </Note>
          )}
        </Card>
      )}

      {(rule.safetyFlags.length > 0 || isMovement) && (
        <Card tint="var(--warning)">
          <SectionTitle title="Safety" />
          {rule.safetyFlags.map((flag) => (
            <p key={flag} className="muted">🛡 {flag}</p>
          ))}
          {isMovement && (
            <>
              <strong className="tiny">Stop immediately for:</strong>
              <ul className="muted" style={{ paddingLeft: '1.2rem', margin: 0 }}>
                {STOP_SIGNS.map((sign) => (
                  <li key={sign}>{sign}</li>
                ))}
              </ul>
            </>
          )}
        </Card>
      )}

      {rule.unit !== 'yesNo' && (
        <Card>
          <SectionTitle title="Log an amount" />
          <Stepper
            label={`amount of ${rule.title}`}
            value={amount}
            min={0}
            max={target * 2}
            step={UNITS[rule.unit]?.step ?? 1}
            format={(v) => formatAmount(v, rule.unit)}
            onChange={setAmount}
          />
          <button
            type="button"
            className="btn btn--primary btn--block"
            disabled={amount <= 0}
            onClick={async () => {
              await logAmount(rule, amount);
              onClose();
            }}
          >
            Add to today
          </button>
        </Card>
      )}
    </Modal>
  );
}

// --- missed day -------------------------------------------------------------

function MissModal({ day, onClose }) {
  const { run, days, spendFreeze, acknowledgeMiss, restart } = useChallenge();
  const resolution = resolveMiss(run, days, day);
  const gentler = run.tier === 'hard' ? 'medium' : run.tier === 'medium' ? 'soft' : null;

  const close = async () => {
    await acknowledgeMiss(day.dayNumber);
    onClose();
  };

  return (
    <Modal title={`Day ${day.dayNumber} ended incomplete`} onClose={onClose}>
      {resolution.kind === 'restart' && (
        <>
          <p>
            75 Hard's rule is a restart. You'd go back to day 1 and lose {resolution.daysLost} completed{' '}
            {resolution.daysLost === 1 ? 'day' : 'days'} of streak — but not the record of them.
          </p>
          <Note>
            Before you restart: was this a discipline problem or a design problem? If the plan is asking
            for more than your body can give on an average day, restarting the same plan gets the same
            result. Stepping down a tier keeps every day you've done.
          </Note>
          <button
            type="button"
            className="btn btn--danger btn--block"
            onClick={async () => {
              await acknowledgeMiss(day.dayNumber);
              await restart(run.tier);
              onClose();
            }}
          >
            Restart at day 1
          </button>
          {gentler && (
            <button
              type="button"
              className="btn btn--block"
              onClick={async () => {
                await acknowledgeMiss(day.dayNumber);
                await restart(gentler);
                onClose();
              }}
            >
              Switch to {TIER_INFO[gentler].name} and continue
            </button>
          )}
        </>
      )}

      {resolution.kind === 'grace' && (
        <>
          <p>
            You have {resolution.remaining} grace {resolution.remaining === 1 ? 'day' : 'days'} left on{' '}
            {TIER_INFO[run.tier].name}. Spending one keeps the streak and the run intact.
          </p>
          <button
            type="button"
            className="btn btn--primary btn--block"
            onClick={async () => {
              await spendFreeze(day.dayNumber);
              onClose();
            }}
          >
            ❄️ Spend a grace day
          </button>
          <button type="button" className="btn btn--block" onClick={close}>
            Take the streak break
          </button>
        </>
      )}

      {resolution.kind === 'streakBroken' && (
        <>
          <p>
            On 75 Soft nothing resets. Your streak counter goes back to zero and the run carries on from
            today.
          </p>
          <p className="muted">
            Missing one day in seventy-five changes nothing about the outcome. Missing three in a row is
            the signal worth paying attention to.
          </p>
          <button type="button" className="btn btn--primary btn--block" onClick={close}>
            Carry on
          </button>
        </>
      )}
    </Modal>
  );
}
