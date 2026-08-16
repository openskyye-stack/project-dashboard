import { describe, it, expect } from 'vitest';

import { emptyProfile, TIER_INFO } from '../constants.js';
import {
  dailyFluidTarget,
  reminderHours,
  ABSOLUTE_CEILING_ML,
  RESTRICTED_CEILING_ML,
} from '../hydration.js';
import { buildRules, recommendTier, findRule } from '../tiers.js';
import { exerciseOptions, outdoorPolicy } from '../mobility.js';
import { evaluateCheckIn, scaledTarget, NEUTRAL_CHECK_IN } from '../dayScaler.js';
import {
  levelFor,
  streakMultiplier,
  summarise,
  awardForDay,
  isDayComplete,
  todayKey,
  addDays,
  daysBetween,
  dayNumberFor,
  resolveMiss,
} from '../progress.js';
import {
  defaultFilter,
  applyFilter,
  generateWeek,
  buildShoppingList,
  prepSession,
  sessionStandingMinutes,
  sessionTotalMinutes,
  EMPTY_FILTER,
} from '../mealPlanner.js';
import { BUILTIN_RECIPES } from '../../data/recipes.js';

// --- fixtures ---------------------------------------------------------------

function profileOf(overrides = {}) {
  const profile = emptyProfile();
  const { age, ...rest } = overrides;
  if (age !== undefined) profile.birthYear = new Date().getFullYear() - age;
  return { ...profile, ...rest };
}

// --- hydration --------------------------------------------------------------

describe('hydration targets', () => {
  it('never imposes a fixed gallon on a small, older body', () => {
    const result = dailyFluidTarget(profileOf({ age: 78, weightKg: 55 }), 'hard');
    // A US gallon is 3785 ml. 55 kg at 31 ml/kg is ~1705, +15% for Hard.
    expect(result.targetMl).toBeLessThan(2500);
    expect(result.targetMl).toBeGreaterThanOrEqual(1000);
  });

  it('caps fluid-restricted people hard and tells them to ask a clinician', () => {
    const result = dailyFluidTarget(
      profileOf({ age: 70, weightKg: 90, considerations: ['heartFailure'] }),
      'hard'
    );
    expect(result.targetMl).toBeLessThanOrEqual(RESTRICTED_CEILING_ML);
    expect(result.capped).toBe(true);
    expect(result.needsClinician).toBe(true);
  });

  it('never asks anyone for more than four litres', () => {
    const result = dailyFluidTarget(profileOf({ age: 30, weightKg: 200 }), 'hard');
    expect(result.targetMl).toBeLessThanOrEqual(ABSOLUTE_CEILING_ML);
  });

  it('lands every target on a whole number of 250 ml glasses', () => {
    for (let weight = 45; weight <= 140; weight += 5) {
      const result = dailyFluidTarget(profileOf({ weightKg: weight }), 'medium');
      expect(result.targetMl % 250).toBe(0);
    }
  });

  it('scales with tier', () => {
    const person = { age: 45, weightKg: 80 };
    const soft = dailyFluidTarget(profileOf(person), 'soft').targetMl;
    const hard = dailyFluidTarget(profileOf(person), 'hard').targetMl;
    expect(hard).toBeGreaterThan(soft);
  });

  it('stops reminders before wind-down', () => {
    const profile = profileOf({ preferredStartHour: 7, preferredWindDownHour: 21 });
    const hours = reminderHours(profile, 12);
    expect(hours.length).toBeGreaterThanOrEqual(3);
    expect(Math.min(...hours)).toBeGreaterThanOrEqual(7);
    expect(Math.max(...hours)).toBeLessThanOrEqual(19);
  });
});

// --- rule generation --------------------------------------------------------

describe('rule generation', () => {
  it('gives an unrestricted adult on Hard the classic two sessions', () => {
    const rules = buildRules('hard', profileOf({ age: 30, availableMinutesPerDay: 150 }));
    expect(findRule(rules, 'workout.primary').target).toBe(45);
    expect(findRule(rules, 'workout.secondary')).toBeDefined();
  });

  it('shrinks workouts with age and pain but never below fifteen minutes', () => {
    const young = buildRules('hard', profileOf({ age: 30, availableMinutesPerDay: 150 }));
    const old = buildRules(
      'hard',
      profileOf({ age: 82, jointPain: 'severe', availableMinutesPerDay: 60 })
    );

    const youngTarget = findRule(young, 'workout.primary').target;
    const oldTarget = findRule(old, 'workout.primary').target;

    expect(oldTarget).toBeLessThan(youngTarget);
    expect(oldTarget).toBeGreaterThanOrEqual(15);
  });

  it('never exceeds the time the person said they have', () => {
    for (const minutes of [45, 60, 90, 120]) {
      const rules = buildRules('hard', profileOf({ age: 60, availableMinutesPerDay: minutes }));
      const movement = rules.rules
        .filter((r) => r.unit === 'minutes')
        .reduce((sum, r) => sum + r.target, 0);
      expect(movement).toBeLessThanOrEqual(minutes);
    }
  });

  it('splits the session when standing tolerance is short', () => {
    const rules = buildRules('medium', profileOf({ age: 68, continuousStandingMinutes: 10 }));
    expect(findRule(rules, 'workout.primary').maxSplits).toBeGreaterThan(1);
  });

  it('adds balance work for older users and fall risks, but not for a fit thirty-year-old', () => {
    expect(findRule(buildRules('medium', profileOf({ age: 72 })), 'balance.daily')).toBeDefined();
    expect(
      findRule(buildRules('medium', profileOf({ age: 40, hasFallenInLastYear: true })), 'balance.daily')
    ).toBeDefined();
    expect(findRule(buildRules('medium', profileOf({ age: 30 })), 'balance.daily')).toBeUndefined();
  });

  it('explains every adaptation it makes', () => {
    const rules = buildRules(
      'hard',
      profileOf({ age: 78, jointPain: 'moderate', continuousStandingMinutes: 10, availableMinutesPerDay: 60 })
    );
    expect(findRule(rules, 'workout.primary').adaptations.length).toBeGreaterThan(0);
  });

  it('converts pages to minutes for audiobook readers', () => {
    const rules = buildRules('medium', profileOf({ readingFormat: 'audiobook' }));
    expect(findRule(rules, 'reading').unit).toBe('minutes');
  });

  it('rewrites the outdoor rule rather than dropping the session', () => {
    const rules = buildRules('hard', profileOf({ outdoorAccess: 'unavailable' }));
    const second = findRule(rules, 'workout.secondary');
    expect(second).toBeDefined();
    expect(second.kind).toBe('workout');
    expect(second.adaptations.join(' ')).toMatch(/indoor/i);
  });

  it('always produces at least one required rule for every tier', () => {
    for (const tier of ['soft', 'medium', 'hard']) {
      const rules = buildRules(tier, profileOf());
      expect(rules.rules.filter((r) => r.required).length).toBeGreaterThan(0);
      expect(rules.tier).toBe(tier);
    }
  });

  it('recommends a gentler tier for an older, less mobile person', () => {
    const fit = recommendTier(profileOf({ age: 28, availableMinutesPerDay: 150 }));
    const frail = recommendTier(
      profileOf({
        age: 80,
        mobility: 'walkingAid',
        jointPain: 'moderate',
        considerations: ['heartCondition'],
        availableMinutesPerDay: 45,
      })
    );
    expect(TIER_INFO[fit.tier].rank).toBeGreaterThan(TIER_INFO[frail.tier].rank);
    expect(frail.cautions.length).toBeGreaterThan(0);
  });
});

// --- mobility ---------------------------------------------------------------

describe('mobility adaptation', () => {
  it('offers a wheelchair user only seated options', () => {
    const options = exerciseOptions(profileOf({ mobility: 'seated' }));
    expect(options.length).toBeGreaterThan(0);
    expect(options.every((o) => o.seated)).toBe(true);
  });

  it('removes impact work for low-impact profiles', () => {
    const options = exerciseOptions(
      profileOf({ jointPain: 'moderate', considerations: ['osteoporosis'] })
    );
    expect(options.every((o) => o.lowImpact)).toBe(true);
  });

  it('gates on equipment but always assumes a chair', () => {
    const options = exerciseOptions(profileOf({ equipment: [] }));
    expect(options.some((o) => o.id === 'chairCircuit')).toBe(true);
    expect(options.some((o) => o.id === 'pool')).toBe(false);
  });

  it('moves the outdoor requirement to level ground for a fall risk', () => {
    expect(outdoorPolicy(profileOf({ hasFallenInLastYear: true }))).toBe('doorstep');
    expect(outdoorPolicy(profileOf())).toBe('fullyOutdoor');
    expect(outdoorPolicy(profileOf({ outdoorAccess: 'unavailable' }))).toBe('indoors');
  });
});

// --- day scaling ------------------------------------------------------------

describe('daily check-in scaling', () => {
  it('leaves a good morning at the full plan', () => {
    expect(evaluateCheckIn(NEUTRAL_CHECK_IN, profileOf()).scaleFactor).toBe(1);
  });

  it('deloads and suggests rest on high pain', () => {
    const outcome = evaluateCheckIn(
      { sleepHours: 5, pain: 8, energy: 1, soreness: 4 },
      profileOf({ age: 70 })
    );
    expect(outcome.scaleFactor).toBeLessThan(0.7);
    expect(outcome.suggestsRest).toBe(true);
    expect(outcome.suggestsClinician).toBe(true);
  });

  it('never scales below the age-appropriate floor', () => {
    const worst = { sleepHours: 0, pain: 10, energy: 1, soreness: 5 };
    expect(evaluateCheckIn(worst, profileOf({ age: 80 })).scaleFactor).toBeGreaterThanOrEqual(0.5);
    expect(evaluateCheckIn(worst, profileOf({ age: 30 })).scaleFactor).toBeGreaterThanOrEqual(0.4);
  });

  it('never scales water or yes/no rules', () => {
    const water = { id: 'hydration', target: 3000, unit: 'milliliters' };
    const diet = { id: 'nutrition', target: 1, unit: 'yesNo' };
    expect(scaledTarget(water, 0.5)).toBe(3000);
    expect(scaledTarget(diet, 0.5)).toBe(1);
  });

  it('scales minute targets to a round number', () => {
    expect(scaledTarget({ target: 40, unit: 'minutes' }, 0.5)).toBe(20);
    expect(scaledTarget({ target: 45, unit: 'minutes' }, 0.7)).toBe(30);
  });
});

// --- dates ------------------------------------------------------------------

describe('date maths', () => {
  it('adds days across a month boundary', () => {
    expect(addDays('2026-01-30', 3)).toBe('2026-02-02');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
  });

  it('survives a daylight-saving transition', () => {
    // UK clocks go forward on 29 March 2026. A naive +86400000ms would drift.
    expect(daysBetween('2026-03-28', '2026-03-30')).toBe(2);
    expect(addDays('2026-03-28', 2)).toBe('2026-03-30');
  });

  it('maps dates onto day numbers and rejects dates outside the run', () => {
    const run = { startDate: '2026-01-01', totalDays: 75 };
    expect(dayNumberFor(run, '2026-01-01')).toBe(1);
    expect(dayNumberFor(run, '2026-01-10')).toBe(10);
    expect(dayNumberFor(run, '2025-12-31')).toBeNull();
    expect(dayNumberFor(run, '2026-04-01')).toBeNull();
  });
});

// --- gamification -----------------------------------------------------------

describe('XP, levels and streaks', () => {
  it('increases levels monotonically with XP', () => {
    let last = 0;
    for (let xp = 0; xp <= 12000; xp += 100) {
      const level = levelFor(xp);
      expect(level.index).toBeGreaterThanOrEqual(last);
      last = level.index;
    }
  });

  it('keeps the streak multiplier bounded', () => {
    expect(streakMultiplier(0)).toBe(1);
    expect(streakMultiplier(1000)).toBeLessThanOrEqual(2);
    expect(streakMultiplier(30)).toBeGreaterThan(streakMultiplier(5));
  });

  it('gives Hard no grace days and Soft no forced restart', () => {
    expect(TIER_INFO.hard.missPolicy).toBe('restart');
    expect(TIER_INFO.soft.missPolicy).toBe('streakBreak');
    expect(TIER_INFO.medium.missPolicy).toBe('grace');
  });

  it('forces a restart on Hard and only breaks the streak on Soft', () => {
    const missed = { dayNumber: 12 };
    expect(resolveMiss({ tier: 'hard', totalDays: 75 }, [], missed).kind).toBe('restart');
    expect(resolveMiss({ tier: 'soft', totalDays: 75 }, [], missed).kind).toBe('streakBroken');
    expect(resolveMiss({ tier: 'medium', totalDays: 75 }, [], missed).kind).toBe('grace');
  });

  it('awards full credit for a completed deload day', () => {
    const ruleSet = buildRules('medium', profileOf({ age: 70 }));
    const entries = {};
    for (const rule of ruleSet.rules) {
      entries[rule.id] = { value: rule.target, target: rule.target, done: true };
    }

    const fullDay = { dayNumber: 3, date: todayKey(), entries, scaleFactor: 1 };
    const deloadDay = { dayNumber: 3, date: todayKey(), entries, scaleFactor: 0.6 };

    expect(isDayComplete(fullDay, ruleSet)).toBe(true);

    const full = awardForDay(fullDay, ruleSet, 0, 'medium');
    const deload = awardForDay(deloadDay, ruleSet, 0, 'medium');

    expect(deload.totalXp).toBe(full.totalXp);
    // Plus two coins for showing up on a day the body voted against.
    expect(deload.coins).toBeGreaterThan(full.coins);
  });

  it('earns no coins for a half-finished day', () => {
    const ruleSet = buildRules('medium', profileOf());
    const day = { dayNumber: 2, date: todayKey(), entries: {}, scaleFactor: 1 };
    expect(awardForDay(day, ruleSet, 0, 'medium').coins).toBe(0);
  });

  it('does not break the current streak while today is still open', () => {
    const run = { tier: 'medium', startDate: addDays(todayKey(), -2), totalDays: 75, longestStreak: 0 };
    const days = [
      { dayNumber: 1, date: addDays(todayKey(), -2), isComplete: true, entries: {}, scaleFactor: 1 },
      { dayNumber: 2, date: addDays(todayKey(), -1), isComplete: true, entries: {}, scaleFactor: 1 },
      { dayNumber: 3, date: todayKey(), isComplete: false, entries: {}, scaleFactor: 1 },
    ];
    expect(summarise(run, days).current).toBe(2);
  });
});

// --- meal planning ----------------------------------------------------------

describe('meal planning', () => {
  it('covers every meal slot in the shipped library', () => {
    for (const slot of ['breakfast', 'lunch', 'dinner', 'snack']) {
      expect(BUILTIN_RECIPES.some((r) => r.slot === slot)).toBe(true);
    }
  });

  it('gives every recipe a unique id', () => {
    const ids = BUILTIN_RECIPES.map((r) => r.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('respects a limited standing tolerance', () => {
    const filter = defaultFilter(profileOf({ mobility: 'moderate', continuousStandingMinutes: 6 }), 'medium');
    const results = applyFilter(filter, BUILTIN_RECIPES);

    expect(results.length).toBeGreaterThan(0);
    expect(results.every((r) => r.standingMinutes <= 6)).toBe(true);
  });

  it('excludes anything not tagged vegan when vegan is selected', () => {
    const results = applyFilter({ ...EMPTY_FILTER, dietary: ['vegan'] }, BUILTIN_RECIPES);
    expect(results.length).toBeGreaterThan(0);
    expect(results.every((r) => r.dietary.includes('vegan'))).toBe(true);
  });

  it('treats vegan recipes as vegetarian too', () => {
    const results = applyFilter({ ...EMPTY_FILTER, dietary: ['vegetarian'] }, BUILTIN_RECIPES);
    expect(results.some((r) => r.dietary.includes('vegan') && !r.dietary.includes('vegetarian'))).toBe(
      false
    );
    expect(results.length).toBeGreaterThan(0);
  });

  it('fills seven days of every main slot', () => {
    const meals = generateWeek({
      startDate: '2026-01-05',
      recipes: BUILTIN_RECIPES,
      profile: profileOf({ age: 68, mobility: 'mild' }),
      tier: 'medium',
    });

    for (const slot of ['breakfast', 'lunch', 'dinner']) {
      const dates = new Set(meals.filter((m) => m.slot === slot).map((m) => m.date));
      expect(dates.size).toBe(7);
    }
  });

  it('still produces a week for a heavily constrained profile', () => {
    const meals = generateWeek({
      startDate: '2026-01-05',
      recipes: BUILTIN_RECIPES,
      profile: profileOf({ age: 84, mobility: 'seated', dietary: ['vegan', 'softTexture'] }),
      tier: 'soft',
    });
    expect(meals.length).toBeGreaterThan(0);
  });

  it('merges duplicate ingredients across recipes', () => {
    const eggRecipe = BUILTIN_RECIPES.find((r) => r.ingredients.some((i) => i.name === 'eggs'));
    const meals = [
      { recipeId: eggRecipe.id, servings: eggRecipe.servings },
      { recipeId: eggRecipe.id, servings: eggRecipe.servings },
    ];

    const items = buildShoppingList(meals, BUILTIN_RECIPES);
    const eggs = items.filter((i) => i.name === 'eggs');

    expect(eggs).toHaveLength(1);
    expect(eggs[0].quantity).toBe(24);
  });

  it('scales quantities by planned servings', () => {
    const recipe = BUILTIN_RECIPES.find((r) => r.servings >= 4);
    const half = buildShoppingList([{ recipeId: recipe.id, servings: recipe.servings / 2 }], BUILTIN_RECIPES);
    const full = buildShoppingList([{ recipeId: recipe.id, servings: recipe.servings }], BUILTIN_RECIPES);

    const pick = (list) => list.find((i) => i.unit === 'g' || i.unit === 'ml');
    if (pick(full)) {
      expect(pick(half).quantity).toBeLessThan(pick(full).quantity);
    }
  });

  it('leaves optional ingredients off the shopping list', () => {
    const recipe = BUILTIN_RECIPES.find((r) => r.ingredients.some((i) => i.optional));
    const optionalName = recipe.ingredients.find((i) => i.optional).name;
    const items = buildShoppingList([{ recipeId: recipe.id, servings: recipe.servings }], BUILTIN_RECIPES);

    expect(items.some((i) => i.name === optionalName)).toBe(false);
  });

  it('sorts the shopping list in supermarket walking order', () => {
    const meals = BUILTIN_RECIPES.slice(0, 6).map((r) => ({ recipeId: r.id, servings: 1 }));
    const items = buildShoppingList(meals, BUILTIN_RECIPES);
    const orders = items.map((i) => ['produce', 'bakery', 'meatAndFish', 'dairyAndEggs', 'grains', 'pantry', 'spices', 'frozen', 'other'].indexOf(i.aisle));

    expect(orders).toEqual([...orders].sort((a, b) => a - b));
  });

  it('inserts sit-down breaks into prep for limited standing', () => {
    const batch = BUILTIN_RECIPES.filter((r) => r.batchFriendly && r.standingMinutes >= 12);
    const meals = batch.map((r) => ({ recipeId: r.id, servings: 1 }));

    const steps = prepSession(meals, BUILTIN_RECIPES, profileOf({ continuousStandingMinutes: 10 }));

    expect(steps.length).toBeGreaterThan(0);
    expect(steps.some((s) => s.title.startsWith('Sit down'))).toBe(true);
  });

  it('does not pad the prep session with breaks for someone who can stand', () => {
    const batch = BUILTIN_RECIPES.filter((r) => r.batchFriendly && r.standingMinutes >= 12);
    const meals = batch.map((r) => ({ recipeId: r.id, servings: 1 }));

    const steps = prepSession(meals, BUILTIN_RECIPES, profileOf({ continuousStandingMinutes: 45 }));

    expect(steps.some((s) => s.title.startsWith('Sit down'))).toBe(false);
  });

  it('counts standing time even for recipes whose prep can be done sitting', () => {
    // Mason jars are assembled at a table but still need time at a hob. A
    // seated-prep flag alone would report this session as zero standing.
    const jars = BUILTIN_RECIPES.find((r) => r.id === 'builtin:chicken-quinoa-jars');
    const steps = prepSession(
      [{ recipeId: jars.id, servings: 1 }],
      BUILTIN_RECIPES,
      profileOf({ continuousStandingMinutes: 45 })
    );

    expect(sessionStandingMinutes(steps)).toBeGreaterThan(0);
    expect(sessionTotalMinutes(steps)).toBeGreaterThan(sessionStandingMinutes(steps));
  });
});
