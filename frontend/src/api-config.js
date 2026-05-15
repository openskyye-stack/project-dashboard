// API configuration for frontend
// Uses environment variables in production, localhost in development

export const getApiBaseUrl = () => {
  // In production, use the VITE_API_BASE_URL from .env
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL;
  }

  // In development, use localhost
  if (import.meta.env.MODE === 'development') {
    return 'http://localhost:5000';
  }

  // Fallback to relative path (works when frontend and backend are on same domain)
  return '';
};

export const apiBaseUrl = getApiBaseUrl();

export default apiBaseUrl;
