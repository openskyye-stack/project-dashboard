import { TIER_INFO, TOTAL_DAYS, GRACE_DAYS_PER_BLOCK, GRACE_BLOCK_LENGTH } from './constants.js';
import { requiredRules } from './tiers.js';
import { ACHIEVEMENTS } from '../data/achievements.js';

// --- dates ------------------------------------------------------------------
//
// Everything is keyed on a local YYYY-MM-DD string rather than a Date. Two
// reasons: a challenge day is a calendar day wherever you are, not a UTC
// instant, and string comparison of ISO dates is already chronological.

export function todayKey(date = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function addDays(dateKey, days) {
  const [y, m, d] = dateKey.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  date.setDate(date.getDate() + days);
  return todayKey(date);
}

export function daysBetween(fromKey, toKey) {
  const [fy, fm, fd] = fromKey.split('-').map(Number);
  const [ty, tm, td] = toKey.split('-').map(Number);
  const from = new Date(fy, fm - 1, fd);
  const to = new Date(ty, tm - 1, td);
  return Math.round((to - from) / 86400000);
}

export function dayNumberFor(run, dateKey = todayKey()) {
  const diff = daysBetween(run.startDate, dateKey);
  if (diff < 0 || diff >= (run.totalDays ?? TOTAL_DAYS)) return null;
  return diff + 1;
}

export const dateForDay = (run, dayNumber) => addDays(run.startDate, dayNumber - 1);

// --- day evaluation ---------------------------------------------------------

export function entryFraction(entry, target) {
  if (!entry) return 0;
  if (entry.done) return 1;
  if (!target) return 0;
  return Math.min(1, (entry.value ?? 0) / target);
}

export const entrySatisfied = (entry, target) =>
  Boolean(entry?.done) || (target > 0 && (entry?.value ?? 0) >= target);

export function isDayComplete(day, ruleSet) {
  if (!day) return false;
  if (day.usedFreeze) return true;

  const required = requiredRules(ruleSet);
  if (required.length === 0) return false;

  return required.every((rule) => entrySatisfied(day.entries?.[rule.id], targetFor(day, rule)));
}

export function dayCompletionFraction(day, ruleSet) {
  const required = requiredRules(ruleSet);
  if (required.length === 0 || !day) return 0;

  const total = required.reduce(
    (sum, rule) => sum + entryFraction(day.entries?.[rule.id], targetFor(day, rule)),
    0
  );
  return Math.min(1, total / required.length);
}

// A day stores the target it was actually judged against, so re-adapting the
// plan later never retroactively fails a day someone already finished.
export function targetFor(day, rule) {
  const stored = day?.entries?.[rule.id]?.target;
  return stored ?? rule.target;
}

export const isPastDay = (day) => day.date < todayKey();

export const isMissed = (day, ruleSet) =>
  isPastDay(day) && !day.isComplete && !isDayComplete(day, ruleSet);

export const needsMissResolution = (day, ruleSet) => !day.missAcknowledged && isMissed(day, ruleSet);

// --- streaks ----------------------------------------------------------------

export function summarise(run, days) {
  const sorted = [...days].sort((a, b) => a.dayNumber - b.dayNumber);

  let longest = 0;
  let running = 0;
  let missed = 0;
  let freezesUsed = 0;

  for (const day of sorted) {
    if (day.isComplete) {
      running += 1;
      longest = Math.max(longest, running);
      if (day.usedFreeze) freezesUsed += 1;
    } else if (isPastDay(day)) {
      missed += 1;
      running = 0;
    }
  }

  // The current streak runs backwards from the most recent settled day. Today
  // being unfinished doesn't break anything yet — the day isn't over.
  let current = 0;
  for (let i = sorted.length - 1; i >= 0; i -= 1) {
    const day = sorted[i];
    if (day.isComplete) current += 1;
    else if (day.date === todayKey()) continue;
    else break;
  }

  const completed = sorted.filter((d) => d.isComplete).length;
  const settled = sorted.filter((d) => d.isComplete || isPastDay(d)).length;

  return {
    current,
    longest: Math.max(longest, run?.longestStreak ?? 0),
    completedDays: completed,
    missedDays: missed,
    freezesUsed,
    completionRate: settled > 0 ? completed / settled : 0,
  };
}

export function totalGraceDays(run) {
  const policy = TIER_INFO[run.tier]?.missPolicy;
  if (policy === 'restart') return 0;
  if (policy === 'streakBreak') return run.totalDays ?? TOTAL_DAYS;
  return GRACE_DAYS_PER_BLOCK * Math.ceil((run.totalDays ?? TOTAL_DAYS) / GRACE_BLOCK_LENGTH);
}

// What the app should do about a day that ended incomplete.
export function resolveMiss(run, days, missedDay) {
  const policy = TIER_INFO[run.tier]?.missPolicy;

  if (policy === 'streakBreak') return { kind: 'streakBroken' };
  if (policy === 'restart') return { kind: 'restart', daysLost: Math.max(0, missedDay.dayNumber - 1) };

  const used = days.filter((d) => d.usedFreeze).length;
  const remaining = Math.max(0, totalGraceDays(run) - used);
  return remaining > 0
    ? { kind: 'grace', remaining }
    : { kind: 'restart', daysLost: Math.max(0, missedDay.dayNumber - 1) };
}

// --- XP and levels ----------------------------------------------------------

// Deliberately front-loaded: the first few levels come fast, because that is
// when people quit.
export const LEVELS = [
  { minXp: 0, title: 'Starting Out' },
  { minXp: 100, title: 'Showing Up' },
  { minXp: 300, title: 'Building' },
  { minXp: 700, title: 'Consistent' },
  { minXp: 1300, title: 'Steady Hand' },
  { minXp: 2200, title: 'Relentless' },
  { minXp: 3500, title: 'Unshakeable' },
  { minXp: 5200, title: 'Iron Habit' },
  { minXp: 7500, title: 'Veteran' },
  { minXp: 10500, title: 'Legend' },
];

export function levelFor(xp) {
  let index = 0;
  LEVELS.forEach((level, i) => {
    if (xp >= level.minXp) index = i;
  });

  const ceiling = index + 1 < LEVELS.length ? LEVELS[index + 1].minXp : null;
  const floor = LEVELS[index].minXp;

  return {
    index: index + 1,
    title: LEVELS[index].title,
    xp,
    floor,
    ceiling,
    progress: ceiling ? (xp - floor) / (ceiling - floor) : 1,
    xpToNext: ceiling ? Math.max(0, ceiling - xp) : null,
  };
}

// Capped so a long streak doesn't make early days feel worthless, and a break
// doesn't feel catastrophic.
export function streakMultiplier(streak) {
  if (streak >= 50) return 1.75;
  if (streak >= 30) return 1.6;
  if (streak >= 14) return 1.4;
  if (streak >= 7) return 1.25;
  if (streak >= 3) return 1.1;
  return 1;
}

// XP is awarded for what you did, not for what the plan said. A deload day
// completed in full is worth full credit — that is the whole point of the
// adaptive design.
export function awardForDay(day, ruleSet, streak, tier) {
  let taskXp = 0;

  for (const rule of ruleSet.rules ?? []) {
    const entry = day.entries?.[rule.id];
    if (!entry) continue;
    const target = targetFor(day, rule);

    if (entrySatisfied(entry, target)) {
      taskXp += rule.xp;
    } else if (rule.partialCredit) {
      taskXp += Math.floor(rule.xp * entryFraction(entry, target) * 0.5);
    }
  }

  const complete = isDayComplete(day, ruleSet);
  const bonus = complete ? TIER_INFO[tier]?.completionBonus ?? 25 : 0;
  const multiplier = complete ? streakMultiplier(streak) : 1;

  // Coins are the reward currency and are only earned on complete days, so the
  // shop can't be farmed by half-finishing eight days in a row.
  let coins = 0;
  if (complete) {
    coins = 10;
    if (day.dayNumber % 7 === 0) coins += 15;
    if (day.scaleFactor < 1) coins += 2; // showed up anyway
  }

  return {
    taskXp,
    bonus,
    multiplier,
    totalXp: Math.round((taskXp + bonus) * multiplier),
    coins,
    earnsFreeze: complete && tier !== 'hard' && day.dayNumber % 10 === 0,
  };
}

// --- achievements -----------------------------------------------------------

export function newlyUnlocked({ run, profile, days, unlocked, redemptionCount = 0, plannedMealCount = 0 }) {
  const summary = summarise(run, days);
  const completed = days.filter((d) => d.isComplete);
  const earned = [];

  const check = (code, condition) => {
    if (!unlocked.has(code) && condition) earned.push(code);
  };

  check('first.day', summary.completedDays >= 1);
  check('week.one', summary.current >= 7 || summary.longest >= 7);
  check('day.25', summary.completedDays >= 25);
  check('day.50', summary.completedDays >= 50);
  check('day.75', summary.completedDays >= 75);
  check('streak.14', summary.longest >= 14);
  check('streak.30', summary.longest >= 30);

  check('hydration.perfect.week', hasRunOf(completed, 'hydration', 7));
  check('reading.perfect.week', hasRunOf(completed, 'reading', 7));

  check('deload.hero', completed.some((d) => d.scaleFactor < 1));
  check('deload.veteran', completed.filter((d) => d.scaleFactor <= 0.6).length >= 5);

  check('early.bird', completed.some((d) => d.completedAt && new Date(d.completedAt).getHours() < 9));

  check('meal.planner', plannedMealCount >= 7);
  check('meal.architect', plannedMealCount >= 30);
  check('reward.claimed', redemptionCount >= 1);
  check('photo.streak', longestPhotoRun(days) >= 10);

  check('comeback', (run.attemptNumber ?? 1) >= 2 && summary.completedDays >= 7);
  check(
    'balance.builder',
    completed.filter((d) => d.entries?.['balance.daily']?.done || (d.entries?.['balance.daily']?.value ?? 0) > 0)
      .length >= 20
  );

  check('no.freeze', summary.completedDays >= 30 && summary.freezesUsed === 0);
  check('honest.log', days.filter((d) => d.checkIn).length >= 30);
  check(
    'age.is.a.number',
    profile && new Date().getFullYear() - profile.birthYear >= 65 && summary.completedDays >= 30
  );

  const index = Object.fromEntries(ACHIEVEMENTS.map((a) => [a.code, a]));
  return earned.map((code) => index[code]).filter(Boolean);
}

function hasRunOf(days, ruleId, length) {
  const sorted = [...days].sort((a, b) => a.dayNumber - b.dayNumber);
  let streak = 0;

  for (const day of sorted) {
    const entry = day.entries?.[ruleId];
    if (entry?.done || (entry?.value ?? 0) >= (entry?.target ?? Infinity)) {
      streak += 1;
      if (streak >= length) return true;
    } else {
      streak = 0;
    }
  }
  return false;
}

function longestPhotoRun(days) {
  const sorted = [...days].sort((a, b) => a.dayNumber - b.dayNumber);
  let best = 0;
  let running = 0;

  for (const day of sorted) {
    if (day.hasPhoto || day.photo) {
      running += 1;
      best = Math.max(best, running);
    } else if (isPastDay(day)) {
      running = 0;
    }
  }
  return best;
}
