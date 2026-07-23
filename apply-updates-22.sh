#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates (round 22 — multi-file upload, remove-photo button, smaller gallery photo)..."

mkdir -p "components"
cat > "components/ProductGallery.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useState } from 'react';
import Image from 'next/image';
import { ChevronLeft, ChevronRight } from 'lucide-react';

export function ProductGallery({ images, name }: { images: string[]; name: string }) {
  const [index, setIndex] = useState(0);
  const hasMultiple = images.length > 1;

  function prev() {
    setIndex((i) => (i - 1 + images.length) % images.length);
  }
  function next() {
    setIndex((i) => (i + 1) % images.length);
  }

  if (images.length === 0) {
    return <div className="aspect-[4/5] bg-sand" />;
  }

  return (
    <div>
      <div className="relative mx-auto aspect-[4/5] max-h-[65vh] w-auto overflow-hidden bg-sand">
        <Image
          key={images[index]}
          src={images[index]}
          alt={name}
          fill
          priority
          sizes="(min-width: 768px) 50vw, 100vw"
          className="object-cover"
        />

        {hasMultiple && (
          <>
            <button
              onClick={prev}
              aria-label="Previous photo"
              className="absolute left-3 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center bg-cream/85 text-ink transition-colors hover:bg-cream"
            >
              <ChevronLeft size={18} />
            </button>
            <button
              onClick={next}
              aria-label="Next photo"
              className="absolute right-3 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center bg-cream/85 text-ink transition-colors hover:bg-cream"
            >
              <ChevronRight size={18} />
            </button>
            <span className="absolute bottom-3 right-3 bg-cream/85 px-2.5 py-1 font-mono text-[10px] uppercase tracking-widest2 text-ink">
              {index + 1} / {images.length}
            </span>
          </>
        )}
      </div>

      {hasMultiple && (
        <div className="mt-3 flex gap-3 overflow-x-auto">
          {images.map((src, i) => (
            <button
              key={src}
              onClick={() => setIndex(i)}
              className={`relative h-20 w-16 shrink-0 overflow-hidden bg-sand transition-opacity ${
                i === index ? 'opacity-100 ring-1 ring-ink' : 'opacity-60 hover:opacity-90'
              }`}
              aria-label={`Photo ${i + 1}`}
            >
              <Image src={src} alt="" fill sizes="64px" className="object-cover" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/ProductGallery.tsx"

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
    dimensions: '',
    images: [] as string[],
  };
}

export function AdminDashboard() {
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
      dimensions: pickLocalized(p.dimensions, locale),
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
          dimensions: form.dimensions || null,
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
__VKV_PATCH_EOF__
echo "  updated: components/AdminDashboard.tsx"

echo "Done. Restart npm run dev after this."