// Thin fetch wrapper. The auth token lives under the same localStorage key the
// project dashboard uses, so signing in to one signs you in to both.

export const TOKEN_KEY = 'authToken';
export const USER_KEY = 'authUser';

export function apiBaseUrl() {
  if (import.meta.env.VITE_API_BASE_URL) return import.meta.env.VITE_API_BASE_URL;
  if (import.meta.env.MODE === 'development') return 'http://localhost:5000';
  return '';
}

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

async function request(method, path, body, { auth = true } = {}) {
  const headers = { 'Content-Type': 'application/json' };

  if (auth) {
    const token = localStorage.getItem(TOKEN_KEY);
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  let response;
  try {
    response = await fetch(`${apiBaseUrl()}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError("Couldn't reach the server. Is the backend running?", 0);
  }

  if (response.status === 401) {
    // The token has expired or been invalidated. Clearing it sends the user
    // back to the sign-in screen rather than leaving them staring at errors.
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    throw new ApiError('Your session has expired. Sign in again.', 401);
  }

  const text = await response.text();
  const data = text ? safeParse(text) : null;

  if (!response.ok) {
    throw new ApiError(data?.error || `Request failed (${response.status})`, response.status);
  }
  return data;
}

function safeParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

export const api = {
  get: (path) => request('GET', path),
  post: (path, body) => request('POST', path, body),
  put: (path, body) => request('PUT', path, body),
  patch: (path, body) => request('PATCH', path, body),
  del: (path) => request('DELETE', path),

  login: (username, password) => request('POST', '/api/auth/login', { username, password }, { auth: false }),
  signup: (username, password, masterPin) =>
    request('POST', '/api/auth/signup', { username, password, masterPin }, { auth: false }),
};

// --- photos -----------------------------------------------------------------

// Progress photos are stored as data URLs. Downscaling before upload keeps
// seventy-five of them from turning the database into a liability — a phone
// camera JPEG is 3–6 MB and none of that detail survives being looked at on a
// phone screen anyway.
export async function compressImage(file, { maxDimension = 1200, quality = 0.72 } = {}) {
  const bitmap = await createImageBitmap(file);

  const scale = Math.min(1, maxDimension / Math.max(bitmap.width, bitmap.height));
  const width = Math.round(bitmap.width * scale);
  const height = Math.round(bitmap.height * scale);

  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  canvas.getContext('2d').drawImage(bitmap, 0, 0, width, height);
  bitmap.close?.();

  return canvas.toDataURL('image/jpeg', quality);
}
