#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates (round 30 — translation quota boost + failure warnings)..."

mkdir -p "lib"
cat > "lib/translate-server.ts" << '__VKV_PATCH_EOF__'
import { locales, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Translation backend: MyMemory (api.mymemory.translated.net).
 * -----------------------------------------------------------
 * Free, public, no-API-key translation API. Anonymous requests are
 * capped at roughly 1,000–5,000 words/day per IP — easy to hit with a
 * long product description translated into 6 languages, especially once
 * it gets split into multiple chunks. Passing a contact email via the
 * `de` parameter raises that ceiling to ~50,000 words/day. Set
 * MYMEMORY_CONTACT_EMAIL in .env.local to enable this (any real email
 * you control — MyMemory doesn't email you, it's just used to raise
 * your IP's quota).
 */
const MYMEMORY_ENDPOINT = 'https://api.mymemory.translated.net/get';
const MAX_CHUNK_LENGTH = 450; // MyMemory truncates/rejects very long single requests
const CONTACT_EMAIL = process.env.MYMEMORY_CONTACT_EMAIL || '';

async function translateChunk(text: string, source: string, target: string): Promise<string> {
  const params = new URLSearchParams({ q: text, langpair: `${source}|${target}` });
  if (CONTACT_EMAIL) params.set('de', CONTACT_EMAIL);

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
  if (/MYMEMORY WARNING|QUERY LENGTH LIMIT|IS AN INVALID/i.test(translated)) {
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

export type TranslateAllResult = {
  text: LocalizedText;
  /** Locales where translation failed and the source text was used
   * instead — surfaced to the admin UI so a silent quota failure isn't
   * mistaken for a successful translation. */
  failedLocales: Locale[];
};

/**
 * Translates a single string, written in `sourceLocale`, into every
 * locale configured in i18n.ts. `sourceLocale` is the language the admin
 * was actually typing in (whatever /admin is currently displayed in) —
 * far more reliable than trying to auto-detect it.
 */
export async function translateToAllLocales(
  text: string,
  sourceLocale: string
): Promise<TranslateAllResult> {
  const clean = (text ?? '').trim();
  const result: LocalizedText = {};
  const failedLocales: Locale[] = [];

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
        // blank — better to show the wrong language than nothing at all —
        // but record it so the caller can warn about it.
        result[locale as Locale] = clean;
        if (locale !== sourceLocale) failedLocales.push(locale as Locale);
      }
    })
  );

  return { text: result, failedLocales };
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
__VKV_PATCH_EOF__
echo "  updated: app/api/admin/translate-product/route.ts"

mkdir -p "app/api/admin/translate-fields"
cat > "app/api/admin/translate-fields/route.ts" << '__VKV_PATCH_EOF__'
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
__VKV_PATCH_EOF__
echo "  updated: app/api/admin/translate-fields/route.ts"

mkdir -p "components"
cat > "components/AdminDashboard.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { useLocale, useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { pickLocalized } from '@/lib/localized';
import { slugify } from '@/lib/slugify';
import { locales, localeNames, type Locale } from '@/i18n';
import { AdminOrdersPanel } from './AdminOrdersPanel';
import { AdminAboutPanel } from './AdminAboutPanel';
import { AdminCollectionPanel } from './AdminCollectionPanel';
import type { Product } from '@/lib/types';

function emptyFormFor(sourceLocale: string) {
  return {
    id: '',
    sourceLocale,
    name: '',
    slug: '',
    price: '',
    isAvailable: true,
    description: '',
    materials: '',
    height: '',
    circumference: '',
    depth: '',
    weight: '',
    images: [] as string[],
  };
}

function CatalogAdminPanel() {
  const t = useTranslations('admin');
  const locale = useLocale();
  const supabase = createClient();

  const [products, setProducts] = useState<Product[]>([]);
  const [tab, setTab] = useState<'products' | 'orders'>('products');
  const [form, setForm] = useState(() => emptyFormFor(locale));
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [nameOverrides, setNameOverrides] = useState<Partial<Record<Locale, string>>>({});
  const [savingOverrides, setSavingOverrides] = useState(false);

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
    setForm(emptyFormFor(locale));
    setEditingId(null);
    setNameOverrides({});
  }

  function startEdit(p: Product) {
    setEditingId(p.id);
    setNameOverrides(p.name ?? {});
    setForm({
      id: p.id,
      // Text shown here matches sourceLocale below — saving re-translates
      // from that language into every other one, overwriting old
      // translations. Change the dropdown if you're about to edit the
      // text in a different language than what's currently displayed.
      sourceLocale: locale,
      name: pickLocalized(p.name, locale),
      slug: p.slug,
      price: (p.price_cents / 100).toString(),
      isAvailable: p.available,
      description: pickLocalized(p.description, locale),
      materials: pickLocalized(p.materials, locale),
      height: pickLocalized(p.height, locale),
      circumference: pickLocalized(p.circumference, locale),
      depth: pickLocalized(p.depth, locale),
      weight: pickLocalized(p.weight, locale),
      images: p.images ?? [],
    });
  }

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    if (files.length === 0) return;
    setUploading(true);

    const uploadedUrls: string[] = [];
    for (const file of files) {
      const path = `${Date.now()}-${file.name}`;
      const { error } = await supabase.storage
        .from('product-images')
        .upload(path, file, { cacheControl: '3600', upsert: false });
      if (!error) {
        const { data } = supabase.storage.from('product-images').getPublicUrl(path);
        uploadedUrls.push(data.publicUrl);
      }
    }

    setForm((f) => ({ ...f, images: [...f.images, ...uploadedUrls] }));
    setUploading(false);
    e.target.value = ''; // lets you pick the same file(s) again later if needed
  }

  function removeImage(index: number) {
    setForm((f) => ({ ...f, images: f.images.filter((_, i) => i !== index) }));
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    try {
      // Translate from the language explicitly chosen in the "Text
      // language" field below — never guessed from the site's current
      // display language, which is too easy to have left on the wrong
      // one after switching languages to preview something else.
      const res = await fetch('/api/admin/translate-product', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.name,
          description: form.description,
          materials: form.materials || null,
          height: form.height || null,
          circumference: form.circumference || null,
          depth: form.depth || null,
          weight: form.weight || null,
          sourceLocale: form.sourceLocale,
        }),
      });

      if (!res.ok) throw new Error('Translation request failed');
      const translated = await res.json();

      const payload = {
        name: translated.name,
        slug:
          slugify(form.slug) ||
          slugify(translated.name?.en || form.name) ||
          `object-${Date.now()}`,
        price_cents: Math.round(parseFloat(form.price || '0') * 100),
        stock: form.isAvailable ? 1 : 0,
        available: form.isAvailable,
        description: translated.description,
        materials: translated.materials,
        height: translated.height,
        circumference: translated.circumference,
        depth: translated.depth,
        weight: translated.weight,
        images: form.images,
        currency: 'EUR',
      };

      if (editingId) {
        const { error } = await supabase.from('products').update(payload).eq('id', editingId);
        if (error) throw error;
      } else {
        const { error } = await supabase.from('products').insert(payload);
        if (error) throw error;
      }

      resetForm();
      await loadProducts();

      if (translated.failedLocales && translated.failedLocales.length > 0) {
        alert(
          `Saved — but translation failed for: ${translated.failedLocales.join(', ')}.\n` +
            `Those languages are showing the original text for now (usually the free ` +
            `translator's daily limit — try again in a bit, or edit that language directly ` +
            `in "Fine-tune the name per language" below).`
        );
      }
    } catch (err) {
      console.error('Save product error:', err);
      const message = err instanceof Error ? err.message : JSON.stringify(err);
      alert(`Could not save this object:\n\n${message}\n\n(Also check the browser console for the full details.)`);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm(t('confirmDelete'))) return;
    await supabase.from('products').delete().eq('id', id);
    loadProducts();
  }

  async function handleSaveOverrides() {
    if (!editingId) return;
    setSavingOverrides(true);
    await supabase.from('products').update({ name: nameOverrides }).eq('id', editingId);
    await loadProducts();
    setSavingOverrides(false);
  }

  return (
    <div>
      <div className="flex gap-6 border-b border-line pb-4">
        <button
          onClick={() => setTab('products')}
          className={`font-mono text-[11px] uppercase tracking-widest2 ${
            tab === 'products' ? 'text-ink' : 'text-stone hover:text-ink'
          }`}
        >
          {t('productsTab')}
        </button>
        <button
          onClick={() => setTab('orders')}
          className={`font-mono text-[11px] uppercase tracking-widest2 ${
            tab === 'orders' ? 'text-ink' : 'text-stone hover:text-ink'
          }`}
        >
          {t('ordersTab')}
        </button>
      </div>

      {tab === 'orders' ? (
        <AdminOrdersPanel />
      ) : (
    <div className="mt-10 grid gap-16 lg:grid-cols-[1fr_1.2fr]">
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
                      {(p.price_cents / 100).toFixed(2)} €{!p.available && ' · unavailable'}
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
          Fill in the fields below, pick which language you actually typed
          them in from the dropdown, then save — it gets translated into
          all 7 languages automatically from that language.
        </p>
        <form onSubmit={handleSave} className="mt-6 flex flex-col gap-5">
          <Field label="Text language (what you're typing below)">
            <select
              value={form.sourceLocale}
              onChange={(e) => setForm((f) => ({ ...f, sourceLocale: e.target.value }))}
              className="input"
            >
              {locales.map((l) => (
                <option key={l} value={l}>
                  {localeNames[l as Locale]} ({l})
                </option>
              ))}
            </select>
          </Field>
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
          <label className="flex items-center gap-2 font-body text-sm text-ink">
            <input
              type="checkbox"
              checked={form.isAvailable}
              onChange={(e) => setForm((f) => ({ ...f, isAvailable: e.target.checked }))}
            />
            Available for order
          </label>
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
          <Field label="Height">
            <input
              value={form.height}
              onChange={(e) => setForm((f) => ({ ...f, height: e.target.value }))}
              placeholder="e.g. 30 cm"
              className="input"
            />
          </Field>
          <Field label="Circumference">
            <input
              value={form.circumference}
              onChange={(e) => setForm((f) => ({ ...f, circumference: e.target.value }))}
              placeholder="e.g. 86 cm"
              className="input"
            />
          </Field>
          <Field label="Depth">
            <input
              value={form.depth}
              onChange={(e) => setForm((f) => ({ ...f, depth: e.target.value }))}
              placeholder="e.g. 12 cm"
              className="input"
            />
          </Field>
          <Field label="Weight">
            <input
              value={form.weight}
              onChange={(e) => setForm((f) => ({ ...f, weight: e.target.value }))}
              placeholder="e.g. 1.2 kg"
              className="input"
            />
          </Field>

          <Field label={t('images')}>
            <div className="flex flex-wrap gap-3">
              {form.images.map((src, i) => (
                <div key={i} className="group relative h-20 w-16 bg-sand">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={src} alt="" className="h-full w-full object-cover" />
                  <button
                    type="button"
                    onClick={() => removeImage(i)}
                    aria-label="Remove photo"
                    className="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-ink text-[10px] text-cream opacity-0 transition-opacity group-hover:opacity-100"
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
            <label className="mt-3 inline-block cursor-pointer font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4">
              {uploading ? t('saving') : t('uploadImage')}
              <input
                type="file"
                accept="image/*"
                multiple
                onChange={handleUpload}
                className="hidden"
              />
            </label>
            <p className="mt-2 font-body text-xs text-taupe">
              Photos upload right away, but you still need to click &quot;{t('save')}&quot;
              below afterwards for them to actually attach to this object.
            </p>
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

        {editingId && (
          <div className="mt-12 border-t border-line pt-8">
            <h3 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Fine-tune the name per language
            </h3>
            <p className="mt-2 max-w-sm font-body text-xs leading-relaxed text-taupe">
              The automatic translator sometimes gets a short word wrong (e.g.
              turning &quot;Ваза&quot; into &quot;Wasa&quot; instead of &quot;Vase&quot;). Fix any
              one language directly here — this only changes the name, and
              won&apos;t re-translate or touch anything else.
            </p>
            <div className="mt-5 flex flex-col gap-3">
              {locales.map((l) => (
                <div key={l} className="flex items-center gap-3">
                  <span className="w-28 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {localeNames[l as Locale]}
                  </span>
                  <input
                    value={nameOverrides[l as Locale] ?? ''}
                    onChange={(e) =>
                      setNameOverrides((prev) => ({ ...prev, [l]: e.target.value }))
                    }
                    className="input"
                  />
                </div>
              ))}
            </div>
            <button
              type="button"
              onClick={handleSaveOverrides}
              disabled={savingOverrides}
              className="mt-5 border border-ink px-6 py-3 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream disabled:opacity-50"
            >
              {savingOverrides ? 'Saving…' : 'Save these names'}
            </button>
          </div>
        )}
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
      )}
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

export function AdminDashboard() {
  const [section, setSection] = useState<'catalog' | 'about' | 'collection'>('catalog');

  const sections: { id: typeof section; label: string }[] = [
    { id: 'catalog', label: 'Catalog' },
    { id: 'about', label: 'About page' },
    { id: 'collection', label: 'Collection Book' },
  ];

  return (
    <div>
      <div className="flex flex-wrap gap-3">
        {sections.map((s) => (
          <button
            key={s.id}
            onClick={() => setSection(s.id)}
            className={`border px-5 py-2.5 font-mono text-[11px] uppercase tracking-widest2 transition-colors ${
              section === s.id
                ? 'border-ink bg-ink text-cream'
                : 'border-line text-stone hover:border-ink hover:text-ink'
            }`}
          >
            {s.label}
          </button>
        ))}
      </div>

      {section === 'catalog' && <CatalogAdminPanel />}
      {section === 'about' && <AdminAboutPanel />}
      {section === 'collection' && <AdminCollectionPanel />}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/AdminDashboard.tsx"

mkdir -p "components"
cat > "components/AdminAboutPanel.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { useLocale } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { pickLocalized } from '@/lib/localized';
import { locales, localeNames, type Locale } from '@/i18n';
import type { AboutPost } from '@/lib/types';

const FIELDS: { key: string; label: string; multiline?: boolean }[] = [
  { key: 'authorTitle', label: 'Author — title' },
  { key: 'authorBody1', label: 'Author — paragraph 1', multiline: true },
  { key: 'authorBody2', label: 'Author — paragraph 2', multiline: true },
  { key: 'philosophyTitle', label: 'Philosophy — title' },
  { key: 'philosophyBody1', label: 'Philosophy — paragraph 1', multiline: true },
  { key: 'philosophyBody2', label: 'Philosophy — paragraph 2', multiline: true },
  { key: 'philosophyBody3', label: 'Philosophy — paragraph 3', multiline: true },
];

function emptyPostForm(sourceLocale: string) {
  return { sourceLocale, title: '', body: '', images: [] as string[] };
}

export function AdminAboutPanel() {
  const locale = useLocale();
  const supabase = createClient();

  const [sourceLocale, setSourceLocale] = useState(locale);
  const [values, setValues] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [loaded, setLoaded] = useState(false);

  const [posts, setPosts] = useState<AboutPost[]>([]);
  const [postForm, setPostForm] = useState(() => emptyPostForm(locale));
  const [editingPostId, setEditingPostId] = useState<string | null>(null);
  const [postSaving, setPostSaving] = useState(false);
  const [uploading, setUploading] = useState(false);

  async function loadAll() {
    const [{ data: contentRows }, { data: postRows }] = await Promise.all([
      supabase.from('about_content').select('key, value'),
      supabase.from('about_posts').select('*').order('created_at', { ascending: false }),
    ]);

    const map: Record<string, string> = {};
    for (const row of contentRows ?? []) {
      map[row.key] = pickLocalized(row.value, locale);
    }
    setValues(map);
    setPosts((postRows as AboutPost[]) ?? []);
    setLoaded(true);
  }

  useEffect(() => {
    loadAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleSaveContent(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const res = await fetch('/api/admin/translate-fields', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fields: values, sourceLocale }),
      });
      if (!res.ok) throw new Error('translate failed');
      const translated = await res.json();
      const failedLocales: string[] = translated.failedLocales ?? [];

      const rows = Object.entries(translated)
        .filter(([key, value]) => key !== 'failedLocales' && value !== null)
        .map(([key, value]) => ({ key, value }));

      if (rows.length > 0) {
        const { error } = await supabase.from('about_content').upsert(rows);
        if (error) throw error;
      }

      if (failedLocales.length > 0) {
        alert(
          `Saved — but translation failed for: ${failedLocales.join(', ')}. Those ` +
            `languages are showing the original text for now (usually the free ` +
            `translator's daily limit — try again in a bit).`
        );
      } else {
        alert('Saved. Refresh the About page to see it.');
      }
    } catch (err) {
      console.error(err);
      alert('Could not save — check the console.');
    } finally {
      setSaving(false);
    }
  }

  async function handlePostUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    if (files.length === 0) return;
    setUploading(true);
    const urls: string[] = [];
    for (const file of files) {
      const path = `post-${Date.now()}-${file.name}`;
      const { error } = await supabase.storage
        .from('product-images')
        .upload(path, file, { cacheControl: '3600', upsert: false });
      if (!error) {
        const { data } = supabase.storage.from('product-images').getPublicUrl(path);
        urls.push(data.publicUrl);
      }
    }
    setPostForm((f) => ({ ...f, images: [...f.images, ...urls] }));
    setUploading(false);
    e.target.value = '';
  }

  function resetPostForm() {
    setPostForm(emptyPostForm(locale));
    setEditingPostId(null);
  }

  function startEditPost(post: AboutPost) {
    setEditingPostId(post.id);
    setPostForm({
      sourceLocale: locale,
      title: pickLocalized(post.title, locale),
      body: pickLocalized(post.body, locale),
      images: post.images ?? [],
    });
  }

  function removePostImage(index: number) {
    setPostForm((f) => ({ ...f, images: f.images.filter((_, i) => i !== index) }));
  }

  async function handleSavePost(e: React.FormEvent) {
    e.preventDefault();
    setPostSaving(true);
    try {
      const res = await fetch('/api/admin/translate-fields', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fields: { title: postForm.title, body: postForm.body },
          sourceLocale: postForm.sourceLocale,
        }),
      });
      if (!res.ok) throw new Error('translate failed');
      const translated = await res.json();

      const payload = {
        title: translated.title,
        body: translated.body,
        images: postForm.images,
      };

      if (editingPostId) {
        const { error } = await supabase
          .from('about_posts')
          .update(payload)
          .eq('id', editingPostId);
        if (error) throw error;
      } else {
        const { error } = await supabase.from('about_posts').insert(payload);
        if (error) throw error;
      }

      resetPostForm();
      loadAll();

      const failedLocales: string[] = translated.failedLocales ?? [];
      if (failedLocales.length > 0) {
        alert(
          `Saved — but translation failed for: ${failedLocales.join(', ')}. Those ` +
            `languages are showing the original text for now (usually the free ` +
            `translator's daily limit — try again in a bit).`
        );
      }
    } catch (err) {
      console.error(err);
      alert('Could not save this post — check the console.');
    } finally {
      setPostSaving(false);
    }
  }

  async function handleDeletePost(id: string) {
    if (!confirm('Delete this post?')) return;
    await supabase.from('about_posts').delete().eq('id', id);
    loadAll();
  }

  if (!loaded) return <p className="mt-6 font-body text-stone">Loading…</p>;

  return (
    <div className="mt-10 flex flex-col gap-16">
      {/* Page text */}
      <div>
        <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          About page text
        </h2>
        <p className="mt-2 max-w-lg font-body text-xs leading-relaxed text-taupe">
          Edit the text below in one language, choose which language that
          is, then save — it gets translated into all 7 automatically. If
          you leave a field blank, the site keeps showing its original
          built-in text for it.
        </p>

        <form onSubmit={handleSaveContent} className="mt-6 flex max-w-2xl flex-col gap-5">
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Text language
            </span>
            <select
              value={sourceLocale}
              onChange={(e) => setSourceLocale(e.target.value)}
              className="input mt-2"
            >
              {locales.map((l) => (
                <option key={l} value={l}>
                  {localeNames[l as Locale]} ({l})
                </option>
              ))}
            </select>
          </label>

          {FIELDS.map((f) => (
            <label key={f.key} className="block">
              <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {f.label}
              </span>
              {f.multiline ? (
                <textarea
                  rows={3}
                  value={values[f.key] ?? ''}
                  onChange={(e) => setValues((v) => ({ ...v, [f.key]: e.target.value }))}
                  className="input mt-2"
                />
              ) : (
                <input
                  value={values[f.key] ?? ''}
                  onChange={(e) => setValues((v) => ({ ...v, [f.key]: e.target.value }))}
                  className="input mt-2"
                />
              )}
            </label>
          ))}

          <button
            type="submit"
            disabled={saving}
            className="mt-2 self-start bg-ink px-8 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
          >
            {saving ? 'Translating & saving…' : 'Save page text'}
          </button>
        </form>
      </div>

      {/* Journal posts */}
      <div className="border-t border-line pt-16">
        <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          Journal posts
        </h2>
        <p className="mt-2 max-w-lg font-body text-xs leading-relaxed text-taupe">
          Shows up at the bottom of the About page, newest first.
        </p>

        {posts.length > 0 && (
          <ul className="mt-6 flex flex-col gap-3">
            {posts.map((p) => (
              <li
                key={p.id}
                className="flex items-center justify-between gap-4 border border-line p-3"
              >
                <div className="flex items-center gap-3">
                  {p.images?.[0] && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={p.images[0]} alt="" className="h-12 w-16 object-cover" />
                  )}
                  <span className="font-body text-sm text-ink">
                    {pickLocalized(p.title, locale) || '(untitled)'}
                  </span>
                </div>
                <div className="flex gap-4">
                  <button
                    onClick={() => startEditPost(p)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => handleDeletePost(p.id)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-red-800 underline underline-offset-4"
                  >
                    Delete
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}

        <form onSubmit={handleSavePost} className="mt-8 flex max-w-2xl flex-col gap-5">
          <h3 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {editingPostId ? 'Edit post' : 'New post'}
          </h3>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Text language
            </span>
            <select
              value={postForm.sourceLocale}
              onChange={(e) => setPostForm((f) => ({ ...f, sourceLocale: e.target.value }))}
              className="input mt-2"
            >
              {locales.map((l) => (
                <option key={l} value={l}>
                  {localeNames[l as Locale]} ({l})
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Title
            </span>
            <input
              required
              value={postForm.title}
              onChange={(e) => setPostForm((f) => ({ ...f, title: e.target.value }))}
              className="input mt-2"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Text
            </span>
            <textarea
              required
              rows={5}
              value={postForm.body}
              onChange={(e) => setPostForm((f) => ({ ...f, body: e.target.value }))}
              className="input mt-2"
            />
          </label>

          <div className="flex flex-wrap gap-3">
            {postForm.images.map((src, i) => (
              <div key={i} className="group relative h-16 w-20 bg-sand">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={src} alt="" className="h-full w-full object-cover" />
                <button
                  type="button"
                  onClick={() => removePostImage(i)}
                  className="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-ink text-[10px] text-cream opacity-0 transition-opacity group-hover:opacity-100"
                >
                  ×
                </button>
              </div>
            ))}
          </div>
          <label className="inline-block w-fit cursor-pointer font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4">
            {uploading ? 'Uploading…' : 'Upload photo(s)'}
            <input
              type="file"
              accept="image/*"
              multiple
              onChange={handlePostUpload}
              className="hidden"
            />
          </label>

          <div className="mt-2 flex gap-4">
            <button
              type="submit"
              disabled={postSaving}
              className="self-start border border-ink px-8 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream disabled:opacity-50"
            >
              {postSaving ? 'Translating & saving…' : editingPostId ? 'Save post' : 'Publish post'}
            </button>
            {editingPostId && (
              <button
                type="button"
                onClick={resetPostForm}
                className="font-mono text-[11px] uppercase tracking-widest2 text-stone underline underline-offset-4"
              >
                Cancel
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
__VKV_PATCH_EOF__
echo "  updated: components/AdminAboutPanel.tsx"

mkdir -p "components"
cat > "components/AdminCollectionPanel.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { useLocale } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { pickLocalized } from '@/lib/localized';
import { locales, localeNames, type Locale } from '@/i18n';
import type { CollectionItem } from '@/lib/types';

function emptyForm(sourceLocale: string) {
  return {
    sourceLocale,
    name: '',
    description: '',
    soldYear: '',
    images: [] as string[],
  };
}

export function AdminCollectionPanel() {
  const locale = useLocale();
  const supabase = createClient();

  const [items, setItems] = useState<CollectionItem[]>([]);
  const [form, setForm] = useState(() => emptyForm(locale));
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);

  async function load() {
    const { data } = await supabase
      .from('collection_items')
      .select('*')
      .order('created_at', { ascending: false });
    setItems((data as CollectionItem[]) ?? []);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function resetForm() {
    setForm(emptyForm(locale));
    setEditingId(null);
  }

  function startEdit(item: CollectionItem) {
    setEditingId(item.id);
    setForm({
      sourceLocale: locale,
      name: pickLocalized(item.name, locale),
      description: pickLocalized(item.description, locale),
      soldYear: item.sold_year ?? '',
      images: item.images ?? [],
    });
  }

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    if (files.length === 0) return;
    setUploading(true);
    const urls: string[] = [];
    for (const file of files) {
      const path = `collection-${Date.now()}-${file.name}`;
      const { error } = await supabase.storage
        .from('product-images')
        .upload(path, file, { cacheControl: '3600', upsert: false });
      if (!error) {
        const { data } = supabase.storage.from('product-images').getPublicUrl(path);
        urls.push(data.publicUrl);
      }
    }
    setForm((f) => ({ ...f, images: [...f.images, ...urls] }));
    setUploading(false);
    e.target.value = '';
  }

  function removeImage(index: number) {
    setForm((f) => ({ ...f, images: f.images.filter((_, i) => i !== index) }));
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const res = await fetch('/api/admin/translate-fields', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fields: { name: form.name, description: form.description },
          sourceLocale: form.sourceLocale,
        }),
      });
      if (!res.ok) throw new Error('translate failed');
      const translated = await res.json();

      const payload = {
        name: translated.name,
        description: translated.description ?? {},
        sold_year: form.soldYear || null,
        images: form.images,
      };

      if (editingId) {
        const { error } = await supabase
          .from('collection_items')
          .update(payload)
          .eq('id', editingId);
        if (error) throw error;
      } else {
        const { error } = await supabase.from('collection_items').insert(payload);
        if (error) throw error;
      }

      resetForm();
      await load();

      const failedLocales: string[] = translated.failedLocales ?? [];
      if (failedLocales.length > 0) {
        alert(
          `Saved — but translation failed for: ${failedLocales.join(', ')}. Those ` +
            `languages are showing the original text for now (usually the free ` +
            `translator's daily limit — try again in a bit).`
        );
      }
    } catch (err) {
      console.error(err);
      alert('Could not save — check the console.');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this collection item?')) return;
    await supabase.from('collection_items').delete().eq('id', id);
    load();
  }

  return (
    <div className="mt-10 grid gap-16 lg:grid-cols-[1fr_1.2fr]">
      <div>
        <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          Collection Book items
        </h2>
        {items.length === 0 ? (
          <p className="mt-6 font-body text-stone">Nothing archived yet.</p>
        ) : (
          <ul className="mt-6 divide-y divide-line border-t border-line">
            {items.map((item) => (
              <li key={item.id} className="flex items-center justify-between gap-4 py-4">
                <div className="flex items-center gap-4">
                  <div className="h-14 w-12 shrink-0 bg-sand">
                    {item.images?.[0] && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={item.images[0]} alt="" className="h-full w-full object-cover" />
                    )}
                  </div>
                  <div>
                    <p className="font-body text-sm text-ink">
                      {pickLocalized(item.name, locale)}
                    </p>
                    {item.sold_year && (
                      <p className="font-mono text-[11px] text-taupe">Sold {item.sold_year}</p>
                    )}
                  </div>
                </div>
                <div className="flex gap-4">
                  <button
                    onClick={() => startEdit(item)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => handleDelete(item.id)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-red-800 underline underline-offset-4"
                  >
                    Delete
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div>
        <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {editingId ? 'Edit item' : 'Add item to the collection book'}
        </h2>
        <form onSubmit={handleSave} className="mt-6 flex flex-col gap-5">
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Text language
            </span>
            <select
              value={form.sourceLocale}
              onChange={(e) => setForm((f) => ({ ...f, sourceLocale: e.target.value }))}
              className="input"
            >
              {locales.map((l) => (
                <option key={l} value={l}>
                  {localeNames[l as Locale]} ({l})
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Name
            </span>
            <input
              required
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              className="input"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Description
            </span>
            <textarea
              rows={3}
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              className="input"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Sold year (optional)
            </span>
            <input
              value={form.soldYear}
              onChange={(e) => setForm((f) => ({ ...f, soldYear: e.target.value }))}
              placeholder="e.g. 2025"
              className="input"
            />
          </label>

          <div className="flex flex-wrap gap-3">
            {form.images.map((src, i) => (
              <div key={i} className="group relative h-20 w-16 bg-sand">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={src} alt="" className="h-full w-full object-cover" />
                <button
                  type="button"
                  onClick={() => removeImage(i)}
                  className="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-ink text-[10px] text-cream opacity-0 transition-opacity group-hover:opacity-100"
                >
                  ×
                </button>
              </div>
            ))}
          </div>
          <label className="inline-block w-fit cursor-pointer font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4">
            {uploading ? 'Uploading…' : 'Upload photo(s)'}
            <input
              type="file"
              accept="image/*"
              multiple
              onChange={handleUpload}
              className="hidden"
            />
          </label>

          <div className="mt-2 flex gap-4">
            <button
              type="submit"
              disabled={saving}
              className="bg-ink px-8 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
            >
              {saving ? 'Translating & saving…' : 'Save item'}
            </button>
            {editingId && (
              <button
                type="button"
                onClick={resetForm}
                className="font-mono text-[11px] uppercase tracking-widest2 text-stone underline underline-offset-4"
              >
                Cancel
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
__VKV_PATCH_EOF__
echo "  updated: components/AdminCollectionPanel.tsx"

cat > ".env.example" << '__VKV_PATCH_EOF__'
# ---- Supabase (Settings → API in your Supabase project) ----
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
# Service role key — server-only, NEVER expose to the browser, never prefix with NEXT_PUBLIC_
SUPABASE_SERVICE_ROLE_KEY=

# ---- Stripe (Developers → API keys) ----
STRIPE_SECRET_KEY=
# Developers → Webhooks → your endpoint → Signing secret
STRIPE_WEBHOOK_SECRET=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=

# ---- Site ----
NEXT_PUBLIC_SITE_URL=http://localhost:3000

# ---- Studio details shown on /contact ("реквизиты") ----
NEXT_PUBLIC_STUDIO_COMPANY_NAME="vkv.form SIA"
NEXT_PUBLIC_STUDIO_REG_NUMBER=""
NEXT_PUBLIC_STUDIO_VAT_NUMBER=""
NEXT_PUBLIC_STUDIO_ADDRESS=""
NEXT_PUBLIC_STUDIO_EMAIL="hello@vkv.form"

# ---- Free translation quota boost (optional but recommended) ----
# Any real email you control. MyMemory doesn't send you anything — it just
# raises your server's daily translation quota from ~1,000 words to
# ~50,000 words. Without this, long product descriptions translated into
# 6 languages can silently hit the free daily limit.
MYMEMORY_CONTACT_EMAIL=""
__VKV_PATCH_EOF__
echo "  updated: .env.example"

echo
echo "Optional but recommended: add MYMEMORY_CONTACT_EMAIL=youremail@example.com to .env.local"
echo "Done. Restart npm run dev after this."