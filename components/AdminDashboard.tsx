'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
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
      name: p.name,
      slug: p.slug,
      price: (p.price_cents / 100).toString(),
      stock: p.stock.toString(),
      description: p.description,
      materials: p.materials ?? '',
      dimensions: p.dimensions ?? '',
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

    const payload = {
      name: form.name,
      slug: form.slug || form.name.toLowerCase().trim().replace(/\s+/g, '-'),
      price_cents: Math.round(parseFloat(form.price || '0') * 100),
      stock: parseInt(form.stock || '0', 10),
      description: form.description,
      materials: form.materials || null,
      dimensions: form.dimensions || null,
      images: form.images,
      currency: 'EUR',
    };

    if (editingId) {
      await supabase.from('products').update(payload).eq('id', editingId);
    } else {
      await supabase.from('products').insert(payload);
    }

    setSaving(false);
    resetForm();
    loadProducts();
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
                    <p className="font-body text-sm text-ink">{p.name}</p>
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
              {saving ? t('saving') : t('save')}
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
