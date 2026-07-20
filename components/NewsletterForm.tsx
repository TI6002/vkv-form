'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';

export function NewsletterForm() {
  const t = useTranslations('footer');
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<'idle' | 'loading' | 'done' | 'error'>('idle');

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus('loading');
    const supabase = createClient();
    const { error } = await supabase.from('newsletter_subscribers').insert({ email });
    setStatus(error ? 'error' : 'done');
  }

  if (status === 'done') {
    return <p className="font-body text-sm text-ink">{t('newsletterSuccess')}</p>;
  }

  return (
    <form onSubmit={handleSubmit} className="flex max-w-sm gap-0 border-b border-ink/40 pb-1">
      <input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder={t('newsletterPlaceholder')}
        className="w-full bg-transparent font-body text-sm text-ink placeholder:text-stone/70 focus:outline-none"
      />
      <button
        type="submit"
        disabled={status === 'loading'}
        className="whitespace-nowrap font-mono text-[11px] uppercase tracking-widest2 text-ink hover:opacity-60 transition-opacity disabled:opacity-40"
      >
        {t('newsletterCta')}
      </button>
    </form>
  );
}
