// Server-side recipe importer.
//
// This has to live on the server: a browser cannot fetch a recipe page from
// another origin, so the client asks us and we do the fetch.
//
// We read the schema.org `Recipe` JSON-LD that virtually every recipe site
// publishes so Google can render a recipe card. That is structured data the
// site maintains on purpose, so it survives redesigns in a way that scraping
// the visible HTML does not. If a page doesn't publish it, we say so plainly
// rather than guessing.

const FETCH_TIMEOUT_MS = 15000;
const MAX_BYTES = 5 * 1024 * 1024;

const BROWSER_UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

export class ImportError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.name = 'ImportError';
    this.status = status;
  }
}

export async function importRecipe(rawUrl) {
  const url = normaliseUrl(rawUrl);
  const html = await fetchPage(url);
  const recipe = findRecipe(jsonLdBlocks(html));

  if (!recipe) {
    throw new ImportError(
      "That page doesn't publish machine-readable recipe data. Try a different site, or add the recipe by hand.",
      422
    );
  }

  return toDraft(recipe, url);
}

// --- fetching ---------------------------------------------------------------

function normaliseUrl(input) {
  const trimmed = String(input || '').trim();
  if (!trimmed) throw new ImportError('No address given.');

  const withScheme = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;

  let parsed;
  try {
    parsed = new URL(withScheme);
  } catch {
    throw new ImportError("That doesn't look like a web address.");
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new ImportError('Only http and https addresses can be imported.');
  }

  // This endpoint takes a URL from a logged-in user and fetches it from inside
  // our network, which is the shape of an SSRF. Block the obvious internal
  // targets. DNS can still resolve a public name to a private address, so this
  // is a guard rail rather than a guarantee — a deployment that cares should
  // put egress rules in front of it too.
  if (isBlockedHost(parsed.hostname)) {
    throw new ImportError('That address points somewhere internal, so it cannot be fetched.');
  }

  return parsed.toString();
}

function isBlockedHost(hostname) {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, '');

  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.internal')) return true;
  if (host === '::1' || host === '0.0.0.0') return true;
  if (host === 'metadata.google.internal') return true;

  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (ipv4) {
    const [a, b] = ipv4.slice(1).map(Number);
    if (a === 10 || a === 127 || a === 0) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 169 && b === 254) return true; // link-local, incl. cloud metadata
    if (a === 100 && b >= 64 && b <= 127) return true;
  }

  return false;
}

async function fetchPage(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  let response;
  try {
    response = await fetch(url, {
      headers: { 'User-Agent': BROWSER_UA, Accept: 'text/html,application/xhtml+xml' },
      redirect: 'follow',
      signal: controller.signal,
    });
  } catch (err) {
    throw new ImportError(
      err.name === 'AbortError' ? 'The site took too long to respond.' : `Couldn't reach the page. ${err.message}`,
      502
    );
  } finally {
    clearTimeout(timer);
  }

  if (!response.ok) {
    throw new ImportError(`The site returned ${response.status}.`, 502);
  }

  const buffer = await response.arrayBuffer();
  if (buffer.byteLength > MAX_BYTES) {
    throw new ImportError('That page is too large to read.', 413);
  }

  return new TextDecoder('utf-8').decode(buffer);
}

// --- parsing ----------------------------------------------------------------

export function jsonLdBlocks(html) {
  const blocks = [];
  const pattern = /<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi;

  let match;
  while ((match = pattern.exec(html)) !== null) {
    if (/application\/ld\+json/i.test(match[1])) {
      blocks.push(match[2].trim());
    }
  }
  return blocks;
}

export function findRecipe(blocks) {
  for (const block of blocks) {
    let parsed;
    try {
      parsed = JSON.parse(block);
    } catch {
      continue;
    }
    const found = search(parsed);
    if (found) return found;
  }
  return null;
}

// JSON-LD turns up as a bare object, an array, or an @graph. Walk all of them.
function search(node, depth = 0) {
  if (!node || typeof node !== 'object' || depth > 6) return null;

  if (Array.isArray(node)) {
    for (const item of node) {
      const found = search(item, depth + 1);
      if (found) return found;
    }
    return null;
  }

  if (isRecipe(node)) return node;

  for (const value of Object.values(node)) {
    if (value && typeof value === 'object') {
      const found = search(value, depth + 1);
      if (found) return found;
    }
  }
  return null;
}

function isRecipe(node) {
  const type = node['@type'];
  if (!type) return false;
  const types = Array.isArray(type) ? type : [type];
  return types.some((t) => String(t).toLowerCase() === 'recipe');
}

function toDraft(node, sourceUrl) {
  const nutrition = node.nutrition && typeof node.nutrition === 'object' ? node.nutrition : {};

  const prep = isoMinutes(node.prepTime);
  const cook = isoMinutes(node.cookTime);
  const total = isoMinutes(node.totalTime);

  return {
    title: text(node.name) || 'Imported recipe',
    summary: text(node.description) || '',
    servings: servings(node.recipeYield),
    prepMinutes: prep,
    cookMinutes: cook > 0 ? cook : Math.max(0, total - prep),
    calories: Math.round(numeric(nutrition.calories)),
    proteinG: numeric(nutrition.proteinContent),
    carbsG: numeric(nutrition.carbohydrateContent),
    fatG: numeric(nutrition.fatContent),
    fiberG: numeric(nutrition.fiberContent),
    sodiumMg: numeric(nutrition.sodiumContent),
    ingredientTexts: list(node.recipeIngredient),
    steps: instructions(node.recipeInstructions),
    sourceUrl,
  };
}

// --- field helpers ----------------------------------------------------------

const ENTITIES = {
  '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&apos;': "'",
  '&#39;': "'", '&#x27;': "'", '&nbsp;': ' ', '&frac12;': '½', '&frac14;': '¼',
  '&frac34;': '¾', '&deg;': '°',
};

function decodeEntities(value) {
  return value.replace(/&[a-z#0-9]+;/gi, (entity) => ENTITIES[entity.toLowerCase()] ?? entity);
}

export function text(value) {
  if (typeof value === 'string') return decodeEntities(value).trim();
  if (Array.isArray(value)) return text(value[0]);
  if (value && typeof value === 'object') return text(value.text ?? value.name);
  if (typeof value === 'number') return String(value);
  return '';
}

function list(value) {
  if (Array.isArray(value)) return value.map(text).filter(Boolean);
  const single = text(value);
  return single ? [single] : [];
}

export function instructions(value, depth = 0) {
  if (depth > 4) return [];

  if (Array.isArray(value)) {
    const steps = [];
    for (const item of value) {
      // A HowToSection nests its own steps.
      if (item && typeof item === 'object' && item.itemListElement) {
        steps.push(...instructions(item.itemListElement, depth + 1));
        continue;
      }
      const line = text(item);
      if (line) steps.push(line);
    }
    return steps;
  }

  // Some sites hand over one long paragraph.
  const paragraph = text(value);
  if (!paragraph) return [];
  return paragraph
    .split(/(?<=\.)\s+/)
    .map((s) => s.trim())
    .filter(Boolean);
}

// ISO 8601 durations, e.g. PT1H25M.
export function isoMinutes(value) {
  const raw = text(value);
  if (!raw) return 0;
  if (/^\d+$/.test(raw)) return Number(raw);

  const match = raw
    .toUpperCase()
    .match(/^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
  if (!match) return 0;

  const [, days, hours, minutes, seconds] = match.map((v) => (v ? Number(v) : 0));
  return days * 1440 + hours * 60 + minutes + Math.floor(seconds / 60);
}

export function servings(value) {
  if (typeof value === 'number') return Math.max(1, Math.round(value));
  if (Array.isArray(value)) return servings(value[0]);

  const raw = text(value);
  const match = raw.match(/\d+/);
  return match ? Math.max(1, Number(match[0])) : 1;
}

// Nutrition arrives as "23 g", "450 calories", or a plain number.
export function numeric(value) {
  if (typeof value === 'number') return value;
  const raw = text(value);
  const match = raw.match(/[\d.]+/);
  return match ? Number(match[0]) : 0;
}
