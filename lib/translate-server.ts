import { locales, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Translation backend: DeepL API (Free tier).
 * -----------------------------------------------------------
 * Free tier: 500,000 characters/month, no credit card required. Get a
 * key at https://www.deepl.com/pro-api (choose "DeepL API Free") and put
 * it in .env.local as DEEPL_API_KEY.
 *
 * IMPORTANT: requests are sent one at a time, not all at once. Saving a
 * product translates several fields into 6 other languages each — firing
 * all of those as parallel requests (dozens at once) trips DeepL's
 * burst rate limit (HTTP 429) even though you're nowhere near the
 * monthly character quota. Going one at a time (with a short retry on
 * 429) is slower per save but actually reliable.
 */
const DEEPL_ENDPOINT = 'https://api-free.deepl.com/v2/translate';
const DEEPL_API_KEY = process.env.DEEPL_API_KEY || '';

// DeepL's language codes don't always match our locale codes exactly —
// English specifically needs a regional variant when it's the *target*
// language (EN alone is only valid as a *source* language).
const DEEPL_SOURCE_CODE: Record<string, string> = {
  en: 'EN',
  fr: 'FR',
  es: 'ES',
  it: 'IT',
  de: 'DE',
  ru: 'RU',
  lv: 'LV',
};

const DEEPL_TARGET_CODE: Record<string, string> = {
  en: 'EN-GB',
  fr: 'FR',
  es: 'ES',
  it: 'IT',
  de: 'DE',
  ru: 'RU',
  lv: 'LV',
};

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Translates one string from `source` to `target` (locale codes like "ru", "en"). */
export async function translateText(
  text: string,
  source: string,
  target: string
): Promise<string> {
  const clean = (text ?? '').trim();
  if (!clean) return '';
  if (source === target) return clean;

  if (!DEEPL_API_KEY) {
    throw new Error(
      'DEEPL_API_KEY is not set — add it to .env.local (see .env.example).'
    );
  }

  const sourceLang = DEEPL_SOURCE_CODE[source];
  const targetLang = DEEPL_TARGET_CODE[target];
  if (!sourceLang || !targetLang) {
    throw new Error(`Unsupported locale for DeepL: ${source} -> ${target}`);
  }

  const MAX_ATTEMPTS = 4;
  let lastError: unknown;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const res = await fetch(DEEPL_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `DeepL-Auth-Key ${DEEPL_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        text: [clean],
        source_lang: sourceLang,
        target_lang: targetLang,
      }),
    });

    if (res.status === 429 || res.status === 529) {
      // Rate limited / server overloaded — back off and try again
      // instead of giving up immediately.
      lastError = new Error(`DeepL HTTP ${res.status} (rate limited)`);
      if (attempt < MAX_ATTEMPTS) {
        await sleep(attempt * 700); // 700ms, 1400ms, 2100ms
        continue;
      }
      throw lastError;
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`DeepL HTTP ${res.status}${body ? `: ${body}` : ''}`);
    }

    const data = await res.json();
    const translated = data?.translations?.[0]?.text;

    if (!translated || typeof translated !== 'string') {
      throw new Error('DeepL returned no translation');
    }

    return translated;
  }

  // Unreachable in practice, but keeps TypeScript happy.
  throw lastError instanceof Error ? lastError : new Error('DeepL translation failed');
}

export type TranslateAllResult = {
  text: LocalizedText;
  /** Locales where translation failed and the source text was used
   * instead — surfaced to the admin UI so a quota/config failure isn't
   * mistaken for a successful translation. */
  failedLocales: Locale[];
};

/**
 * Translates a single string, written in `sourceLocale`, into every
 * locale configured in i18n.ts — one request at a time (see note above
 * about why this isn't parallelized).
 */
export async function translateToAllLocales(
  text: string,
  sourceLocale: string
): Promise<TranslateAllResult> {
  const clean = (text ?? '').trim();
  const result: LocalizedText = {};
  const failedLocales: Locale[] = [];

  for (const locale of locales) {
    if (!clean) {
      result[locale as Locale] = '';
      continue;
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
  }

  return { text: result, failedLocales };
}
