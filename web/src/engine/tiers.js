import {
  TIER_INFO,
  HEALTH_CONSIDERATIONS,
  bandOf,
  painInfo,
  isFallRisk,
  shouldPromptClinician,
  ageOf,
} from './constants.js';
import { dailyFluidTarget } from './hydration.js';
import { outdoorPolicy, OUTDOOR_POLICIES, safetyFlags } from './mobility.js';

// Turns a tier plus a person into a concrete, safe daily rule set.
//
// Every adjustment records a plain-language reason, which the app shows back to
// the user. Nobody should have to guess why their workout says 28 minutes when
// the internet says 45.

const BASELINES = {
  hard: {
    primaryMinutes: 45,
    secondaryMinutes: 45,
    readingPages: 10,
    requiresPhoto: true,
    secondIsOutdoor: true,
    diet: 'No treat meals, no alcohol. Pick a plan and hold it.',
    reflection: false,
  },
  medium: {
    primaryMinutes: 45,
    secondaryMinutes: 20,
    readingPages: 10,
    requiresPhoto: true,
    secondIsOutdoor: false,
    diet: 'Whole foods by default. One planned treat meal a week, no alcohol on training days.',
    reflection: true,
  },
  soft: {
    primaryMinutes: 45,
    secondaryMinutes: null,
    readingPages: 10,
    requiresPhoto: false,
    secondIsOutdoor: false,
    diet: 'Mostly whole foods, protein at every meal, alcohol only on occasions.',
    reflection: true,
  },
};

const roundTo5 = (value) => Math.round(value / 5) * 5;

const HEALTH_INDEX = Object.fromEntries(HEALTH_CONSIDERATIONS.map((c) => [c.id, c]));

export function buildRules(tier, profile) {
  const base = BASELINES[tier] ?? BASELINES.medium;
  const rules = [];
  const globalNotes = [];

  const flags = safetyFlags(profile);
  const policyId = outdoorPolicy(profile);
  const policy = OUTDOOR_POLICIES[policyId];

  // --- duration adaptation --------------------------------------------------
  const band = bandOf(profile);
  const painMultiplier = painInfo(profile.jointPain).multiplier;
  const durationNotes = [];

  if (band.duration < 1) {
    durationNotes.push(
      `Shortened for the ${band.name} band — same stimulus, less accumulated joint load.`
    );
  }
  if (painMultiplier < 1) {
    durationNotes.push(
      `Shortened again for ${painInfo(profile.jointPain).name.toLowerCase()} joint pain.`
    );
  }

  let primary = Math.max(15, roundTo5(base.primaryMinutes * band.duration * painMultiplier));
  let secondary =
    base.secondaryMinutes === null
      ? null
      : Math.max(10, roundTo5(base.secondaryMinutes * band.duration * painMultiplier));

  // --- time budget ----------------------------------------------------------
  // Never prescribe more movement than the person told us they have. 25 minutes
  // is held back for reading, meals and the photo.
  const available = profile.availableMinutesPerDay ?? 90;
  const movementBudget = Math.max(20, available - 25);
  const requested = primary + (secondary ?? 0);

  if (requested > movementBudget) {
    const scale = movementBudget / requested;
    primary = Math.max(15, roundTo5(primary * scale));
    if (secondary !== null) secondary = Math.max(10, roundTo5(secondary * scale));
    durationNotes.push(
      `Trimmed to fit the ${available} minutes a day you said you actually have.`
    );
    globalNotes.push('Your plan is sized to your real schedule. A plan you can finish beats a plan you admire.');
  }

  // --- splitting ------------------------------------------------------------
  // Someone who can stand for 10 minutes should not be handed a 45-minute block.
  const standing = profile.continuousStandingMinutes ?? 30;
  let splits = 1;
  if (standing > 0 && primary > standing) {
    splits = Math.min(4, Math.ceil(primary / Math.max(5, standing)));
    if (splits > 1) {
      durationNotes.push(
        `Split into ${splits} chunks because you told us you can keep going for about ${standing} minutes at a time. Broken-up movement counts exactly the same.`
      );
    }
  }

  // --- 1. primary workout ---------------------------------------------------
  rules.push({
    id: 'workout.primary',
    kind: 'workout',
    title: 'Main workout',
    detail:
      policyId === 'indoors' || !base.secondIsOutdoor
        ? 'Your choice of modality. Effort matters more than the exercise.'
        : 'Indoors or out — the second session is the one that has to be outside.',
    target: primary,
    unit: 'minutes',
    required: true,
    partialCredit: true,
    xp: 30,
    maxSplits: splits,
    adaptations: [...durationNotes],
    safetyFlags: flags,
  });

  // --- 2. second session ----------------------------------------------------
  if (secondary !== null) {
    const secondaryNotes = [...durationNotes];
    let title = 'Second session';
    let detail = policy.detail;
    let kind = 'outdoorWorkout';

    if (policyId === 'fullyOutdoor') {
      title = 'Outdoor session';
    } else if (policyId === 'withConditions') {
      title = 'Outdoor session';
      secondaryNotes.push(
        'Bad conditions move this indoors without breaking your streak. Ice and heatwaves are not character tests.'
      );
    } else if (policyId === 'doorstep') {
      title = 'Fresh-air session';
      secondaryNotes.push(
        'Rewritten as a doorstep session — you told us balance or footing is a concern, and a fall would end this challenge far faster than a missed walk.'
      );
    } else {
      kind = 'workout';
      detail = 'Indoors. Open a window or step outside for a few minutes either side.';
      secondaryNotes.push(
        "The outdoor requirement became an indoor one because getting outside daily isn't realistic for you."
      );
    }

    rules.push({
      id: 'workout.secondary',
      kind,
      title,
      detail,
      target: secondary,
      unit: 'minutes',
      required: true,
      partialCredit: true,
      xp: 25,
      maxSplits: Math.max(1, splits - 1),
      adaptations: secondaryNotes,
      safetyFlags: flags,
    });
  } else {
    // Soft tier still gets outside, just without a duration demand.
    rules.push({
      id: 'outdoor.presence',
      kind: 'outdoorWorkout',
      title: 'Get outside',
      detail: policy.detail,
      target: 10,
      unit: 'minutes',
      required: true,
      partialCredit: true,
      xp: 15,
      maxSplits: 2,
      adaptations: ['75 Soft asks for fresh air rather than a second workout.'],
      safetyFlags: [],
    });
  }

  // --- 3. balance and bone work ---------------------------------------------
  // The highest-value addition for an older participant, and the original
  // challenge contains nothing that trains balance.
  if (band.balance || isFallRisk(profile) || (profile.considerations ?? []).includes('osteoporosis')) {
    const reason = isFallRisk(profile)
      ? 'Added and prioritised: you flagged unsteadiness or a fall in the last year.'
      : 'Added because balance is what protects independence — and the original challenge has nothing in it that trains balance.';

    rules.push({
      id: 'balance.daily',
      kind: 'balanceWork',
      title: 'Balance & steadiness',
      detail: 'Heel-to-toe stands, weight shifts, sit-to-stands. One hand on a counter throughout.',
      target: 5,
      unit: 'minutes',
      required: tier !== 'soft',
      partialCredit: true,
      xp: 20,
      maxSplits: 2,
      adaptations: [reason],
      safetyFlags: ["Always within arm's reach of a solid support."],
    });
  }

  // --- 4. hydration ---------------------------------------------------------
  const hydration = dailyFluidTarget(profile, tier);
  rules.push({
    id: 'hydration',
    kind: 'hydration',
    title: 'Water',
    detail: `${hydration.glasses} glasses across the day. Sip steadily rather than catching up at night.`,
    target: hydration.targetMl,
    unit: 'milliliters',
    required: true,
    partialCredit: true,
    xp: 20,
    maxSplits: hydration.glasses,
    adaptations: hydration.notes,
    safetyFlags: hydration.needsClinician
      ? ['Confirm this number with your clinician before following it.']
      : [],
  });
  if (hydration.capped) {
    globalNotes.push('Your water target is capped for safety. That is not a lesser version of the challenge.');
  }

  // --- 5. nutrition ---------------------------------------------------------
  const dietNotes = [];
  if (band.protein) {
    dietNotes.push(
      `Aim for about ${Math.round((profile.weightKg || 70) * 1.2)} g of protein daily. Muscle is harder to keep after 55 and protein is the lever.`
    );
  }
  if ((profile.considerations ?? []).includes('diabetes')) {
    dietNotes.push('Keep carbohydrate steady across meals rather than saving it for the evening.');
  }
  if ((profile.dietary ?? []).includes('lowSodium')) {
    dietNotes.push('Recipes are filtered to the lower-sodium set.');
  }

  rules.push({
    id: 'nutrition',
    kind: 'nutrition',
    title: 'Stick to the plan',
    detail: base.diet,
    target: 1,
    unit: 'yesNo',
    required: true,
    partialCredit: false,
    xp: 30,
    maxSplits: 1,
    adaptations: dietNotes,
    safetyFlags: [],
  });

  // --- 6. reading -----------------------------------------------------------
  const isAudio = profile.readingFormat === 'audiobook';
  rules.push({
    id: 'reading',
    kind: 'reading',
    title: 'Read',
    detail: isAudio
      ? 'Fifteen minutes of non-fiction listening.'
      : 'Non-fiction. Something that changes how you do things.',
    target: isAudio ? 15 : base.readingPages,
    unit: isAudio ? 'minutes' : 'pages',
    required: true,
    partialCredit: true,
    xp: 20,
    maxSplits: 3,
    adaptations: isAudio
      ? ["Converted from pages to minutes because you're listening. Fifteen minutes is roughly ten pages."]
      : [],
    safetyFlags: [],
  });

  // --- 7. progress photo ----------------------------------------------------
  if (base.requiresPhoto) {
    rules.push({
      id: 'photo',
      kind: 'progressPhoto',
      title: 'Progress photo',
      detail: 'Same spot, same light. Only you can see it.',
      target: 1,
      unit: 'yesNo',
      required: tier === 'hard',
      partialCredit: false,
      xp: 10,
      maxSplits: 1,
      adaptations: [],
      safetyFlags: [],
    });
  }

  // --- 8. reflection --------------------------------------------------------
  if (base.reflection) {
    rules.push({
      id: 'reflection',
      kind: 'reflection',
      title: 'One line about today',
      detail: "What worked, what hurt, what you'd change tomorrow.",
      target: 1,
      unit: 'yesNo',
      required: false,
      partialCredit: false,
      xp: 10,
      maxSplits: 1,
      adaptations: [],
      safetyFlags: [],
    });
  }

  // --- global notes ---------------------------------------------------------
  if (shouldPromptClinician(profile)) {
    globalNotes.push(
      "Talk to your doctor before you start. This app adapts the plan, it doesn't know your medical history."
    );
  }
  if (splits > 1) {
    globalNotes.push('Broken-up movement counts. Three short walks are not a worse version of one long one.');
  }
  if (tier === 'hard' && (ageOf(profile) >= 70 || profile.mobility !== 'unrestricted')) {
    globalNotes.push(
      "75 Hard's zero-tolerance restart rule is brutal by design. If it starts costing you sleep or pushing you through pain, stepping down to 75 Medium is a strategy, not a failure."
    );
  }

  return { version: 1, tier, generatedAt: new Date().toISOString(), rules, globalNotes };
}

export const requiredRules = (ruleSet) => (ruleSet?.rules ?? []).filter((rule) => rule.required);
export const findRule = (ruleSet, id) => (ruleSet?.rules ?? []).find((rule) => rule.id === id);

// --- recommendation ---------------------------------------------------------

// Advice, not a gate. The user can always override.
export function recommendTier(profile) {
  let score = 0;
  const reasons = [];
  const cautions = [];

  const band = bandOf(profile);
  score += { under40: 2, '40to54': 1, '55to69': 0, '70to79': -1, '80plus': -2 }[band.id] ?? 0;
  score += { unrestricted: 1, mild: 0, moderate: -1, walkingAid: -2, seated: -2 }[profile.mobility] ?? 0;
  score += { none: 1, mild: 0, moderate: -1, severe: -2 }[profile.jointPain] ?? 0;

  const serious = (profile.considerations ?? [])
    .map((id) => HEALTH_INDEX[id])
    .filter((info) => info && (info.capsIntensity || info.capsHydration));
  if (serious.length > 0) {
    score -= serious.length;
    cautions.push(
      `You flagged ${serious.map((info) => info.name).join(', ')}. The plan is capped accordingly.`
    );
  }

  const available = profile.availableMinutesPerDay ?? 90;
  if (available >= 100) {
    score += 1;
    reasons.push(`You have ${available} minutes a day, which is enough for a two-session tier.`);
  } else if (available < 60) {
    score -= 1;
    reasons.push('Under an hour a day realistically supports one solid session, not two.');
  }

  if (isFallRisk(profile)) {
    score -= 1;
    cautions.push('Fall risk moves the outdoor requirement to level, familiar ground.');
  }

  const tier = score >= 4 ? 'hard' : score >= 1 ? 'medium' : 'soft';

  if (tier === 'hard') {
    reasons.unshift('Nothing in your answers argues against the full version.');
  } else if (tier === 'medium') {
    reasons.unshift(
      '75 Medium gives you real demands and a grace day, which is the difference between finishing and restarting.'
    );
  } else {
    reasons.unshift(
      '75 Soft is the right starting point — it never resets you to day one, so a bad day costs a day rather than ten weeks.'
    );
  }

  if (band.id === '70to79' || band.id === '80plus') {
    reasons.push(
      `At ${ageOf(profile)}, consistency over 75 days is worth far more than intensity in any single one of them.`
    );
  }

  return { tier, headline: `We'd start you on ${TIER_INFO[tier].name}`, reasons, cautions };
}
