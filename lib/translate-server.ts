import { locales, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Translation backend: MyMemory (api.mymemory.translated.net).
 * -----------------------------------------------------------
 * We switched away from the unofficial Google Translate scraper here
 * because it silently fails when called from a server's IP (very common
 * with hosting providers) — Google blocks/rate-limits it, the library
 * swallows the error, and every language ends up with the original,
 * untranslated text. MyMemory is a genuinely free, public, no-API-key
 * translation API meant exactly for this kind of server-side use, so it
 * doesn't get blocked the same way. (scripts/translate-missing.mjs, which
 * runs on your own machine, still uses the Google wrapper — that one's
 * fine since it's not calling from a shared hosting IP.)
 */
const MYMEMORY_ENDPOINT = 'https://api.mymemory.translated.net/get';
const MAX_CHUNK_LENGTH = 450; // MyMemory truncates/rejects very long single requests

async function translateChunk(text: string, source: string, target: string): Promise<string> {
  const params = new URLSearchParams({ q: text, langpair: `${source}|${target}` });
  const res = await fetch(`${MYMEMORY_ENDPOINT}?${params.toString()}`);

  if (!res.ok) throw new Error(`MyMemory HTTP ${res.status}`);

  const data = await res.json();
  const translated = data?.responseData?.translatedText;

  if (!translated || typeof translated !== 'string') {
    throw new Error('MyMemory returned no translation');
  }
  // MyMemory returns its rate-limit/quota notices *as* the "translation"
  // text instead of an HTTP error — catch that so it doesn't get saved
  // as if it were real product copy.
  if (/MYMEMORY WARNING|QUERY LENGTH LIMIT/i.test(translated)) {
    throw new Error(translated);
  }

  return translated;
}

function splitIntoChunks(text: string, maxLen: number): string[] {
  if (text.length <= maxLen) return [text];

  const sentences = text.split(/(?<=[.!?])\s+/);
  const chunks: string[] = [];
  let current = '';

  for (const sentence of sentences) {
    const candidate = current ? `${current} ${sentence}` : sentence;
    if (candidate.length > maxLen && current) {
      chunks.push(current);
      current = sentence;
    } else {
      current = candidate;
    }
  }
  if (current) chunks.push(current);

  return chunks;
}

/** Translates one string from `source` to `target` (both locale codes like "ru", "en"). */
export async function translateText(
  text: string,
  source: string,
  target: string
): Promise<string> {
  const clean = (text ?? '').trim();
  if (!clean) return '';
  if (source === target) return clean;

  const chunks = splitIntoChunks(clean, MAX_CHUNK_LENGTH);
  const translatedChunks = await Promise.all(
    chunks.map((chunk) => translateChunk(chunk, source, target))
  );
  return translatedChunks.join(' ');
}

/**
 * Translates a single string, written in `sourceLocale`, into every
 * locale configured in i18n.ts. `sourceLocale` is the language the admin
 * was actually typing in (whatever /admin is currently displayed in) —
 * far more reliable than trying to auto-detect it.
 */
export async function translateToAllLocales(
  text: string,
  sourceLocale: string
): Promise<LocalizedText> {
  const clean = (text ?? '').trim();
  const result: LocalizedText = {};

  await Promise.all(
    locales.map(async (locale) => {
      if (!clean) {
        result[locale as Locale] = '';
        return;
      }
      try {
        result[locale as Locale] = await translateText(clean, sourceLocale, locale);
      } catch (err) {
        console.error(`[translate] ${sourceLocale} -> ${locale} failed:`, err);
        // Fall back to the original text rather than leaving the field
        // blank — better to show the wrong language than nothing at all.
        result[locale as Locale] = clean;
      }
    })
  );

  return result;
}
