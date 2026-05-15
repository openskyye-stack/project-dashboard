import { QueryClient } from '@tanstack/react-query';

// Persist queries to localStorage for offline support
const createPersister = () => {
  return {
    persistQuery: (options, state) => {
      const key = `query_${options.queryKey.join('_')}`;
      try {
        localStorage.setItem(key, JSON.stringify(state));
      } catch (e) {
        console.error('Failed to persist query:', e);
      }
    },
    restoreQuery: (options) => {
      const key = `query_${options.queryKey.join('_')}`;
      try {
        const data = localStorage.getItem(key);
        return data ? JSON.parse(data) : null;
      } catch (e) {
        console.error('Failed to restore query:', e);
        return null;
      }
    },
  };
};

const persister = createPersister();

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      gcTime: 1000 * 60 * 60, // 1 hour
      retry: 1,
      networkMode: 'always',
    },
    mutations: {
      networkMode: 'always',
      retry: 1,
    },
  },
});

// Service Worker for offline support
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js').catch(() => {
    // SW registration failed, app still works in online mode
  });
}
