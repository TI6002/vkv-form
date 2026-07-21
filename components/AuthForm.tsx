'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export function AuthForm() {
  const t = useTranslations('account');
  const router = useRouter();
  const [mode, setMode] = useState<'signIn' | 'signUp'>('signIn');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    console.log('Creating supabase client');
    const supabase = createClient();

    const result =
  mode === 'signIn'
    ? await supabase.auth.signInWithPassword({ email, password })
    : await supabase.auth.signUp({ email, password });

  console.log(result);

  const { error } = result;

    setLoading(false);
    if (error) {
  console.log('SUPABASE ERROR:', error);
  setError(error.message);
  return;
}
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex max-w-sm flex-col gap-6">
      <h1 className="font-display text-3xl text-ink">
        {mode === 'signIn' ? t('signInTitle') : t('signUpTitle')}
      </h1>

      <div>
        <label className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('email')}
        </label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mt-2 w-full border-b border-line bg-transparent py-2 font-body text-ink focus:outline-none focus:border-ink"
        />
      </div>
      <div>
        <label className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('password')}
        </label>
        <input
          type="password"
          required
          minLength={6}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mt-2 w-full border-b border-line bg-transparent py-2 font-body text-ink focus:outline-none focus:border-ink"
        />
      </div>

      {error && <p className="font-body text-sm text-red-800">{error}</p>}

      <button
        type="submit"
        disabled={loading}
        className="bg-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
      >
        {mode === 'signIn' ? t('signIn') : t('signUp')}
      </button>

      <button
        type="button"
        onClick={() => setMode(mode === 'signIn' ? 'signUp' : 'signIn')}
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone underline underline-offset-4 text-left"
      >
        {mode === 'signIn' ? t('orSignUp') : t('orSignIn')}
      </button>
    </form>
  );
}
