#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — switch order status sync from Realtime to polling..."

mkdir -p "components"
cat > "components/AccountOrdersLive.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { OrderCard } from './OrderCard';
import { Reveal } from './Reveal';
import type { Order } from '@/lib/types';

const POLL_INTERVAL_MS = 5000;

/**
 * Renders the "Active orders" / "Order history" sections on /account and
 * keeps them in sync with the database. An order counts as active while
 * it's still in progress — pending, paid, or shipped (on its way, not
 * yet confirmed delivered) — and moves to history once it's finished:
 * delivered or cancelled.
 *
 * This polls the database every few seconds instead of relying on
 * Supabase Realtime — Realtime requires a one-time setup per table
 * (enabling replication + correct RLS) that's easy to have missed or
 * misconfigured, and polling works regardless, so if an admin changes
 * an order's status in /admin while the customer has this page open,
 * it moves between sections within a few seconds, no page refresh
 * needed. It also refetches immediately whenever the tab becomes
 * visible again, so switching back to the tab feels instant.
 */
export function AccountOrdersLive({
  userId,
  locale,
  initialOrders,
  activeOrdersTitle,
  pastOrdersTitle,
  noOrdersText,
  noPastOrdersText,
}: {
  userId: string;
  locale: string;
  initialOrders: Order[];
  activeOrdersTitle: string;
  pastOrdersTitle: string;
  noOrdersText: string;
  noPastOrdersText: string;
}) {
  const supabase = createClient();
  const [orders, setOrders] = useState<Order[]>(initialOrders);

  useEffect(() => {
    let cancelled = false;

    async function refetch() {
      const { data, error } = await supabase
        .from('orders')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });
      if (cancelled) return;
      if (error) {
        console.error('Could not refresh orders:', error);
        return;
      }
      setOrders((data as Order[]) ?? []);
    }

    const interval = setInterval(refetch, POLL_INTERVAL_MS);

    function handleVisibility() {
      if (document.visibilityState === 'visible') refetch();
    }
    document.addEventListener('visibilitychange', handleVisibility);

    return () => {
      cancelled = true;
      clearInterval(interval);
      document.removeEventListener('visibilitychange', handleVisibility);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  const activeOrders = orders.filter(
    (o) => o.status === 'pending' || o.status === 'paid' || o.status === 'shipped'
  );
  const pastOrders = orders.filter((o) => o.status === 'delivered' || o.status === 'cancelled');

  return (
    <>
      <Reveal>
        <div className="bg-white p-8">
          <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {activeOrdersTitle}
          </p>
          {activeOrders.length === 0 ? (
            <p className="mt-6 font-body text-stone">{noOrdersText}</p>
          ) : (
            <div className="mt-6 flex flex-col gap-4">
              {activeOrders.map((order) => (
                <OrderCard key={order.id} order={order} locale={locale} />
              ))}
            </div>
          )}
        </div>
      </Reveal>

      <Reveal delay={0.05}>
        <div className="bg-paper p-8">
          <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {pastOrdersTitle}
          </p>
          {pastOrders.length === 0 ? (
            <p className="mt-6 font-body text-stone">{noPastOrdersText}</p>
          ) : (
            <div className="mt-6 flex flex-col gap-4">
              {pastOrders.map((order) => (
                <OrderCard key={order.id} order={order} locale={locale} />
              ))}
            </div>
          )}
        </div>
      </Reveal>
    </>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/AccountOrdersLive.tsx"

echo ""
echo "No Supabase dashboard changes needed for this one — polling works"
echo "regardless of Realtime replication settings."
echo ""
echo "Done. git add -A && git commit -m \"Switch order status sync from Realtime to polling (more reliable)\" && git push"