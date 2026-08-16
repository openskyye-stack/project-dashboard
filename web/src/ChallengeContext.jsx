import { createContext, useContext, useCallback, useEffect, useMemo, useState } from 'react';

import { api, ApiError, TOKEN_KEY, USER_KEY } from './api.js';
import { TIER_INFO } from './engine/constants.js';
import { buildRules } from './engine/tiers.js';
import { scaledTarget } from './engine/dayScaler.js';
import {
  todayKey,
  dayNumberFor,
  isDayComplete,
  summarise,
  awardForDay,
  newlyUnlocked,
  needsMissResolution,
  entrySatisfied,
} from './engine/progress.js';
import { BUILTIN_RECIPES } from './data/recipes.js';
import { STARTER_REWARDS, MILESTONE_REWARDS } from './data/rewards.js';

const ChallengeContext = createContext(null);

export const useChallenge = () => {
  const value = useContext(ChallengeContext);
  if (!value) throw new Error('useChallenge must be used inside ChallengeProvider');
  return value;
};

// One store for the whole app.
//
// Every action updates local state first and then persists, so tapping a task
// never waits on the network. If a write fails the error surfaces in a banner
// and the next write resends the whole day, which is why the day endpoint is an
// idempotent upsert rather than a patch.
export function ChallengeProvider({ user, onSignOut, children }) {
  const [state, setState] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [celebration, setCelebration] = useState(null);

  const handleError = useCallback(
    (err) => {
      if (err instanceof ApiError && err.status === 401) {
        onSignOut?.();
        return;
      }
      setError(err.message);
    },
    [onSignOut]
  );

  const refresh = useCallback(async () => {
    try {
      const next = await api.get('/api/challenge/state');
      setState(next);
      setError(null);
      return next;
    } catch (err) {
      handleError(err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [handleError]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // --- derived --------------------------------------------------------------

  const recipes = useMemo(
    () => [...BUILTIN_RECIPES, ...(state?.importedRecipes ?? [])],
    [state?.importedRecipes]
  );

  const run = state?.run ?? null;
  const profile = state?.profile ?? null;
  const days = state?.days ?? [];
  const ruleSet = run?.ruleSet ?? { rules: [], globalNotes: [] };

  const todayNumber = run ? dayNumberFor(run) : null;
  const today = todayNumber ? days.find((d) => d.dayNumber === todayNumber) ?? null : null;

  const stats = useMemo(() => (run ? summarise(run, days) : null), [run, days]);

  const unresolvedMiss = useMemo(
    () => days.find((day) => needsMissResolution(day, ruleSet)) ?? null,
    [days, ruleSet]
  );

  // --- helpers --------------------------------------------------------------

  const patchState = useCallback((updater) => {
    setState((current) => (current ? updater(current) : current));
  }, []);

  const upsertDay = useCallback(
    (dayNumber, changes) => {
      patchState((current) => {
        const existing = current.days.find((d) => d.dayNumber === dayNumber);
        const merged = existing
          ? { ...existing, ...changes }
          : {
              dayNumber,
              date: todayKey(),
              checkIn: null,
              scaleFactor: 1,
              scaleReason: '',
              entries: {},
              isComplete: false,
              completedAt: null,
              usedFreeze: false,
              missAcknowledged: false,
              reflection: '',
              xpEarned: 0,
              coinsEarned: 0,
              ...changes,
            };

        return {
          ...current,
          days: existing
            ? current.days.map((d) => (d.dayNumber === dayNumber ? merged : d))
            : [...current.days, merged].sort((a, b) => a.dayNumber - b.dayNumber),
        };
      });
    },
    [patchState]
  );

  const persistDay = useCallback(
    async (runId, dayNumber, payload) => {
      try {
        await api.put(`/api/challenge/runs/${runId}/days/${dayNumber}`, payload);
      } catch (err) {
        handleError(err);
      }
    },
    [handleError]
  );

  // Entries carry the target they were judged against, so re-adapting the plan
  // later cannot retroactively fail a day someone already finished.
  const ensureEntries = useCallback((day, rules, scaleFactor) => {
    const entries = { ...(day?.entries ?? {}) };
    for (const rule of rules) {
      const target = scaledTarget(rule, scaleFactor);
      entries[rule.id] = { value: 0, done: false, ...entries[rule.id], target };
    }
    return entries;
  }, []);

  // --- actions --------------------------------------------------------------

  const saveProfile = useCallback(
    async (nextProfile) => {
      patchState((current) => ({ ...current, profile: nextProfile }));
      try {
        await api.put('/api/challenge/profile', nextProfile);
      } catch (err) {
        handleError(err);
      }
    },
    [patchState, handleError]
  );

  const startRun = useCallback(
    async (tier, nextProfile, extraRewards = []) => {
      const rules = buildRules(tier, nextProfile);
      try {
        await api.put('/api/challenge/profile', nextProfile);

        const created = await api.post('/api/challenge/runs', {
          tier,
          ruleSet: rules,
          startDate: todayKey(),
          freezeTokens: TIER_INFO[tier].startingFreezes,
        });

        // Seed the reward shop on the very first run only, so a restart doesn't
        // duplicate everything the user has already curated.
        if ((state?.rewards ?? []).length === 0) {
          for (const reward of [...extraRewards, ...STARTER_REWARDS, ...MILESTONE_REWARDS]) {
            await api.post('/api/challenge/rewards', reward);
          }
        }

        await refresh();
        return created;
      } catch (err) {
        handleError(err);
        return null;
      }
    },
    [state?.rewards, refresh, handleError]
  );

  const submitCheckIn = useCallback(
    async (checkIn, outcome) => {
      if (!run || !todayNumber) return;

      const existing = days.find((d) => d.dayNumber === todayNumber);
      const entries = ensureEntries(existing, ruleSet.rules, outcome.scaleFactor);

      const changes = {
        date: todayKey(),
        checkIn,
        scaleFactor: outcome.scaleFactor,
        scaleReason: outcome.reason,
        entries,
      };

      upsertDay(todayNumber, changes);
      await persistDay(run.id, todayNumber, changes);
    },
    [run, todayNumber, days, ruleSet, ensureEntries, upsertDay, persistDay]
  );

  // Shared tail for anything that changes a task: recompute completion, award
  // XP the first time the day tips over, and persist.
  const applyEntryChange = useCallback(
    async (mutate) => {
      if (!run || !todayNumber) return;

      const existing = days.find((d) => d.dayNumber === todayNumber);
      const baseEntries = ensureEntries(existing, ruleSet.rules, existing?.scaleFactor ?? 1);
      const entries = mutate({ ...baseEntries });

      const candidate = {
        ...(existing ?? { dayNumber: todayNumber, date: todayKey(), scaleFactor: 1 }),
        entries,
      };

      const wasComplete = existing?.isComplete ?? false;
      const nowComplete = isDayComplete(candidate, ruleSet);

      const changes = { date: todayKey(), entries };

      if (nowComplete && !wasComplete) {
        const streakBefore = stats?.current ?? 0;
        const award = awardForDay(candidate, ruleSet, streakBefore, run.tier);

        changes.isComplete = true;
        changes.completedAt = new Date().toISOString();
        changes.xpEarned = award.totalXp;
        changes.coinsEarned = award.coins;

        const updatedDays = days.some((d) => d.dayNumber === todayNumber)
          ? days.map((d) => (d.dayNumber === todayNumber ? { ...candidate, ...changes } : d))
          : [...days, { ...candidate, ...changes }];

        const unlocked = newlyUnlocked({
          run,
          profile,
          days: updatedDays,
          unlocked: new Set((state?.achievements ?? []).map((a) => a.code)),
          redemptionCount: (state?.redemptions ?? []).length,
          plannedMealCount: state?.plannedMealCount ?? 0,
        });

        const achievementCoins = unlocked.reduce((sum, a) => sum + a.coins, 0);
        const nextRun = {
          ...run,
          xp: run.xp + award.totalXp,
          coins: run.coins + award.coins + achievementCoins,
          freezeTokens: run.freezeTokens + (award.earnsFreeze ? 1 : 0),
          longestStreak: Math.max(run.longestStreak, (stats?.longest ?? 0) + 1),
        };

        upsertDay(todayNumber, changes);
        patchState((current) => ({ ...current, run: nextRun }));

        setCelebration({
          title: todayNumber >= run.totalDays ? 'Seventy-five days. Done.' : 'Day complete',
          message: buildCelebrationMessage(todayNumber, run, award, candidate),
          coins: award.coins + achievementCoins,
          achievements: unlocked,
        });

        await persistDay(run.id, todayNumber, changes);
        try {
          await api.put(`/api/challenge/runs/${run.id}`, {
            xp: nextRun.xp,
            coins: nextRun.coins,
            freezeTokens: nextRun.freezeTokens,
            longestStreak: nextRun.longestStreak,
          });
          if (unlocked.length > 0) {
            const achievements = await api.post('/api/challenge/achievements', {
              codes: unlocked.map((a) => a.code),
              runId: run.id,
            });
            patchState((current) => ({ ...current, achievements }));
          }
        } catch (err) {
          handleError(err);
        }
        return;
      }

      upsertDay(todayNumber, changes);
      await persistDay(run.id, todayNumber, changes);
    },
    [
      run, todayNumber, days, ruleSet, stats, profile, state, ensureEntries,
      upsertDay, patchState, persistDay, handleError,
    ]
  );

  const logAmount = useCallback(
    (rule, amount) =>
      applyEntryChange((entries) => {
        const entry = entries[rule.id];
        const value = Math.max(0, (entry.value ?? 0) + amount);
        return { ...entries, [rule.id]: { ...entry, value, done: entry.done && value > 0 } };
      }),
    [applyEntryChange]
  );

  const toggleRule = useCallback(
    (rule) =>
      applyEntryChange((entries) => {
        const entry = entries[rule.id];
        const done = !entrySatisfied(entry, entry.target);
        return {
          ...entries,
          [rule.id]: { ...entry, done, value: done ? Math.max(entry.value ?? 0, entry.target) : 0 },
        };
      }),
    [applyEntryChange]
  );

  const setPhoto = useCallback(
    async (dataUrl) => {
      if (!run || !todayNumber) return;
      upsertDay(todayNumber, { photo: dataUrl, hasPhoto: Boolean(dataUrl) });
      await persistDay(run.id, todayNumber, { date: todayKey(), photo: dataUrl });

      const photoRule = ruleSet.rules.find((r) => r.id === 'photo');
      if (photoRule && dataUrl) {
        await applyEntryChange((entries) => ({
          ...entries,
          [photoRule.id]: { ...entries[photoRule.id], done: true, value: 1 },
        }));
      }
    },
    [run, todayNumber, ruleSet, upsertDay, persistDay, applyEntryChange]
  );

  const setReflection = useCallback(
    async (textValue) => {
      if (!run || !todayNumber) return;
      upsertDay(todayNumber, { reflection: textValue });

      const rule = ruleSet.rules.find((r) => r.id === 'reflection');
      if (rule) {
        await applyEntryChange((entries) => ({
          ...entries,
          [rule.id]: { ...entries[rule.id], done: textValue.trim().length > 0, value: textValue.trim() ? 1 : 0 },
        }));
      }
      await persistDay(run.id, todayNumber, { date: todayKey(), reflection: textValue });
    },
    [run, todayNumber, ruleSet, upsertDay, persistDay, applyEntryChange]
  );

  const spendFreeze = useCallback(
    async (dayNumber) => {
      if (!run || run.freezeTokens <= 0 || run.tier === 'hard') return;

      const changes = {
        usedFreeze: true,
        isComplete: true,
        completedAt: new Date().toISOString(),
        missAcknowledged: true,
      };
      upsertDay(dayNumber, changes);

      const nextRun = { ...run, freezeTokens: run.freezeTokens - 1, restDaysUsed: run.restDaysUsed + 1 };
      patchState((current) => ({ ...current, run: nextRun }));

      setCelebration({
        title: 'Day protected',
        message: `You've spent a freeze on day ${dayNumber}. The streak holds. Rest is part of the plan, not a hole in it.`,
        coins: 0,
        achievements: [],
      });

      await persistDay(run.id, dayNumber, changes);
      try {
        await api.put(`/api/challenge/runs/${run.id}`, {
          freezeTokens: nextRun.freezeTokens,
          restDaysUsed: nextRun.restDaysUsed,
        });
      } catch (err) {
        handleError(err);
      }
    },
    [run, upsertDay, patchState, persistDay, handleError]
  );

  const acknowledgeMiss = useCallback(
    async (dayNumber) => {
      if (!run) return;
      upsertDay(dayNumber, { missAcknowledged: true });
      await persistDay(run.id, dayNumber, { missAcknowledged: true });
    },
    [run, upsertDay, persistDay]
  );

  const restart = useCallback(
    async (tier) => {
      if (!profile) return;
      await startRun(tier ?? run?.tier ?? 'medium', profile);
    },
    [profile, run, startRun]
  );

  const readaptRules = useCallback(async () => {
    if (!run || !profile) return;
    const rules = buildRules(run.tier, profile);
    patchState((current) => ({ ...current, run: { ...current.run, ruleSet: rules } }));
    try {
      await api.put(`/api/challenge/runs/${run.id}`, { ruleSet: rules });
    } catch (err) {
      handleError(err);
    }
  }, [run, profile, patchState, handleError]);

  const redeemReward = useCallback(
    async (reward) => {
      if (!run) return false;
      try {
        const { coins } = await api.post(`/api/challenge/rewards/${reward.id}/redeem`, {
          dayNumber: todayNumber ?? 0,
        });
        patchState((current) => ({ ...current, run: { ...current.run, coins } }));
        await refresh();
        return true;
      } catch (err) {
        handleError(err);
        return false;
      }
    },
    [run, todayNumber, patchState, refresh, handleError]
  );

  const addReward = useCallback(
    async (reward) => {
      try {
        const created = await api.post('/api/challenge/rewards', reward);
        patchState((current) => ({ ...current, rewards: [...current.rewards, created] }));
      } catch (err) {
        handleError(err);
      }
    },
    [patchState, handleError]
  );

  const removeReward = useCallback(
    async (id) => {
      patchState((current) => ({ ...current, rewards: current.rewards.filter((r) => r.id !== id) }));
      try {
        await api.del(`/api/challenge/rewards/${id}`);
      } catch (err) {
        handleError(err);
      }
    },
    [patchState, handleError]
  );

  const resetEverything = useCallback(async () => {
    try {
      await api.del('/api/challenge/reset');
      localStorage.removeItem(`${USER_KEY}:challenge`);
      await refresh();
    } catch (err) {
      handleError(err);
    }
  }, [refresh, handleError]);

  const value = {
    loading, error, setError, user,
    state, profile, run, days, ruleSet, recipes,
    today, todayNumber, stats, unresolvedMiss,
    celebration, setCelebration,
    refresh, saveProfile, startRun, submitCheckIn,
    logAmount, toggleRule, setPhoto, setReflection,
    spendFreeze, acknowledgeMiss, restart, readaptRules,
    redeemReward, addReward, removeReward, resetEverything,
    signOut: () => {
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(USER_KEY);
      onSignOut?.();
    },
  };

  return <ChallengeContext.Provider value={value}>{children}</ChallengeContext.Provider>;
}

function buildCelebrationMessage(dayNumber, run, award, day) {
  let message = `Day ${dayNumber} of ${run.totalDays} complete.`;
  if (award.multiplier > 1) message += ` Streak multiplier ×${award.multiplier.toFixed(2)}.`;
  if (day.scaleFactor < 1) {
    message += " You did it on a day your body voted against — that's the one that counts.";
  }
  return message;
}
