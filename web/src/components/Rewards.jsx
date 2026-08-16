import { useMemo, useState } from 'react';

import { useChallenge } from '../ChallengeContext.jsx';
import { REWARD_CATEGORIES } from '../engine/constants.js';
import { levelFor } from '../engine/progress.js';
import { ACHIEVEMENTS } from '../data/achievements.js';
import { Card, SectionTitle, Empty, Modal, Stepper, Pill, Note } from './ui.jsx';

export default function Rewards() {
  const { state, run, stats, redeemReward, addReward, removeReward } = useChallenge();
  const [adding, setAdding] = useState(false);
  const [confirming, setConfirming] = useState(null);

  const rewards = state?.rewards ?? [];
  const redemptions = state?.redemptions ?? [];
  const unlocked = useMemo(() => new Set((state?.achievements ?? []).map((a) => a.code)), [state]);

  if (!run) return <Empty title="No active run" message="Start a run to earn coins." />;

  const shop = rewards.filter((r) => !r.unlocksAtDay);
  const milestones = rewards
    .filter((r) => r.unlocksAtDay)
    .sort((a, b) => a.unlocksAtDay - b.unlocksAtDay);

  const level = levelFor(run.xp);

  return (
    <>
      <Card tint="var(--coin)">
        <div className="row row--between">
          <div>
            <div style={{ fontSize: '2.4rem', fontWeight: 800, lineHeight: 1 }}>{run.coins}</div>
            <div className="tiny">Grit Coins</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <strong style={{ color: '#7367bf' }}>⭐ Lv {level.index}</strong>
            <div className="tiny">{level.title}</div>
          </div>
        </div>
        <p className="tiny">
          Ten coins a completed day, fifteen more every seventh day, plus two for finishing a day your
          body voted against.
        </p>
      </Card>

      <Card>
        <SectionTitle title="Milestones" subtitle="Unlocked by reaching the day, not by spending." />
        {milestones.map((reward) => {
          const reached = (stats?.completedDays ?? 0) >= reward.unlocksAtDay;
          return (
            <div key={reward.id} className="row">
              <span style={{ fontSize: '1.3rem' }} aria-hidden="true">
                {reached ? reward.symbol : '🔒'}
              </span>
              <div className="list__label">
                <strong style={{ color: reached ? 'var(--ink)' : 'var(--ink-soft)' }}>{reward.title}</strong>
                <p className="tiny">{reward.detail}</p>
              </div>
              <span className="tiny" style={{ color: reached ? 'var(--success)' : 'var(--ink-soft)', fontWeight: 700 }}>
                Day {reward.unlocksAtDay}
              </span>
            </div>
          );
        })}
      </Card>

      <Card>
        <div className="row row--between">
          <SectionTitle title="Spend your coins" subtitle="Tap anything you can afford." />
          <button type="button" className="btn btn--small" onClick={() => setAdding(true)}>
            ＋ Add
          </button>
        </div>

        {shop.length === 0 && <p className="muted">No rewards yet. Add something you actually want.</p>}

        {shop.map((reward) => {
          const affordable = run.coins >= reward.cost;
          return (
            <div key={reward.id} className="row" style={{ opacity: affordable ? 1 : 0.55 }}>
              <button
                type="button"
                className="list__item"
                style={{ border: 0 }}
                disabled={!affordable}
                onClick={() => setConfirming(reward)}
              >
                <span style={{ fontSize: '1.3rem' }} aria-hidden="true">{reward.symbol}</span>
                <span className="list__label">
                  <strong style={{ display: 'block' }}>{reward.title}</strong>
                  {reward.detail && <span className="tiny">{reward.detail}</span>}
                  {reward.timesRedeemed > 0 && (
                    <span className="tiny" style={{ color: 'var(--success)' }}>
                      {' '}Claimed {reward.timesRedeemed}×
                    </span>
                  )}
                </span>
                <span style={{ fontWeight: 700, color: affordable ? 'var(--coin)' : 'var(--ink-soft)' }}>
                  {reward.cost}
                </span>
              </button>
              {reward.isCustom && (
                <button
                  type="button"
                  className="btn btn--ghost btn--small"
                  onClick={() => removeReward(reward.id)}
                  aria-label={`Remove ${reward.title}`}
                >
                  ✕
                </button>
              )}
            </div>
          );
        })}
      </Card>

      <Card>
        <SectionTitle title="Badges" subtitle={`${unlocked.size} of ${ACHIEVEMENTS.length} earned`} />
        <div className="badges">
          {ACHIEVEMENTS.map((achievement) => {
            const earned = unlocked.has(achievement.code);
            return (
              <div
                key={achievement.code}
                className={`badge ${earned ? 'badge--earned' : ''}`}
                title={earned ? achievement.detail : 'Locked'}
              >
                <span className="badge__icon" aria-hidden="true">{earned ? achievement.icon : '🔒'}</span>
                <span>{achievement.title}</span>
                <span className="visually-hidden">
                  {earned ? `Earned. ${achievement.detail}` : 'Locked.'}
                </span>
              </div>
            );
          })}
        </div>
      </Card>

      {redemptions.length > 0 && (
        <Card>
          <SectionTitle title="Claimed" />
          <div className="list">
            {redemptions.slice(0, 10).map((entry) => (
              <div key={entry.id} className="list__item">
                <span className="list__label">
                  <strong style={{ display: 'block' }}>{entry.rewardTitle}</strong>
                  <span className="tiny">Day {entry.dayNumber}</span>
                </span>
                <span className="muted">−{entry.cost}</span>
              </div>
            ))}
          </div>
        </Card>
      )}

      {adding && <AddRewardModal onClose={() => setAdding(false)} onSave={addReward} />}

      {confirming && (
        <Modal title="Redeem this?" onClose={() => setConfirming(null)}>
          <p>
            <strong>{confirming.title}</strong> costs {confirming.cost} coins. You'll have{' '}
            {Math.max(0, run.coins - confirming.cost)} left.
          </p>
          <Note variant="info">Claim it today — a reward you keep postponing stops working.</Note>
          <button
            type="button"
            className="btn btn--primary btn--block"
            onClick={async () => {
              await redeemReward(confirming);
              setConfirming(null);
            }}
          >
            Redeem
          </button>
          <button type="button" className="btn btn--block" onClick={() => setConfirming(null)}>
            Not yet
          </button>
        </Modal>
      )}
    </>
  );
}

function AddRewardModal({ onClose, onSave }) {
  const [title, setTitle] = useState('');
  const [detail, setDetail] = useState('');
  const [cost, setCost] = useState(100);
  const [category, setCategory] = useState('treat');

  return (
    <Modal title="New reward" onClose={onClose}>
      <label className="field">
        <span className="tiny">What is it?</span>
        <input className="input" value={title} onChange={(e) => setTitle(e.target.value)} />
      </label>
      <p className="tiny">Be specific. "A massage on the 14th" pulls harder than "self care".</p>

      <label className="field">
        <span className="tiny">Any detail (optional)</span>
        <input className="input" value={detail} onChange={(e) => setDetail(e.target.value)} />
      </label>

      <div className="field">
        <span className="tiny">Cost</span>
        <Stepper label="cost" value={cost} min={10} max={1000} step={10} format={(v) => `${v} coins`} onChange={setCost} />
        <p className="tiny">Roughly {Math.round(cost / 10)} completed days.</p>
      </div>

      <div className="field">
        <span className="tiny">Kind</span>
        <div className="row row--wrap">
          {REWARD_CATEGORIES.filter((c) => c.id !== 'milestone').map((c) => (
            <button
              key={c.id}
              type="button"
              className="chip"
              aria-pressed={category === c.id}
              onClick={() => setCategory(c.id)}
            >
              {c.name}
            </button>
          ))}
        </div>
      </div>

      <button
        type="button"
        className="btn btn--primary btn--block"
        disabled={!title.trim()}
        onClick={async () => {
          await onSave({ title: title.trim(), detail: detail.trim(), cost, category, symbol: '🎁', isCustom: true });
          onClose();
        }}
      >
        Save
      </button>
    </Modal>
  );
}
