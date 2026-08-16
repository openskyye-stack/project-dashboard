import express from 'express';
import { getDB } from './db.js';
import { importRecipe, ImportError } from './recipeImport.js';

const router = express.Router();

// All routes here are mounted behind authMiddleware, so req.user.userId is set
// and every query filters on it.
//
// On where the rules live: the adaptation engine runs in the browser, because
// onboarding has to show the plan changing as you answer. The server stores the
// rule set it produces and the day-by-day progress against it. That makes the
// client authoritative for gameplay numbers, which is the right trade for a
// personal tracker — the only person who could cheat is the person the streak
// belongs to. The server still enforces what actually matters: you can only
// touch your own rows, and you cannot spend coins you do not have.

const asJson = (value, fallback) => {
  if (value === null || value === undefined) return fallback;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
};

const bool = (value) => (value ? 1 : 0);

function mapRun(row) {
  if (!row) return null;
  return {
    id: row.id,
    tier: row.tier,
    startDate: row.start_date,
    totalDays: row.total_days,
    isActive: !!row.is_active,
    endedAt: row.ended_at,
    endReason: row.end_reason,
    ruleSet: asJson(row.rule_set, { rules: [], globalNotes: [] }),
    xp: row.xp,
    coins: row.coins,
    freezeTokens: row.freeze_tokens,
    restDaysUsed: row.rest_days_used,
    longestStreak: row.longest_streak,
    attemptNumber: row.attempt_number,
  };
}

function mapDay(row) {
  return {
    dayNumber: row.day_number,
    date: row.date,
    checkIn: asJson(row.check_in, null),
    scaleFactor: row.scale_factor,
    scaleReason: row.scale_reason || '',
    entries: asJson(row.entries, {}),
    isComplete: !!row.is_complete,
    completedAt: row.completed_at,
    usedFreeze: !!row.used_freeze,
    missAcknowledged: !!row.miss_acknowledged,
    photo: row.photo || null,
    reflection: row.reflection || '',
    xpEarned: row.xp_earned,
    coinsEarned: row.coins_earned,
  };
}

function mapReward(row) {
  return {
    id: row.id,
    title: row.title,
    detail: row.detail || '',
    cost: row.cost,
    category: row.category,
    symbol: row.symbol,
    isCustom: !!row.is_custom,
    unlocksAtDay: row.unlocks_at_day,
    timesRedeemed: row.times_redeemed,
    archived: !!row.archived,
  };
}

// --- state ------------------------------------------------------------------

// One call boots the whole app. Photos are excluded here because seventy-five
// of them would make this response enormous; they load per-day on demand.
router.get('/state', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;

    const profileRow = await db.get(
      'SELECT data FROM challenge_profiles WHERE user_id = ?',
      [userId]
    );

    const runRow = await db.get(
      'SELECT * FROM challenge_runs WHERE user_id = ? AND is_active = 1 ORDER BY start_date DESC LIMIT 1',
      [userId]
    );

    const [rewards, achievements, redemptions, recipes, pastRuns, plannedMeals] = await Promise.all([
      db.all('SELECT * FROM challenge_rewards WHERE user_id = ? AND archived = 0 ORDER BY cost', [userId]),
      db.all('SELECT code, unlocked_at FROM challenge_achievements WHERE user_id = ?', [userId]),
      db.all('SELECT * FROM challenge_redemptions WHERE user_id = ? ORDER BY created_at DESC LIMIT 50', [userId]),
      db.all('SELECT id, data FROM challenge_recipes WHERE user_id = ?', [userId]),
      db.all('SELECT COUNT(*) AS n FROM challenge_runs WHERE user_id = ?', [userId]),
      // Needed by the meal-planning achievements, which can never fire without it.
      db.all('SELECT COUNT(*) AS n FROM challenge_meals WHERE user_id = ?', [userId]),
    ]);

    let days = [];
    if (runRow) {
      const rows = await db.all(
        `SELECT id, user_id, run_id, day_number, date, check_in, scale_factor, scale_reason,
                entries, is_complete, completed_at, used_freeze, miss_acknowledged,
                reflection, xp_earned, coins_earned,
                CASE WHEN photo IS NULL THEN 0 ELSE 1 END AS photo
         FROM challenge_days WHERE run_id = ? ORDER BY day_number`,
        [runRow.id]
      );
      days = rows.map((row) => ({ ...mapDay(row), photo: null, hasPhoto: !!row.photo }));
    }

    res.json({
      profile: asJson(profileRow?.data, null),
      run: mapRun(runRow),
      days,
      rewards: rewards.map(mapReward),
      achievements: achievements.map((a) => ({ code: a.code, unlockedAt: a.unlocked_at })),
      redemptions: redemptions.map((r) => ({
        id: r.id,
        rewardTitle: r.reward_title,
        cost: r.cost,
        dayNumber: r.day_number,
        note: r.note,
        date: r.created_at,
      })),
      importedRecipes: recipes.map((r) => ({ ...asJson(r.data, {}), id: `user:${r.id}`, dbId: r.id })),
      totalRuns: pastRuns[0]?.n ?? 0,
      plannedMealCount: plannedMeals[0]?.n ?? 0,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- profile ----------------------------------------------------------------

router.put('/profile', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;
    const data = JSON.stringify(req.body ?? {});

    await db.run(
      `INSERT INTO challenge_profiles (user_id, data) VALUES (?, ?)
       ON CONFLICT(user_id) DO UPDATE SET data = excluded.data, updated_at = CURRENT_TIMESTAMP`,
      [userId, data]
    );

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- runs -------------------------------------------------------------------

router.post('/runs', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;
    const { tier, ruleSet, startDate, freezeTokens = 0 } = req.body ?? {};

    if (!tier || !ruleSet) {
      return res.status(400).json({ error: 'tier and ruleSet are required' });
    }

    // Ending the previous run rather than deleting it: a restart should cost
    // you the streak, not the evidence that you showed up for 40 days.
    await db.run(
      "UPDATE challenge_runs SET is_active = 0, ended_at = CURRENT_TIMESTAMP, end_reason = COALESCE(end_reason, 'restarted') WHERE user_id = ? AND is_active = 1",
      [userId]
    );

    const { n } = await db.get('SELECT COUNT(*) AS n FROM challenge_runs WHERE user_id = ?', [userId]);

    const result = await db.run(
      `INSERT INTO challenge_runs (user_id, tier, start_date, rule_set, freeze_tokens, attempt_number)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, tier, startDate || new Date().toISOString().slice(0, 10), JSON.stringify(ruleSet), freezeTokens, n + 1]
    );

    const row = await db.get('SELECT * FROM challenge_runs WHERE id = ?', [result.lastID]);
    res.status(201).json(mapRun(row));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/runs/:id', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;

    const run = await db.get('SELECT * FROM challenge_runs WHERE id = ? AND user_id = ?', [
      req.params.id,
      userId,
    ]);
    if (!run) return res.status(404).json({ error: 'Not found' });

    const { ruleSet, xp, coins, freezeTokens, longestStreak, restDaysUsed, isActive, endReason } = req.body ?? {};

    await db.run(
      `UPDATE challenge_runs SET
         rule_set = ?, xp = ?, coins = ?, freeze_tokens = ?, longest_streak = ?, rest_days_used = ?,
         is_active = ?, end_reason = ?, ended_at = ?
       WHERE id = ? AND user_id = ?`,
      [
        ruleSet ? JSON.stringify(ruleSet) : run.rule_set,
        xp ?? run.xp,
        Math.max(0, coins ?? run.coins),
        Math.max(0, freezeTokens ?? run.freeze_tokens),
        longestStreak ?? run.longest_streak,
        restDaysUsed ?? run.rest_days_used,
        isActive === undefined ? run.is_active : bool(isActive),
        endReason ?? run.end_reason,
        isActive === false && !run.ended_at ? new Date().toISOString() : run.ended_at,
        run.id,
        userId,
      ]
    );

    const updated = await db.get('SELECT * FROM challenge_runs WHERE id = ?', [run.id]);
    res.json(mapRun(updated));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Upsert a day. The client sends the whole day, which keeps this idempotent and
// means a dropped request costs nothing — the next tap resends the full state.
router.put('/runs/:id/days/:dayNumber', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;

    const run = await db.get('SELECT * FROM challenge_runs WHERE id = ? AND user_id = ?', [
      req.params.id,
      userId,
    ]);
    if (!run) return res.status(404).json({ error: 'Not found' });

    const dayNumber = Number(req.params.dayNumber);
    if (!Number.isInteger(dayNumber) || dayNumber < 1 || dayNumber > run.total_days) {
      return res.status(400).json({ error: 'Day out of range for this run' });
    }

    const body = req.body ?? {};
    const existing = await db.get('SELECT * FROM challenge_days WHERE run_id = ? AND day_number = ?', [
      run.id,
      dayNumber,
    ]);

    const fields = {
      date: body.date ?? existing?.date ?? new Date().toISOString().slice(0, 10),
      check_in: body.checkIn === undefined ? existing?.check_in ?? null : JSON.stringify(body.checkIn),
      scale_factor: body.scaleFactor ?? existing?.scale_factor ?? 1,
      scale_reason: body.scaleReason ?? existing?.scale_reason ?? '',
      entries: body.entries === undefined ? existing?.entries ?? '{}' : JSON.stringify(body.entries),
      is_complete: body.isComplete === undefined ? existing?.is_complete ?? 0 : bool(body.isComplete),
      completed_at: body.completedAt ?? existing?.completed_at ?? null,
      used_freeze: body.usedFreeze === undefined ? existing?.used_freeze ?? 0 : bool(body.usedFreeze),
      miss_acknowledged:
        body.missAcknowledged === undefined ? existing?.miss_acknowledged ?? 0 : bool(body.missAcknowledged),
      // `photo: undefined` leaves it alone; `photo: null` clears it.
      photo: body.photo === undefined ? existing?.photo ?? null : body.photo,
      reflection: body.reflection ?? existing?.reflection ?? '',
      xp_earned: body.xpEarned ?? existing?.xp_earned ?? 0,
      coins_earned: body.coinsEarned ?? existing?.coins_earned ?? 0,
    };

    // Named explicitly rather than spreading Object.values(fields): the column
    // list and the value list have to agree, and relying on object key order to
    // keep them in step is the kind of thing that silently writes a reflection
    // into the photo column six months from now.
    const columns = [
      'date', 'check_in', 'scale_factor', 'scale_reason', 'entries', 'is_complete',
      'completed_at', 'used_freeze', 'miss_acknowledged', 'photo', 'reflection',
      'xp_earned', 'coins_earned',
    ];
    const values = columns.map((column) => fields[column]);

    if (existing) {
      await db.run(
        `UPDATE challenge_days SET ${columns.map((c) => `${c} = ?`).join(', ')} WHERE id = ?`,
        [...values, existing.id]
      );
    } else {
      await db.run(
        `INSERT INTO challenge_days (user_id, run_id, day_number, ${columns.join(', ')})
         VALUES (${new Array(columns.length + 3).fill('?').join(', ')})`,
        [userId, run.id, dayNumber, ...values]
      );
    }

    const row = await db.get('SELECT * FROM challenge_days WHERE run_id = ? AND day_number = ?', [
      run.id,
      dayNumber,
    ]);
    res.json(mapDay(row));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Photos are fetched one at a time so the state call stays small.
router.get('/runs/:id/days/:dayNumber/photo', async (req, res) => {
  try {
    const db = getDB();
    const row = await db.get(
      `SELECT d.photo FROM challenge_days d
       JOIN challenge_runs r ON r.id = d.run_id
       WHERE d.run_id = ? AND d.day_number = ? AND r.user_id = ?`,
      [req.params.id, req.params.dayNumber, req.user.userId]
    );
    if (!row) return res.status(404).json({ error: 'Not found' });
    res.json({ photo: row.photo || null });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- recipes ----------------------------------------------------------------

router.post('/recipes/import', async (req, res) => {
  try {
    const draft = await importRecipe(req.body?.url);
    res.json(draft);
  } catch (err) {
    if (err instanceof ImportError) {
      return res.status(err.status).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
});

router.post('/recipes', async (req, res) => {
  try {
    const db = getDB();
    const recipe = req.body ?? {};
    if (!recipe.title) return res.status(400).json({ error: 'A title is required' });

    const result = await db.run('INSERT INTO challenge_recipes (user_id, data) VALUES (?, ?)', [
      req.user.userId,
      JSON.stringify(recipe),
    ]);
    res.status(201).json({ ...recipe, id: `user:${result.lastID}`, dbId: result.lastID });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/recipes/:id', async (req, res) => {
  try {
    const db = getDB();
    await db.run('DELETE FROM challenge_recipes WHERE id = ? AND user_id = ?', [
      req.params.id,
      req.user.userId,
    ]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- meal plan --------------------------------------------------------------

router.get('/meals', async (req, res) => {
  try {
    const db = getDB();
    const { start, days = 7 } = req.query;
    const startDate = start || new Date().toISOString().slice(0, 10);
    const end = new Date(`${startDate}T00:00:00Z`);
    end.setUTCDate(end.getUTCDate() + Number(days));

    const rows = await db.all(
      'SELECT * FROM challenge_meals WHERE user_id = ? AND date >= ? AND date < ? ORDER BY date, slot',
      [req.user.userId, startDate, end.toISOString().slice(0, 10)]
    );

    res.json(
      rows.map((r) => ({
        id: r.id,
        date: r.date,
        slot: r.slot,
        recipeId: r.recipe_id,
        recipeTitle: r.recipe_title,
        servings: r.servings,
      }))
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/meals', async (req, res) => {
  try {
    const db = getDB();
    const { date, slot, recipeId, recipeTitle, servings = 1 } = req.body ?? {};
    if (!date || !slot || !recipeId) {
      return res.status(400).json({ error: 'date, slot and recipeId are required' });
    }

    const result = await db.run(
      'INSERT INTO challenge_meals (user_id, date, slot, recipe_id, recipe_title, servings) VALUES (?, ?, ?, ?, ?, ?)',
      [req.user.userId, date, slot, recipeId, recipeTitle || '', servings]
    );
    res.status(201).json({ id: result.lastID, date, slot, recipeId, recipeTitle, servings });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Replace a whole week in one shot, which is what "rebuild my week" wants.
router.put('/meals/week', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;
    const { weekStart, meals = [] } = req.body ?? {};
    if (!weekStart) return res.status(400).json({ error: 'weekStart is required' });

    const end = new Date(`${weekStart}T00:00:00Z`);
    end.setUTCDate(end.getUTCDate() + 7);
    const endDate = end.toISOString().slice(0, 10);

    await db.run('DELETE FROM challenge_meals WHERE user_id = ? AND date >= ? AND date < ?', [
      userId,
      weekStart,
      endDate,
    ]);

    for (const meal of meals) {
      await db.run(
        'INSERT INTO challenge_meals (user_id, date, slot, recipe_id, recipe_title, servings) VALUES (?, ?, ?, ?, ?, ?)',
        [userId, meal.date, meal.slot, meal.recipeId, meal.recipeTitle || '', meal.servings || 1]
      );
    }

    const rows = await db.all(
      'SELECT * FROM challenge_meals WHERE user_id = ? AND date >= ? AND date < ? ORDER BY date, slot',
      [userId, weekStart, endDate]
    );
    res.json(
      rows.map((r) => ({
        id: r.id,
        date: r.date,
        slot: r.slot,
        recipeId: r.recipe_id,
        recipeTitle: r.recipe_title,
        servings: r.servings,
      }))
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/meals/:id', async (req, res) => {
  try {
    const db = getDB();
    await db.run('DELETE FROM challenge_meals WHERE id = ? AND user_id = ?', [
      req.params.id,
      req.user.userId,
    ]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- shopping list ----------------------------------------------------------

router.get('/shopping', async (req, res) => {
  try {
    const db = getDB();
    const weekStart = req.query.weekStart || new Date().toISOString().slice(0, 10);
    const rows = await db.all(
      'SELECT * FROM challenge_shopping WHERE user_id = ? AND week_start = ? ORDER BY aisle, name',
      [req.user.userId, weekStart]
    );
    res.json(
      rows.map((r) => ({
        id: r.id,
        name: r.name,
        quantity: r.quantity,
        unit: r.unit,
        aisle: r.aisle,
        checked: !!r.checked,
        manual: !!r.manual,
        sources: asJson(r.sources, []),
      }))
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Rebuilding replaces generated lines but leaves anything hand-added alone —
// the milk you added yourself shouldn't vanish because you re-planned dinner.
router.put('/shopping', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;
    const { weekStart, items = [] } = req.body ?? {};
    if (!weekStart) return res.status(400).json({ error: 'weekStart is required' });

    await db.run('DELETE FROM challenge_shopping WHERE user_id = ? AND week_start = ? AND manual = 0', [
      userId,
      weekStart,
    ]);

    for (const item of items) {
      await db.run(
        `INSERT INTO challenge_shopping (user_id, week_start, name, quantity, unit, aisle, sources)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [userId, weekStart, item.name, item.quantity ?? 1, item.unit ?? '', item.aisle ?? 'other', JSON.stringify(item.sources ?? [])]
      );
    }

    const rows = await db.all(
      'SELECT * FROM challenge_shopping WHERE user_id = ? AND week_start = ? ORDER BY aisle, name',
      [userId, weekStart]
    );
    res.json(
      rows.map((r) => ({
        id: r.id,
        name: r.name,
        quantity: r.quantity,
        unit: r.unit,
        aisle: r.aisle,
        checked: !!r.checked,
        manual: !!r.manual,
        sources: asJson(r.sources, []),
      }))
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/shopping', async (req, res) => {
  try {
    const db = getDB();
    const { weekStart, name, quantity = 1, unit = '', aisle = 'other' } = req.body ?? {};
    if (!weekStart || !name) return res.status(400).json({ error: 'weekStart and name are required' });

    const result = await db.run(
      `INSERT INTO challenge_shopping (user_id, week_start, name, quantity, unit, aisle, manual)
       VALUES (?, ?, ?, ?, ?, ?, 1)`,
      [req.user.userId, weekStart, name, quantity, unit, aisle]
    );
    res.status(201).json({ id: result.lastID, name, quantity, unit, aisle, checked: false, manual: true, sources: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.patch('/shopping/:id', async (req, res) => {
  try {
    const db = getDB();
    await db.run('UPDATE challenge_shopping SET checked = ? WHERE id = ? AND user_id = ?', [
      bool(req.body?.checked),
      req.params.id,
      req.user.userId,
    ]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/shopping/:id', async (req, res) => {
  try {
    const db = getDB();
    await db.run('DELETE FROM challenge_shopping WHERE id = ? AND user_id = ?', [
      req.params.id,
      req.user.userId,
    ]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- rewards ----------------------------------------------------------------

router.post('/rewards', async (req, res) => {
  try {
    const db = getDB();
    const { title, detail = '', cost = 50, category = 'treat', symbol = 'gift', isCustom = true, unlocksAtDay = null } =
      req.body ?? {};
    if (!title) return res.status(400).json({ error: 'A title is required' });

    const result = await db.run(
      `INSERT INTO challenge_rewards (user_id, title, detail, cost, category, symbol, is_custom, unlocks_at_day)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.user.userId, title, detail, cost, category, symbol, bool(isCustom), unlocksAtDay]
    );
    const row = await db.get('SELECT * FROM challenge_rewards WHERE id = ?', [result.lastID]);
    res.status(201).json(mapReward(row));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/rewards/:id', async (req, res) => {
  try {
    const db = getDB();
    await db.run('UPDATE challenge_rewards SET archived = 1 WHERE id = ? AND user_id = ?', [
      req.params.id,
      req.user.userId,
    ]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// The one place the server refuses to take the client's word for it: you cannot
// spend coins you don't have, and the balance is decremented from the stored
// value rather than from whatever the browser thinks it is.
router.post('/rewards/:id/redeem', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;

    const reward = await db.get('SELECT * FROM challenge_rewards WHERE id = ? AND user_id = ?', [
      req.params.id,
      userId,
    ]);
    if (!reward) return res.status(404).json({ error: 'Not found' });
    if (reward.unlocks_at_day) return res.status(400).json({ error: 'Milestone rewards are unlocked, not bought' });

    const run = await db.get(
      'SELECT * FROM challenge_runs WHERE user_id = ? AND is_active = 1 ORDER BY start_date DESC LIMIT 1',
      [userId]
    );
    if (!run) return res.status(400).json({ error: 'No active run' });
    if (run.coins < reward.cost) {
      return res.status(400).json({ error: `That costs ${reward.cost} coins and you have ${run.coins}.` });
    }

    await db.run('UPDATE challenge_runs SET coins = coins - ? WHERE id = ?', [reward.cost, run.id]);
    await db.run('UPDATE challenge_rewards SET times_redeemed = times_redeemed + 1 WHERE id = ?', [reward.id]);
    await db.run(
      'INSERT INTO challenge_redemptions (user_id, reward_title, cost, day_number, note) VALUES (?, ?, ?, ?, ?)',
      [userId, reward.title, reward.cost, req.body?.dayNumber ?? 0, req.body?.note ?? '']
    );

    const updated = await db.get('SELECT * FROM challenge_runs WHERE id = ?', [run.id]);
    res.json({ coins: updated.coins });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- achievements -----------------------------------------------------------

router.post('/achievements', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;
    const codes = Array.isArray(req.body?.codes) ? req.body.codes : [];
    const runId = req.body?.runId ?? null;

    for (const code of codes) {
      await db.run(
        'INSERT OR IGNORE INTO challenge_achievements (user_id, code, run_id) VALUES (?, ?, ?)',
        [userId, code, runId]
      );
    }

    const rows = await db.all('SELECT code, unlocked_at FROM challenge_achievements WHERE user_id = ?', [userId]);
    res.json(rows.map((r) => ({ code: r.code, unlockedAt: r.unlocked_at })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- reset ------------------------------------------------------------------

router.delete('/reset', async (req, res) => {
  try {
    const db = getDB();
    const userId = req.user.userId;

    // challenge_days cascades from challenge_runs.
    for (const table of [
      'challenge_runs',
      'challenge_meals',
      'challenge_shopping',
      'challenge_rewards',
      'challenge_redemptions',
      'challenge_achievements',
      'challenge_recipes',
      'challenge_profiles',
    ]) {
      await db.run(`DELETE FROM ${table} WHERE user_id = ?`, [userId]);
    }

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
