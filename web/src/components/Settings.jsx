import { useState } from 'react';

import { useChallenge } from '../ChallengeContext.jsx';
import {
  TIERS, TIER_INFO, MOBILITY_LEVELS, PAIN_LEVELS, OUTDOOR_ACCESS, READING_FORMATS,
  ageOf, shouldPromptClinician, safetyNotes, formatAmount, displayName,
} from '../engine/constants.js';
import { STOP_SIGNS } from '../engine/mobility.js';
import { Card, SectionTitle, Note, Modal, Stepper, Toggle, Option } from './ui.jsx';

export default function Settings() {
  const { profile, run, saveProfile, restart, readaptRules, resetEverything, signOut, user } = useChallenge();

  const [editing, setEditing] = useState(false);
  const [planOpen, setPlanOpen] = useState(false);
  const [tierOpen, setTierOpen] = useState(false);
  const [confirmReset, setConfirmReset] = useState(false);
  const [readapted, setReadapted] = useState(false);

  if (!profile) return null;

  return (
    <>
      {run && (
        <Card>
          <SectionTitle title="Current run" />
          <Row label="Tier" value={TIER_INFO[run.tier].name} />
          <Row label="Started" value={run.startDate} />
          <Row label="Attempt" value={String(run.attemptNumber)} />
          <button type="button" className="btn btn--block" onClick={() => setTierOpen(true)}>
            Change tier
          </button>
          {run.tier === 'hard' && (
            <p className="tiny">
              Stepping down to 75 Medium is a strategy, not a failure. Most people who finish did not
              finish their first attempt at the hardest tier.
            </p>
          )}
        </Card>
      )}

      <Card>
        <SectionTitle title="Your plan" />
        <button type="button" className="btn btn--block" onClick={() => setPlanOpen(true)}>
          See today's rules and why
        </button>
        <button type="button" className="btn btn--block" onClick={() => setEditing(true)}>
          Update my answers
        </button>
        <button
          type="button"
          className="btn btn--block"
          onClick={async () => {
            await readaptRules();
            setReadapted(true);
          }}
        >
          Re-adapt the plan to my answers
        </button>
        {readapted && <Note variant="info">Plan updated from your current answers.</Note>}
        <p className="tiny">
          Re-adapting rewrites the targets for the rest of this run. Days you've already completed keep
          the targets they were judged against.
        </p>
      </Card>

      <Card>
        <SectionTitle title="Accessibility" />
        <Toggle
          label="Larger text everywhere"
          checked={profile.wantsLargeText}
          onChange={(v) => saveProfile({ ...profile, wantsLargeText: v })}
        />
        <Toggle
          label="Reduce animation"
          checked={profile.wantsReducedMotion}
          onChange={(v) => saveProfile({ ...profile, wantsReducedMotion: v })}
        />
        <p className="tiny">
          The app also follows your system text size and reduced-motion settings — this is on top of those.
        </p>
      </Card>

      <Card>
        <SectionTitle title="Safety" />
        {shouldPromptClinician(profile) && (
          <Note variant="critical">
            Based on your answers, this plan should be reviewed by a clinician. Show them the rules page —
            it's specific enough to be useful.
          </Note>
        )}
        <Toggle
          label="A clinician has cleared me"
          checked={profile.clinicianCleared}
          onChange={(v) => saveProfile({ ...profile, clinicianCleared: v })}
        />
        {safetyNotes(profile).map((note) => (
          <p key={note} className="muted">🛡 {note}</p>
        ))}
        <details>
          <summary style={{ minHeight: 'var(--tap)', display: 'flex', alignItems: 'center', color: 'var(--danger)' }}>
            Stop immediately if…
          </summary>
          <ul className="muted" style={{ paddingLeft: '1.2rem' }}>
            {STOP_SIGNS.map((sign) => (
              <li key={sign}>{sign}</li>
            ))}
          </ul>
        </details>
      </Card>

      <Card>
        <SectionTitle title="Account" />
        <Row label="Signed in as" value={user?.username ?? '—'} />
        <p className="tiny">
          Your data is stored in your own account on this server. It is not shared with other users, and
          nothing is sent anywhere else.
        </p>
        <button type="button" className="btn btn--block" onClick={signOut}>
          Sign out
        </button>
        <button type="button" className="btn btn--danger btn--block" onClick={() => setConfirmReset(true)}>
          Erase my challenge data
        </button>
      </Card>

      <Card>
        <p className="tiny">
          75 Hard is a challenge created by Andy Frisella. This app is not affiliated with it. Medium and
          Soft are community variants, and every tier here is further adapted to your answers.
        </p>
        <p className="tiny" style={{ fontWeight: 700 }}>Nothing in this app is medical advice.</p>
      </Card>

      {editing && <ProfileEditor onClose={() => setEditing(false)} />}
      {planOpen && <PlanSummary onClose={() => setPlanOpen(false)} />}

      {tierOpen && (
        <Modal title="Change tier" onClose={() => setTierOpen(false)}>
          <Note>
            This starts a fresh run at day 1 on the new tier. Your current run is kept in your history,
            not deleted.
          </Note>
          {[...TIERS].reverse().map((id) => (
            <button
              key={id}
              type="button"
              className="btn btn--block"
              disabled={id === run?.tier}
              onClick={async () => {
                await restart(id);
                setTierOpen(false);
              }}
            >
              {TIER_INFO[id].name}
            </button>
          ))}
        </Modal>
      )}

      {confirmReset && (
        <Modal title="Erase everything?" onClose={() => setConfirmReset(false)}>
          <Note variant="critical">
            Every run, photo, planned meal and reward in your account is deleted. There is no undo.
          </Note>
          <button
            type="button"
            className="btn btn--danger btn--block"
            onClick={async () => {
              await resetEverything();
              setConfirmReset(false);
            }}
          >
            Erase
          </button>
          <button type="button" className="btn btn--block" onClick={() => setConfirmReset(false)}>
            Cancel
          </button>
        </Modal>
      )}
    </>
  );
}

function Row({ label, value }) {
  return (
    <div className="row row--between">
      <span className="muted">{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

// The page to take to a doctor's appointment.
function PlanSummary({ onClose }) {
  const { profile, run, ruleSet } = useChallenge();

  return (
    <Modal title="Your plan" onClose={onClose}>
      <Card>
        <h2>{TIER_INFO[run.tier].name}, adapted</h2>
        <p className="tiny">
          {displayName(profile)}, age {ageOf(profile)} ·{' '}
          {MOBILITY_LEVELS.find((m) => m.id === profile.mobility)?.name.toLowerCase()}
        </p>
      </Card>

      {ruleSet.rules.map((rule) => (
        <Card key={rule.id}>
          <div className="row row--between">
            <strong>{rule.title}</strong>
            <span className="task__amount">{formatAmount(rule.target, rule.unit)}</span>
          </div>
          <p className="tiny">{rule.detail}</p>
          {rule.adaptations.map((note) => (
            <p key={note} className="tiny">• {note}</p>
          ))}
          {rule.safetyFlags.map((flag) => (
            <p key={flag} className="tiny" style={{ color: 'var(--warning)' }}>⚠︎ {flag}</p>
          ))}
        </Card>
      ))}

      {ruleSet.globalNotes.map((note) => (
        <Note key={note} variant={note.toLowerCase().includes('doctor') ? 'critical' : 'warning'}>
          {note}
        </Note>
      ))}

      {safetyNotes(profile).length > 0 && (
        <Card>
          <SectionTitle title="Condition-specific notes" />
          {safetyNotes(profile).map((note) => (
            <p key={note} className="muted">🛡 {note}</p>
          ))}
        </Card>
      )}
    </Modal>
  );
}

function ProfileEditor({ onClose }) {
  const { profile, saveProfile } = useChallenge();
  const [draft, setDraft] = useState(profile);
  const set = (patch) => setDraft((current) => ({ ...current, ...patch }));

  return (
    <Modal title="Your answers" onClose={onClose}>
      <Card>
        <label className="field">
          <span className="tiny">Name</span>
          <input className="input" value={draft.name} onChange={(e) => set({ name: e.target.value })} />
        </label>
        <label className="field">
          <span className="tiny">Born</span>
          <input
            className="input"
            type="number"
            value={draft.birthYear}
            onChange={(e) => set({ birthYear: Number(e.target.value) })}
          />
        </label>
        <Stepper
          label="weight"
          value={Math.round(draft.weightKg)}
          min={35}
          max={200}
          step={1}
          format={(v) => `${v} kg`}
          onChange={(v) => set({ weightKg: v })}
        />
      </Card>

      <Card>
        <SectionTitle title="Moving around" />
        {MOBILITY_LEVELS.map((level) => (
          <Option
            key={level.id}
            title={level.name}
            selected={draft.mobility === level.id}
            onClick={() => set({ mobility: level.id })}
          />
        ))}
      </Card>

      <Card>
        <SectionTitle title="Joint pain" />
        {PAIN_LEVELS.map((level) => (
          <Option
            key={level.id}
            title={level.name}
            selected={draft.jointPain === level.id}
            onClick={() => set({ jointPain: level.id })}
          />
        ))}
      </Card>

      <Card>
        <SectionTitle title="Steadiness" />
        <input
          type="range"
          min={1}
          max={5}
          value={draft.balanceConfidence}
          onChange={(e) => set({ balanceConfidence: Number(e.target.value) })}
          aria-label={`Balance confidence ${draft.balanceConfidence} of 5`}
        />
        <Toggle
          label="Fallen in the last year"
          checked={draft.hasFallenInLastYear}
          onChange={(v) => set({ hasFallenInLastYear: v })}
        />
        <Stepper
          label="standing tolerance"
          value={draft.continuousStandingMinutes}
          min={0}
          max={90}
          step={5}
          format={(v) => (v <= 0 ? 'Seated exercise' : `${v} min standing`)}
          onChange={(v) => set({ continuousStandingMinutes: v })}
        />
      </Card>

      <Card>
        <SectionTitle title="Your day" />
        <Stepper
          label="minutes available"
          value={draft.availableMinutesPerDay}
          min={30}
          max={180}
          step={10}
          format={(v) => `${v} min available`}
          onChange={(v) => set({ availableMinutesPerDay: v })}
        />
        <label className="field">
          <span className="tiny">Outdoor access</span>
          <select className="select" value={draft.outdoorAccess} onChange={(e) => set({ outdoorAccess: e.target.value })}>
            {OUTDOOR_ACCESS.map((o) => (
              <option key={o.id} value={o.id}>{o.name}</option>
            ))}
          </select>
        </label>
        <label className="field">
          <span className="tiny">Reading</span>
          <select className="select" value={draft.readingFormat} onChange={(e) => set({ readingFormat: e.target.value })}>
            {READING_FORMATS.map((o) => (
              <option key={o.id} value={o.id}>{o.name}</option>
            ))}
          </select>
        </label>
      </Card>

      <Card>
        <SectionTitle title="Why you're doing this" />
        <textarea
          className="textarea"
          value={draft.whyStatement}
          onChange={(e) => set({ whyStatement: e.target.value })}
        />
      </Card>

      <Note variant="info">
        Saving updates your profile. To push these changes into your current run's targets, use
        "Re-adapt the plan".
      </Note>

      <button
        type="button"
        className="btn btn--primary btn--block"
        onClick={async () => {
          await saveProfile(draft);
          onClose();
        }}
      >
        Save
      </button>
    </Modal>
  );
}
