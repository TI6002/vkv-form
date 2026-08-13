#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — manual ordering for Collection Book items..."

# --- 1. lib/types.ts: add sort_order to CollectionItem ---
FILE="lib/types.ts"
if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE not found — run this from the project root."
  exit 1
fi
if grep -B1 "sold_year: string | null;" "$FILE" | grep -q "sort_order?: number | null;"; then
  echo "  $FILE already has sort_order on CollectionItem — skipping type edit."
elif grep -qF "sold_year: string | null;" "$FILE"; then
  sed -i '/sold_year: string | null;/i\  sort_order?: number | null;' "$FILE"
  echo "  updated: $FILE"
else
  echo "WARNING: could not find \"sold_year: string | null;\" in $FILE."
  echo "  Open lib/types.ts yourself and add this field to the CollectionItem type:"
  echo "    sort_order?: number | null;"
fi

# --- 2. New lib helper: fetch collection items ordered by sort_order ---
mkdir -p "lib"
cat > "lib/collection-items.ts" << '__VKV_PATCH_EOF__'
import { createClient } from '@/lib/supabase/server';
import type { CollectionItem } from '@/lib/types';
export const dynamic = 'force-dynamic';

/**
 * Fetches Collection Book items in the admin-controlled manual order
 * (sort_order — set by the up/down buttons in /admin). Items that
 * haven't been manually ordered yet have sort_order = null, which
 * Postgres places last in ascending order automatically — so newly
 * archived pieces always land at the end until the admin moves them.
 * Among those, newest first.
 */
export async function getCollectionItems(): Promise<CollectionItem[]> {
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('collection_items')
      .select('*')
      .order('sort_order', { ascending: true, nullsFirst: false })
      .order('created_at', { ascending: false });
    if (error) {
      console.error('[getCollectionItems] Supabase error:', error);
      return [];
    }
    return (data as CollectionItem[]) ?? [];
  } catch (err) {
    console.error('[getCollectionItems] Unexpected error:', err);
    return [];
  }
}
__VKV_PATCH_EOF__
echo "  created: lib/collection-items.ts"

# --- 3. Collection Book listing page: use the new ordered fetch ---
mkdir -p "app/[locale]/collection"
cat > "app/[locale]/collection/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { Reveal } from '@/components/Reveal';
import { Link } from '@/lib/navigation';
import { getCollectionItems } from '@/lib/collection-items';
import { pickLocalized } from '@/lib/localized';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function CollectionPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('collection');
  const items = await getCollectionItems();

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
      <Reveal>
        <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('eyebrow')}
        </p>
        <h1 className="mt-4 font-display text-4xl italic text-ink md:text-5xl">
          {t('title')}
        </h1>
        <p className="mt-6 max-w-lg font-body text-base leading-relaxed text-stone">
          {t('intro')}
        </p>
      </Reveal>

      {items.length === 0 ? (
        <p className="mt-20 font-body text-stone">{t('empty')}</p>
      ) : (
        <div className="mt-16 grid grid-cols-1 gap-x-8 gap-y-16 sm:grid-cols-2 md:grid-cols-3">
          {items.map((item, i) => {
            const name = pickLocalized(item.name, locale);
            const description = pickLocalized(item.description, locale);
            return (
              <Reveal key={item.id} delay={(i % 3) * 0.06}>
                <Link href={`/collection/${item.id}`} className="group block">
                  <div className="relative aspect-[4/5] overflow-hidden bg-sand">
                    {item.images?.[0] && (
                      <Image
                        src={item.images[0]}
                        alt={name}
                        fill
                        sizes="(min-width: 768px) 33vw, 50vw"
                        className="object-cover grayscale-[15%] transition-transform duration-700 group-hover:scale-105"
                      />
                    )}
                    {/* Just "Sold" — no year shown publicly, even if one
                        was entered in the admin for internal reference. */}
                    <span className="absolute left-4 top-4 bg-cream/85 px-2.5 py-1 font-mono text-[10px] uppercase tracking-widest2 text-ink">
                      {t('sold')}
                    </span>
                  </div>
                  <h3 className="mt-4 font-display text-lg text-ink">{name}</h3>
                  {description && (
                    <p className="mt-1 font-body text-sm text-stone">{description}</p>
                  )}
                </Link>
              </Reveal>
            );
          })}
        </div>
      )}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/collection/page.tsx"

# --- 4. AdminCollectionPanel: same order as public page + up/down buttons ---
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
  const [reordering, setReordering] = useState(false);

  async function load() {
    // Same order as the public Collection Book page: manual sort_order
    // first (null last automatically), then newest first as a tie-breaker.
    const { data } = await supabase
      .from('collection_items')
      .select('*')
      .order('sort_order', { ascending: true, nullsFirst: false })
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

  // Swaps this item's position with the one above/below it in the
  // currently displayed list, by swapping their sort_order values —
  // exactly like the up/down buttons in the catalogue admin.
  async function moveItem(index: number, direction: 'up' | 'down') {
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= items.length || reordering) return;

    const current = items[index];
    const target = items[targetIndex];
    const currentOrder = current.sort_order ?? index;
    const targetOrder = target.sort_order ?? targetIndex;

    const next = [...items];
    next[index] = { ...current, sort_order: targetOrder };
    next[targetIndex] = { ...target, sort_order: currentOrder };
    next.sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));

    const previous = items;
    setItems(next);
    setReordering(true);

    const [{ error: err1 }, { error: err2 }] = await Promise.all([
      supabase.from('collection_items').update({ sort_order: targetOrder }).eq('id', current.id),
      supabase.from('collection_items').update({ sort_order: currentOrder }).eq('id', target.id),
    ]);
    setReordering(false);

    if (err1 || err2) {
      console.error(err1, err2);
      setItems(previous);
      alert('Could not reorder these items — check the console.');
    }
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
        // sort_order is intentionally left untouched here — new items
        // stay null (which sorts last, landing at the end of the
        // Collection Book) until moved with the up/down buttons.
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
        <p className="mt-2 max-w-sm font-body text-xs leading-relaxed text-taupe">
          Use the ↑ / ↓ buttons to set the order items appear in on the
          public Collection Book page. Newly archived pieces are added
          to the end of the list until you move them.
        </p>
        {items.length === 0 ? (
          <p className="mt-6 font-body text-stone">Nothing archived yet.</p>
        ) : (
          <ul className="mt-6 divide-y divide-line border-t border-line">
            {items.map((item, i) => (
              <li key={item.id} className="flex items-center justify-between gap-4 py-4">
                <div className="flex items-center gap-4">
                  <div className="flex flex-col">
                    <button
                      type="button"
                      onClick={() => moveItem(i, 'up')}
                      disabled={i === 0 || reordering}
                      aria-label="Move up"
                      className="px-1 font-mono text-sm leading-none text-taupe transition-colors hover:text-ink disabled:cursor-not-allowed disabled:opacity-25"
                    >
                      ↑
                    </button>
                    <button
                      type="button"
                      onClick={() => moveItem(i, 'down')}
                      disabled={i === items.length - 1 || reordering}
                      aria-label="Move down"
                      className="px-1 font-mono text-sm leading-none text-taupe transition-colors hover:text-ink disabled:cursor-not-allowed disabled:opacity-25"
                    >
                      ↓
                    </button>
                  </div>
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

echo ""
echo "IMPORTANT — one-time SQL to run in the Supabase SQL editor before this works:"
echo ""
echo "  alter table collection_items add column if not exists sort_order integer;"
echo ""
echo "  -- Backfill so existing items keep their current visual order"
echo "  -- right after the migration:"
echo "  with ranked as ("
echo "    select id, row_number() over (order by created_at asc) - 1 as rn"
echo "    from collection_items"
echo "  )"
echo "  update collection_items c"
echo "  set sort_order = ranked.rn"
echo "  from ranked"
echo "  where c.id = ranked.id;"
echo ""
echo "Also add this column to supabase/full-schema.sql yourself, since I"
echo "don't have that file, so a fresh database setup includes it too."
echo ""
echo "Done. git add -A && git commit -m \"Add manual ordering (up/down) for Collection Book items\" && git push"