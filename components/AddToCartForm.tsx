'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import type { Product } from '@/lib/types';

export function AddToCartForm({ product }: { product: Product }) {
  const t = useTranslations('product');
  const { addItem } = useCart();
  const [quantity, setQuantity] = useState(1);
  const [justAdded, setJustAdded] = useState(false);
  const outOfStock = product.stock <= 0;

  function handleAdd() {
    addItem(
      {
        productId: product.id,
        slug: product.slug,
        name: product.name,
        priceCents: product.price_cents,
        image: product.images?.[0] ?? null,
      },
      quantity
    );
    setJustAdded(true);
    setTimeout(() => setJustAdded(false), 1800);
  }

  if (outOfStock) {
    return (
      <p className="mt-8 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
        {t('outOfStock')}
      </p>
    );
  }

  return (
    <div className="mt-8 flex items-center gap-4">
      <select
        value={quantity}
        onChange={(e) => setQuantity(Number(e.target.value))}
        aria-label={t('quantityLabel')}
        className="border border-line bg-transparent px-3 py-3.5 font-mono text-sm text-ink"
      >
        {Array.from({ length: Math.min(product.stock, 9) }, (_, i) => i + 1).map((n) => (
          <option key={n} value={n}>
            {n}
          </option>
        ))}
      </select>
      <button
        onClick={handleAdd}
        className="flex-1 bg-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90"
      >
        {justAdded ? t('added') : t('addToCart')}
      </button>
    </div>
  );
}
