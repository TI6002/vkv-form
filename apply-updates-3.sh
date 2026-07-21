#!/usr/bin/env bash
set -e
echo "Applying vkv.form updates (round 3 — translation fix)..."

mkdir -p "lib"
cat > "lib/translate-server.ts" << '__VKV_PATCH_EOF__'
import { locales, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Translation backend: MyMemory (api.mymemory.translated.net).
 * -----------------------------------------------------------
 * We switched away from the unofficial Google Translate scraper here
 * because it silently fails when called from a server's IP (very common
 * with hosting providers) — Google blocks/rate-limits it, the library
 * swallows the error, and every language ends up with the original,
 * untranslated text. MyMemory is a genuinely free, public, no-API-key
 * translation API meant exactly for this kind of server-side use, so it
 * doesn't get blocked the same way. (scripts/translate-missing.mjs, which
 * runs on your own machine, still uses the Google wrapper — that one's
 * fine since it's not calling from a shared hosting IP.)
 */
const MYMEMORY_ENDPOINT = 'https://api.mymemory.translated.net/get';
const MAX_CHUNK_LENGTH = 450; // MyMemory truncates/rejects very long single requests

async function translateChunk(text: string, source: string, target: string): Promise<string> {
  const params = new URLSearchParams({ q: text, langpair: `${source}|${target}` });
  const res = await fetch(`${MYMEMORY_ENDPOINT}?${params.toString()}`);

  if (!res.ok) throw new Error(`MyMemory HTTP ${res.status}`);

  const data = await res.json();
  const translated = data?.responseData?.translatedText;

  if (!translated || typeof translated !== 'string') {
    throw new Error('MyMemory returned no translation');
  }
  // MyMemory returns its rate-limit/quota notices *as* the "translation"
  // text instead of an HTTP error — catch that so it doesn't get saved
  // as if it were real product copy.
  if (/MYMEMORY WARNING|QUERY LENGTH LIMIT/i.test(translated)) {
    throw new Error(translated);
  }

  return translated;
}

function splitIntoChunks(text: string, maxLen: number): string[] {
  if (text.length <= maxLen) return [text];

  const sentences = text.split(/(?<=[.!?])\s+/);
  const chunks: string[] = [];
  let current = '';

  for (const sentence of sentences) {
    const candidate = current ? `${current} ${sentence}` : sentence;
    if (candidate.length > maxLen && current) {
      chunks.push(current);
      current = sentence;
    } else {
      current = candidate;
    }
  }
  if (current) chunks.push(current);

  return chunks;
}

/** Translates one string from `source` to `target` (both locale codes like "ru", "en"). */
export async function translateText(
  text: string,
  source: string,
  target: string
): Promise<string> {
  const clean = (text ?? '').trim();
  if (!clean) return '';
  if (source === target) return clean;

  const chunks = splitIntoChunks(clean, MAX_CHUNK_LENGTH);
  const translatedChunks = await Promise.all(
    chunks.map((chunk) => translateChunk(chunk, source, target))
  );
  return translatedChunks.join(' ');
}

/**
 * Translates a single string, written in `sourceLocale`, into every
 * locale configured in i18n.ts. `sourceLocale` is the language the admin
 * was actually typing in (whatever /admin is currently displayed in) —
 * far more reliable than trying to auto-detect it.
 */
export async function translateToAllLocales(
  text: string,
  sourceLocale: string
): Promise<LocalizedText> {
  const clean = (text ?? '').trim();
  const result: LocalizedText = {};

  await Promise.all(
    locales.map(async (locale) => {
      if (!clean) {
        result[locale as Locale] = '';
        return;
      }
      try {
        result[locale as Locale] = await translateText(clean, sourceLocale, locale);
      } catch (err) {
        console.error(`[translate] ${sourceLocale} -> ${locale} failed:`, err);
        // Fall back to the original text rather than leaving the field
        // blank — better to show the wrong language than nothing at all.
        result[locale as Locale] = clean;
      }
    })
  );

  return result;
}
__VKV_PATCH_EOF__
echo "  updated: lib/translate-server.ts"

mkdir -p "app/api/admin/translate-product"
cat > "app/api/admin/translate-product/route.ts" << '__VKV_PATCH_EOF__'
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
__VKV_PATCH_EOF__
echo "  updated: app/api/admin/translate-product/route.ts"

mkdir -p "components"
cat > "components/AdminDashboard.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { useLocale, useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { pickLocalized } from '@/lib/localized';
import type { Product } from '@/lib/types';

const emptyForm = {
  id: '',
  name: '',
  slug: '',
  price: '',
  stock: '',
  description: '',
  materials: '',
  dimensions: '',
  images: [] as string[],
};

export function AdminDashboard() {
  const t = useTranslations('admin');
  const locale = useLocale();
  const supabase = createClient();

  const [products, setProducts] = useState<Product[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);

  async function loadProducts() {
    const { data } = await supabase
      .from('products')
      .select('*')
      .order('created_at', { ascending: false });
    setProducts((data as Product[]) ?? []);
  }

  useEffect(() => {
    loadProducts();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
  }

  function startEdit(p: Product) {
    setEditingId(p.id);
    setForm({
      id: p.id,
      // Show the version matching whatever language the admin is
      // currently browsing in — saving will re-translate from this
      // into every language, overwriting the old translations.
      name: pickLocalized(p.name, locale),
      slug: p.slug,
      price: (p.price_cents / 100).toString(),
      stock: p.stock.toString(),
      description: pickLocalized(p.description, locale),
      materials: pickLocalized(p.materials, locale),
      dimensions: pickLocalized(p.dimensions, locale),
      images: p.images ?? [],
    });
  }

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const path = `${Date.now()}-${file.name}`;
    const { error } = await supabase.storage
      .from('product-images')
      .upload(path, file, { cacheControl: '3600', upsert: false });

    if (!error) {
      const { data } = supabase.storage.from('product-images').getPublicUrl(path);
      setForm((f) => ({ ...f, images: [...f.images, data.publicUrl] }));
    }
    setUploading(false);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    try {
      // Translate whatever the admin typed (any language) into every
      // language configured in i18n.ts, via the free Google Translate
      // wrapper running server-side in this API route.
      const res = await fetch('/api/admin/translate-product', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.name,
          description: form.description,
          materials: form.materials || null,
          dimensions: form.dimensions || null,
          sourceLocale: locale,
        }),
      });

      if (!res.ok) throw new Error('Translation request failed');
      const translated = await res.json();

      const payload = {
        name: translated.name,
        slug: form.slug || form.name.toLowerCase().trim().replace(/\s+/g, '-'),
        price_cents: Math.round(parseFloat(form.price || '0') * 100),
        stock: parseInt(form.stock || '0', 10),
        description: translated.description,
        materials: translated.materials,
        dimensions: translated.dimensions,
        images: form.images,
        currency: 'EUR',
      };

      if (editingId) {
        await supabase.from('products').update(payload).eq('id', editingId);
      } else {
        await supabase.from('products').insert(payload);
      }

      resetForm();
      await loadProducts();
    } catch (err) {
      console.error('Save product error:', err);
      alert('Could not save this object — check the browser console for details.');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm(t('confirmDelete'))) return;
    await supabase.from('products').delete().eq('id', id);
    loadProducts();
  }

  return (
    <div className="grid gap-16 lg:grid-cols-[1fr_1.2fr]">
      {/* Product list */}
      <div>
        <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('productsTab')}
        </h2>
        {products.length === 0 ? (
          <p className="mt-6 font-body text-stone">{t('noProducts')}</p>
        ) : (
          <ul className="mt-6 divide-y divide-line border-t border-line">
            {products.map((p) => (
              <li key={p.id} className="flex items-center justify-between gap-4 py-4">
                <div className="flex items-center gap-4">
                  <div className="h-14 w-12 shrink-0 bg-sand">
                    {p.images?.[0] && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.images[0]} alt="" className="h-full w-full object-cover" />
                    )}
                  </div>
                  <div>
                    <p className="font-body text-sm text-ink">{pickLocalized(p.name, locale)}</p>
                    <p className="font-mono text-[11px] text-taupe">
                      {(p.price_cents / 100).toFixed(2)} € · stock {p.stock}
                    </p>
                  </div>
                </div>
                <div className="flex gap-4">
                  <button
                    onClick={() => startEdit(p)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
                  >
                    {t('edit')}
                  </button>
                  <button
                    onClick={() => handleDelete(p.id)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-red-800 underline underline-offset-4"
                  >
                    {t('delete')}
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Product form */}
      <div>
        <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {editingId ? t('edit') : t('newProduct')}
        </h2>
        <p className="mt-2 max-w-sm font-body text-xs leading-relaxed text-taupe">
          Switch the site to whichever language you're about to type in (using
          the language switcher in the header), fill in the fields below in
          that language, then save — it gets translated into all 7
          languages automatically. Right now this page is in {locale.toUpperCase()}.
        </p>
        <form onSubmit={handleSave} className="mt-6 flex flex-col gap-5">
          <Field label={t('name')}>
            <input
              required
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              className="input"
            />
          </Field>
          <Field label={t('slug')}>
            <input
              value={form.slug}
              onChange={(e) => setForm((f) => ({ ...f, slug: e.target.value }))}
              placeholder="auto-generated from name if left blank"
              className="input"
            />
          </Field>
          <div className="grid grid-cols-2 gap-5">
            <Field label={t('price')}>
              <input
                required
                type="number"
                step="0.01"
                value={form.price}
                onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))}
                className="input"
              />
            </Field>
            <Field label={t('stock')}>
              <input
                required
                type="number"
                value={form.stock}
                onChange={(e) => setForm((f) => ({ ...f, stock: e.target.value }))}
                className="input"
              />
            </Field>
          </div>
          <Field label={t('description')}>
            <textarea
              required
              rows={4}
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              className="input"
            />
          </Field>
          <Field label={t('materials')}>
            <input
              value={form.materials}
              onChange={(e) => setForm((f) => ({ ...f, materials: e.target.value }))}
              className="input"
            />
          </Field>
          <Field label={t('dimensions')}>
            <input
              value={form.dimensions}
              onChange={(e) => setForm((f) => ({ ...f, dimensions: e.target.value }))}
              className="input"
            />
          </Field>

          <Field label={t('images')}>
            <div className="flex flex-wrap gap-3">
              {form.images.map((src, i) => (
                <div key={i} className="h-20 w-16 bg-sand">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={src} alt="" className="h-full w-full object-cover" />
                </div>
              ))}
            </div>
            <label className="mt-3 inline-block cursor-pointer font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4">
              {uploading ? t('saving') : t('uploadImage')}
              <input type="file" accept="image/*" onChange={handleUpload} className="hidden" />
            </label>
          </Field>

          <div className="mt-2 flex gap-4">
            <button
              type="submit"
              disabled={saving}
              className="bg-ink px-8 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
            >
              {saving ? 'Translating & saving…' : t('save')}
            </button>
            {editingId && (
              <button
                type="button"
                onClick={resetForm}
                className="font-mono text-[11px] uppercase tracking-widest2 text-stone underline underline-offset-4"
              >
                {t('cancel')}
              </button>
            )}
          </div>
        </form>
      </div>

      <style jsx global>{`
        .input {
          width: 100%;
          border-bottom: 1px solid #dcd0bc;
          background: transparent;
          padding: 0.5rem 0;
          font-family: var(--font-body);
          color: #211e1a;
        }
        .input:focus {
          outline: none;
          border-color: #211e1a;
        }
      `}</style>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
        {label}
      </span>
      <div className="mt-2">{children}</div>
    </label>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/AdminDashboard.tsx"

cat > "package.json" << '__VKV_PATCH_EOF__'
{
  "name": "vkv-form",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "translate": "node scripts/translate-missing.mjs"
  },
  "dependencies": {
    "@stripe/stripe-js": "^4.7.0",
    "@supabase/ssr": "^0.5.2",
    "@supabase/supabase-js": "^2.45.4",
    "clsx": "^2.1.1",
    "framer-motion": "^11.11.17",
    "lucide-react": "^0.454.0",
    "next": "14.2.15",
    "next-intl": "3.26.3",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "stripe": "^17.1.0",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^20.14.2",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "@vitalets/google-translate-api": "^9.2.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38",
    "tailwindcss": "^3.4.4",
    "typescript": "^5.5.2"
  }
}
__VKV_PATCH_EOF__
echo "  updated: package.json"

echo
echo "Done. Now run:"
echo "  npm install"