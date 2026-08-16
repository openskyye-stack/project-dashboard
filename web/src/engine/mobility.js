import {
  mobilityInfo,
  needsLowImpact,
  capsIntensity,
  isFallRisk,
  bandOf,
} from './constants.js';

// Translates a profile into safe, specific movement options.
//
// The design rule: never remove the task, change the shape of it. Someone in a
// wheelchair still does a workout — it becomes a seated circuit, not a walk.
// The challenge stays intact; only the modality moves.

export const EXERCISE_OPTIONS = [
  {
    id: 'walk',
    title: 'Walk',
    detail: 'Steady pace where you can still hold a conversation.',
    seated: false,
    lowImpact: true,
    outdoorCapable: true,
    requires: [],
  },
  {
    id: 'walkIntervals',
    title: 'Walk with pick-ups',
    detail: 'Two minutes easy, one minute brisk, repeated.',
    seated: false,
    lowImpact: true,
    outdoorCapable: true,
    requires: [],
  },
  {
    id: 'chairCircuit',
    title: 'Seated strength circuit',
    detail: 'Seated press, row, leg extension, knee lifts, twists. Three rounds.',
    seated: true,
    lowImpact: true,
    outdoorCapable: true,
    requires: ['chair'],
  },
  {
    id: 'chairCardio',
    title: 'Seated cardio',
    detail: 'Arm circles, seated marching, punches and reaches, kept continuous.',
    seated: true,
    lowImpact: true,
    outdoorCapable: true,
    requires: ['chair'],
  },
  {
    id: 'bandStrength',
    title: 'Resistance band strength',
    detail: 'Row, chest press, pull-apart, seated leg press. Two to three rounds.',
    seated: true,
    lowImpact: true,
    outdoorCapable: false,
    requires: ['bands'],
  },
  {
    id: 'sitToStand',
    title: 'Sit-to-stand sets',
    detail:
      'Stand from a chair without using your hands, sit slowly. The single best predictor of staying independent.',
    seated: false,
    lowImpact: true,
    outdoorCapable: false,
    requires: ['chair'],
  },
  {
    id: 'balanceSupported',
    title: 'Supported balance work',
    detail: 'Heel-to-toe stand, single-leg stand, weight shifts — one hand on a counter.',
    seated: false,
    lowImpact: true,
    outdoorCapable: false,
    requires: [],
  },
  {
    id: 'pool',
    title: 'Pool walking or swimming',
    detail: 'Water takes the load off every joint. Ideal on sore days.',
    seated: false,
    lowImpact: true,
    outdoorCapable: true,
    requires: ['pool'],
  },
  {
    id: 'bike',
    title: 'Stationary bike',
    detail: 'Zero impact, easy to keep conversational.',
    seated: true,
    lowImpact: true,
    outdoorCapable: false,
    requires: ['cardioMachine'],
  },
  {
    id: 'dumbbellFull',
    title: 'Dumbbell full body',
    detail: 'Goblet squat, row, press, hinge, carry.',
    seated: false,
    lowImpact: true,
    outdoorCapable: false,
    requires: ['lightDumbbells'],
  },
  {
    id: 'bodyweight',
    title: 'Bodyweight circuit',
    detail: 'Squats, push-ups, lunges, planks. Three rounds.',
    seated: false,
    lowImpact: false,
    outdoorCapable: true,
    requires: [],
  },
  {
    id: 'mobilityFlow',
    title: 'Mobility flow',
    detail: 'Ankles, hips, thoracic spine, shoulders. Slow and unhurried.',
    seated: false,
    lowImpact: true,
    outdoorCapable: false,
    requires: [],
  },
  {
    id: 'chairYoga',
    title: 'Chair yoga',
    detail: 'Seated sun salutation, spinal twists, gentle hamstring work.',
    seated: true,
    lowImpact: true,
    outdoorCapable: false,
    requires: ['chair'],
  },
  {
    id: 'garden',
    title: 'Gardening or yard work',
    detail: "Counts when it's continuous and you're warm and slightly breathless.",
    seated: false,
    lowImpact: true,
    outdoorCapable: true,
    requires: [],
  },
  {
    id: 'doorstep',
    title: 'Doorstep session',
    detail:
      'The whole workout done on a porch, balcony or just inside an open door. Outdoors without going anywhere.',
    seated: true,
    lowImpact: true,
    outdoorCapable: true,
    requires: [],
  },
];

// A sturdy chair is assumed available to everyone — it is the most useful piece
// of equipment on the list and gating on it would be absurd.
const ASSUMED_EQUIPMENT = new Set(['chair']);

export function exerciseOptions(profile, { outdoorOnly = false } = {}) {
  const owned = new Set(profile.equipment ?? []);
  const mobility = mobilityInfo(profile.mobility);
  const lowImpactOnly = needsLowImpact(profile);
  const fallRisk = isFallRisk(profile);

  return EXERCISE_OPTIONS.filter((option) => {
    if (outdoorOnly && !option.outdoorCapable) return false;
    if (lowImpactOnly && !option.lowImpact) return false;
    if (profile.mobility === 'seated' && !option.seated) return false;
    if (mobility.needsSeatedOptions && option.id === 'bodyweight') return false;
    if (fallRisk && option.id === 'walkIntervals') return false;

    return option.requires
      .filter((item) => !ASSUMED_EQUIPMENT.has(item))
      .every((item) => owned.has(item));
  }).sort((a, b) => score(b, profile) - score(a, profile));
}

function score(option, profile) {
  let total = 0;
  if (mobilityInfo(profile.mobility).needsSeatedOptions && option.seated) total += 3;
  if (needsLowImpact(profile) && option.lowImpact) total += 2;
  if (bandOf(profile).balance && (option.id === 'balanceSupported' || option.id === 'sitToStand')) total += 2;
  if ((profile.equipment ?? []).some((item) => option.requires.includes(item))) total += 1;
  if (option.requires.length === 0) total += 1;
  return total;
}

// How the outdoor requirement should be honoured for this person.
//
// 75 Hard insists one workout is outdoors "regardless of weather". For someone
// with a fall risk on an icy pavement, that rule is how people get hurt — so it
// becomes an outdoor *presence* requirement instead.
export const OUTDOOR_POLICIES = {
  fullyOutdoor: {
    title: 'Outdoors, whatever the weather',
    detail: 'One session happens outside. Rain and cold are part of it.',
  },
  withConditions: {
    title: "Outdoors when it's safe underfoot",
    detail:
      'Outside is the default. Ice, storms or heat warnings move it under cover — that still counts.',
  },
  doorstep: {
    title: 'Doorstep, balcony or sheltered ground',
    detail:
      'Level, familiar ground only. A porch, balcony or covered path counts as outside.',
  },
  indoors: {
    title: 'Indoors, window open',
    detail: 'Fresh air on your face for a few minutes counts. The workout itself stays indoors.',
  },
};

export function outdoorPolicy(profile) {
  if (profile.outdoorAccess === 'unavailable') return 'indoors';
  if (isFallRisk(profile)) return 'doorstep';
  if (profile.outdoorAccess === 'limited') return 'withConditions';
  return 'fullyOutdoor';
}

export function safetyFlags(profile) {
  const flags = [];

  if (capsIntensity(profile)) {
    flags.push('Keep effort conversational — you should be able to speak a full sentence.');
  }
  if (isFallRisk(profile)) {
    flags.push('Stay within reach of something solid. No balance work in open space.');
  }
  if (needsLowImpact(profile)) {
    flags.push('No jumping, running or deep impact. Low-impact movement only.');
  }
  if (!mobilityInfo(profile.mobility).allowsFloorWork) {
    flags.push('Nothing that needs getting down to or up from the floor.');
  }
  if ((profile.considerations ?? []).includes('osteoporosis')) {
    flags.push('No loaded forward bends or twisting sit-ups.');
  }
  if ((profile.considerations ?? []).includes('diabetes')) {
    flags.push('Have fast-acting glucose within reach.');
  }
  if ((profile.considerations ?? []).includes('asthmaCopd')) {
    flags.push('Reliever inhaler on you before you start.');
  }
  return flags;
}

// Shown on every workout card regardless of profile.
export const STOP_SIGNS = [
  'Chest pain, pressure or tightness',
  'Breathlessness out of proportion to the effort',
  'Dizziness, greying vision or feeling faint',
  'New or sharp joint pain, rather than muscle burn',
  'An irregular or racing heartbeat at rest',
];
