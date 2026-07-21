'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import { Link } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';

export default function CheckoutPage() {
  const t = useTranslations('checkout');
  const tc = useTranslations('cart');
  const { lines, subtotalCents } = useCart();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handlePay() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ lines, email }),
      });
      const data = await res.json();
      if (!res.ok || !data.url) throw new Error(data.error || 'failed');
      window.location.href = data.url;
    } catch {
      setError(t('error'));
      setLoading(false);
    }
  }

  if (lines.length === 0) {
    return (
      <div className="mx-auto max-w-[1400px] px-6 py-28 text-center md:px-10">
        <p className="font-body text-stone">{tc('empty')}</p>
        <Link
          href="/catalog"
          className="mt-6 inline-block font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
        >
          {tc('continue')}
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-[700px] px-6 py-20 md:px-10 md:py-28">
      <h1 className="font-display text-4xl text-ink">{t('title')}</h1>

      <ul className="mt-10 divide-y divide-line border-y border-line">
        {lines.map((line) => (
          <li key={line.productId} className="flex items-center justify-between py-4">
            <div>
              <p className="font-body text-sm text-ink">{line.name}</p>
              <p className="font-mono text-[11px] text-taupe">
                {tc('quantity')}: {line.quantity}
              </p>
            </div>
            <p className="font-mono text-sm text-stone">
              {formatPrice(line.priceCents * line.quantity)}
            </p>
          </li>
        ))}
      </ul>

      <div className="mt-6 flex items-baseline justify-between">
        <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {tc('subtotal')}
        </span>
        <span className="font-display text-2xl text-ink">{formatPrice(subtotalCents)}</span>
      </div>

      <div className="mt-10">
        <label className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('emailLabel')}
        </label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mt-2 w-full border-b border-line bg-transparent py-2 font-body text-ink focus:outline-none focus:border-ink"
        />
      </div>

      {error && <p className="mt-4 font-body text-sm text-red-800">{error}</p>}

      <button
        onClick={handlePay}
        disabled={loading || !email}
        className="mt-8 w-full bg-ink py-4 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
      >
        {loading ? t('redirecting') : t('payButton')}
      </button>
      <p className="mt-4 font-body text-xs text-taupe">{tc('taxNote')}</p>
    </div>
  );
}