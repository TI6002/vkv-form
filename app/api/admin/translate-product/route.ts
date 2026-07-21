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
    const { name, description, materials, dimensions, sourceLocale } = await req.json();
    const source = sourceLocale || 'en';

    const [nameT, descriptionT, materialsT, dimensionsT] = await Promise.all([
      translateToAllLocales(name ?? '', source),
      translateToAllLocales(description ?? '', source),
      materials ? translateToAllLocales(materials, source) : Promise.resolve(null),
      dimensions ? translateToAllLocales(dimensions, source) : Promise.resolve(null),
    ]);

    return NextResponse.json({
      name: nameT,
      description: descriptionT,
      materials: materialsT,
      dimensions: dimensionsT,
    });
  } catch (err) {
    console.error('Product translation error:', err);
    return NextResponse.json({ error: 'Translation failed' }, { status: 500 });
  }
}
