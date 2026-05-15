import React from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from './AuthContext';
import App from './App';
import { queryClient } from './queryClient';
import './index.css';

window.addEventListener('error', (event) => {
  console.error('Global error:', event.error);
  const root = document.getElementById('root');
  if (root) {
    root.innerHTML = `<div style="color: red; padding: 20px; font-family: monospace; background: #ffe0e0;">
      <h2>❌ Error: ${event.error?.message || 'Unknown error'}</h2>
      <pre>${event.error?.stack || ''}</pre>
    </div>`;
  }
});

window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled rejection:', event.reason);
  const root = document.getElementById('root');
  if (root) {
    root.innerHTML = `<div style="color: red; padding: 20px; font-family: monospace; background: #ffe0e0;">
      <h2>❌ Promise Rejection: ${event.reason?.message || String(event.reason)}</h2>
      <pre>${event.reason?.stack || ''}</pre>
    </div>`;
  }
});

console.log('main.jsx loaded');
const root = document.getElementById('root');
console.log('root element:', root);

if (root) {
  root.innerHTML = '<div style="padding: 20px; font-family: monospace;">Initializing React...</div>';

  setTimeout(() => {
    try {
      ReactDOM.createRoot(root).render(
        <React.StrictMode>
          <AuthProvider>
            <QueryClientProvider client={queryClient}>
              <App />
            </QueryClientProvider>
          </AuthProvider>
        </React.StrictMode>
      );
      console.log('React rendering completed');
    } catch (error) {
      console.error('Error rendering React:', error);
      root.innerHTML = `<div style="color: red; padding: 20px; font-family: monospace; background: #ffe0e0;">
        <h2>❌ React Error: ${error.message}</h2>
        <pre>${error.stack || ''}</pre>
      </div>`;
    }
  }, 100);
} else {
  document.body.innerHTML = '<div style="color: red; padding: 20px;">ERROR: root element not found</div>';
}
