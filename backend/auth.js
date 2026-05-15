import crypto from 'crypto';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-key-change-in-production';

// Simple JWT encoding (not secure for production, but fine for local use)
export function createToken(userId, username) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = { userId, username, iat: Math.floor(Date.now() / 1000) };

  const headerEncoded = Buffer.from(JSON.stringify(header)).toString('base64url');
  const payloadEncoded = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(`${headerEncoded}.${payloadEncoded}`)
    .digest('base64url');

  return `${headerEncoded}.${payloadEncoded}.${signature}`;
}

export function verifyToken(token) {
  if (!token) return null;

  const [headerEncoded, payloadEncoded, signature] = token.split('.');

  const expectedSignature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(`${headerEncoded}.${payloadEncoded}`)
    .digest('base64url');

  if (signature !== expectedSignature) return null;

  try {
    const payload = JSON.parse(Buffer.from(payloadEncoded, 'base64url').toString());
    return payload;
  } catch {
    return null;
  }
}

// Hash password with simple SHA256 (fine for local, use bcrypt in production)
export function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

export function comparePassword(password, hash) {
  return hashPassword(password) === hash;
}

// Generate recovery code: ABC123-DEF456-GHI789 format (displayed), but stored without dashes
export function generateRecoveryCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 18; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  // Return in display format with dashes
  return `${code.slice(0, 6)}-${code.slice(6, 12)}-${code.slice(12)}`;
}

// Normalize recovery code for storage/comparison (remove dashes, uppercase)
function normalizeRecoveryCode(code) {
  return code.toUpperCase().replace(/-/g, '');
}

export { normalizeRecoveryCode };

// Middleware to verify token
export function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const payload = verifyToken(token);
  if (!payload) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  req.user = payload;
  next();
}
