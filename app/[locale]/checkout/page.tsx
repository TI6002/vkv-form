'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import { Link } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';
import { Reveal } from '@/components/Reveal';

/**
 * The order-review "anketa" the brief asked for: a full page (rather than
 * the small drawer) showing exactly what's being bought, letting the
 * person adjust quantities one last time, before handing off to Stripe's
 * own secure hosted page to actually enter card details and a shipping
 * address. We don't build our own card-entry form here on purpose —
 * that's what Stripe Checkout is for, and it's the part that needs to be
 * PCI-compliant.
 */
export default function CheckoutPage() {
  const t = useTranslations('cart');
  const tc = useTranslations('checkout');
  const { lines, removeItem, subtotalCents } = useCart();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);

  async function handlePay() {
    setLoading(true);
    setError(false);
    try {
      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ lines }),
      });
      const data = await res.json();
      if (data.url) {
        window.location.href = data.url;
      } else {
        throw new Error('No checkout URL returned');
      }
    } catch {
      setError(true);
      setLoading(false);
    }
  }

  if (lines.length === 0) {
    return (
      <div className="mx-auto max-w-[1400px] px-6 py-28 text-center md:px-10">
        <p className="font-body text-stone">{t('empty')}</p>
        <Link
          href="/catalog"
          className="mt-6 inline-block font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
        >
          {t('continue')}
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl px-6 py-16 md:px-10 md:py-24">
      <Reveal>
        <h1 className="font-display text-4xl text-ink md:text-5xl">{tc('title')}</h1>

        <ul className="mt-10 divide-y divide-line border-y border-line">
          {lines.map((line) => (
            <li key={line.productId} className="flex items-center gap-4 py-5">
              <div className="h-20 w-16 shrink-0 bg-sand">
                {line.image && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={line.image} alt={line.name} className="h-full w-full object-cover" />
                )}
              </div>
              <div className="flex flex-1 items-center justify-between gap-4">
                <div>
                  <p className="font-display text-base text-ink">{line.name}</p>
                  <button
                    onClick={() => removeItem(line.productId)}
                    className="mt-1 font-mono text-xs text-stone underline underline-offset-4 hover:text-ink"
                  >
                    {t('remove')}
                  </button>
                </div>
                <p className="font-mono text-sm text-ink">
                  {formatPrice(line.priceCents * line.quantity)}
                </p>
              </div>
            </li>
          ))}
        </ul>

        <div className="mt-8 flex items-baseline justify-between">
          <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {t('subtotal')}
          </span>
          <span className="font-display text-2xl text-ink">{formatPrice(subtotalCents)}</span>
        </div>
        <p className="mt-2 font-body text-xs text-stone">{t('taxNote')}</p>

        <button
          onClick={handlePay}
          disabled={loading}
          className="mt-8 w-full bg-ink py-4 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
        >
          {loading ? tc('redirecting') : tc('title')}
        </button>
        {error && (
          <p className="mt-4 font-body text-sm text-red-800">{tc('error')}</p>
        )}
      </Reveal>
    </div>
  );
}
