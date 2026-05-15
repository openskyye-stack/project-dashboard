import { createContext, useContext, useState, useEffect } from 'react';
import { apiBaseUrl } from './api-config';

const AuthContext = createContext();

export function AuthProvider({ children }) {
  console.log('[AuthProvider] Initializing');
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [loading, setLoading] = useState(true);

  // Load token from localStorage on mount
  useEffect(() => {
    const savedToken = localStorage.getItem('authToken');
    const savedUser = localStorage.getItem('authUser');
    if (savedToken && savedUser) {
      setToken(savedToken);
      setUser(JSON.parse(savedUser));
    }
    setLoading(false);
  }, []);

  const login = async (username, password) => {
    const res = await fetch(`${apiBaseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    if (!res.ok) throw new Error('Login failed');
    const data = await res.json();
    setToken(data.token);
    setUser(data.user);
    localStorage.setItem('authToken', data.token);
    localStorage.setItem('authUser', JSON.stringify(data.user));
    return data;
  };

  const signup = async (username, password, masterPin) => {
    const res = await fetch(`${apiBaseUrl}/api/auth/signup`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password, masterPin }),
    });
    if (!res.ok) {
      const errorData = await res.json();
      throw new Error(errorData.error || 'Signup failed');
    }
    const data = await res.json();
    // Don't auto-login, let the user see the master PIN first
    return data;
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem('authToken');
    localStorage.removeItem('authUser');
  };

  return (
    <AuthContext.Provider value={{ user, token, loading, login, signup, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
