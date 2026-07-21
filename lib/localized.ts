import { defaultLocale, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Picks the right-language string out of a per-locale text field.
 * Falls back to English, then to whatever language happens to be
 * there, so a product never renders as a blank field just because
 * one language is missing a translation.
 */
export function pickLocalized(
  value: LocalizedText | null | undefined,
  locale: string
): string {
  if (!value) return '';
  const asLocale = locale as Locale;
  if (value[asLocale]) return value[asLocale] as string;
  if (value[defaultLocale]) return value[defaultLocale] as string;
  const first = Object.values(value).find(Boolean);
  return first ?? '';
}
