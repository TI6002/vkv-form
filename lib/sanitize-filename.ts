/**
 * Storage keys in Supabase must be "safe" ASCII paths — filenames with
 * spaces, Cyrillic, or other non-ASCII characters (e.g. a camera export
 * named "Z62_2136 копия.jpg") get rejected with "Invalid key". This
 * strips a filename down to something guaranteed-safe while keeping the
 * extension, so uploads never fail just because of how a photo happened
 * to be named on someone's computer.
 */
export function sanitizeFileName(name: string): string {
  const dotIndex = name.lastIndexOf('.');
  const base = dotIndex > 0 ? name.slice(0, dotIndex) : name;
  const ext = dotIndex > 0 ? name.slice(dotIndex + 1).replace(/[^a-zA-Z0-9]/g, '').toLowerCase() : '';

  const safeBase =
    base
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '') // strip Latin diacritics (café -> cafe)
      .replace(/[^a-zA-Z0-9]+/g, '-') // anything else (spaces, Cyrillic, etc.) -> hyphen
      .replace(/^-+|-+$/g, '')
      .toLowerCase() || 'photo';

  return ext ? `${safeBase}.${ext}` : safeBase;
}
