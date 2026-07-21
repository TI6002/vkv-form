/**
 * Turns any text — Latvian, Russian, whatever — into a clean, ASCII-only
 * URL slug. Diacritics (ā, š, ģ, ...) are stripped down to their base
 * Latin letter; anything else that isn't a-z/0-9 becomes a hyphen.
 *
 * This matters because raw accented characters in a URL (e.g. /catalog/vāze)
 * are fragile: some caching layers, browser history entries, and copy-paste
 * flows re-encode them inconsistently, which is what caused product pages
 * to 404 intermittently.
 */
export function slugify(input: string): string {
  return input
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // strip combining diacritical marks
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
