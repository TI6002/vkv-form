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
