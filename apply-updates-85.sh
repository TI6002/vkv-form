#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — materials & dimensions for Collection Book items..."

# --- 1. lib/types.ts: add materials/dimensions to CollectionItem ---
FILE="lib/types.ts"
if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE not found — run this from the project root."
  exit 1
fi
if grep -q "materials: LocalizedText | null;" "$FILE" && grep -A2 "sold_year: string | null;" "$FILE" | grep -q "created_at"; then
  # crude check: if materials already appears right before sold_year, skip
  :
fi
if grep -qF "sold_year: string | null;" "$FILE"; then
  if grep -B1 "sold_year: string | null;" "$FILE" | grep -q "weight: LocalizedText | null;"; then
    echo "  $FILE already has materials/dimensions on CollectionItem — skipping type edit."
  else
    sed -i '/sold_year: string | null;/i\  materials: LocalizedText | null;\n  height: LocalizedText | null;\n  width: LocalizedText | null;\n  circumference: LocalizedText | null;\n  depth: LocalizedText | null;\n  weight: LocalizedText | null;' "$FILE"
    echo "  updated: $FILE"
  fi
else
  echo "WARNING: could not find \"sold_year: string | null;\" in $FILE."
  echo "  Open lib/types.ts yourself and add these fields to the CollectionItem type:"
  echo "    materials: LocalizedText | null;"
  echo "    height: LocalizedText | null;"
  echo "    width: LocalizedText | null;"
  echo "    circumference: LocalizedText | null;"
  echo "    depth: LocalizedText | null;"
  echo "    weight: LocalizedText | null;"
fi

# --- 2. AdminCollectionPanel: materials/dimensions fields, translated and saved ---
mkdir -p "components"
cat > "components/AdminCollectionPanel.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { useLocale } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { pickLocalized } from '@/lib/localized';
import { sanitizeFileName } from '@/lib/sanitize-filename';
import { locales, localeNames, type Locale } from '@/i18n';
import type { CollectionItem } from '@/lib/types';

function emptyForm(sourceLocale: string) {
  return {
    sourceLocale,
    name: '',
    description: '',
    materials: '',
    height: '',
    width: '',
    circumference: '',
    depth: '',
    weight: '',
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
      materials: pickLocalized(item.materials, locale),
      height: pickLocalized(item.height, locale),
      width: pickLocalized(item.width, locale),
      circumference: pickLocalized(item.circumference, locale),
      depth: pickLocalized(item.depth, locale),
      weight: pickLocalized(item.weight, locale),
      soldYear: item.sold_year ?? '',
      images: item.images ?? [],
    });
  }

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    if (files.length === 0) return;
    setUploading(true);
    const urls: string[] = [];
    const errors: string[] = [];
    for (const file of files) {
      const path = `collection-${Date.now()}-${sanitizeFileName(file.name)}`;
      const { error } = await supabase.storage
        .from('product-images')
        .upload(path, file, { cacheControl: '3600', upsert: false });
      if (error) {
        console.error('Collection image upload failed:', file.name, error);
        errors.push(`${file.name}: ${error.message}`);
      } else {
        const { data } = supabase.storage.from('product-images').getPublicUrl(path);
        urls.push(data.publicUrl);
      }
    }
    if (urls.length > 0) {
      setForm((f) => ({ ...f, images: [...f.images, ...urls] }));
    }
    setUploading(false);
    e.target.value = '';
    if (errors.length > 0) {
      alert(`Could not upload:\n\n${errors.join('\n')}`);
    }
  }

  function removeImage(index: number) {
    setForm((f) => ({ ...f, images: f.images.filter((_, i) => i !== index) }));
  }

  // Swaps a photo with its neighbour so the admin can control the
  // order they appear in — the first photo is used as the thumbnail.
  function moveImage(index: number, direction: 'left' | 'right') {
    setForm((f) => {
      const target = direction === 'left' ? index - 1 : index + 1;
      if (target < 0 || target >= f.images.length) return f;
      const images = [...f.images];
      [images[index], images[target]] = [images[target], images[index]];
      return { ...f, images };
    });
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const res = await fetch('/api/admin/translate-fields', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fields: {
            name: form.name,
            description: form.description,
            materials: form.materials || null,
            height: form.height || null,
            width: form.width || null,
            circumference: form.circumference || null,
            depth: form.depth || null,
            weight: form.weight || null,
          },
          sourceLocale: form.sourceLocale,
        }),
      });
      if (!res.ok) throw new Error('translate failed');
      const translated = await res.json();

      const payload = {
        name: translated.name,
        description: translated.description ?? {},
        materials: translated.materials ?? null,
        height: translated.height ?? null,
        width: translated.width ?? null,
        circumference: translated.circumference ?? null,
        depth: translated.depth ?? null,
        weight: translated.weight ?? null,
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
        const reason =
          translated.deeplConfigured === false
            ? "DEEPL_API_KEY is not set (or the server wasn't restarted after adding it)."
            : "usually the free translator's daily limit — try again in a bit.";
        alert(`Saved — but translation failed for: ${failedLocales.join(', ')}.\n\nReason: ${reason}`);
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
    const { error } = await supabase.from('collection_items').delete().eq('id', id);
    if (error) {
      console.error(error);
      alert('Could not delete this item — check the console.');
      return;
    }
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
              Materials
            </span>
            <input
              value={form.materials}
              onChange={(e) => setForm((f) => ({ ...f, materials: e.target.value }))}
              className="input"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Height
            </span>
            <input
              value={form.height}
              onChange={(e) => setForm((f) => ({ ...f, height: e.target.value }))}
              placeholder="e.g. 30 cm"
              className="input"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Width
            </span>
            <input
              value={form.width}
              onChange={(e) => setForm((f) => ({ ...f, width: e.target.value }))}
              placeholder="e.g. 20 cm"
              className="input"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Circumference
            </span>
            <input
              value={form.circumference}
              onChange={(e) => setForm((f) => ({ ...f, circumference: e.target.value }))}
              placeholder="e.g. 86 cm"
              className="input"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Depth
            </span>
            <input
              value={form.depth}
              onChange={(e) => setForm((f) => ({ ...f, depth: e.target.value }))}
              placeholder="e.g. 12 cm"
              className="input"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Weight
            </span>
            <input
              value={form.weight}
              onChange={(e) => setForm((f) => ({ ...f, weight: e.target.value }))}
              placeholder="e.g. 1.2 kg"
              className="input"
            />
          </label>
          <label className="block">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              Sold year (optional, kept for your own records — not shown publicly)
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
                {i > 0 && (
                  <button
                    type="button"
                    onClick={() => moveImage(i, 'left')}
                    aria-label="Move photo earlier"
                    className="absolute -left-1.5 top-1/2 flex h-5 w-5 -translate-y-1/2 items-center justify-center rounded-full bg-ink text-[10px] text-cream opacity-0 transition-opacity group-hover:opacity-100"
                  >
                    ‹
                  </button>
                )}
                {i < form.images.length - 1 && (
                  <button
                    type="button"
                    onClick={() => moveImage(i, 'right')}
                    aria-label="Move photo later"
                    className="absolute -right-1.5 top-1/2 flex h-5 w-5 -translate-y-1/2 items-center justify-center rounded-full bg-ink text-[10px] text-cream opacity-0 transition-opacity group-hover:opacity-100"
                  >
                    ›
                  </button>
                )}
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
          <p className="-mt-2 font-body text-xs text-taupe">
            Hover a photo and use the ‹ › arrows to reorder it — the
            first photo is used as the thumbnail.
          </p>

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

# --- 3. AdminDashboard: markAsSold now carries materials/dimensions over too ---
FILE="components/AdminDashboard.tsx"
if [ -f "$FILE" ] && grep -q "images: p.images," "$FILE"; then
  sed -i "s/images: p.images,/images: p.images,\n      materials: p.materials,\n      height: p.height,\n      width: p.width,\n      circumference: p.circumference,\n      depth: p.depth,\n      weight: p.weight,/" "$FILE"
  echo "  updated: components/AdminDashboard.tsx (markAsSold now carries materials/dimensions)"
else
  echo "WARNING: could not find \"images: p.images,\" in components/AdminDashboard.tsx."
  echo "  Open the markAsSold() function yourself and add these lines to the"
  echo "  collection_items insert payload, alongside images: p.images:"
  echo "    materials: p.materials,"
  echo "    height: p.height,"
  echo "    width: p.width,"
  echo "    circumference: p.circumference,"
  echo "    depth: p.depth,"
  echo "    weight: p.weight,"
fi

# --- 4. Collection item detail page: show materials/dimensions like a normal product ---
mkdir -p "app/[locale]/collection/[id]"
cat > "app/[locale]/collection/[id]/page.tsx" << '__VKV_PATCH_EOF__'
import { notFound } from 'next/navigation';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { ProductGallery } from '@/components/ProductGallery';
import { getCollectionItemById } from '@/lib/collection-item';
import { pickLocalized } from '@/lib/localized';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function CollectionItemPage({
  params: { locale, id },
}: {
  params: { locale: string; id: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('collection');
  const tp = await getTranslations('product');
  const item = await getCollectionItemById(id);
  if (!item) notFound();

  const name = pickLocalized(item.name, locale);
  const description = pickLocalized(item.description, locale);
  const materials = pickLocalized(item.materials, locale);
  const height = pickLocalized(item.height, locale);
  const width = pickLocalized(item.width, locale);
  const circumference = pickLocalized(item.circumference, locale);
  const depth = pickLocalized(item.depth, locale);
  const weight = pickLocalized(item.weight, locale);

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-24">
      <Link
        href="/collection"
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone hover:text-ink"
      >
        ← {t('title')}
      </Link>

      <div className="mt-8 grid gap-14 md:grid-cols-2 md:gap-20">
        <Reveal>
          <ProductGallery images={item.images ?? []} name={name} />
        </Reveal>

        <Reveal delay={0.1}>
          <h1 className="font-display text-4xl text-ink md:text-5xl">{name}</h1>

          {/* No price, no buy button, no year — this piece has already
              found its home; this badge is the only status shown. */}
          <span className="mt-5 inline-block bg-sand px-3.5 py-2 font-mono text-[11px] uppercase tracking-widest2 text-ink">
            {t('sold')}
          </span>

          {description && (
            <p className="mt-8 font-body text-base leading-relaxed text-stone">
              {description}
            </p>
          )}

          {(materials || height || width || circumference || depth || weight) && (
            <dl className="mt-8 space-y-3 border-t border-line pt-6">
              {materials && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('materialsLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{materials}</dd>
                </div>
              )}
              {height && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('heightLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{height}</dd>
                </div>
              )}
              {width && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('widthLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{width}</dd>
                </div>
              )}
              {circumference && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('circumferenceLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{circumference}</dd>
                </div>
              )}
              {depth && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('depthLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{depth}</dd>
                </div>
              )}
              {weight && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('weightLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{weight}</dd>
                </div>
              )}
            </dl>
          )}
        </Reveal>
      </div>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/collection/[id]/page.tsx"

echo ""
echo "IMPORTANT — one-time SQL to run in the Supabase SQL editor before this works:"
echo ""
echo "  alter table collection_items"
echo "    add column if not exists materials jsonb,"
echo "    add column if not exists height jsonb,"
echo "    add column if not exists width jsonb,"
echo "    add column if not exists circumference jsonb,"
echo "    add column if not exists depth jsonb,"
echo "    add column if not exists weight jsonb;"
echo ""
echo "Also add these columns to supabase/full-schema.sql yourself, since I"
echo "don't have that file, so a fresh database setup includes them too."
echo ""
echo "Done. git add -A && git commit -m \"Add materials/dimensions to Collection Book items\" && git push"