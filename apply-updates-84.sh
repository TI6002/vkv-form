#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — clickable Collection Book items + Mark as sold..."

# --- 1. New helper: fetch a single collection item by id ---
mkdir -p "lib"
cat > "lib/collection-item.ts" << '__VKV_PATCH_EOF__'
import { createClient } from '@/lib/supabase/server';
import type { CollectionItem } from '@/lib/types';

export async function getCollectionItemById(id: string): Promise<CollectionItem | null> {
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('collection_items')
      .select('*')
      .eq('id', id)
      .single();
    if (error) {
      console.error(`[getCollectionItemById:${id}] Supabase error:`, error);
      return null;
    }
    return (data as CollectionItem) ?? null;
  } catch (err) {
    console.error(`[getCollectionItemById:${id}] Unexpected error:`, err);
    return null;
  }
}
__VKV_PATCH_EOF__
echo "  created: lib/collection-item.ts"

# --- 2. Collection Book listing: cards are now clickable, "Sold" tag has no year ---
mkdir -p "app/[locale]/collection"
cat > "app/[locale]/collection/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { Reveal } from '@/components/Reveal';
import { Link } from '@/lib/navigation';
import { getCollectionItems } from '@/lib/content';
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

# --- 3. New: Collection Book item detail page ---
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
  const item = await getCollectionItemById(id);
  if (!item) notFound();

  const name = pickLocalized(item.name, locale);
  const description = pickLocalized(item.description, locale);

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
        </Reveal>
      </div>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  created: app/[locale]/collection/[id]/page.tsx"

# --- 4. AdminDashboard: add "Mark as sold" button next to Edit/Delete ---
mkdir -p "components"
cat > "components/AdminDashboard.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { useLocale, useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { pickLocalized } from '@/lib/localized';
import { slugify } from '@/lib/slugify';
import { sanitizeFileName } from '@/lib/sanitize-filename';
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
    width: '',
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
  const [reordering, setReordering] = useState(false);
  const [markingSoldId, setMarkingSoldId] = useState<string | null>(null);

  async function loadProducts() {
    // Same order as the public catalog: manual sort_order first (null
    // last automatically), then newest first as a tie-breaker.
    const { data } = await supabase
      .from('products')
      .select('*')
      .order('sort_order', { ascending: true, nullsFirst: false })
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
      // description/materials/dimensions from that language into every
      // other one. The name is NOT auto-translated (see handleSave) —
      // it's set per language in "Set the name in each language" below.
      sourceLocale: locale,
      name: pickLocalized(p.name, locale),
      slug: p.slug,
      price: (p.price_cents / 100).toString(),
      isAvailable: p.available,
      description: pickLocalized(p.description, locale),
      materials: pickLocalized(p.materials, locale),
      height: pickLocalized(p.height, locale),
      width: pickLocalized(p.width, locale),
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
    const errors: string[] = [];
    for (const file of files) {
      const path = `${Date.now()}-${sanitizeFileName(file.name)}`;
      const { error } = await supabase.storage
        .from('product-images')
        .upload(path, file, { cacheControl: '3600', upsert: false });
      if (error) {
        console.error('Product image upload failed:', file.name, error);
        errors.push(`${file.name}: ${error.message}`);
      } else {
        const { data } = supabase.storage.from('product-images').getPublicUrl(path);
        uploadedUrls.push(data.publicUrl);
      }
    }

    if (uploadedUrls.length > 0) {
      setForm((f) => ({ ...f, images: [...f.images, ...uploadedUrls] }));
    }
    setUploading(false);
    e.target.value = ''; // lets you pick the same file(s) again later if needed
    if (errors.length > 0) {
      alert(`Could not upload:\n\n${errors.join('\n')}`);
    }
  }

  function removeImage(index: number) {
    setForm((f) => ({ ...f, images: f.images.filter((_, i) => i !== index) }));
  }

  // Swaps a photo with its neighbour so the admin can control the
  // order they appear in everywhere on the site — the first photo is
  // always used as the thumbnail (catalogue grid, favourites, etc).
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
      // The name is deliberately NOT sent through the translator — it's
      // set per language directly, merging whatever was already saved
      // for other languages (nameOverrides) with whatever's typed here
      // for the current "Text language". Only description/materials/
      // dimensions get auto-translated from that language into the
      // other 6.
      const nameField: Partial<Record<Locale, string>> = {
        ...nameOverrides,
        [form.sourceLocale]: form.name,
      };

      const res = await fetch('/api/admin/translate-product', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.name,
          description: form.description,
          materials: form.materials || null,
          height: form.height || null,
          width: form.width || null,
          circumference: form.circumference || null,
          depth: form.depth || null,
          weight: form.weight || null,
          sourceLocale: form.sourceLocale,
        }),
      });

      if (!res.ok) throw new Error('Translation request failed');
      const translated = await res.json();

      const payload = {
        name: nameField,
        slug:
          slugify(form.slug) ||
          slugify(form.name) ||
          `object-${Date.now()}`,
        price_cents: Math.round(parseFloat(form.price || '0') * 100),
        stock: form.isAvailable ? 1 : 0,
        available: form.isAvailable,
        description: translated.description,
        materials: translated.materials,
        height: translated.height,
        width: translated.width,
        circumference: translated.circumference,
        depth: translated.depth,
        weight: translated.weight,
        images: form.images,
        currency: 'EUR',
        // sort_order is intentionally left untouched here: for a new
        // product it stays null (which sorts last, i.e. lands at the
        // end of the catalog), and for an existing one this never
        // overwrites whatever position the admin has already set with
        // the up/down buttons.
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
        const reason =
          translated.deeplConfigured === false
            ? 'DEEPL_API_KEY is not set (or the server wasn\'t restarted after adding it) — translation cannot run at all right now.'
            : 'usually the free translator\'s daily limit — try again in a bit.';
        alert(
          `Saved — but translating the description/materials/dimensions failed for: ${translated.failedLocales.join(', ')}.\n\n` +
            `Reason: ${reason}\n\n` +
            `(The name itself is never auto-translated, so this doesn't affect it.)`
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
    const { error } = await supabase.from('products').delete().eq('id', id);
    if (error) {
      console.error(error);
      alert('Could not delete this object — check the console.');
      return;
    }
    loadProducts();
  }

  // Copies this product into the Collection Book (as a sold, archived
  // piece) and removes it from the catalogue. Note: collection_items
  // only has name/description/images/sold_year columns — materials
  // and dimensions are NOT carried over, since there's nowhere to put
  // them yet. If that's needed, those columns can be added later.
  async function markAsSold(p: Product) {
    const displayName = pickLocalized(p.name, locale) || 'this object';
    if (
      !confirm(
        `Mark "${displayName}" as sold?\n\n` +
          'It will be added to the Collection Book (archive) and removed ' +
          'from the catalogue. Note: materials and dimensions are not ' +
          'carried over — only the name, description and photos.'
      )
    ) {
      return;
    }

    setMarkingSoldId(p.id);
    const soldYear = new Date().getFullYear().toString();

    const { error: insertError } = await supabase.from('collection_items').insert({
      name: p.name,
      description: p.description,
      images: p.images,
      sold_year: soldYear,
    });

    if (insertError) {
      console.error(insertError);
      setMarkingSoldId(null);
      alert(
        'Could not add this to the Collection Book — check the console. ' +
          'The product was NOT removed from the catalogue.'
      );
      return;
    }

    const { error: deleteError } = await supabase.from('products').delete().eq('id', p.id);
    setMarkingSoldId(null);

    if (deleteError) {
      console.error(deleteError);
      alert(
        'This was added to the Collection Book, but could not be removed ' +
          'from the catalogue — check the console and delete it manually ' +
          'from the product list below.'
      );
    }

    await loadProducts();
  }

  async function handleSaveOverrides() {
    if (!editingId) return;
    setSavingOverrides(true);
    const { error } = await supabase
      .from('products')
      .update({ name: nameOverrides })
      .eq('id', editingId);
    await loadProducts();
    setSavingOverrides(false);
    if (error) {
      console.error(error);
      alert('Could not save these names — check the console.');
    }
  }

  // Swaps this product's position with the one above/below it in the
  // currently displayed list, by swapping their sort_order values.
  async function moveProduct(index: number, direction: 'up' | 'down') {
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= products.length || reordering) return;

    const current = products[index];
    const target = products[targetIndex];
    const currentOrder = current.sort_order ?? index;
    const targetOrder = target.sort_order ?? targetIndex;

    const next = [...products];
    next[index] = { ...current, sort_order: targetOrder };
    next[targetIndex] = { ...target, sort_order: currentOrder };
    next.sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));

    const previous = products;
    setProducts(next);
    setReordering(true);

    const [{ error: err1 }, { error: err2 }] = await Promise.all([
      supabase.from('products').update({ sort_order: targetOrder }).eq('id', current.id),
      supabase.from('products').update({ sort_order: currentOrder }).eq('id', target.id),
    ]);
    setReordering(false);

    if (err1 || err2) {
      console.error(err1, err2);
      setProducts(previous);
      alert('Could not reorder these objects — check the console.');
    }
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
        <p className="mt-2 max-w-sm font-body text-xs leading-relaxed text-taupe">
          Use the ↑ / ↓ buttons to set the order objects appear in on the
          public catalogue page. New objects are added to the end of the
          list until you move them.
        </p>
        {products.length === 0 ? (
          <p className="mt-6 font-body text-stone">{t('noProducts')}</p>
        ) : (
          <ul className="mt-6 divide-y divide-line border-t border-line">
            {products.map((p, i) => (
              <li key={p.id} className="flex flex-wrap items-center justify-between gap-4 py-4">
                <div className="flex items-center gap-4">
                  <div className="flex flex-col">
                    <button
                      type="button"
                      onClick={() => moveProduct(i, 'up')}
                      disabled={i === 0 || reordering}
                      aria-label="Move up"
                      className="px-1 font-mono text-sm leading-none text-taupe transition-colors hover:text-ink disabled:cursor-not-allowed disabled:opacity-25"
                    >
                      ↑
                    </button>
                    <button
                      type="button"
                      onClick={() => moveProduct(i, 'down')}
                      disabled={i === products.length - 1 || reordering}
                      aria-label="Move down"
                      className="px-1 font-mono text-sm leading-none text-taupe transition-colors hover:text-ink disabled:cursor-not-allowed disabled:opacity-25"
                    >
                      ↓
                    </button>
                  </div>
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
                <div className="flex flex-wrap gap-4">
                  <button
                    onClick={() => startEdit(p)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
                  >
                    {t('edit')}
                  </button>
                  <button
                    onClick={() => markAsSold(p)}
                    disabled={markingSoldId === p.id}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-cocoa underline underline-offset-4 disabled:opacity-50"
                  >
                    {markingSoldId === p.id ? 'Moving…' : 'Mark as sold'}
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
          The name is never auto-translated — set it for each language
          yourself in &quot;Set the name in each language&quot; below.
          Everything else (description, materials, dimensions) gets
          translated into all 7 languages automatically from whatever
          language you pick here.
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
          <Field label={`${t('name')} (${form.sourceLocale})`}>
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
          <Field label="Width">
            <input
              value={form.width}
              onChange={(e) => setForm((f) => ({ ...f, width: e.target.value }))}
              placeholder="e.g. 20 cm"
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
              Hover a photo and use the ‹ › arrows to reorder it — the
              first photo is used as the thumbnail everywhere on the
              site. Photos upload right away, but you still need to
              click &quot;{t('save')}&quot; below afterwards for changes
              to actually attach to this object.
            </p>
          </Field>

          <div className="mt-2 flex gap-4">
            <button
              type="submit"
              disabled={saving}
              className="bg-ink px-8 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
            >
              {saving ? 'Saving…' : t('save')}
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

        <div className="mt-12 border-t border-line pt-8">
          <h3 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
            Set the name in each language
          </h3>
          <p className="mt-2 max-w-sm font-body text-xs leading-relaxed text-taupe">
            The name is never auto-translated. Fill it in for every
            language you want to support — languages left blank here
            will fall back to whatever you typed in &quot;{t('name')}&quot;
            above.
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
                  placeholder={form.sourceLocale === l ? form.name : ''}
                  className="input"
                />
              </div>
            ))}
          </div>
          {editingId ? (
            <button
              type="button"
              onClick={handleSaveOverrides}
              disabled={savingOverrides}
              className="mt-5 border border-ink px-6 py-3 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream disabled:opacity-50"
            >
              {savingOverrides ? 'Saving…' : 'Save these names'}
            </button>
          ) : (
            <p className="mt-5 font-body text-xs text-taupe">
              These are saved automatically together with the rest of
              the form when you click &quot;{t('save')}&quot; above for
              a new object.
            </p>
          )}
        </div>
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

# --- 5. Add the "sold" (no year) translation key to all 7 locale files ---
add_sold_key() {
  file="$1"
  old_line="$2"
  new_line="$3"
  if [ ! -f "$file" ]; then
    echo "  WARNING: $file not found — skipped."
    return
  fi
  if grep -qF "\"sold\":" "$file"; then
    echo "  $file already has a \"sold\" key — skipped."
    return
  fi
  if grep -qF "$old_line" "$file"; then
    sed -i "s/$(printf '%s' "$old_line" | sed -e 's/[\/&]/\\&/g')/$(printf '%s' "$new_line" | sed -e 's/[\/&]/\\&/g')/" "$file"
    echo "  updated: $file"
  else
    echo "  WARNING: could not find matching line in $file — add manually:"
    echo "    $new_line"
  fi
}

add_sold_key "messages/en.json" '"soldIn": "Sold in"' '"soldIn": "Sold in",\n    "sold": "Sold"'
add_sold_key "messages/ru.json" '"soldIn": "Продано в"' '"soldIn": "Продано в",\n    "sold": "Продано"'
add_sold_key "messages/de.json" '"soldIn": "Verkauft im Jahr"' '"soldIn": "Verkauft im Jahr",\n    "sold": "Verkauft"'
add_sold_key "messages/es.json" '"soldIn": "Vendido en"' '"soldIn": "Vendido en",\n    "sold": "Vendido"'
add_sold_key "messages/fr.json" '"soldIn": "Vendu en"' '"soldIn": "Vendu en",\n    "sold": "Vendu"'
add_sold_key "messages/it.json" '"soldIn": "Venduto nel"' '"soldIn": "Venduto nel",\n    "sold": "Venduto"'
add_sold_key "messages/lv.json" '"soldIn": "Pārdots"' '"soldIn": "Pārdots",\n    "sold": "Pārdots"'

echo ""
echo "IMPORTANT — check the output above for any WARNING lines, and check"
echo "each messages/*.json still parses as valid JSON after the sed edits"
echo "(the automated insert is line-based)."
echo ""
echo "Done. git add -A && git commit -m \"Clickable Collection Book items, Mark as sold action, plain Sold label\" && git push"