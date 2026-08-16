// Starter rewards. These are suggestions the user edits or deletes — onboarding
// explicitly asks them to name their own, because a reward someone else chose
// has no pull.

export const STARTER_REWARDS = [
  { title: 'A proper lie-in', detail: 'No alarm. The plan waits until you’re up.', cost: 60, category: 'rest', symbol: '🛏️' },
  { title: 'Long bath or sauna', detail: 'Thirty uninterrupted minutes.', cost: 40, category: 'rest', symbol: '🛁' },
  { title: 'Massage', detail: 'Book it. Actually book it.', cost: 200, category: 'rest', symbol: '💆' },
  { title: 'Film night, your pick', detail: 'Nobody else gets a vote.', cost: 50, category: 'treat', symbol: '🎬' },
  { title: 'The good coffee', detail: 'The one you normally talk yourself out of.', cost: 25, category: 'treat', symbol: '☕' },
  { title: 'New book', detail: "You're going through them at ten pages a day now.", cost: 80, category: 'gear', symbol: '📚' },
  { title: 'New trainers', detail: 'Earned, not bought on a whim.', cost: 400, category: 'gear', symbol: '👟' },
  { title: 'Lunch with someone you miss', detail: 'You pay.', cost: 120, category: 'social', symbol: '👥' },
  { title: 'A day trip', detail: 'Somewhere you keep meaning to go.', cost: 300, category: 'experience', symbol: '🗺️' },
  { title: 'Concert or match ticket', detail: 'Front half of the venue.', cost: 500, category: 'experience', symbol: '🎟️' },
];

// Unlocked by reaching a day, not by spending coins.
export const MILESTONE_REWARDS = [
  { title: 'Week One Badge', detail: 'Seven days in. Tell one person.', cost: 0, category: 'milestone', symbol: '⑦', unlocksAtDay: 7 },
  { title: 'Quarter Mark Treat', detail: 'Day 25. Something small and real, today.', cost: 0, category: 'milestone', symbol: '🚩', unlocksAtDay: 25 },
  { title: 'Halfway Reset', detail: 'Day 38. A full rest day that costs you nothing.', cost: 0, category: 'milestone', symbol: '🔄', unlocksAtDay: 38 },
  { title: 'Fifty Day Splurge', detail: 'Day 50. The one you’ve been eyeing.', cost: 0, category: 'milestone', symbol: '🏁', unlocksAtDay: 50 },
  { title: "Finisher's Prize", detail: 'Day 75. Decide what this is on day one.', cost: 0, category: 'milestone', symbol: '🏆', unlocksAtDay: 75 },
];

// Used in onboarding to get the user to name rewards that mean something.
export const REWARD_PROMPTS = [
  "What's something small you'd enjoy this week but usually don't let yourself have?",
  "What's worth a month of work?",
  'What would you want waiting for you on day 75?',
];

export const REWARD_PROMPT_COSTS = [40, 150, 400];
export const REWARD_PROMPT_CATEGORIES = ['treat', 'experience', 'milestone'];
