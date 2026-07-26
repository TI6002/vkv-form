'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import { useRouter } from '@/lib/navigation';
import { createClient } from '@/lib/supabase/client';
import type { Product } from '@/lib/types';

/**
 * Each object is a one-of-a-kind, handmade piece — there's only ever one
 * in stock, so there's no quantity to choose. Quantity is always 1.
 *
 * Availability is also kept live via Supabase Realtime: if an admin
 * toggles it off in /admin while someone has this page open, the button
 * disables itself immediately instead of waiting for a refresh.
 */
export function AddToCartForm({ product, name }: { product: Product; name: string }) {
  const t = useTranslations('product');
  const { addItem } = useCart();
  const router = useRouter();
  const [justAdded, setJustAdded] = useState(false);
  const [available, setAvailable] = useState(product.available);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`product-cart-availability-${product.id}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'products',
          filter: `id=eq.${product.id}`,
        },
        (payload) => {
          const next = (payload.new as { available?: boolean }).available;
          if (typeof next === 'boolean') setAvailable(next);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [product.id]);

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
