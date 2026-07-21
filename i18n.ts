import { getRequestConfig } from 'next-intl/server';

// The base language we write copy in. All other files under /messages
// are generated automatically — see scripts/translate-missing.mjs and README.md.
export const defaultLocale = 'en' as const;

export const locales = ['en', 'fr', 'it', 'es', 'de', 'ru', 'lv'] as const;

export type Locale = (typeof locales)[number];

export const localeNames: Record<Locale, string> = {
  en: 'English',
  fr: 'Français',
  it: 'Italiano',
  es: 'Español',
  de: 'Deutsch',
  ru: 'Русский',
  lv: 'Latviešu',
};

export default getRequestConfig(async ({ requestLocale }) => {
  // requestLocale reflects the actual /xx segment in the URL. Awaiting it
  // (instead of the old, now-deprecated synchronous `locale` param) is what
  // fixes the "switches to the wrong language" bug — the old API could
  // resolve locale from a stale cookie instead of the URL you're on.
  let locale = await requestLocale;

  if (!locale || !locales.includes(locale as Locale)) {
    locale = defaultLocale;
  }

  return {
    locale,
    messages: (await import(`./messages/${locale}.json`)).default,
  };
});
