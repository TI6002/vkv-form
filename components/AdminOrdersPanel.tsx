'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatPrice } from '@/lib/format';
import type { Order } from '@/lib/types';

const STATUSES: Order['status'][] = ['pending', 'paid', 'shipped', 'cancelled'];

export function AdminOrdersPanel() {
  const supabase = createClient();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    const { data } = await supabase
      .from('orders')
      .select('*')
      .order('created_at', { ascending: false });
    setOrders((data as Order[]) ?? []);
    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function updateStatus(id: string, status: Order['status']) {
    setOrders((prev) => prev.map((o) => (o.id === id ? { ...o, status } : o)));
    await supabase.from('orders').update({ status }).eq('id', id);
  }

  if (loading) {
    return <p className="mt-6 font-body text-stone">Loading orders…</p>;
  }

  if (orders.length === 0) {
    return <p className="mt-6 font-body text-stone">No orders yet.</p>;
  }

  return (
    <div className="mt-6 flex flex-col gap-4">
      {orders.map((order) => (
        <div key={order.id} className="border border-line p-5">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p className="font-display text-lg text-ink">
                Order #{order.order_number ?? order.id.slice(0, 8)}
              </p>
              <p className="font-mono text-[11px] text-taupe">
                {new Date(order.created_at).toLocaleString()}
              </p>
            </div>
            <select
              value={order.status}
              onChange={(e) => updateStatus(order.id, e.target.value as Order['status'])}
              className="border border-line bg-transparent px-3 py-2 font-mono text-xs uppercase tracking-widest2 text-ink"
            >
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>

          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            <div>
              <p className="font-mono text-[11px] uppercase tracking-widest2 text-taupe">Items</p>
              <ul className="mt-1 font-body text-sm text-ink">
                {order.items?.length > 0 ? (
                  order.items.map((item, i) => (
                    <li key={i}>
                      {item.name} × {item.quantity} — {formatPrice(item.amount_total)}
                    </li>
                  ))
                ) : (
                  <li className="text-taupe">No item detail recorded</li>
                )}
              </ul>
              <p className="mt-2 font-mono text-sm text-ink">
                Total: {formatPrice(order.total_cents, order.currency)}
              </p>
            </div>

            <div>
              <p className="font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                Customer
              </p>
              <p className="mt-1 font-body text-sm text-ink">
                {order.customer_details?.name || '—'}
              </p>
              <p className="font-body text-sm text-stone">{order.email}</p>
              {order.customer_details?.phone && (
                <p className="font-body text-sm text-stone">{order.customer_details.phone}</p>
              )}
              {order.customer_details?.address && (
                <p className="mt-1 font-body text-xs leading-relaxed text-stone">
                  {[
                    order.customer_details.address.line1,
                    order.customer_details.address.line2,
                    order.customer_details.address.city,
                    order.customer_details.address.postal_code,
                    order.customer_details.address.country,
                  ]
                    .filter(Boolean)
                    .join(', ')}
                </p>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
