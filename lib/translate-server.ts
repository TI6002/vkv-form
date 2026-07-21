import { translate } from '@vitalets/google-translate-api';
import { locales, defaultLocale, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Translates a single string into every locale in i18n.ts, using the same
 * free Google Translate wrapper as scripts/translate-missing.mjs. Source
 * language is auto-detected, so it doesn't matter whether the admin typed
 * the product copy in Russian, English, or anything else.
 */
export async function translateToAllLocales(text: string): Promise<LocalizedText> {
  const clean = (text ?? '').trim();
  const result: LocalizedText = { [defaultLocale]: clean };

  if (!clean) {
    for (const locale of locales) result[locale] = '';
    return result;
  }

  await Promise.all(
    locales.map(async (locale) => {
      try {
        const { text: translated } = await translate(clean, { to: locale });
        result[locale as Locale] = translated;
      } catch {
        // Translation API hiccup — fall back to the original text rather
        // than leaving the field blank.
        result[locale as Locale] = clean;
      }
    })
  );

  return result;
}
