#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — remove debug logging, fix confirmed working..."

mkdir -p "components"
cat > "components/ClearCartOnSuccess.tsx" << '__VKV_PATCH_EOF__'
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
 * else needs to remember to do that. (Confirmed working via manual
 * testing — this was the actual cause of the earlier "cart doesn't
 * clear" bug.)
 */
function ClearCartOnSuccessInner() {
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

export function ClearCartOnSuccess() {
  return (
    <Suspense fallback={null}>
      <ClearCartOnSuccessInner />
    </Suspense>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/ClearCartOnSuccess.tsx"

echo "Done. git add -A && git commit -m \"Remove debug logging from ClearCartOnSuccess\" && git push"