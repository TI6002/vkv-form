#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates (round 20 — fix field name: available, not is_available)..."

mkdir -p "components"
cat > "components/ProductCard.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useLocale, useTranslations } from 'next-intl';
import Image from 'next/image';
import { Link } from '@/lib/navigation';
import type { Product } from '@/lib/types';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';
import { LikeButton } from './LikeButton';

export function ProductCard({ product, index }: { product: Product; index: number }) {
  const t = useTranslations('catalog');
  const tp = useTranslations('product');
  const locale = useLocale();
  const image = product.images?.[0];
  const name = pickLocalized(product.name, locale);
  const available = product.available;

  return (
    <Link href={`/catalog/${product.slug}`} className="group block">
      <div className="relative aspect-[4/5] overflow-hidden bg-sand">
        {image ? (
          <Image
            src={image}
            alt={name}
            fill
            sizes="(min-width: 768px) 33vw, 50vw"
            className={`object-cover transition-transform duration-[1400ms] ease-signature group-hover:scale-[1.045] ${
              available ? '' : 'opacity-60'
            }`}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center font-mono text-xs text-taupe">
            No image
          </div>
        )}
        <span className="absolute left-4 top-4 font-mono text-[10px] uppercase tracking-widest2 text-stone/80">
          {String(index + 1).padStart(2, '0')}
        </span>
        <div className="absolute right-3 top-3">
          <LikeButton productId={product.id} variant="icon" />
        </div>
        {!available && (
          <span className="absolute bottom-3 left-3 bg-ink/85 px-2.5 py-1 font-mono text-[10px] uppercase tracking-widest2 text-cream">
            {tp('outOfStock')}
          </span>
        )}
      </div>
      <div className="mt-4 flex items-baseline justify-between">
        <h3 className="font-display text-lg text-ink">{name}</h3>
        <span className="font-mono text-sm text-stone">
          {formatPrice(product.price_cents, product.currency)}
        </span>
      </div>
    </Link>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/ProductCard.tsx"

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

mkdir -p "components"
cat > "components/AddToCartForm.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import { useRouter } from '@/lib/navigation';
import type { Product } from '@/lib/types';

/**
 * Each object is a one-of-a-kind, handmade piece — there's only ever one
 * in stock, so there's no quantity to choose. Quantity is always 1.
 */
export function AddToCartForm({ product, name }: { product: Product; name: string }) {
  const t = useTranslations('product');
  const { addItem } = useCart();
  const router = useRouter();
  const [justAdded, setJustAdded] = useState(false);
  const available = product.available;

  function currentLine() {
    return {
      productId: product.id,
      slug: product.slug,
      name,
      priceCents: product.price_cents,
      image: product.images?.[0] ?? null,
    };
  }

  function handleAdd() {
    addItem(currentLine(), 1);
    setJustAdded(true);
    setTimeout(() => setJustAdded(false), 1800);
  }

  function handleOrderNow() {
    addItem(currentLine(), 1);
    router.push('/checkout');
  }

  if (!available) {
    return (
      <p className="mt-8 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
        {t('outOfStock')}
      </p>
    );
  }

  return (
    <div className="mt-8 flex flex-col gap-3">
      <button
        onClick={handleAdd}
        className="w-full border border-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream"
      >
        {justAdded ? t('added') : t('addToCart')}
      </button>
      <button
        onClick={handleOrderNow}
        className="w-full bg-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90"
      >
        {t('orderNow')}
      </button>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/AddToCartForm.tsx"

mkdir -p "app/[locale]/catalog/[slug]"
cat > "app/[locale]/catalog/[slug]/page.tsx" << '__VKV_PATCH_EOF__'
import { notFound } from 'next/navigation';
import Image from 'next/image';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';

// Without this, Next.js can cache this page's rendered output (and the
// Supabase fetch behind it) and keep showing stale product data — e.g.
// availability toggled in /admin not showing up here without a rebuild.
export const dynamic = 'force-dynamic';
export const revalidate = 0;
import { AddToCartForm } from '@/components/AddToCartForm';
import { LikeButton } from '@/components/LikeButton';
import { getProductBySlug } from '@/lib/products';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';

export default async function ProductPage({
  params: { locale, slug },
}: {
  params: { locale: string; slug: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('product');
  const product = await getProductBySlug(slug);
  if (!product) notFound();

  const name = pickLocalized(product.name, locale);
  const description = pickLocalized(product.description, locale);
  const materials = pickLocalized(product.materials, locale);
  const dimensions = pickLocalized(product.dimensions, locale);
  const available = product.available;

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-24">
      <Link
        href="/catalog"
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone hover:text-ink"
      >
        ← {t('back')}
      </Link>

      <div className="mt-8 grid gap-14 md:grid-cols-2 md:gap-20">
        <Reveal>
          <div className="relative aspect-[4/5] bg-sand">
            {product.images?.[0] && (
              <Image
                src={product.images[0]}
                alt={name}
                fill
                priority
                sizes="(min-width: 768px) 50vw, 100vw"
                className="object-cover"
              />
            )}
          </div>
        </Reveal>

        <Reveal delay={0.1}>
          <div className="flex items-start justify-between gap-4">
            <h1 className="font-display text-4xl text-ink md:text-5xl">{name}</h1>
          </div>
          <p className="mt-3 font-mono text-xl text-stone">
            {formatPrice(product.price_cents, product.currency)}
          </p>

          <p className="mt-3 font-mono text-[11px] uppercase tracking-widest2">
            <span className={available ? 'text-stone' : 'text-red-800'}>
              {available ? t('inStock') : t('outOfStock')}
            </span>
          </p>

          <p className="mt-8 font-body text-base leading-relaxed text-stone">
            {description}
          </p>

          <dl className="mt-8 space-y-3 border-t border-line pt-6">
            {materials && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('materialsLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{materials}</dd>
              </div>
            )}
            {dimensions && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('dimensionsLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{dimensions}</dd>
              </div>
            )}
          </dl>

          <AddToCartForm product={product} name={name} />

          <div className="mt-3">
            <LikeButton productId={product.id} />
          </div>

          <p className="mt-6 font-body text-xs leading-relaxed text-taupe">
            {t('shippingNote')}
          </p>
        </Reveal>
      </div>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/catalog/[slug]/page.tsx"

mkdir -p "lib"
cat > "lib/demo-products.ts" << '__VKV_PATCH_EOF__'
import type { Product } from './types';

export const demoProducts: Product[] = [
  {
    id: 'demo-1',
    slug: 'volta-vase',
    name: { en: 'Volta Vase' },
    price_cents: 18800,
    currency: 'EUR',
    description: {
      en: 'A hand-built stoneware vase with a soft asymmetric lean, left unglazed to show the raw clay body. Each one is thrown and altered by hand, so the exact curve varies slightly from piece to piece.',
    },
    materials: { en: 'Unglazed stoneware, sealed interior' },
    dimensions: { en: 'H 32 cm · Ø 16 cm' },
    stock: 4,
    available: true,
    images: ['/images/product-1.png'],
    created_at: new Date().toISOString(),
  },
  {
    id: 'demo-2',
    slug: 'muted-bowl-no-2',
    name: { en: 'Muted Bowl No. 2' },
    price_cents: 9400,
    currency: 'EUR',
    description: {
      en: 'A shallow bowl in tinted plaster with a soft, chalky surface. Suited to a single piece of fruit or a scatter of keys — it is meant to be used, not shelved.',
    },
    materials: { en: 'Tinted plaster, wax-sealed' },
    dimensions: { en: 'H 6 cm · Ø 24 cm' },
    stock: 7,
    available: true,
    images: ['/images/product-2.png'],
    created_at: new Date().toISOString(),
  },
  {
    id: 'demo-3',
    slug: 'still-form-obelisk',
    name: { en: 'Still Form Obelisk' },
    price_cents: 24200,
    currency: 'EUR',
    description: {
      en: 'A carved soft-stone obelisk, hand-finished with a matte, slightly porous surface. Reads as sculpture on its own, or as a quiet anchor on a shelf of smaller objects.',
    },
    materials: { en: 'Soft natural stone' },
    dimensions: { en: 'H 38 cm · W 8 cm · D 8 cm' },
    stock: 2,
    available: true,
    images: ['/images/product-3.png'],
    created_at: new Date().toISOString(),
  },
];
__VKV_PATCH_EOF__
echo "  updated: lib/demo-products.ts"

mkdir -p "lib"
cat > "lib/types.ts" << '__VKV_PATCH_EOF__'
import type { Locale } from '@/i18n';

/** A piece of text stored once per language, e.g. { en: "Vase", ru: "Ваза" }. */
export type LocalizedText = Partial<Record<Locale, string>>;

export type Product = {
  id: string;
  slug: string;
  name: LocalizedText;
  price_cents: number;
  currency: string;
  description: LocalizedText;
  materials: LocalizedText | null;
  dimensions: LocalizedText | null;
  stock: number;
  available: boolean;
  images: string[];
  created_at: string;
};

export type CartLine = {
  productId: string;
  slug: string;
  name: string;
  priceCents: number;
  image: string | null;
  quantity: number;
};

/** One line of what was actually bought, captured from the Stripe session
 * by the webhook — stored as part of the `items` jsonb column on `orders`. */
export type OrderLineItem = {
  name: string;
  quantity: number;
  amount_total: number;
};

export type CustomerAddress = {
  line1?: string | null;
  line2?: string | null;
  city?: string | null;
  postal_code?: string | null;
  country?: string | null;
};

export type CustomerDetails = {
  name?: string | null;
  email?: string | null;
  phone?: string | null;
  address?: CustomerAddress | null;
};

export type Order = {
  id: string;
  order_number: number;
  user_id: string | null;
  email: string;
  status: 'pending' | 'paid' | 'shipped' | 'cancelled';
  total_cents: number;
  currency: string;
  stripe_session_id: string | null;
  created_at: string;
  items: OrderLineItem[];
  customer_details: CustomerDetails | null;
};

export type Favorite = {
  id: string;
  user_id: string;
  product_id: string;
  created_at: string;
  products?: Product;
};
__VKV_PATCH_EOF__
echo "  updated: lib/types.ts"

echo "Done. Restart npm run dev after this."