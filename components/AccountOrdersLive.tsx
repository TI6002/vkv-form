'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { OrderCard } from './OrderCard';
import { Reveal } from './Reveal';
import type { Order } from '@/lib/types';

/**
 * Renders the "Active orders" / "Order history" sections on /account and
 * keeps them in sync in real time. An order counts as active while it's
 * still in progress — pending, paid, or shipped (on its way, not yet
 * confirmed delivered) — and moves to history once it's finished:
 * delivered or cancelled. If an admin changes the status in /admin
 * while the customer has this page open, the order moves between
 * sections immediately — no page refresh needed.
 *
 * Requires Realtime replication to be enabled for the `orders` table
 * in Supabase (Database → Replication, or:
 *   alter publication supabase_realtime add table orders;
 * ) — otherwise this silently falls back to whatever `initialOrders`
 * was at page load (still correct, just not live).
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
    const channel = supabase
      .channel(`account-orders-${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'orders',
          filter: `user_id=eq.${userId}`,
        },
        (payload: any) => {
          setOrders((prev) => {
            if (payload.eventType === 'DELETE') {
              return prev.filter((o) => o.id !== payload.old.id);
            }
            const updated = payload.new as Order;
            const exists = prev.some((o) => o.id === updated.id);
            if (exists) {
              return prev.map((o) => (o.id === updated.id ? updated : o));
            }
            // A brand new order that arrived while the page was open
            // (e.g. the Stripe webhook fired just now) — show it first.
            return [updated, ...prev];
          });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
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
