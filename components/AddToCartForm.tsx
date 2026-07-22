'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import { useRouter } from '@/lib/navigation';
import type { Product } from '@/lib/types';

/**
 * Each object is a one-of-a-kind, handmade piece — there's only ever one
 * in stock, so there's no quantity to choose. Quantity is always 1.
 */
export function AddToCartForm({ product, name }: { product: Product; name: string }) {
  const t = useTranslations('product');
  const { addItem } = useCart();
  const router = useRouter();
  const [justAdded, setJustAdded] = useState(false);
  const available = product.available;

  function currentLine() {
    return {
      productId: product.id,
      slug: product.slug,
      name,
      priceCents: product.price_cents,
      image: product.images?.[0] ?? null,
    };
  }

  function handleAdd() {
    addItem(currentLine(), 1);
    setJustAdded(true);
    setTimeout(() => setJustAdded(false), 1800);
  }

  function handleOrderNow() {
    addItem(currentLine(), 1);
    router.push('/checkout');
  }

  if (!available) {
    return (
      <p className="mt-8 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
        {t('outOfStock')}
      </p>
    );
  }

  return (
    <div className="mt-8 flex flex-col gap-3">
      <button
        onClick={handleAdd}
        className="w-full border border-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream"
      >
        {justAdded ? t('added') : t('addToCart')}
      </button>
      <button
        onClick={handleOrderNow}
        className="w-full bg-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90"
      >
        {t('orderNow')}
      </button>
    </div>
  );
}
