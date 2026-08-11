'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { OrderCard } from './OrderCard';
import type { Order } from '@/lib/types';

const STATUSES: Order['status'][] = ['pending', 'paid', 'shipped', 'delivered', 'cancelled'];

export function AdminOrdersPanel() {
  const supabase = createClient();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);

  async function load() {
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
    const previous = orders;
    setOrders((prev) => prev.map((o) => (o.id === id ? { ...o, status } : o)));
    const { error } = await supabase.from('orders').update({ status }).eq('id', id);
    if (error) {
      console.error(error);
      setOrders(previous);
      alert("Could not update this order's status — check the console.");
    }
  }

  async function deleteOrder(id: string) {
    if (!confirm('Delete this order? This cannot be undone.')) return;
    const previous = orders;
    setOrders((prev) => prev.filter((o) => o.id !== id));
    const { error } = await supabase.from('orders').delete().eq('id', id);
    if (error) {
      console.error(error);
      setOrders(previous);
      alert('Could not delete this order — check the console.');
    }
  }

  if (loading) return <p className="mt-6 font-body text-stone">Loading…</p>;

  if (orders.length === 0) {
    return <p className="mt-6 font-body text-stone">No orders yet.</p>;
  }

  return (
    <div className="mt-6 flex flex-col gap-5">
      {orders.map((order) => (
        <div key={order.id} className="relative">
          <OrderCard order={order} />
          <div className="mt-2 flex flex-wrap items-center gap-3 border border-t-0 border-line bg-cream px-5 py-3">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-taupe">
              {order.email}
            </span>
            <div className="ml-auto flex items-center gap-4">
              <div className="flex items-center gap-2">
                <span className="font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  Status:
                </span>
                <select
                  value={order.status}
                  onChange={(e) => updateStatus(order.id, e.target.value as Order['status'])}
                  className="border border-line bg-white px-2 py-1 font-mono text-[11px] uppercase tracking-widest2 text-ink"
                >
                  {STATUSES.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </div>
              <button
                onClick={() => deleteOrder(order.id)}
                className="font-mono text-[11px] uppercase tracking-widest2 text-red-600 underline underline-offset-4 hover:text-red-800"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
