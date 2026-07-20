'use client';

import { usePathname, useRouter } from 'next/navigation';
import { useLocale } from 'next-intl';
import { useState, useRef, useEffect } from 'react';
import { locales, localeNames, type Locale } from '@/i18n';

export function LanguageSwitcher() {
  const locale = useLocale() as Locale;
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  function switchTo(next: Locale) {
    // Strip the current locale prefix (if any) then re-add the new one.
    const segments = pathname.split('/').filter(Boolean);
    const hasLocalePrefix = locales.includes(segments[0] as Locale);
    const rest = hasLocalePrefix ? segments.slice(1) : segments;
    const path = rest.length ? `/${rest.join('/')}` : '/';
    const target = next === 'en' ? path : `/${next}${path}`;
    router.push(target);
    setOpen(false);
  }

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((v) => !v)}
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone hover:text-ink transition-colors"
        aria-expanded={open}
      >
        {locale}
      </button>
      {open && (
        <div className="absolute right-0 top-full mt-3 w-40 border border-line bg-paper shadow-[0_12px_32px_-8px_rgba(33,30,26,0.18)] z-50">
          {locales.map((l) => (
            <button
              key={l}
              onClick={() => switchTo(l)}
              className={`block w-full text-left px-4 py-2.5 text-sm font-body transition-colors hover:bg-sand/60 ${
                l === locale ? 'text-ink' : 'text-stone'
              }`}
            >
              {localeNames[l]}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
