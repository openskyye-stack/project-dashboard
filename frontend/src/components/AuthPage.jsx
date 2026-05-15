import { useState } from 'react';
import { useAuth } from '../AuthContext';
import { apiBaseUrl } from '../api-config';
import './AuthPage.css';

function AuthPage() {
  const { login, signup } = useAuth();
  const [mode, setMode] = useState('login'); // 'login', 'signup', 'recover'
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [masterPin, setMasterPin] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showMasterPin, setShowMasterPin] = useState(null); // Show PIN after signup

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (mode === 'login') {
        await login(username, password);
      } else if (mode === 'signup') {
        const response = await signup(username, password, masterPin);
        if (response?.user) {
          setShowMasterPin(masterPin);
          setUsername('');
          setPassword('');
          setMasterPin('');
        }
      } else if (mode === 'recover') {
        const res = await fetch(`${apiBaseUrl}/api/auth/recover`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username, masterPin, newPassword }),
        });
        if (!res.ok) {
          const errorData = await res.json();
          throw new Error(errorData.error || 'Password reset failed');
        }
        const data = await res.json();
        localStorage.setItem('authToken', data.token);
        localStorage.setItem('authUser', JSON.stringify(data.user));
        window.location.reload();
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Handle master PIN display after signup
  if (showMasterPin) {
    return (
      <div className="auth-page">
        <div className="auth-container">
          <div className="auth-card">
            <h1 className="auth-title">✅ Account Created!</h1>
            <div className="master-pin-box">
              <h2>Save Your Master PIN</h2>
              <p style={{ color: '#d4a25a', marginBottom: '16px', fontWeight: 600 }}>
                ⚠️ Save this PIN in a safe place. You'll need it to reset your password if you forget it.
              </p>
              <div className="master-pin-display">{showMasterPin}</div>
              <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '16px' }}>
                💡 Store this in a password manager, notes app, or written down somewhere safe.
              </p>
              <button
                onClick={() => {
                  navigator.clipboard.writeText(showMasterPin);
                  alert('Copied to clipboard!');
                }}
                className="btn-copy"
              >
                📋 Copy to Clipboard
              </button>
              <button
                onClick={() => {
                  setShowMasterPin(null);
                  setMode('login');
                }}
                className="btn-primary"
                style={{ marginTop: '12px', width: '100%' }}
              >
                Continue to Login
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="auth-page">
      <div className="auth-container">
        <div className="auth-card">
          <h1 className="auth-title">Project Dashboard</h1>

          <form onSubmit={handleSubmit} className="auth-form">
            <h2>
              {mode === 'login' && 'Sign In'}
              {mode === 'signup' && 'Create Account'}
              {mode === 'recover' && 'Recover Account'}
            </h2>

            {error && <div className="auth-error">{error}</div>}

            <div className="form-group">
              <label>Username</label>
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="Enter username"
                disabled={loading}
                required
              />
            </div>

            {(mode === 'login' || mode === 'signup') && (
              <div className="form-group">
                <label>Password</label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password"
                  disabled={loading}
                  required
                />
              </div>
            )}

            {mode === 'signup' && (
              <div className="form-group">
                <label>Master PIN (4-6 digits)</label>
                <input
                  type="text"
                  inputMode="numeric"
                  value={masterPin}
                  onChange={(e) => {
                    const val = e.target.value.replace(/\D/g, '').slice(0, 6);
                    setMasterPin(val);
                  }}
                  placeholder="1234"
                  disabled={loading}
                  maxLength="6"
                  required
                />
                <small style={{ color: 'var(--text-secondary)', marginTop: '4px', display: 'block' }}>
                  Save this PIN! You'll need it to reset your password.
                </small>
              </div>
            )}

            {mode === 'recover' && (
              <>
                <div className="form-group">
                  <label>Master PIN</label>
                  <input
                    type="text"
                    inputMode="numeric"
                    value={masterPin}
                    onChange={(e) => {
                      const val = e.target.value.replace(/\D/g, '').slice(0, 6);
                      setMasterPin(val);
                    }}
                    placeholder="1234"
                    disabled={loading}
                    maxLength="6"
                    required
                  />
                </div>
                <div className="form-group">
                  <label>New Password</label>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder="Enter new password"
                    disabled={loading}
                    required
                  />
                </div>
              </>
            )}

            <button
              type="submit"
              className="auth-submit"
              disabled={loading || (mode === 'signup' && masterPin.length < 4)}
            >
              {loading && 'Loading...'}
              {!loading && mode === 'login' && 'Sign In'}
              {!loading && mode === 'signup' && 'Create Account'}
              {!loading && mode === 'recover' && 'Reset Password'}
            </button>
          </form>

          <div className="auth-toggle">
            {mode === 'login' && (
              <>
                <div>
                  Don't have an account?{' '}
                  <button
                    type="button"
                    onClick={() => {
                      setMode('signup');
                      setError('');
                    }}
                    className="toggle-btn"
                  >
                    Sign up
                  </button>
                </div>
                <div style={{ marginTop: '8px', fontSize: '12px' }}>
                  Forgot password?{' '}
                  <button
                    type="button"
                    onClick={() => {
                      setMode('recover');
                      setError('');
                      setPassword('');
                    }}
                    className="toggle-btn"
                  >
                    Recover account
                  </button>
                </div>
              </>
            )}
            {(mode === 'signup' || mode === 'recover') && (
              <>
                Back to{' '}
                <button
                  type="button"
                  onClick={() => {
                    setMode('login');
                    setError('');
                    setPassword('');
                    setMasterPin('');
                    setNewPassword('');
                  }}
                  className="toggle-btn"
                >
                  Sign in
                </button>
              </>
            )}
          </div>

          {mode === 'login' && (
            <div className="auth-demo">
              <p><strong>New user?</strong></p>
              <p>Create an account and set a 4-6 digit Master PIN.</p>
              <p>Lost your PIN? The admin can reset your password via the backend.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default AuthPage;
