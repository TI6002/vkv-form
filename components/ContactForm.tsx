'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';

export function ContactForm() {
  const t = useTranslations('contact');
  const [status, setStatus] = useState<'idle' | 'loading' | 'done' | 'error'>('idle');

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus('loading');
    const form = new FormData(e.currentTarget);
    try {
      const res = await fetch('/api/contact', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.get('name'),
          email: form.get('email'),
          message: form.get('message'),
        }),
      });
      if (!res.ok) throw new Error();
      setStatus('done');
    } catch {
      setStatus('error');
    }
  }

  if (status === 'done') {
    return <p className="font-body text-base text-ink">{t('formSuccess')}</p>;
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-6">
      <div>
        <label className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('formName')}
        </label>
        <input
          name="name"
          required
          className="mt-2 w-full border-b border-line bg-transparent py-2 font-body text-ink focus:outline-none focus:border-ink"
        />
      </div>
      <div>
        <label className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('formEmail')}
        </label>
        <input
          name="email"
          type="email"
          required
          className="mt-2 w-full border-b border-line bg-transparent py-2 font-body text-ink focus:outline-none focus:border-ink"
        />
      </div>
      <div>
        <label className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('formMessage')}
        </label>
        <textarea
          name="message"
          required
          rows={5}
          className="mt-2 w-full border-b border-line bg-transparent py-2 font-body text-ink focus:outline-none focus:border-ink"
        />
      </div>
      <button
        type="submit"
        disabled={status === 'loading'}
        className="self-start bg-ink px-8 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
      >
        {t('formSubmit')}
      </button>
      {status === 'error' && (
        <p className="font-body text-sm text-red-800">{t('formError')}</p>
      )}
    </form>
  );
}
