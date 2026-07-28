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
    const results = await Promise.all(
      entries.map(async ([name, text]) => {
        if (!text) return [name, null, []] as const;
        const { text: translated, failedLocales } = await translateToAllLocales(text, source);
        return [name, translated, failedLocales] as const;
      })
    );

    const out: Record<string, unknown> = {};
    const allFailed = new Set<string>();
    for (const [name, value, failed] of results) {
      out[name] = value;
      failed.forEach((l) => allFailed.add(l));
    }
    out.failedLocales = Array.from(allFailed);

    return NextResponse.json(out);
  } catch (err) {
    console.error('translate-fields error:', err);
    return NextResponse.json({ error: 'Translation failed' }, { status: 500 });
  }
}
