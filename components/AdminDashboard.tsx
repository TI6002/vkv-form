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
        width: translated.width,
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
        const reason =
          translated.deeplConfigured === false
            ? 'DEEPL_API_KEY is not set (or the server wasn\'t restarted after adding it) — translation cannot run at all right now.'
            : 'usually the free translator\'s daily limit — try again in a bit, or edit that language directly in "Fine-tune the name per language" below.';
        alert(
          `Saved — but translation failed for: ${translated.failedLocales.join(', ')}.\n\n` +
            `Reason: ${reason}`
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
