import { NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/auth';
import { translateToAllLocales } from '@/lib/translate-server';

export async function POST(req: Request) {
  // Gate this behind admin auth — it's the one place in the app that calls
  // out to the translation API, and we don't want it open to anyone.
  const admin = await requireAdmin();
  if (!admin) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  try {
    const {
      name,
      description,
      materials,
      height,
      circumference,
      depth,
      weight,
      sourceLocale,
    } = await req.json();
    const source = sourceLocale || 'en';

    const empty = { text: null, failedLocales: [] as string[] };

    const [nameR, descriptionR, materialsR, heightR, circumferenceR, depthR, weightR] =
      await Promise.all([
        translateToAllLocales(name ?? '', source),
        translateToAllLocales(description ?? '', source),
        materials ? translateToAllLocales(materials, source) : Promise.resolve(empty),
        height ? translateToAllLocales(height, source) : Promise.resolve(empty),
        circumference ? translateToAllLocales(circumference, source) : Promise.resolve(empty),
        depth ? translateToAllLocales(depth, source) : Promise.resolve(empty),
        weight ? translateToAllLocales(weight, source) : Promise.resolve(empty),
      ]);

    const failedLocales = Array.from(
      new Set([
        ...nameR.failedLocales,
        ...descriptionR.failedLocales,
        ...materialsR.failedLocales,
        ...heightR.failedLocales,
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
      circumference: circumferenceR.text,
      depth: depthR.text,
      weight: weightR.text,
      failedLocales,
    });
  } catch (err) {
    console.error('Product translation error:', err);
    return NextResponse.json({ error: 'Translation failed' }, { status: 500 });
  }
}
