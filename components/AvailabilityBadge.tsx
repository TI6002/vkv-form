'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';

/**
 * Shows "in stock" / "unavailable" and updates live the moment an admin
 * toggles availability in /admin — no page refresh needed.
 */
export function AvailabilityBadge({
  productId,
  initialAvailable,
}: {
  productId: string;
  initialAvailable: boolean;
}) {
  const t = useTranslations('product');
  const [available, setAvailable] = useState(initialAvailable);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`product-availability-${productId}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'products', filter: `id=eq.${productId}` },
        (payload: any) => {
          const nextAvailable = payload?.new?.available;
          if (typeof nextAvailable === 'boolean') setAvailable(nextAvailable);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [productId]);

  return (
    <p className="mt-3 font-mono text-[11px] uppercase tracking-widest2">
      <span className={available ? 'text-stone' : 'text-red-800'}>
        {available ? t('inStock') : t('outOfStock')}
      </span>
    </p>
  );
}
