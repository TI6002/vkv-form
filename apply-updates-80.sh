#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — detect and fix silent RLS failures on order updates..."

mkdir -p "components"
cat > "components/AdminOrdersPanel.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { OrderCard } from './OrderCard';
import type { Order } from '@/lib/types';

const STATUSES: Order['status'][] = ['pending', 'paid', 'shipped', 'delivered', 'cancelled'];

// Shown when an update/delete "succeeds" (no error) but changes 0 rows —
// which in Supabase almost always means Row Level Security silently
// blocked it, not that anything is actually wrong with the request.
const RLS_HINT =
  "This saved with no error, but nothing in the database actually " +
  "changed — that's the signature of a missing Row Level Security " +
  "policy, not a real error. In the Supabase SQL editor, run:\n\n" +
  "create policy \"Admins can update orders\" on orders for update\n" +
  "using (exists (select 1 from profiles where profiles.id = auth.uid() and profiles.role = 'admin'))\n" +
  "with check (exists (select 1 from profiles where profiles.id = auth.uid() and profiles.role = 'admin'));\n\n" +
  "create policy \"Admins can delete orders\" on orders for delete\n" +
  "using (exists (select 1 from profiles where profiles.id = auth.uid() and profiles.role = 'admin'));";

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

    // .select() after .update() makes Supabase return the rows it
    // actually changed. If RLS silently blocks the write, `error` is
    // null but `data` comes back empty — that's the case we need to
    // catch, because otherwise this looks like a successful save.
    const { data, error } = await supabase
      .from('orders')
      .update({ status })
      .eq('id', id)
      .select();

    if (error) {
      console.error(error);
      setOrders(previous);
      alert("Could not update this order's status — check the console.");
      return;
    }

    if (!data || data.length === 0) {
      console.error('Order status update affected 0 rows (likely blocked by RLS):', id, status);
      setOrders(previous);
      alert(RLS_HINT);
      return;
    }
  }

  async function deleteOrder(id: string) {
    if (!confirm('Delete this order? This cannot be undone.')) return;
    const previous = orders;
    setOrders((prev) => prev.filter((o) => o.id !== id));

    const { data, error } = await supabase.from('orders').delete().eq('id', id).select();

    if (error) {
      console.error(error);
      setOrders(previous);
      alert('Could not delete this order — check the console.');
      return;
    }

    if (!data || data.length === 0) {
      console.error('Order delete affected 0 rows (likely blocked by RLS):', id);
      setOrders(previous);
      alert(RLS_HINT);
      return;
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
__VKV_PATCH_EOF__
echo "  updated: components/AdminOrdersPanel.tsx"

echo ""
echo "=============================================================="
echo "REQUIRED — run this in the Supabase SQL editor now:"
echo "=============================================================="
echo ""
echo "create policy \"Admins can update orders\" on orders for update"
echo "using (exists (select 1 from profiles where profiles.id = auth.uid() and profiles.role = 'admin'))"
echo "with check (exists (select 1 from profiles where profiles.id = auth.uid() and profiles.role = 'admin'));"
echo ""
echo "create policy \"Admins can delete orders\" on orders for delete"
echo "using (exists (select 1 from profiles where profiles.id = auth.uid() and profiles.role = 'admin'));"
echo ""
echo "If either policy already exists under a different name and errors"
echo "out with 'policy already exists', that's fine — check its USING"
echo "clause actually matches an admin role check like the one above."
echo ""
echo "Also add both policies to supabase/full-schema.sql yourself, since"
echo "I don't have that file, so a fresh database setup includes them."
echo "=============================================================="
echo ""
echo "Done. git add -A && git commit -m \"Surface silent RLS failures on order status update/delete\" && git push"