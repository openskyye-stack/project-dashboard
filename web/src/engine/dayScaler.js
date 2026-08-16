import { bandOf } from './constants.js';

// The morning check-in, and what the app does with the answers.
//
// This is the piece that makes the challenge survivable for an older body. A
// fixed plan meets a variable body; without a scaling rule, the only options on
// a bad day are "push through and get hurt" or "miss and reset". This adds a
// third: do a smaller version that still counts.

export const NEUTRAL_CHECK_IN = { sleepHours: 7, pain: 0, energy: 3, soreness: 1 };

export const CHECK_IN_QUESTIONS = [
  'How many hours did you sleep?',
  'Worst pain right now, 0 to 10?',
  'Energy today?',
  'How sore are you from yesterday?',
];

export function evaluateCheckIn(checkIn, profile) {
  const { sleepHours, pain, energy, soreness } = { ...NEUTRAL_CHECK_IN, ...checkIn };

  let scale = 1;
  const reasons = [];
  const advice = [];
  let suggestsRest = false;
  let suggestsClinician = false;

  // Pain is the dominant signal.
  if (pain >= 7) {
    scale -= 0.55;
    reasons.push(`pain at ${pain}`);
    suggestsRest = true;
    advice.push('This is a day for gentle range of motion, not training.');
    if (pain >= 8) suggestsClinician = true;
  } else if (pain >= 5) {
    scale -= 0.35;
    reasons.push(`pain at ${pain}`);
    advice.push(
      'Halve the load, keep the habit. Movement usually helps pain at this level — sharp pain is the exception.'
    );
  } else if (pain >= 3) {
    scale -= 0.15;
    reasons.push(`pain at ${pain}`);
    advice.push('Choose a low-impact modality today. Water or a bike if you have them.');
  }

  // Sleep debt.
  if (sleepHours < 5) {
    scale -= 0.2;
    reasons.push("under five hours' sleep");
    advice.push('On short sleep, injury risk climbs and technique slips. Keep it simple and familiar.');
  } else if (sleepHours < 6.5) {
    scale -= 0.1;
    reasons.push('short sleep');
  }

  // Energy.
  if (energy <= 1) {
    scale -= 0.2;
    reasons.push('very low energy');
  } else if (energy === 2) {
    scale -= 0.1;
    reasons.push('low energy');
  } else if (energy === 5 && pain <= 2) {
    advice.push("Good day to take the harder option if you've been coasting.");
  }

  // Soreness.
  if (soreness >= 4) {
    scale -= 0.15;
    reasons.push('heavy soreness');
    advice.push('Work different muscles than yesterday rather than resting completely.');
  }

  // Older bodies deload more and recover slower, so the floor is higher — we'd
  // rather they do 50% than nothing.
  const floor = bandOf(profile).scaleFloor;
  scale = Math.max(floor, Math.min(1, scale));
  scale = Math.round(scale * 20) / 20; // nearest 5%

  if (suggestsClinician) {
    advice.push('Pain at this level for more than a couple of days is worth a phone call to your doctor.');
  }
  if ((profile.considerations ?? []).includes('diabetes') && energy <= 2) {
    advice.push('Check your blood glucose before you train.');
  }

  const headline =
    scale >= 0.98 ? 'Full plan today'
      : scale >= 0.8 ? 'Slightly lighter today'
      : scale >= 0.6 ? 'Deload day'
      : 'Minimum effective day';

  const reason = reasons.length
    ? `Scaled to ${Math.round(scale * 100)}% for ${listPhrase(reasons)}. It still counts as a completed day.`
    : 'Nothing in your check-in suggests holding back.';

  return { scaleFactor: scale, headline, reason, advice, suggestsRest, suggestsClinician };
}

// Applies the day's scale factor to a rule's target.
//
// Hydration and yes/no rules are never scaled: you don't drink less because you
// slept badly, and "stuck to the plan" has no 70% version.
export function scaledTarget(rule, scaleFactor) {
  if (scaleFactor >= 1) return rule.target;

  switch (rule.unit) {
    case 'yesNo':
    case 'milliliters':
      return rule.target;
    case 'minutes':
      return Math.max(5, Math.round((rule.target * scaleFactor) / 5) * 5);
    default:
      return Math.max(1, Math.round(rule.target * scaleFactor));
  }
}

function listPhrase(items) {
  if (items.length === 0) return '';
  if (items.length === 1) return items[0];
  if (items.length === 2) return `${items[0]} and ${items[1]}`;
  return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`;
}
