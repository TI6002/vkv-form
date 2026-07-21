import { defaultLocale, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Picks the right-language string out of a per-locale text field.
 * Falls back to English, then to whatever language happens to be
 * there, so a product never renders as a blank field just because
 * one language is missing a translation.
 *
 * Defensive on purpose: if the `products` table hasn't been migrated
 * to jsonb yet (see supabase/migration-i18n-products.sql), Postgres can
 * hand this a plain string — sometimes even a JSON-encoded string like
 * '{"en":"Vase"}' — instead of a real object. Blindly doing
 * Object.values(value) on a string returns its individual characters,
 * which is exactly how a product name could end up rendering as a
 * lone "{". This function checks the actual type first so that can't happen.
 */
export function pickLocalized(
  value: LocalizedText | string | null | undefined,
  locale: string
): string {
  if (!value) return '';

  // Column not migrated yet, or a JSON-encoded string ended up stored as
  // plain text — try to parse it back into an object; otherwise treat it
  // as the plain string it is.
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed.startsWith('{')) {
      try {
        return pickLocalized(JSON.parse(trimmed), locale);
      } catch {
        return value;
      }
    }
    return value;
  }

  if (typeof value !== 'object') return '';

  const asLocale = locale as Locale;
  if (value[asLocale]) return value[asLocale] as string;
  if (value[defaultLocale]) return value[defaultLocale] as string;

  const first = Object.values(value).find((v) => typeof v === 'string' && v);
  return (first as string) ?? '';
}
