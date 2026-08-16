// Vocabulary shared by the whole app.
//
// Plain objects rather than classes: these get serialised into the rule set
// stored on the server, so they need to survive a JSON round trip unchanged.

export const TIERS = ['soft', 'medium', 'hard'];

export const TIER_INFO = {
  soft: {
    name: '75 Soft',
    tagline: 'Build the habit. Nothing resets.',
    blurb:
      'One workout a day, sensible hydration, whole foods, ten pages. Miss a day and you simply pick the streak back up tomorrow.',
    rank: 0,
    missPolicy: 'streakBreak',
    startingFreezes: 3,
    completionBonus: 25,
  },
  medium: {
    name: '75 Medium',
    tagline: 'Real demands, humane rules.',
    blurb:
      'A full workout plus a daily walk, a firmer hydration target, one planned treat meal a week. You get grace days instead of a hard reset.',
    rank: 1,
    missPolicy: 'grace',
    startingFreezes: 1,
    completionBonus: 30,
  },
  hard: {
    name: '75 Hard',
    tagline: 'No compromise. Miss a task, start over.',
    blurb:
      'Two workouts a day, one of them outdoors, no treat meals, no alcohol, and a photo every single day. Miss any required task and the run restarts at day one.',
    rank: 2,
    missPolicy: 'restart',
    startingFreezes: 0,
    completionBonus: 40,
  },
};

export const GRACE_DAYS_PER_BLOCK = 1;
export const GRACE_BLOCK_LENGTH = 25;
export const TOTAL_DAYS = 75;

export function gentlerTier(tier) {
  if (tier === 'hard') return 'medium';
  if (tier === 'medium') return 'soft';
  return null;
}

// --- units ------------------------------------------------------------------

export const UNITS = {
  minutes: { step: 5 },
  milliliters: { step: 250 },
  pages: { step: 1 },
  count: { step: 1 },
  yesNo: { step: 1 },
};

export function formatAmount(value, unit) {
  const n = Number(value) || 0;
  switch (unit) {
    case 'minutes':
      return `${Math.round(n)} min`;
    case 'milliliters':
      return formatVolume(n);
    case 'pages':
      return `${Math.round(n)} ${Math.round(n) === 1 ? 'page' : 'pages'}`;
    case 'yesNo':
      return n >= 1 ? 'Done' : 'Not yet';
    default:
      return String(Math.round(n));
  }
}

export function usesImperial() {
  if (typeof navigator === 'undefined') return false;
  const locale = navigator.language || 'en-GB';
  // The US is the only place where "a gallon of water" reads as a unit rather
  // than a translation problem.
  return /-US$/i.test(locale);
}

export function formatVolume(milliliters) {
  if (usesImperial()) {
    const oz = milliliters / 29.5735;
    if (oz >= 128) return `${(oz / 128).toFixed(2)} gal`;
    return `${Math.round(oz)} oz`;
  }
  if (milliliters >= 1000) return `${(milliliters / 1000).toFixed(1)} L`;
  return `${Math.round(milliliters)} ml`;
}

export function glassesFor(milliliters, glassSize = 250) {
  return Math.round(milliliters / glassSize);
}

// --- person -----------------------------------------------------------------

export const MOBILITY_LEVELS = [
  {
    id: 'unrestricted',
    name: 'No real limits',
    detail: 'You can walk, climb stairs and get up from the floor without help.',
    allowsFloorWork: true,
    needsSeatedOptions: false,
  },
  {
    id: 'mild',
    name: 'Some stiffness or slower going',
    detail: 'You get around fine but joints complain, or you need a moment to get going.',
    allowsFloorWork: true,
    needsSeatedOptions: false,
  },
  {
    id: 'moderate',
    name: 'Standing and stairs are hard',
    detail: 'Long standing, stairs or getting off the floor is genuinely difficult.',
    allowsFloorWork: false,
    needsSeatedOptions: true,
  },
  {
    id: 'walkingAid',
    name: 'I use a cane, walker or rollator',
    detail: 'You rely on a device for walking distance or stability.',
    allowsFloorWork: false,
    needsSeatedOptions: true,
  },
  {
    id: 'seated',
    name: 'I exercise seated or use a wheelchair',
    detail: 'Your workouts happen from a chair or wheelchair.',
    allowsFloorWork: false,
    needsSeatedOptions: true,
  },
];

export const mobilityInfo = (id) => MOBILITY_LEVELS.find((m) => m.id === id) ?? MOBILITY_LEVELS[0];

export const PAIN_LEVELS = [
  { id: 'none', name: 'None', multiplier: 1.0 },
  { id: 'mild', name: 'Mild — noticeable, not limiting', multiplier: 0.9 },
  { id: 'moderate', name: 'Moderate — it changes what I do', multiplier: 0.7 },
  { id: 'severe', name: 'Severe — it stops me', multiplier: 0.5 },
];

export const painInfo = (id) => PAIN_LEVELS.find((p) => p.id === id) ?? PAIN_LEVELS[0];

// Age bands. Used for duration floors, fluid targets and whether balance work
// is added — never to tell someone what they are too old to attempt.
export const AGE_BANDS = [
  { id: 'under40', name: 'Under 40', max: 39, duration: 1.0, fluidMlPerKg: 35, balance: false, protein: false, scaleFloor: 0.4 },
  { id: '40to54', name: '40–54', max: 54, duration: 1.0, fluidMlPerKg: 35, balance: false, protein: false, scaleFloor: 0.4 },
  { id: '55to69', name: '55–69', max: 69, duration: 0.9, fluidMlPerKg: 33, balance: true, protein: true, scaleFloor: 0.45 },
  { id: '70to79', name: '70–79', max: 79, duration: 0.75, fluidMlPerKg: 31, balance: true, protein: true, scaleFloor: 0.5 },
  { id: '80plus', name: '80+', max: Infinity, duration: 0.6, fluidMlPerKg: 30, balance: true, protein: true, scaleFloor: 0.5 },
];

export function ageBand(age) {
  return AGE_BANDS.find((band) => age <= band.max) ?? AGE_BANDS[AGE_BANDS.length - 1];
}

// A deliberately short, high-signal list. Each entry earns its place by
// changing a number somewhere in the plan.
export const HEALTH_CONSIDERATIONS = [
  {
    id: 'heartCondition',
    name: 'Heart condition',
    capsIntensity: true,
    note: 'Effort stays conversational. Stop for chest pressure, unusual breathlessness or palpitations.',
  },
  {
    id: 'highBloodPressure',
    name: 'High blood pressure',
    capsIntensity: true,
    note: 'Avoid holding your breath under effort. Change position slowly.',
  },
  {
    id: 'diabetes',
    name: 'Diabetes',
    note: 'Carry fast-acting glucose and check levels before and after longer sessions.',
  },
  {
    id: 'asthmaCopd',
    name: 'Asthma or COPD',
    capsIntensity: true,
    note: 'Keep your reliever inhaler with you and warm up longer in cold air.',
  },
  {
    id: 'arthritis',
    name: 'Arthritis',
    lowImpact: true,
    note: 'Sore-but-settling within an hour is fine. Sharp or lingering joint pain is not.',
  },
  {
    id: 'osteoporosis',
    name: 'Osteoporosis or low bone density',
    lowImpact: true,
    indoorSafer: true,
    note: 'No spinal flexion under load, no twisting crunches, and balance work stays next to a support.',
  },
  {
    id: 'backIssue',
    name: 'Back or disc problem',
    lowImpact: true,
    note: 'Hinge from the hips, avoid loaded rounding of the lower back.',
  },
  {
    id: 'jointReplacement',
    name: 'Joint replacement',
    lowImpact: true,
    note: 'Respect the range-of-motion limits from your surgeon, especially deep hip flexion.',
  },
  {
    id: 'kidneyDisease',
    name: 'Kidney disease',
    capsHydration: true,
    note: 'Your fluid target is capped and needs to come from your clinician, not from a challenge rule.',
  },
  {
    id: 'heartFailure',
    name: 'Heart failure',
    capsHydration: true,
    capsIntensity: true,
    note: 'Your fluid target is capped and needs to come from your clinician, not from a challenge rule.',
  },
  {
    id: 'fluidRestriction',
    name: "I've been told to limit fluids",
    capsHydration: true,
    note: 'Your fluid target is capped and needs to come from your clinician, not from a challenge rule.',
  },
  {
    id: 'dizziness',
    name: 'Dizziness or fainting spells',
    capsIntensity: true,
    indoorSafer: true,
    note: 'Change position slowly and keep a hand on something stable for balance work.',
  },
  {
    id: 'neuropathy',
    name: 'Numbness in feet or hands',
    lowImpact: true,
    indoorSafer: true,
    note: 'Check your feet daily and choose stable surfaces over uneven ground.',
  },
  {
    id: 'recentSurgery',
    name: 'Surgery in the last 3 months',
    lowImpact: true,
    capsIntensity: true,
    indoorSafer: true,
    note: 'Stay inside whatever limits your surgeon gave you — this app does not override them.',
  },
  {
    id: 'pregnancy',
    name: 'Pregnant or recently postpartum',
    lowImpact: true,
    capsIntensity: true,
    note: 'Avoid lying flat on your back after the first trimester and skip anything with a fall risk.',
  },
];

export const considerationInfo = (id) => HEALTH_CONSIDERATIONS.find((c) => c.id === id);

export const EQUIPMENT = [
  { id: 'chair', name: 'A sturdy chair' },
  { id: 'bands', name: 'Resistance bands' },
  { id: 'lightDumbbells', name: 'Light dumbbells' },
  { id: 'heavyDumbbells', name: 'Heavier dumbbells' },
  { id: 'kettlebell', name: 'Kettlebell' },
  { id: 'cardioMachine', name: 'Treadmill or stationary bike' },
  { id: 'pool', name: 'Pool access' },
  { id: 'gym', name: 'Gym membership' },
  { id: 'mat', name: 'Yoga mat' },
  { id: 'pullUpBar', name: 'Pull-up bar' },
];

export const OUTDOOR_ACCESS = [
  { id: 'easy', name: 'Easy — I can get outside daily' },
  { id: 'limited', name: 'Limited — weather or transport gets in the way' },
  { id: 'unavailable', name: 'Not realistic for me' },
];

export const DIETARY = [
  { id: 'vegetarian', name: 'Vegetarian' },
  { id: 'vegan', name: 'Vegan' },
  { id: 'pescatarian', name: 'Pescatarian' },
  { id: 'glutenFree', name: 'Gluten free' },
  { id: 'dairyFree', name: 'Dairy free' },
  { id: 'lowSodium', name: 'Low sodium' },
  { id: 'lowCarb', name: 'Lower carb' },
  { id: 'softTexture', name: 'Easy to chew' },
  { id: 'nutFree', name: 'Nut free' },
  { id: 'halal', name: 'Halal' },
  { id: 'kosher', name: 'Kosher' },
];

export const READING_FORMATS = [
  { id: 'print', name: 'Paper book' },
  { id: 'ebook', name: 'E-reader' },
  { id: 'audiobook', name: 'Audiobook' },
];

export const MEAL_SLOTS = ['breakfast', 'lunch', 'dinner', 'snack'];

export const SLOT_NAMES = {
  breakfast: 'Breakfast',
  lunch: 'Lunch',
  dinner: 'Dinner',
  snack: 'Snack',
};

// Roughly the order you walk a supermarket in, so the list sorts usefully.
export const AISLES = [
  { id: 'produce', name: 'Produce', order: 0 },
  { id: 'bakery', name: 'Bakery', order: 1 },
  { id: 'meatAndFish', name: 'Meat & fish', order: 2 },
  { id: 'dairyAndEggs', name: 'Dairy & eggs', order: 3 },
  { id: 'grains', name: 'Grains & bread', order: 4 },
  { id: 'pantry', name: 'Pantry', order: 5 },
  { id: 'spices', name: 'Herbs & spices', order: 6 },
  { id: 'frozen', name: 'Frozen', order: 7 },
  { id: 'other', name: 'Other', order: 8 },
];

export const aisleInfo = (id) => AISLES.find((a) => a.id === id) ?? AISLES[AISLES.length - 1];

export const REWARD_CATEGORIES = [
  { id: 'rest', name: 'Rest & recovery' },
  { id: 'treat', name: 'Small treat' },
  { id: 'experience', name: 'Experience' },
  { id: 'gear', name: 'Gear' },
  { id: 'social', name: 'People' },
  { id: 'milestone', name: 'Milestone' },
];

// --- profile helpers --------------------------------------------------------

export function emptyProfile() {
  const year = new Date().getFullYear();
  return {
    name: '',
    birthYear: year - 45,
    weightKg: 75,
    heightCm: 170,
    usesMetric: !usesImperial(),
    mobility: 'unrestricted',
    jointPain: 'none',
    balanceConfidence: 4,
    hasFallenInLastYear: false,
    continuousStandingMinutes: 30,
    considerations: [],
    clinicianCleared: false,
    equipment: [],
    outdoorAccess: 'easy',
    availableMinutesPerDay: 90,
    preferredStartHour: 7,
    preferredWindDownHour: 21,
    dietary: [],
    readingFormat: 'print',
    whyStatement: '',
    wantsLargeText: false,
    wantsReducedMotion: false,
  };
}

export function ageOf(profile) {
  return Math.max(0, new Date().getFullYear() - (profile.birthYear || 0));
}

export function bandOf(profile) {
  return ageBand(ageOf(profile));
}

const anyConsideration = (profile, key) =>
  (profile.considerations ?? []).some((id) => considerationInfo(id)?.[key]);

export const capsHydration = (profile) => anyConsideration(profile, 'capsHydration');
export const capsIntensity = (profile) => anyConsideration(profile, 'capsIntensity');
export const indoorSafer = (profile) => anyConsideration(profile, 'indoorSafer');

export function needsLowImpact(profile) {
  if (anyConsideration(profile, 'lowImpact')) return true;
  return profile.jointPain === 'moderate' || profile.jointPain === 'severe';
}

// Whether solo sessions on uneven outdoor ground are a genuine fall risk.
export function isFallRisk(profile) {
  if (profile.hasFallenInLastYear) return true;
  if ((profile.balanceConfidence ?? 5) <= 2) return true;
  if (profile.mobility === 'walkingAid' || profile.mobility === 'seated') return true;
  return indoorSafer(profile);
}

export function shouldPromptClinician(profile) {
  if (profile.clinicianCleared) return false;
  if (ageOf(profile) >= 65) return true;
  if ((profile.considerations ?? []).length > 0) return true;
  return profile.mobility !== 'unrestricted';
}

export function safetyNotes(profile) {
  return (profile.considerations ?? [])
    .map((id) => considerationInfo(id)?.note)
    .filter(Boolean);
}

export function displayName(profile) {
  const trimmed = (profile?.name ?? '').trim();
  return trimmed || 'Friend';
}
