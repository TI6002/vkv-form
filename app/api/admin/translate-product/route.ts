import { NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/auth';
import { translateToAllLocales } from '@/lib/translate-server';
export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  // Gate this behind admin auth — it's the one place in the app that calls
  // out to the translation API, and we don't want it open to anyone.
  const admin = await requireAdmin();
  if (!admin) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  // ============================================================
  // >>> LOOK FOR THIS LINE IN THE TERMINAL <<<
  // ============================================================
  const keyConfigured = !!process.env.DEEPL_API_KEY;
  console.log(
    `\n>>> DEEPL_API_KEY configured: ${keyConfigured} (length: ${
      (process.env.DEEPL_API_KEY || '').length
    }) <<<\n`
  );
  // ============================================================

  try {
    const {
      name,
      description,
      materials,
      height,
      width,
      circumference,
      depth,
      weight,
      sourceLocale,
    } = await req.json();
    const source = sourceLocale || 'en';

    const empty = { text: null, failedLocales: [] as string[] };

    // Translated one field at a time, on purpose — see the note in
    // lib/translate-server.ts about why parallel requests trip DeepL's
    // burst rate limit.
    const nameR = await translateToAllLocales(name ?? '', source);
    const descriptionR = await translateToAllLocales(description ?? '', source);
    const materialsR = materials ? await translateToAllLocales(materials, source) : empty;
    const heightR = height ? await translateToAllLocales(height, source) : empty;
    const widthR = width ? await translateToAllLocales(width, source) : empty;
    const circumferenceR = circumference
      ? await translateToAllLocales(circumference, source)
      : empty;
    const depthR = depth ? await translateToAllLocales(depth, source) : empty;
    const weightR = weight ? await translateToAllLocales(weight, source) : empty;

    const failedLocales = Array.from(
      new Set([
        ...nameR.failedLocales,
        ...descriptionR.failedLocales,
        ...materialsR.failedLocales,
        ...heightR.failedLocales,
        ...widthR.failedLocales,
        ...circumferenceR.failedLocales,
        ...depthR.failedLocales,
        ...weightR.failedLocales,
      ])
    );

    return NextResponse.json({
      name: nameR.text,
      description: descriptionR.text,
      materials: materialsR.text,
      height: heightR.text,
      width: widthR.text,
      circumference: circumferenceR.text,
      depth: depthR.text,
      weight: weightR.text,
      failedLocales,
      deeplConfigured: keyConfigured,
    });
  } catch (err) {
    console.error('Product translation error:', err);
    return NextResponse.json({ error: 'Translation failed' }, { status: 500 });
  }
}
