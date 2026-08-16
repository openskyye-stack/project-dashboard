import { useEffect, useState } from 'react';

import { useChallenge } from '../ChallengeContext.jsx';
import { api } from '../api.js';
import { TIER_INFO } from '../engine/constants.js';
import { dayCompletionFraction, entrySatisfied, isPastDay, dateForDay } from '../engine/progress.js';
import { Card, SectionTitle, Ring, Bar, Note, Empty } from './ui.jsx';

export default function Progress() {
  const { run, days, ruleSet, stats } = useChallenge();

  if (!run) return <Empty title="No active run" message="Start a run to see progress." />;

  const settled = days.filter((d) => d.isComplete || isPastDay(d));

  return (
    <>
      <Card>
        <div className="row" style={{ gap: '1.25rem' }}>
          <Ring
            value={(stats?.completedDays ?? 0) / run.totalDays}
            label={`${stats?.completedDays ?? 0}`}
            caption={`of ${run.totalDays}`}
            size={130}
          />
          <div className="stack" style={{ gap: '0.45rem', flex: 1 }}>
            <span>🔥 <strong>{stats?.current ?? 0}</strong> <span className="tiny">current streak</span></span>
            <span>🏆 <strong>{stats?.longest ?? 0}</strong> <span className="tiny">longest</span></span>
            <span>％ <strong>{Math.round((stats?.completionRate ?? 0) * 100)}</strong> <span className="tiny">completion</span></span>
            <span>❄️ <strong>{stats?.freezesUsed ?? 0}</strong> <span className="tiny">freezes used</span></span>
          </div>
        </div>
        {run.attemptNumber > 1 && (
          <p className="tiny">
            Attempt {run.attemptNumber}. Everything you did in earlier runs is still recorded.
          </p>
        )}
      </Card>

      <Card>
        <SectionTitle title={`All ${run.totalDays} days`} subtitle="Filled is complete, blue is a freeze." />
        <div className="calendar">
          {Array.from({ length: run.totalDays }, (_, i) => i + 1).map((number) => {
            const day = days.find((d) => d.dayNumber === number);
            const state = cellState(day, run, number);
            return (
              <div key={number} className={`calendar__cell calendar__cell--${state}`} title={`Day ${number}: ${state}`}>
                {number}
                <span className="visually-hidden">{`Day ${number}: ${state}`}</span>
              </div>
            );
          })}
        </div>
      </Card>

      <Card>
        <SectionTitle title="Completion by day" />
        {settled.length === 0 ? (
          <p className="muted">A few days in, this fills up.</p>
        ) : (
          <ColumnChart
            data={settled.map((day) => ({
              label: day.dayNumber,
              value: dayCompletionFraction(day, ruleSet),
              tint: day.isComplete ? 'var(--success)' : 'var(--warning)',
            }))}
          />
        )}
      </Card>

      <Card>
        <SectionTitle
          title="How you've felt"
          subtitle="Pain and energy over the run. Worth showing your doctor."
        />
        <CheckInChart days={days.filter((d) => d.checkIn)} />
      </Card>

      <Card>
        <SectionTitle title="Which task trips you up" />
        {settled.length === 0 ? (
          <p className="muted">Nothing to compare yet.</p>
        ) : (
          <>
            {ruleSet.rules.map((rule) => {
              const hits = settled.filter((day) =>
                entrySatisfied(day.entries?.[rule.id], day.entries?.[rule.id]?.target ?? rule.target)
              ).length;
              const rate = hits / settled.length;
              return (
                <div key={rule.id} className="stack" style={{ gap: '0.2rem' }}>
                  <div className="row row--between">
                    <span>{rule.title}</span>
                    <strong style={{ color: rate >= 0.8 ? 'var(--success)' : 'var(--warning)' }}>
                      {Math.round(rate * 100)}%
                    </strong>
                  </div>
                  <Bar value={rate} tint={rate >= 0.8 ? 'var(--success)' : 'var(--warning)'} />
                </div>
              );
            })}
            <WeakestNote rules={ruleSet.rules} settled={settled} />
          </>
        )}
      </Card>

      <PhotoTimeline run={run} days={days} />
    </>
  );
}

function cellState(day, run, number) {
  if (!day) {
    const date = dateForDay(run, number);
    return date < new Date().toISOString().slice(0, 10) ? 'missed' : 'future';
  }
  if (day.usedFreeze) return 'freeze';
  if (day.isComplete) return 'done';
  if (isPastDay(day)) return 'missed';
  return 'future';
}

function WeakestNote({ rules, settled }) {
  if (settled.length < 5) return null;

  const scored = rules
    .filter((r) => r.required)
    .map((rule) => {
      const hits = settled.filter((day) =>
        entrySatisfied(day.entries?.[rule.id], day.entries?.[rule.id]?.target ?? rule.target)
      ).length;
      return { rule, rate: hits / settled.length };
    })
    .sort((a, b) => a.rate - b.rate);

  const worst = scored[0];
  if (!worst || worst.rate >= 0.7) return null;

  return (
    <Note>
      <strong>{worst.rule.title}</strong> is your weak point. That usually means the target is wrong for
      your life, not that you lack discipline — open it and check what it's actually asking.
    </Note>
  );
}

// Bars and lines are drawn as plain SVG rather than pulling in a chart library:
// three charts do not justify the dependency, and hand-drawn SVG is easier to
// label for screen readers than most chart libraries' output.
function ColumnChart({ data }) {
  const width = 320;
  const height = 140;
  const gap = 1;
  const barWidth = Math.max(1, width / data.length - gap);

  return (
    <svg viewBox={`0 0 ${width} ${height}`} width="100%" height={height} role="img"
      aria-label={`Completion for ${data.length} days. ${data.filter((d) => d.value >= 1).length} fully complete.`}>
      <line x1="0" y1={height - 1} x2={width} y2={height - 1} stroke="var(--line)" />
      {data.map((point, index) => {
        const barHeight = Math.max(1, point.value * (height - 8));
        return (
          <rect
            key={point.label}
            x={index * (barWidth + gap)}
            y={height - barHeight - 1}
            width={barWidth}
            height={barHeight}
            fill={point.tint}
            rx={1}
          />
        );
      })}
    </svg>
  );
}

function CheckInChart({ days }) {
  if (days.length < 2) return <p className="muted">Two check-ins and this becomes a chart.</p>;

  const width = 320;
  const height = 140;
  const maxDay = Math.max(...days.map((d) => d.dayNumber), 1);

  const line = (accessor, scale) =>
    days
      .map((day, index) => {
        const x = (day.dayNumber / maxDay) * width;
        const y = height - (accessor(day) / scale) * (height - 10) - 5;
        return `${index === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join(' ');

  return (
    <>
      <svg viewBox={`0 0 ${width} ${height}`} width="100%" height={height} role="img"
        aria-label={`Pain and energy across ${days.length} check-ins.`}>
        <path d={line((d) => d.checkIn?.pain ?? 0, 10)} fill="none" stroke="var(--danger)" strokeWidth="2.5" />
        <path d={line((d) => (d.checkIn?.energy ?? 3) * 2, 10)} fill="none" stroke="var(--success)" strokeWidth="2.5" />
      </svg>
      <div className="row row--wrap tiny">
        <span style={{ color: 'var(--danger)' }}>▬ Pain</span>
        <span style={{ color: 'var(--success)' }}>▬ Energy</span>
        <span>Energy is scaled to the same 0–10 axis as pain.</span>
      </div>
    </>
  );
}

// Photos are excluded from the boot payload — seventy-five of them would make it
// enormous — so this fetches only the ones that exist, one at a time.
function PhotoTimeline({ run, days }) {
  const withPhotos = days.filter((d) => d.hasPhoto || d.photo);
  const [loaded, setLoaded] = useState({});

  useEffect(() => {
    let cancelled = false;

    (async () => {
      for (const day of withPhotos) {
        if (day.photo || loaded[day.dayNumber]) continue;
        try {
          const { photo } = await api.get(`/api/challenge/runs/${run.id}/days/${day.dayNumber}/photo`);
          if (!cancelled && photo) {
            setLoaded((current) => ({ ...current, [day.dayNumber]: photo }));
          }
        } catch {
          // A missing photo is not worth an error banner.
        }
      }
    })();

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [run.id, withPhotos.length]);

  return (
    <Card>
      <SectionTitle
        title="Photo timeline"
        subtitle={withPhotos.length === 0 ? 'No photos yet.' : `${withPhotos.length} photos`}
      />
      {withPhotos.length > 0 && (
        <div className="photo-strip">
          {withPhotos.map((day) => {
            const src = day.photo ?? loaded[day.dayNumber];
            return (
              <figure key={day.dayNumber}>
                {src ? (
                  <img src={src} alt={`Progress photo, day ${day.dayNumber}`} />
                ) : (
                  <div style={{ width: 96, height: 128, borderRadius: 10, background: 'var(--surface-2)' }} />
                )}
                <figcaption>Day {day.dayNumber}</figcaption>
              </figure>
            );
          })}
        </div>
      )}
    </Card>
  );
}
