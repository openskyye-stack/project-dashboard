import { bandOf, capsHydration, ageOf, glassesFor } from './constants.js';

// Works out a daily fluid target that is defensible for the person in front of
// us rather than copying "one gallon" onto everybody.
//
// The classic 75 Hard rule is a US gallon (3785 ml) regardless of body size,
// age, climate or kidney function. For a 55 kg eighty-year-old on a diuretic
// that is not a challenge, it is a hyponatraemia risk. So the target is built
// from body weight and age, nudged by tier, then hard-capped by any condition
// that limits fluids.

// Healthy kidneys clear roughly 0.8–1.0 L/hour. Sustained intake past this
// offers nothing, so nobody is ever asked for more.
export const ABSOLUTE_CEILING_ML = 4000;

// Applied when a condition or medication limits fluid intake. Deliberately
// conservative — the real number has to come from a clinician.
export const RESTRICTED_CEILING_ML = 1500;

const TIER_MULTIPLIER = { hard: 1.15, medium: 1.05, soft: 1.0 };

export function dailyFluidTarget(profile, tier) {
  const notes = [];
  const band = bandOf(profile);
  const perKg = band.fluidMlPerKg;
  const weight = profile.weightKg || 70;

  let target = weight * perKg;
  notes.push(`Based on ${perKg} ml per kg at ${Math.round(weight)} kg.`);

  const multiplier = TIER_MULTIPLIER[tier] ?? 1;
  target *= multiplier;
  if (tier === 'hard') notes.push('75 Hard adds 15% on top.');
  else if (tier === 'medium') notes.push('75 Medium adds 5% on top.');
  else notes.push('75 Soft keeps the baseline target.');

  // Reduced mobility usually means lower sweat losses across the day.
  if (profile.mobility === 'seated' || profile.mobility === 'walkingAid') {
    target *= 0.92;
    notes.push('Trimmed slightly for lower daily sweat loss.');
  }

  let capped = false;
  let needsClinician = false;

  if (capsHydration(profile)) {
    target = Math.min(target, RESTRICTED_CEILING_ML);
    capped = true;
    needsClinician = true;
    notes.push(
      'Capped because you told us your fluids are limited. Replace this number with the one your clinician gives you.'
    );
  }

  if (target > ABSOLUTE_CEILING_ML) {
    target = ABSOLUTE_CEILING_ML;
    capped = true;
    notes.push('Capped at 4 L — more than this does nothing useful.');
  }

  // Round to whole 250 ml glasses so the tracker is tappable.
  target = Math.max(1000, Math.round(target / 250) * 250);

  if (ageOf(profile) >= 65 && !capsHydration(profile)) {
    notes.push(
      'Thirst gets less reliable with age, so drink to the schedule rather than waiting to feel thirsty.'
    );
  }

  return { targetMl: target, notes, capped, needsClinician, glasses: glassesFor(target) };
}

// Evenly spaced reminder times between waking and wind-down, stopping two hours
// early so nobody is up at 3am because an app told them to drink at 9pm.
export function reminderHours(profile, glasses) {
  const start = Math.max(5, Math.min(profile.preferredStartHour ?? 7, 11));
  const end = Math.max(start + 3, (profile.preferredWindDownHour ?? 21) - 2);
  const count = Math.min(Math.max(3, Math.floor(glasses / 2)), 8);

  if (count <= 1) return [start];

  const span = end - start;
  return Array.from({ length: count }, (_, index) =>
    start + Math.round((span * index) / (count - 1))
  );
}
