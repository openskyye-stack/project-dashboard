import { useEffect, useState } from 'react';

import { api, TOKEN_KEY, USER_KEY } from './api.js';
import { ChallengeProvider, useChallenge } from './ChallengeContext.jsx';
import Onboarding from './components/Onboarding.jsx';
import Today from './components/Today.jsx';
import Meals from './components/Meals.jsx';
import Rewards from './components/Rewards.jsx';
import Progress from './components/Progress.jsx';
import Settings from './components/Settings.jsx';
import { Card, Modal, Note } from './components/ui.jsx';

const TABS = [
  { id: 'today', label: 'Today', icon: '✓' },
  { id: 'meals', label: 'Meals', icon: '🍽' },
  { id: 'rewards', label: 'Rewards', icon: '🎁' },
  { id: 'progress', label: 'Progress', icon: '📈' },
  { id: 'settings', label: 'Settings', icon: '⚙️' },
];

export default function App() {
  const [session, setSession] = useState(() => readSession());

  if (!session) return <AuthScreen onSignedIn={setSession} />;

  return (
    <ChallengeProvider user={session.user} onSignOut={() => setSession(null)}>
      <Shell />
    </ChallengeProvider>
  );
}

function readSession() {
  const token = localStorage.getItem(TOKEN_KEY);
  if (!token) return null;
  try {
    return { token, user: JSON.parse(localStorage.getItem(USER_KEY) ?? 'null') };
  } catch {
    return { token, user: null };
  }
}

// --- shell ------------------------------------------------------------------

function Shell() {
  const { loading, error, setError, profile, run, todayNumber, startRun, celebration, setCelebration } =
    useChallenge();
  const [tab, setTab] = useState('today');

  // Accessibility preferences live on the profile so they follow the user
  // between devices rather than being stuck in one browser's storage.
  useEffect(() => {
    const root = document.documentElement;
    root.dataset.largeText = String(Boolean(profile?.wantsLargeText));
    root.dataset.reduceMotion = String(Boolean(profile?.wantsReducedMotion));
  }, [profile?.wantsLargeText, profile?.wantsReducedMotion]);

  if (loading) {
    return (
      <div className="auth">
        <p className="muted">Loading…</p>
      </div>
    );
  }

  if (!profile || !run) {
    return <Onboarding onStart={startRun} />;
  }

  return (
    <div className="app">
      <a className="skip-link" href="#main">Skip to content</a>

      <header className="topbar">
        <span className="topbar__title">
          {tab === 'today' ? (todayNumber ? `Day ${todayNumber}` : 'Today') : TABS.find((t) => t.id === tab)?.label}
        </span>
        <span className="topbar__meta">
          <span title="Grit Coins">🪙 <strong>{run.coins}</strong></span>
          {run.freezeTokens > 0 && <span title="Freeze tokens">❄️ <strong>{run.freezeTokens}</strong></span>}
        </span>
      </header>

      {error && (
        <div style={{ padding: '0 1rem' }}>
          <div className="banner">
            <span>{error}</span>
            <button type="button" className="btn btn--ghost btn--small" onClick={() => setError(null)}>
              Dismiss
            </button>
          </div>
        </div>
      )}

      <main className="app__body" id="main">
        {tab === 'today' && <Today />}
        {tab === 'meals' && <Meals />}
        {tab === 'rewards' && <Rewards />}
        {tab === 'progress' && <Progress />}
        {tab === 'settings' && <Settings />}
      </main>

      <nav className="tabbar" aria-label="Sections">
        {TABS.map((item) => (
          <button
            key={item.id}
            type="button"
            aria-current={tab === item.id ? 'page' : undefined}
            onClick={() => setTab(item.id)}
          >
            <span className="tabbar__icon" aria-hidden="true">{item.icon}</span>
            {item.label}
          </button>
        ))}
      </nav>

      {celebration && <CelebrationModal celebration={celebration} onClose={() => setCelebration(null)} />}
    </div>
  );
}

// --- celebration ------------------------------------------------------------

// Short, loud, and gone. A celebration that needs dismissing twice stops being
// a reward.
function CelebrationModal({ celebration, onClose }) {
  return (
    <Modal title={celebration.title} onClose={onClose}>
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontSize: '4rem', lineHeight: 1 }} aria-hidden="true">
          {celebration.title.includes('protected') ? '❄️' : '🎉'}
        </div>
        <h1>{celebration.title}</h1>
        <p className="muted">{celebration.message}</p>
      </div>

      {celebration.coins > 0 && (
        <p style={{ textAlign: 'center', fontSize: '1.3rem', fontWeight: 700, color: 'var(--coin)' }}>
          +{celebration.coins} Grit Coins
        </p>
      )}

      {celebration.achievements.length > 0 && (
        <Card>
          <strong className="tiny">Unlocked</strong>
          {celebration.achievements.map((achievement) => (
            <div key={achievement.code} className="row">
              <span style={{ fontSize: '1.6rem' }} aria-hidden="true">{achievement.icon}</span>
              <div>
                <strong style={{ display: 'block' }}>{achievement.title}</strong>
                <span className="tiny">{achievement.detail}</span>
              </div>
            </div>
          ))}
        </Card>
      )}

      <button type="button" className="btn btn--primary btn--block" onClick={onClose}>
        Nice
      </button>
    </Modal>
  );
}

// --- auth -------------------------------------------------------------------

function AuthScreen({ onSignedIn }) {
  const [mode, setMode] = useState('login');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [masterPin, setMasterPin] = useState('');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const submit = async (event) => {
    event.preventDefault();
    setBusy(true);
    setError(null);

    try {
      const data =
        mode === 'login'
          ? await api.login(username, password)
          : await api.signup(username, password, masterPin);

      localStorage.setItem(TOKEN_KEY, data.token);
      localStorage.setItem(USER_KEY, JSON.stringify(data.user));
      onSignedIn({ token: data.token, user: data.user });
    } catch (err) {
      setError(err.message);
    }
    setBusy(false);
  };

  return (
    <div className="auth">
      <form className="card auth__card" onSubmit={submit}>
        <h1>75 Adaptive</h1>
        <p className="muted">
          A seventy-five day challenge that adapts to your age, your joints and how today actually feels.
        </p>

        <label className="field">
          <span className="tiny">Username</span>
          <input
            className="input"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            required
          />
        </label>

        <label className="field">
          <span className="tiny">Password</span>
          <input
            className="input"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
            required
          />
        </label>

        {mode === 'signup' && (
          <label className="field">
            <span className="tiny">Master PIN (4–6 digits)</span>
            <input
              className="input"
              inputMode="numeric"
              pattern="\d{4,6}"
              value={masterPin}
              onChange={(e) => setMasterPin(e.target.value)}
              required
            />
            <span className="tiny">Used to recover your account if you forget the password.</span>
          </label>
        )}

        {error && <Note variant="critical">{error}</Note>}

        <button type="submit" className="btn btn--primary btn--block" disabled={busy}>
          {busy ? 'Please wait…' : mode === 'login' ? 'Sign in' : 'Create account'}
        </button>

        <button
          type="button"
          className="btn btn--ghost btn--block"
          onClick={() => {
            setMode(mode === 'login' ? 'signup' : 'login');
            setError(null);
          }}
        >
          {mode === 'login' ? 'Create an account' : 'I already have an account'}
        </button>

        <p className="tiny">
          This uses the same account as the project dashboard on this server.
        </p>
      </form>
    </div>
  );
}
