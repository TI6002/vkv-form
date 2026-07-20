import { getRequestConfig } from 'next-intl/server';
import { notFound } from 'next/navigation';

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

export default getRequestConfig(async ({ locale }) => {
  if (!locales.includes(locale as Locale)) notFound();

  return {
    messages: (await import(`./messages/${locale}.json`)).default,
  };
});
