import { useCallback, useEffect, useMemo, useState } from 'react';

import { useChallenge } from '../ChallengeContext.jsx';
import { api } from '../api.js';
import { MEAL_SLOTS, SLOT_NAMES, AISLES } from '../engine/constants.js';
import { todayKey, addDays } from '../engine/progress.js';
import {
  defaultFilter, applyFilter, generateWeek, buildShoppingList, prepSession,
  formatQuantity, sessionStandingMinutes, sessionTotalMinutes,
} from '../engine/mealPlanner.js';
import { totalMinutes, proteinPerServing, caloriesPerServing } from '../data/recipes.js';
import { Card, SectionTitle, Empty, Chip, Pill, Modal, Note, Bar, Stepper, Toggle } from './ui.jsx';

const SECTIONS = [
  { id: 'plan', name: 'Plan' },
  { id: 'recipes', name: 'Recipes' },
  { id: 'shopping', name: 'Shopping' },
  { id: 'prep', name: 'Prep' },
];

export default function Meals() {
  const [section, setSection] = useState('plan');
  const [weekStart, setWeekStart] = useState(() => todayKey());
  const [importOpen, setImportOpen] = useState(false);

  return (
    <>
      <div className="chip-row" role="tablist" aria-label="Meal sections">
        {SECTIONS.map((item) => (
          <Chip key={item.id} pressed={section === item.id} onClick={() => setSection(item.id)}>
            {item.name}
          </Chip>
        ))}
        <Chip onClick={() => setImportOpen(true)}>＋ Import</Chip>
      </div>

      {section === 'plan' && <WeekPlan weekStart={weekStart} setWeekStart={setWeekStart} />}
      {section === 'recipes' && <RecipeList />}
      {section === 'shopping' && <ShoppingList weekStart={weekStart} />}
      {section === 'prep' && <PrepSession weekStart={weekStart} />}

      {importOpen && <ImportModal onClose={() => setImportOpen(false)} />}
    </>
  );
}

// --- week plan --------------------------------------------------------------

function WeekPlan({ weekStart, setWeekStart }) {
  const { profile, run, recipes, refresh } = useChallenge();
  const [meals, setMeals] = useState([]);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      setMeals(await api.get(`/api/challenge/meals?start=${weekStart}&days=7`));
    } catch {
      setMeals([]);
    }
  }, [weekStart]);

  useEffect(() => {
    load();
  }, [load]);

  const build = async () => {
    setBusy(true);
    const generated = generateWeek({ startDate: weekStart, recipes, profile, tier: run.tier });
    const saved = await api.put('/api/challenge/meals/week', { weekStart, meals: generated });
    setMeals(saved);

    const items = buildShoppingList(saved, recipes);
    await api.put('/api/challenge/shopping', { weekStart, items });

    await refresh();
    setBusy(false);
  };

  const days = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));

  return (
    <>
      <Card>
        <div className="row row--between">
          <button type="button" className="btn btn--ghost" onClick={() => setWeekStart(addDays(weekStart, -7))} aria-label="Previous week">
            ‹
          </button>
          <div style={{ textAlign: 'center' }}>
            <strong>{formatDate(weekStart)}</strong>
            <p className="tiny">week of</p>
          </div>
          <button type="button" className="btn btn--ghost" onClick={() => setWeekStart(addDays(weekStart, 7))} aria-label="Next week">
            ›
          </button>
        </div>
      </Card>

      {meals.length === 0 ? (
        <Card>
          <Empty
            icon="🗓️"
            title="No plan for this week"
            message="Build one from the recipes that fit your tier, your diet and how long you can stand at a hob."
            action={
              <button type="button" className="btn btn--primary" disabled={busy} onClick={build}>
                {busy ? 'Building…' : 'Build my week'}
              </button>
            }
          />
        </Card>
      ) : (
        <>
          {days.map((date) => (
            <DayCard key={date} date={date} meals={meals.filter((m) => m.date === date)} recipes={recipes} />
          ))}
          <button type="button" className="btn btn--block" disabled={busy} onClick={build}>
            {busy ? 'Rebuilding…' : '🔄 Rebuild this week'}
          </button>
        </>
      )}
    </>
  );
}

function DayCard({ date, meals, recipes }) {
  const [open, setOpen] = useState(null);
  const byId = useMemo(() => new Map(recipes.map((r) => [r.id, r])), [recipes]);

  return (
    <Card>
      <div className="row row--between">
        <strong>{new Date(`${date}T00:00:00`).toLocaleDateString([], { weekday: 'long' })}</strong>
        <span className="tiny">
          {formatDate(date)} {date === todayKey() && <Pill variant="info">today</Pill>}
        </span>
      </div>

      {meals.length === 0 ? (
        <p className="tiny">Nothing planned.</p>
      ) : (
        <div className="list">
          {MEAL_SLOTS.flatMap((slot) =>
            meals
              .filter((m) => m.slot === slot)
              .map((meal) => {
                const recipe = byId.get(meal.recipeId);
                return (
                  <button
                    key={meal.id ?? `${meal.slot}-${meal.recipeId}`}
                    type="button"
                    className="list__item"
                    onClick={() => recipe && setOpen(recipe)}
                  >
                    <span className="list__label">
                      <strong style={{ display: 'block' }}>{meal.recipeTitle}</strong>
                      <span className="tiny">{SLOT_NAMES[slot]}</span>
                    </span>
                    {recipe && (
                      <span className="tiny" style={{ color: 'var(--success)', fontWeight: 700 }}>
                        {Math.round(proteinPerServing(recipe))}g
                      </span>
                    )}
                    <span aria-hidden="true">›</span>
                  </button>
                );
              })
          )}
        </div>
      )}

      {open && <RecipeModal recipe={open} onClose={() => setOpen(null)} />}
    </Card>
  );
}

// --- recipes ----------------------------------------------------------------

function RecipeList() {
  const { profile, run, recipes } = useChallenge();
  const [filter, setFilter] = useState(() => defaultFilter(profile, run?.tier ?? null));
  const [showAll, setShowAll] = useState(false);
  const [open, setOpen] = useState(null);

  const results = useMemo(() => {
    const active = showAll ? { ...filter, maxStandingMinutes: null, tier: null, dietary: [], requiresSeatedPrep: false } : filter;
    return applyFilter(active, recipes);
  }, [filter, showAll, recipes]);

  const toggle = (key) => setFilter((f) => ({ ...f, [key]: !f[key] }));

  return (
    <>
      <Card>
        <input
          className="input"
          type="search"
          placeholder="Search recipes"
          value={filter.search}
          onChange={(e) => setFilter((f) => ({ ...f, search: e.target.value }))}
        />

        <div className="chip-row">
          <Chip pressed={filter.slot === null} onClick={() => setFilter((f) => ({ ...f, slot: null }))}>
            All
          </Chip>
          {MEAL_SLOTS.map((slot) => (
            <Chip
              key={slot}
              pressed={filter.slot === slot}
              onClick={() => setFilter((f) => ({ ...f, slot: f.slot === slot ? null : slot }))}
            >
              {SLOT_NAMES[slot]}
            </Chip>
          ))}
        </div>

        <div className="chip-row">
          <Chip pressed={filter.batchOnly} onClick={() => toggle('batchOnly')}>Batch cook</Chip>
          <Chip pressed={filter.requiresSeatedPrep} onClick={() => toggle('requiresSeatedPrep')}>Seated prep</Chip>
          <Chip pressed={filter.requiresOneHanded} onClick={() => toggle('requiresOneHanded')}>One-handed</Chip>
          <Chip pressed={filter.requiresSoftTexture} onClick={() => toggle('requiresSoftTexture')}>Easy to chew</Chip>
          <Chip
            pressed={filter.maxTotalMinutes !== null}
            onClick={() => setFilter((f) => ({ ...f, maxTotalMinutes: f.maxTotalMinutes === null ? 20 : null }))}
          >
            Under 20 min
          </Chip>
        </div>

        <Toggle
          label="Show everything"
          detail="Ignores your tier, diet and standing limits."
          checked={showAll}
          onChange={setShowAll}
        />
      </Card>

      {results.length === 0 ? (
        <Card>
          <Empty icon="🔍" title="Nothing matches" message="Loosen a filter, or import a recipe from a site you already use." />
        </Card>
      ) : (
        results.map((recipe) => (
          <button key={recipe.id} type="button" className="card" style={{ textAlign: 'left' }} onClick={() => setOpen(recipe)}>
            <div className="row row--between" style={{ alignItems: 'flex-start' }}>
              <div className="stack" style={{ gap: '0.15rem' }}>
                <strong>{recipe.title}</strong>
                <p className="tiny">{recipe.summary}</p>
              </div>
              <div style={{ textAlign: 'right', flexShrink: 0 }}>
                <div style={{ fontSize: '1.2rem', fontWeight: 700, color: 'var(--success)' }}>
                  {Math.round(proteinPerServing(recipe))}g
                </div>
                <div className="tiny">protein</div>
              </div>
            </div>
            <div className="row row--wrap">
              <Pill>⏱ {totalMinutes(recipe)} min</Pill>
              <Pill variant={recipe.standingMinutes <= 10 ? 'good' : 'warn'}>
                🧍 {recipe.standingMinutes === 0 ? 'no standing' : `${recipe.standingMinutes} min standing`}
              </Pill>
              {recipe.batchFriendly && <Pill variant="info">batch</Pill>}
              {recipe.softTexture && <Pill variant="info">soft</Pill>}
            </div>
          </button>
        ))
      )}

      {open && <RecipeModal recipe={open} onClose={() => setOpen(null)} />}
    </>
  );
}

function RecipeModal({ recipe, onClose }) {
  const { refresh } = useChallenge();
  const [date, setDate] = useState(todayKey());
  const [slot, setSlot] = useState(recipe.slot);
  const [servings, setServings] = useState(1);
  const [added, setAdded] = useState(false);

  const add = async () => {
    await api.post('/api/challenge/meals', {
      date,
      slot,
      recipeId: recipe.id,
      recipeTitle: recipe.title,
      servings,
    });
    setAdded(true);
    await refresh();
  };

  return (
    <Modal title={recipe.title} onClose={onClose}>
      <Card>
        <p>{recipe.summary}</p>
        <div className="metrics">
          <Metric value={recipe.prepMinutes} label="min prep" />
          <Metric value={recipe.cookMinutes} label="min cook" />
          <Metric value={recipe.servings} label="servings" />
        </div>
      </Card>

      <Card>
        <SectionTitle title="Per serving" />
        <div className="metrics">
          <Metric value={caloriesPerServing(recipe)} label="kcal" />
          <Metric value={`${Math.round(proteinPerServing(recipe))}g`} label="protein" />
          <Metric value={`${Math.round(recipe.carbsG / Math.max(1, recipe.servings))}g`} label="carbs" />
          <Metric value={`${Math.round(recipe.fatG / Math.max(1, recipe.servings))}g`} label="fat" />
        </div>
        {recipe.calories === 0 && (
          <p className="tiny">This recipe came from the web without nutrition data.</p>
        )}
      </Card>

      <Card>
        <SectionTitle title="Effort" />
        <div className="row row--wrap">
          <Pill variant={recipe.standingMinutes <= 10 ? 'good' : 'warn'}>
            🧍 {recipe.standingMinutes === 0 ? 'Nothing standing' : `${recipe.standingMinutes} min standing`}
          </Pill>
          {recipe.seatedPrep && <Pill variant="info">Seated prep</Pill>}
          {recipe.oneHanded && <Pill variant="info">One-handed</Pill>}
          {recipe.batchFriendly && <Pill variant="info">Batch friendly</Pill>}
          {recipe.lowKnifeSkill && <Pill variant="info">Little chopping</Pill>}
          {recipe.softTexture && <Pill variant="info">Easy to chew</Pill>}
        </div>
      </Card>

      <Card>
        <SectionTitle title="Ingredients" subtitle={`Makes ${recipe.servings}`} />
        <ul style={{ margin: 0, paddingLeft: '1.2rem' }}>
          {recipe.ingredients.map((line, index) => (
            <li key={`${line.name}-${index}`}>
              {formatQuantity(line.quantity, line.unit)} {line.name}
              {line.note && `, ${line.note}`}
              {line.optional && <span className="tiny"> (optional)</span>}
            </li>
          ))}
        </ul>
      </Card>

      <Card>
        <SectionTitle title="Method" />
        <ol style={{ margin: 0, paddingLeft: '1.4rem' }}>
          {recipe.steps.map((step, index) => (
            <li key={index} style={{ marginBottom: '0.5rem' }}>{step}</li>
          ))}
        </ol>
      </Card>

      {recipe.sourceUrl && (
        <a className="tiny" href={recipe.sourceUrl} target="_blank" rel="noreferrer noopener">
          Original recipe ↗
        </a>
      )}

      <Card>
        <SectionTitle title="Add to plan" />
        <label className="field">
          <span className="tiny">Day</span>
          <input className="input" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </label>
        <label className="field">
          <span className="tiny">Meal</span>
          <select className="select" value={slot} onChange={(e) => setSlot(e.target.value)}>
            {MEAL_SLOTS.map((s) => (
              <option key={s} value={s}>{SLOT_NAMES[s]}</option>
            ))}
          </select>
        </label>
        <Stepper label="servings" value={servings} min={1} max={8} step={1} format={(v) => `${v}`} onChange={setServings} />
        <button type="button" className="btn btn--primary btn--block" onClick={add} disabled={added}>
          {added ? 'Added ✓' : 'Add to plan'}
        </button>
      </Card>
    </Modal>
  );
}

function Metric({ value, label }) {
  return (
    <div className="metric">
      <span className="metric__value">{value}</span>
      <span className="metric__label">{label}</span>
    </div>
  );
}

// --- shopping ---------------------------------------------------------------

function ShoppingList({ weekStart }) {
  const { recipes } = useChallenge();
  const [items, setItems] = useState([]);
  const [newItem, setNewItem] = useState('');

  const load = useCallback(async () => {
    try {
      setItems(await api.get(`/api/challenge/shopping?weekStart=${weekStart}`));
    } catch {
      setItems([]);
    }
  }, [weekStart]);

  useEffect(() => {
    load();
  }, [load]);

  const rebuild = async () => {
    const meals = await api.get(`/api/challenge/meals?start=${weekStart}&days=7`);
    const built = buildShoppingList(meals, recipes);
    setItems(await api.put('/api/challenge/shopping', { weekStart, items: built }));
  };

  const toggle = async (item) => {
    setItems((current) => current.map((i) => (i.id === item.id ? { ...i, checked: !i.checked } : i)));
    await api.patch(`/api/challenge/shopping/${item.id}`, { checked: !item.checked });
  };

  const add = async (event) => {
    event.preventDefault();
    const name = newItem.trim();
    if (!name) return;
    const created = await api.post('/api/challenge/shopping', { weekStart, name });
    setItems((current) => [...current, created]);
    setNewItem('');
  };

  if (items.length === 0) {
    return (
      <Card>
        <Empty
          icon="🛒"
          title="No shopping list yet"
          message="Plan a week first, then the list builds itself — merged, scaled and sorted the way you walk a shop."
          action={
            <button type="button" className="btn btn--primary" onClick={rebuild}>
              Build from this week's plan
            </button>
          }
        />
      </Card>
    );
  }

  const outstanding = items.filter((i) => !i.checked);
  const done = items.filter((i) => i.checked);
  const grouped = AISLES.map((aisle) => ({
    aisle,
    items: outstanding.filter((i) => i.aisle === aisle.id),
  })).filter((group) => group.items.length > 0);

  return (
    <>
      <Card>
        <div className="row row--between">
          <strong>{done.length} of {items.length}</strong>
          <button type="button" className="btn btn--ghost btn--small" onClick={rebuild}>
            Rebuild
          </button>
        </div>
        <Bar value={items.length ? done.length / items.length : 0} tint="var(--success)" />
      </Card>

      {grouped.map(({ aisle, items: group }) => (
        <Card key={aisle.id}>
          <SectionTitle title={aisle.name} />
          <div className="list">
            {group.map((item) => (
              <ShoppingRow key={item.id} item={item} onToggle={() => toggle(item)} />
            ))}
          </div>
        </Card>
      ))}

      {done.length > 0 && (
        <Card>
          <SectionTitle title="In the trolley" subtitle={`${done.length} items`} />
          <div className="list">
            {done.map((item) => (
              <ShoppingRow key={item.id} item={item} onToggle={() => toggle(item)} />
            ))}
          </div>
        </Card>
      )}

      <Card>
        <form className="row" onSubmit={add}>
          <input
            className="input"
            value={newItem}
            onChange={(e) => setNewItem(e.target.value)}
            placeholder="Add something else"
          />
          <button type="submit" className="btn btn--primary" aria-label="Add item">
            ＋
          </button>
        </form>
      </Card>
    </>
  );
}

function ShoppingRow({ item, onToggle }) {
  return (
    <button
      type="button"
      className={`list__item ${item.checked ? 'list__item--checked' : ''}`}
      onClick={onToggle}
      aria-pressed={item.checked}
    >
      <span aria-hidden="true">{item.checked ? '☑' : '☐'}</span>
      <span className="list__label">
        <span style={{ display: 'block' }}>{formatQuantity(item.quantity, item.unit)} {item.name}</span>
        {item.sources.length > 0 && <span className="tiny">{item.sources.join(' · ')}</span>}
      </span>
    </button>
  );
}

// --- prep -------------------------------------------------------------------

function PrepSession({ weekStart }) {
  const { profile, recipes } = useChallenge();
  const [steps, setSteps] = useState([]);
  const [done, setDone] = useState(() => new Set());

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const meals = await api.get(`/api/challenge/meals?start=${weekStart}&days=7`);
        if (!cancelled) {
          setSteps(prepSession(meals, recipes, profile));
          setDone(new Set());
        }
      } catch {
        if (!cancelled) setSteps([]);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [weekStart, recipes, profile]);

  if (steps.length === 0) {
    return (
      <Card>
        <Empty
          icon="⏱️"
          title="No prep session"
          message="Plan a week with some batch-friendly recipes and this becomes an ordered session — longest cook first, all the chopping in one seated block."
        />
      </Card>
    );
  }

  const standing = sessionStandingMinutes(steps);

  return (
    <>
      <Card>
        <SectionTitle
          title="This week's prep"
          subtitle="Do it once and the week stops asking you questions."
        />
        <div className="metrics">
          <Metric value={sessionTotalMinutes(steps)} label="min total" />
          <Metric value={standing} label="min standing" />
          <Metric value={`${done.size}/${steps.length}`} label="done" />
        </div>
        <Bar value={done.size / steps.length} tint="var(--success)" />
      </Card>

      {steps.map((step) => (
        <button
          key={step.id}
          type="button"
          className="card"
          style={{ textAlign: 'left' }}
          aria-pressed={done.has(step.id)}
          onClick={() =>
            setDone((current) => {
              const next = new Set(current);
              if (next.has(step.id)) next.delete(step.id);
              else next.add(step.id);
              return next;
            })
          }
        >
          <div className="row" style={{ alignItems: 'flex-start' }}>
            <span
              style={{
                width: 40, height: 40, borderRadius: '50%', flexShrink: 0,
                display: 'grid', placeItems: 'center', fontWeight: 700,
                background: done.has(step.id) ? 'var(--success)' : 'var(--surface-2)',
                color: done.has(step.id) ? '#fff' : 'inherit',
              }}
            >
              {done.has(step.id) ? '✓' : step.order}
            </span>
            <div className="stack" style={{ gap: '0.2rem' }}>
              <strong className={done.has(step.id) ? 'task__title--done' : ''}>{step.title}</strong>
              <p className="tiny">{step.detail}</p>
              <div className="row row--wrap">
                <Pill>⏱ {step.minutes} min</Pill>
                <Pill variant={step.standing === 0 ? 'good' : 'warn'}>
                  {step.standing === 0 ? 'seated' : `${step.standing} min standing`}
                </Pill>
              </div>
            </div>
          </div>
        </button>
      ))}
    </>
  );
}

// --- import -----------------------------------------------------------------

function ImportModal({ onClose }) {
  const { refresh } = useChallenge();
  const [url, setUrl] = useState('');
  const [slot, setSlot] = useState('dinner');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [imported, setImported] = useState(null);

  const run = async () => {
    setBusy(true);
    setError(null);
    setImported(null);
    try {
      const draft = await api.post('/api/challenge/recipes/import', { url });
      const recipe = await api.post('/api/challenge/recipes', {
        ...toRecipe(draft, slot),
      });
      setImported(recipe.title);
      setUrl('');
      await refresh();
    } catch (err) {
      setError(err.message);
    }
    setBusy(false);
  };

  return (
    <Modal title="Import a recipe" onClose={onClose}>
      <p className="muted">
        Most recipe sites publish machine-readable data behind the page — the same data Google reads for
        its recipe cards. We read that, so nothing breaks when the site changes its layout.
      </p>

      <input
        className="input"
        type="url"
        inputMode="url"
        placeholder="https://…"
        value={url}
        onChange={(e) => setUrl(e.target.value)}
      />

      <div className="chip-row">
        {MEAL_SLOTS.map((s) => (
          <Chip key={s} pressed={slot === s} onClick={() => setSlot(s)}>
            {SLOT_NAMES[s]}
          </Chip>
        ))}
      </div>

      {error && <Note variant="critical">{error}</Note>}

      {imported && (
        <Note variant="info">
          Imported <strong>{imported}</strong>. Check the ingredients — quantities are parsed from free
          text and occasionally need a nudge.
        </Note>
      )}

      <button type="button" className="btn btn--primary btn--block" disabled={busy || !url.trim()} onClick={run}>
        {busy ? 'Importing…' : 'Import'}
      </button>
    </Modal>
  );
}

// The server hands back a draft; the client decides how it slots into the
// library. Imported recipes start with no tier tags, so the planner treats them
// as always-eligible rather than pretending to know they fit 75 Hard.
function toRecipe(draft, slot) {
  return {
    title: draft.title,
    summary: draft.summary,
    slot,
    servings: draft.servings,
    prepMinutes: draft.prepMinutes,
    cookMinutes: draft.cookMinutes,
    calories: draft.calories,
    proteinG: draft.proteinG,
    carbsG: draft.carbsG,
    fatG: draft.fatG,
    fiberG: draft.fiberG,
    sodiumMg: draft.sodiumMg,
    ingredients: draft.ingredientTexts.map(parseIngredient),
    steps: draft.steps,
    tiers: [],
    dietary: [],
    standingMinutes: draft.prepMinutes,
    seatedPrep: false,
    oneHanded: false,
    softTexture: false,
    batchFriendly: draft.servings >= 4,
    lowKnifeSkill: false,
    sourceUrl: draft.sourceUrl,
    userAdded: true,
  };
}

const KNOWN_UNITS = new Set([
  'g', 'kg', 'ml', 'l', 'oz', 'lb', 'lbs', 'cup', 'cups', 'tbsp', 'tsp',
  'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons', 'clove', 'cloves',
  'slice', 'slices', 'pinch', 'can', 'cans', 'tin', 'tins', 'stick', 'sticks',
  'handful', 'sprig', 'sprigs', 'head', 'heads',
]);

const FRACTIONS = { '½': 0.5, '¼': 0.25, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3 };

// Turns "2 tbsp olive oil" into a structured line so imported recipes feed the
// shopping list the way the built-in ones do.
export function parseIngredient(text) {
  const tokens = String(text).trim().split(/\s+/);
  if (tokens.length === 0) return { name: text, quantity: 1, unit: '', aisle: 'other', optional: false, note: '' };

  let quantity = 1;
  let unit = '';
  let index = 0;

  const asNumber = (token) => {
    if (FRACTIONS[token] !== undefined) return FRACTIONS[token];
    if (token.includes('/')) {
      const [a, b] = token.split('/').map(Number);
      return b ? a / b : null;
    }
    const value = Number(token);
    return Number.isFinite(value) ? value : null;
  };

  const first = asNumber(tokens[0]);
  if (first !== null) {
    quantity = first;
    index = 1;
    // "1 1/2 cups" — a second fraction token belongs to the same quantity.
    if (tokens[1] && tokens[1].includes('/')) {
      const second = asNumber(tokens[1]);
      if (second !== null) {
        quantity += second;
        index = 2;
      }
    }
  }

  const candidate = (tokens[index] ?? '').toLowerCase().replace(/[.,]/g, '');
  if (KNOWN_UNITS.has(candidate)) {
    unit = candidate;
    index += 1;
  }

  const name = tokens.slice(index).join(' ') || String(text);
  return { name, quantity, unit, aisle: guessAisle(name), optional: false, note: '' };
}

const AISLE_KEYWORDS = [
  ['produce', ['onion', 'garlic', 'tomato', 'pepper', 'carrot', 'celery', 'lettuce', 'spinach', 'potato', 'lemon', 'lime', 'apple', 'banana', 'berr', 'cucumber', 'avocado', 'broccoli', 'courgette', 'zucchini', 'ginger', 'herb', 'mushroom', 'kale']],
  ['meatAndFish', ['chicken', 'beef', 'pork', 'lamb', 'turkey', 'salmon', 'cod', 'prawn', 'shrimp', 'tuna', 'mince', 'bacon', 'fish', 'steak']],
  ['dairyAndEggs', ['milk', 'yoghurt', 'yogurt', 'cheese', 'butter', 'cream', 'egg', 'tofu', 'hummus']],
  ['grains', ['rice', 'pasta', 'oat', 'quinoa', 'noodle', 'barley', 'bread', 'wrap', 'tortilla', 'couscous']],
  ['frozen', ['frozen', 'peas', 'ice']],
  ['bakery', ['baguette', 'roll', 'loaf', 'pitta', 'pita']],
  ['spices', ['salt', 'pepper', 'cumin', 'paprika', 'cinnamon', 'oregano', 'thyme', 'rosemary', 'chilli', 'chili', 'curry powder', 'bay lea', 'seasoning']],
  ['pantry', ['oil', 'vinegar', 'stock', 'tinned', 'canned', 'bean', 'lentil', 'chickpea', 'flour', 'sugar', 'honey', 'soy sauce', 'tahini', 'olive', 'nut', 'seed', 'coconut milk', 'purée', 'puree', 'mustard']],
];

export function guessAisle(name) {
  const lower = name.toLowerCase();
  for (const [aisle, keywords] of AISLE_KEYWORDS) {
    if (keywords.some((keyword) => lower.includes(keyword))) return aisle;
  }
  return 'other';
}

function formatDate(dateKey) {
  return new Date(`${dateKey}T00:00:00`).toLocaleDateString([], { day: 'numeric', month: 'short' });
}
