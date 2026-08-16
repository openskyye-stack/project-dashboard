// Badges deliberately weight the behaviour that predicts finishing. "Five Hard
// Mornings" — five heavily scaled days finished rather than skipped — is worth
// three times "Well Watered", because that is the habit that actually carries
// someone to day 75.

export const ACHIEVEMENTS = [
  { code: 'first.day', title: 'Day One Done', detail: 'You finished a full day. The hardest one is behind you.', icon: '①', coins: 15 },
  { code: 'week.one', title: 'Seven Straight', detail: 'A full week without a gap.', icon: '⑦', coins: 30 },
  { code: 'day.25', title: 'Quarter Mark', detail: 'Twenty-five days complete.', icon: '🚩', coins: 60 },
  { code: 'day.50', title: 'Two Thirds', detail: 'Fifty days complete. Most people never see this screen.', icon: '🏁', coins: 100 },
  { code: 'day.75', title: 'Finisher', detail: 'Seventy-five days. Done.', icon: '🏆', coins: 250 },

  { code: 'streak.14', title: 'Fortnight', detail: 'A fourteen-day streak.', icon: '🔥', coins: 45 },
  { code: 'streak.30', title: 'Thirty Days Lit', detail: 'A thirty-day streak.', icon: '🌋', coins: 90 },

  { code: 'hydration.perfect.week', title: 'Well Watered', detail: 'Hit your water target seven days running.', icon: '💧', coins: 25 },
  { code: 'reading.perfect.week', title: 'Page Turner', detail: 'Seven straight days of reading.', icon: '📖', coins: 25 },

  { code: 'deload.hero', title: 'Showed Up Anyway', detail: 'Completed a day your body had voted against.', icon: '❤️', coins: 30 },
  {
    code: 'deload.veteran',
    title: 'Five Hard Mornings',
    detail: 'Five heavily scaled days finished rather than skipped. This is the badge that actually predicts finishing.',
    icon: '🛡️',
    coins: 75,
  },

  { code: 'early.bird', title: 'Before Nine', detail: 'Finished a whole day before 9am.', icon: '🌅', coins: 20 },
  { code: 'meal.planner', title: 'Prepped', detail: 'Planned a full week of meals.', icon: '📅', coins: 30 },
  { code: 'meal.architect', title: 'Kitchen Architect', detail: 'Thirty planned meals.', icon: '🍽️', coins: 60 },
  {
    code: 'reward.claimed',
    title: 'Paid Yourself',
    detail: 'Redeemed your first reward. Claiming them is part of the system, not a weakness.',
    icon: '🎁',
    coins: 10,
  },
  { code: 'photo.streak', title: 'Ten in Frame', detail: 'Ten consecutive progress photos.', icon: '📷', coins: 30 },

  {
    code: 'comeback',
    title: 'Back Again',
    detail: 'Restarted and got seven days deep. Attempt two beats attempt one every time.',
    icon: '🔄',
    coins: 50,
  },
  {
    code: 'balance.builder',
    title: 'Steady',
    detail: 'Twenty days of balance work. This is the one that keeps you on your feet at eighty.',
    icon: '🧘',
    coins: 60,
  },
  { code: 'no.freeze', title: 'Clean Thirty', detail: 'Thirty completed days without spending a single freeze.', icon: '💎', coins: 70 },
  { code: 'honest.log', title: 'Thirty Check-ins', detail: 'Told the truth about how you felt thirty times.', icon: '✅', coins: 40 },
  {
    code: 'age.is.a.number',
    title: 'Thirty at Sixty-Five Plus',
    detail: 'Thirty days done, past an age where most people stop starting things.',
    icon: '⭐',
    coins: 100,
  },
];

export const achievementByCode = Object.fromEntries(ACHIEVEMENTS.map((a) => [a.code, a]));
