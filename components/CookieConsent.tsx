'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { Link } from '@/lib/navigation';

const STORAGE_KEY = 'vkv-form-cookie-consent';

/**
 * Simple GDPR-style cookie notice. Doesn't block anything or gate
 * scripts (this site doesn't load any third-party analytics/ad cookies —
 * only Supabase's own auth cookie, which is strictly necessary and
 * doesn't legally require consent), it just informs the visitor and
 * remembers their acknowledgement so it doesn't show again.
 */
export function CookieConsent() {
  const t = useTranslations('cookies');
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const seen = window.localStorage.getItem(STORAGE_KEY);
    if (!seen) setVisible(true);
  }, []);

  function accept() {
    window.localStorage.setItem(STORAGE_KEY, 'accepted');
    setVisible(false);
  }

  if (!visible) return null;

  return (
    <div className="fixed inset-x-0 bottom-0 z-50 border-t border-line bg-cream/97 px-6 py-5 backdrop-blur-sm md:px-10">
      <div className="mx-auto flex max-w-[1400px] flex-col items-start justify-between gap-4 md:flex-row md:items-center">
        <p className="max-w-2xl font-body text-sm leading-relaxed text-stone">
          {t('message')}{' '}
          <Link href="/cookie-policy" className="underline underline-offset-4 text-ink">
            {t('learnMore')}
          </Link>
        </p>
        <button
          onClick={accept}
          className="shrink-0 bg-ink px-7 py-3 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90"
        >
          {t('accept')}
        </button>
      </div>
    </div>
  );
}
