'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import { useRouter } from '@/lib/navigation';
import type { Product } from '@/lib/types';

export function AddToCartForm({ product, name }: { product: Product; name: string }) {
  const t = useTranslations('product');
  const { addItem } = useCart();
  const router = useRouter();
  const [quantity, setQuantity] = useState(1);
  const [justAdded, setJustAdded] = useState(false);
  const isAvailable = product.available && product.stock > 0;

  function lineItem() {
    return {
      productId: product.id,
      slug: product.slug,
      name,
      priceCents: product.price_cents,
      image: product.images?.[0] ?? null,
    };
  }

  function handleAdd() {
    addItem(lineItem(), quantity);
    setJustAdded(true);
    setTimeout(() => setJustAdded(false), 1800);
  }

  function handleOrderNow() {
    addItem(lineItem(), quantity);
    router.push('/checkout');
  }

  if (!isAvailable) {
    return (
      <p className="mt-8 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
        {t('outOfStock')}
      </p>
    );
  }

  return (
    <div className="mt-8 flex flex-col gap-4">
      <div className="flex items-center gap-4">
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
          className="flex-1 border border-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream"
        >
          {justAdded ? t('added') : t('addToCart')}
        </button>
      </div>
      <button
        onClick={handleOrderNow}
        className="bg-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90"
      >
        {t('orderNow')}
      </button>
    </div>
  );
}