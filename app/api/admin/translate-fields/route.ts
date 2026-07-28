import { NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/auth';
import { translateToAllLocales } from '@/lib/translate-server';

/**
 * Generic version of /api/admin/translate-product — takes any set of named
 * text fields and translates each into every locale. Used by the About
 * page editor, journal posts, and Collection Book admin panels, so those
 * don't need their own bespoke translate route each.
 *
 * Body: { fields: { [name: string]: string | null }, sourceLocale: string }
 * Response: { [name: string]: LocalizedText | null, failedLocales: string[] }
 */
export async function POST(req: Request) {
  const admin = await requireAdmin();
  if (!admin) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  try {
    const { fields, sourceLocale } = await req.json();
    const source = sourceLocale || 'en';

    const entries = Object.entries(fields ?? {}) as [string, string | null][];
    // One field at a time, on purpose — see lib/translate-server.ts for why
    // parallel requests trip DeepL's burst rate limit.
    const results: (readonly [string, unknown, string[]])[] = [];
    for (const [name, text] of entries) {
      if (!text) {
        results.push([name, null, []] as const);
        continue;
      }
      const { text: translated, failedLocales } = await translateToAllLocales(text, source);
      results.push([name, translated, failedLocales] as const);
    }

    const out: Record<string, unknown> = {};
    const allFailed = new Set<string>();
    for (const [name, value, failed] of results) {
      out[name] = value;
      failed.forEach((l) => allFailed.add(l));
    }
    out.failedLocales = Array.from(allFailed);
    out.deeplConfigured = !!process.env.DEEPL_API_KEY;

    return NextResponse.json(out);
  } catch (err) {
    console.error('translate-fields error:', err);
    return NextResponse.json({ error: 'Translation failed' }, { status: 500 });
  }
}
