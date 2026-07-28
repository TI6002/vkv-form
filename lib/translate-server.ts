import { locales, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Translation backend: MyMemory (api.mymemory.translated.net).
 * -----------------------------------------------------------
 * Free, public, no-API-key translation API. Anonymous requests are
 * capped at roughly 1,000–5,000 words/day per IP — easy to hit with a
 * long product description translated into 6 languages, especially once
 * it gets split into multiple chunks. Passing a contact email via the
 * `de` parameter raises that ceiling to ~50,000 words/day. Set
 * MYMEMORY_CONTACT_EMAIL in .env.local to enable this (any real email
 * you control — MyMemory doesn't email you, it's just used to raise
 * your IP's quota).
 */
const MYMEMORY_ENDPOINT = 'https://api.mymemory.translated.net/get';
const MAX_CHUNK_LENGTH = 450; // MyMemory truncates/rejects very long single requests
const CONTACT_EMAIL = process.env.MYMEMORY_CONTACT_EMAIL || '';

async function translateChunk(text: string, source: string, target: string): Promise<string> {
  const params = new URLSearchParams({ q: text, langpair: `${source}|${target}` });
  if (CONTACT_EMAIL) params.set('de', CONTACT_EMAIL);

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
  if (/MYMEMORY WARNING|QUERY LENGTH LIMIT|IS AN INVALID/i.test(translated)) {
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

export type TranslateAllResult = {
  text: LocalizedText;
  /** Locales where translation failed and the source text was used
   * instead — surfaced to the admin UI so a silent quota failure isn't
   * mistaken for a successful translation. */
  failedLocales: Locale[];
};

/**
 * Translates a single string, written in `sourceLocale`, into every
 * locale configured in i18n.ts. `sourceLocale` is the language the admin
 * was actually typing in (whatever /admin is currently displayed in) —
 * far more reliable than trying to auto-detect it.
 */
export async function translateToAllLocales(
  text: string,
  sourceLocale: string
): Promise<TranslateAllResult> {
  const clean = (text ?? '').trim();
  const result: LocalizedText = {};
  const failedLocales: Locale[] = [];

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
        // blank — better to show the wrong language than nothing at all —
        // but record it so the caller can warn about it.
        result[locale as Locale] = clean;
        if (locale !== sourceLocale) failedLocales.push(locale as Locale);
      }
    })
  );

  return { text: result, failedLocales };
}
