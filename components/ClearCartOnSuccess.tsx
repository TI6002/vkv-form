'use client';

import { useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { useCart } from '@/context/CartContext';

/**
 * Renders nothing — just watches for ?order=success (set by the
 * Stripe success_url after a completed payment) and clears the cart
 * once. Without this, a bought item could sit in the browser's
 * localStorage cart and look purchasable again later, even though the
 * webhook already marked it sold.
 */
export function ClearCartOnSuccess() {
  const searchParams = useSearchParams();
  const { clearCart } = useCart();

  useEffect(() => {
    if (searchParams.get('order') === 'success') {
      clearCart();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return null;
}
