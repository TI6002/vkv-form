'use client';

import { useEffect, useState } from 'react';
import { useLocale } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { pickLocalized } from '@/lib/localized';
import { sanitizeFileName } from '@/lib/sanitize-filename';
import { locales, localeNames, type Locale } from '@/i18n';
import type { AboutPost } from '@/lib/types';

// authorBody is ONE free-form field now — the client separates paragraphs
// herself with a blank line (press Enter twice), same as any normal text
// editor, instead of being limited to a fixed number of paragraph fields.
const FIELDS: { key: string; label: string; multiline?: boolean }[] = [
  { key: 'authorTitle', label: 'Author — title (the quote)' },
  { key: 'authorBody', label: 'Author — text', multiline: true },
];

function emptyPostForm(sourceLocale: string) {
  return { sourceLocale, title: '', body: '', images: [] as string[] };
}

/**
 * Lets Tab actually insert a tab character at the cursor instead of
 * jumping focus to the next field — the normal browser behaviour in a
 * <textarea> is unhelpful for writing indented paragraphs.
 */
function handleTabIndent(
  e: React.KeyboardEvent<HTMLTextAreaElement>,
  update: (transform: (prev: string) => string) => void
) {
  if (e.key !== 'Tab') return;
  e.preventDefault();
  const el = e.currentTarget;
  const start = el.selectionStart;
  const end = el.selectionEnd;
  update((prev) => prev.slice(0, start) + '\t' + prev.slice(end));
  requestAnimationFrame(() => {
    el.selectionStart = el.selectionEnd = start + 1;
  });
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
    // If the client already saved the old two-field version (authorBody1 /
    // authorBody2) but hasn't re-saved under the new combined "authorBody"
    // field yet, prefill it here so nothing looks like it vanished.
    if (!map.authorBody && (map.authorBody1 || map.authorBody2)) {
      map.authorBody = [map.authorBody1, map.authorBody2].filter(Boolean).join('\n\n');
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
        .filter(([key, value]) => key !== 'failedLocales' && key !== 'deeplConfigured' && value !== null)
        .map(([key, value]) => ({ key, value }));

      if (rows.length > 0) {
        const { error } = await supabase.from('about_content').upsert(rows);
        if (error) throw error;
      }

      if (failedLocales.length > 0) {
        const reason =
          translated.deeplConfigured === false
            ? "DEEPL_API_KEY is not set (or the server wasn't restarted after adding it)."
            : "usually the free translator's daily limit — try again in a bit.";
        alert(`Saved — but translation failed for: ${failedLocales.join(', ')}.\n\nReason: ${reason}`);
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

  async function handlePostUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    if (files.length === 0) return;
    setUploading(true);
    const urls: string[] = [];
    const errors: string[] = [];
    for (const file of files) {
      const path = `post-${Date.now()}-${sanitizeFileName(file.name)}`;
      const { error } = await supabase.storage
        .from('product-images')
        .upload(path, file, { cacheControl: '3600', upsert: false });
      if (error) {
        console.error('Post image upload failed:', file.name, error);
        errors.push(`${file.name}: ${error.message}`);
      } else {
        const { data } = supabase.storage.from('product-images').getPublicUrl(path);
        urls.push(data.publicUrl);
      }
    }
    if (urls.length > 0) {
      setPostForm((f) => ({ ...f, images: [...f.images, ...urls] }));
    }
    setUploading(false);
    e.target.value = '';
    if (errors.length > 0) {
      alert(`Could not upload:\n\n${errors.join('\n')}`);
    }
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
    const { error } = await supabase.from('about_posts').delete().eq('id', id);
    if (error) {
      console.error(error);
      alert('Could not delete this post — check the console.');
      return;
    }
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
                <>
                  <textarea
                    rows={12}
                    value={values[f.key] ?? ''}
                    onChange={(e) => setValues((v) => ({ ...v, [f.key]: e.target.value }))}
                    onKeyDown={(e) =>
                      handleTabIndent(e, (transform) =>
                        setValues((v) => ({ ...v, [f.key]: transform(v[f.key] ?? '') }))
                      )
                    }
                    className="input mt-2 font-mono text-sm"
                  />
                  <p className="mt-1.5 font-body text-xs text-taupe">
                    Leave a blank line between paragraphs (press Enter twice) —
                    each becomes its own paragraph on the page. Tab now inserts
                    a real indent.
                  </p>
                </>
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
              rows={8}
              value={postForm.body}
              onChange={(e) => setPostForm((f) => ({ ...f, body: e.target.value }))}
              onKeyDown={(e) =>
                handleTabIndent(e, (transform) =>
                  setPostForm((f) => ({ ...f, body: transform(f.body) }))
                )
              }
              className="input mt-2 font-mono text-sm"
            />
            <p className="mt-1.5 font-body text-xs text-taupe">
              Blank line between paragraphs; Tab inserts a real indent.
            </p>
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
