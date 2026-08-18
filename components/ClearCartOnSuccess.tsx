'use client';

import { Suspense, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { useCart } from '@/context/CartContext';

/**
 * Renders nothing — just watches for ?order=success (set by the
 * Stripe success_url after a completed payment) and clears the cart
 * once. Without this, a bought item could sit in the browser's
 * localStorage cart and look purchasable again later, even though the
 * webhook already marked it sold.
 *
 * useSearchParams() needs a <Suspense> boundary around it in the App
 * Router — without one it can silently fail to pick up the query
 * string on some renders. Wrapping it here, self-contained, so nothing
 * else needs to remember to do that.
 */
function ClearCartOnSuccessInner() {
  const searchParams = useSearchParams();
  const { clearCart } = useCart();

  useEffect(() => {
    const order = searchParams.get('order');
    console.log('ClearCartOnSuccess: order param is', JSON.stringify(order));
    if (order === 'success') {
      clearCart();
      console.log('ClearCartOnSuccess: cart cleared.');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return null;
}

export function ClearCartOnSuccess() {
  return (
    <Suspense fallback={null}>
      <ClearCartOnSuccessInner />
    </Suspense>
  );
}
