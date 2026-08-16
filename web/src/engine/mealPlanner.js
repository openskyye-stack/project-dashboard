import { MEAL_SLOTS, aisleInfo } from './constants.js';
import { totalMinutes, proteinPerServing } from '../data/recipes.js';
import { addDays } from './progress.js';

// Chooses recipes and turns a week's plan into a shopping list and a batch-prep
// session.

export const EMPTY_FILTER = {
  tier: null,
  dietary: [],
  slot: null,
  maxStandingMinutes: null,
  requiresSeatedPrep: false,
  requiresOneHanded: false,
  requiresSoftTexture: false,
  batchOnly: false,
  maxTotalMinutes: null,
  search: '',
};

// The filter that matches this person's constraints, so the recipe list opens
// on things they can actually cook.
export function defaultFilter(profile, tier) {
  const filter = { ...EMPTY_FILTER, tier, dietary: profile.dietary ?? [] };

  // Someone who can stand for 10 minutes should not be shown a recipe that
  // needs 25 minutes at the hob.
  const standing = profile.continuousStandingMinutes ?? 30;
  if (profile.mobility !== 'unrestricted' || standing < 20) {
    filter.maxStandingMinutes = Math.max(5, standing);
  }
  if (profile.mobility === 'seated') filter.requiresSeatedPrep = true;
  if ((profile.dietary ?? []).includes('softTexture')) filter.requiresSoftTexture = true;

  return filter;
}

export function suitsDiet(recipe, preferences) {
  if (!preferences || preferences.length === 0) return true;
  const tags = new Set(recipe.dietary ?? []);

  return preferences.every((preference) => {
    if (preference === 'vegetarian') return tags.has('vegetarian') || tags.has('vegan');
    if (preference === 'pescatarian') {
      return tags.has('pescatarian') || tags.has('vegetarian') || tags.has('vegan');
    }
    return tags.has(preference);
  });
}

export function applyFilter(filter, recipes) {
  const query = (filter.search ?? '').trim().toLowerCase();

  return recipes.filter((recipe) => {
    // An imported recipe has no tier tags yet, so it isn't excluded by one.
    if (filter.tier && (recipe.tiers ?? []).length > 0 && !recipe.tiers.includes(filter.tier)) return false;
    if (filter.slot && recipe.slot !== filter.slot) return false;
    if (!suitsDiet(recipe, filter.dietary)) return false;
    if (filter.maxStandingMinutes !== null && (recipe.standingMinutes ?? 0) > filter.maxStandingMinutes) return false;
    if (filter.requiresSeatedPrep && !recipe.seatedPrep) return false;
    if (filter.requiresOneHanded && !recipe.oneHanded) return false;
    if (filter.requiresSoftTexture && !recipe.softTexture) return false;
    if (filter.batchOnly && !recipe.batchFriendly) return false;
    if (filter.maxTotalMinutes !== null && totalMinutes(recipe) > filter.maxTotalMinutes) return false;

    if (query) {
      const haystack = `${recipe.title} ${recipe.summary}`.toLowerCase();
      if (!haystack.includes(query)) return false;
    }
    return true;
  });
}

// --- automatic week ---------------------------------------------------------

// Fills seven days, favouring batch-friendly recipes so the week costs two
// cooking sessions rather than twenty-one.
export function generateWeek({ startDate, recipes, profile, tier, includeSnack = true }) {
  const filter = defaultFilter(profile, tier);
  const pool = applyFilter(filter, recipes);

  // Fall back rather than produce an empty week: a plan with a compromise in it
  // beats a blank screen.
  const candidates = (slot) => {
    const strict = pool.filter((r) => r.slot === slot);
    if (strict.length > 0) return strict;

    const relaxed = recipes.filter((r) => r.slot === slot && suitsDiet(r, filter.dietary));
    return relaxed.length > 0 ? relaxed : recipes.filter((r) => r.slot === slot);
  };

  const slots = includeSnack ? MEAL_SLOTS : MEAL_SLOTS.filter((s) => s !== 'snack');
  const planned = [];

  for (const slot of slots) {
    const options = [...candidates(slot)].sort((a, b) => {
      if (a.batchFriendly !== b.batchFriendly) return a.batchFriendly ? -1 : 1;
      if ((a.standingMinutes ?? 0) !== (b.standingMinutes ?? 0)) {
        return (a.standingMinutes ?? 0) - (b.standingMinutes ?? 0);
      }
      return proteinPerServing(b) - proteinPerServing(a);
    });

    if (options.length === 0) continue;

    let dayIndex = 0;
    let optionIndex = 0;

    while (dayIndex < 7) {
      const chosen = options[optionIndex % options.length];
      // A batch recipe covers as many days as it makes servings, up to four —
      // past that it stops being appetising.
      const span = chosen.batchFriendly
        ? Math.min(4, Math.max(1, chosen.servings), 7 - dayIndex)
        : 1;

      for (let offset = 0; offset < span; offset += 1) {
        planned.push({
          date: addDays(startDate, dayIndex + offset),
          slot,
          recipeId: chosen.id,
          recipeTitle: chosen.title,
          servings: 1,
        });
      }

      dayIndex += span;
      optionIndex += 1;
    }
  }

  return planned;
}

// --- shopping list ----------------------------------------------------------

// Aggregates every planned meal into one list, merging identical ingredients
// and scaling by how many servings are actually planned.
export function buildShoppingList(meals, recipes) {
  const byId = new Map(recipes.map((r) => [r.id, r]));
  const merged = new Map();

  for (const meal of meals) {
    const recipe = byId.get(meal.recipeId);
    if (!recipe) continue;

    const scale = recipe.servings > 0 ? (meal.servings ?? 1) / recipe.servings : 1;

    for (const line of recipe.ingredients ?? []) {
      if (line.optional) continue;

      const key = `${line.name.toLowerCase()}|${(line.unit ?? '').toLowerCase()}`;
      const existing = merged.get(key);

      if (existing) {
        existing.quantity += line.quantity * scale;
        existing.sources.add(recipe.title);
      } else {
        merged.set(key, {
          name: line.name,
          quantity: line.quantity * scale,
          unit: line.unit ?? '',
          aisle: line.aisle ?? 'other',
          sources: new Set([recipe.title]),
        });
      }
    }
  }

  return [...merged.values()]
    .map((item) => ({
      name: item.name,
      quantity: roundForShopping(item.quantity, item.unit),
      unit: item.unit,
      aisle: item.aisle,
      sources: [...item.sources].sort(),
    }))
    .sort((a, b) => {
      const orderDiff = aisleInfo(a.aisle).order - aisleInfo(b.aisle).order;
      return orderDiff !== 0 ? orderDiff : a.name.localeCompare(b.name);
    });
}

// Weight and volume can stay fractional; countable things round up, because
// half an onion is still one onion at the till.
const MEASURED_UNITS = new Set(['g', 'kg', 'ml', 'l', 'oz', 'lb', 'tbsp', 'tsp', 'cup', 'cups']);

function roundForShopping(quantity, unit) {
  if (MEASURED_UNITS.has((unit ?? '').toLowerCase())) {
    return Math.round(quantity * 10) / 10;
  }
  return Math.ceil(quantity);
}

export function formatQuantity(quantity, unit) {
  const rounded = Math.round(quantity * 100) / 100;
  let number;

  if (rounded === Math.round(rounded)) number = String(Math.round(rounded));
  else if (Math.abs(rounded - 0.5) < 0.01) number = '½';
  else if (Math.abs(rounded - 0.25) < 0.01) number = '¼';
  else if (Math.abs(rounded - 0.75) < 0.01) number = '¾';
  else number = rounded.toFixed(2);

  return unit ? `${number} ${unit}` : number;
}

// --- batch prep session -----------------------------------------------------

// Turns the week's batch recipes into an ordered session with the long cooks
// first and the seated work grouped together, so standing time arrives in one
// predictable block instead of scattered through the afternoon.
export function prepSession(meals, recipes, profile) {
  const byId = new Map(recipes.map((r) => [r.id, r]));
  const unique = [...new Set(meals.map((m) => m.recipeId))]
    .map((id) => byId.get(id))
    .filter(Boolean);

  const batch = unique.filter((r) => r.batchFriendly);
  if (batch.length === 0) return [];

  const steps = [];

  // `seatedPrep` and `standingMinutes` answer different questions: the first is
  // "can this be done at a table", the second is "how long are you on your feet
  // regardless". Jars you assemble sitting down still need twelve minutes at a
  // hob to poach the chicken. The break logic keys on the minutes, not the flag,
  // because the flag would report that session as zero standing.
  const standingFor = (r, stepMinutes) =>
    Math.min(stepMinutes, r.seatedPrep ? Math.round(r.standingMinutes / 2) : r.standingMinutes);

  // 1. Longest cook goes on first so it runs while you do everything else.
  for (const r of [...batch].sort((a, b) => b.cookMinutes - a.cookMinutes)) {
    if (r.cookMinutes < 20) continue;
    const minutes = Math.max(5, r.prepMinutes);
    steps.push({
      title: `Start ${r.title}`,
      detail: `Longest cook in the session — get it going first. ${r.cookMinutes} minutes unattended.`,
      minutes,
      standing: standingFor(r, minutes),
    });
  }

  // 2. All the chopping in one seated block.
  const choppers = batch.filter((r) => !r.lowKnifeSkill);
  if (choppers.length > 0) {
    steps.push({
      title: 'Chop everything, sitting down',
      detail: `Bring a board and bowls to the table. Covers ${choppers.map((r) => r.title).join(', ')}.`,
      minutes: choppers.reduce((sum, r) => sum + Math.round(r.prepMinutes / 2), 0),
      standing: 0,
    });
  }

  // 3. Short-cook items.
  for (const r of batch.filter((r) => r.cookMinutes < 20)) {
    const minutes = totalMinutes(r);
    steps.push({
      title: `Assemble ${r.title}`,
      detail: `${r.servings} servings. ${r.standingMinutes} minutes on your feet.`,
      minutes,
      standing: standingFor(r, minutes),
    });
  }

  // 4. Portion and label.
  steps.push({
    title: 'Portion and label',
    detail:
      'Containers on the table, date each lid. This is the step people skip and then eat toast on Thursday.',
    minutes: 10,
    standing: 0,
  });

  return withRestBreaks(steps, profile);
}

export const sessionStandingMinutes = (steps) => steps.reduce((sum, s) => sum + (s.standing ?? 0), 0);
export const sessionTotalMinutes = (steps) => steps.reduce((sum, s) => sum + s.minutes, 0);

// Insert a sit-down whenever standing time has accumulated past what this
// person told us they can manage in one go.
function withRestBreaks(steps, profile) {
  const limit = profile.continuousStandingMinutes ?? 30;
  const number = (list) => list.map((step, index) => ({ ...step, order: index + 1, id: `step-${index}` }));

  if (limit >= 25) return number(steps);

  const out = [];
  let standingRun = 0;

  for (const step of steps) {
    out.push(step);
    // A step with no standing in it is itself a rest, so the run resets.
    standingRun = step.standing === 0 ? 0 : standingRun + step.standing;

    if (standingRun >= limit) {
      out.push({
        title: 'Sit down for five minutes',
        detail: `You've been on your feet for about ${standingRun} minutes. The food will wait.`,
        minutes: 5,
        standing: 0,
      });
      standingRun = 0;
    }
  }

  return number(out);
}
