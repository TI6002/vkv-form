#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — add 'delivered' status, admin delete order, fix empty-history text..."

# --- 1. Add 'delivered' to the Order status union type wherever it's declared ---
FILES_WITH_STATUS_TYPE=$(grep -rl "'shipped' | 'cancelled'" --include="*.ts" --include="*.tsx" . 2>/dev/null || true)
if [ -z "$FILES_WITH_STATUS_TYPE" ]; then
  echo "WARNING: could not find \"'shipped' | 'cancelled'\" in any .ts/.tsx file."
  echo "  Open lib/types.ts yourself and add 'delivered' to the Order status union, e.g.:"
  echo "    status: 'pending' | 'paid' | 'shipped' | 'delivered' | 'cancelled';"
else
  echo "$FILES_WITH_STATUS_TYPE" | while IFS= read -r f; do
    sed -i "s/'shipped' | 'cancelled'/'shipped' | 'delivered' | 'cancelled'/g" "$f"
    echo "  updated status type in: $f"
  done
fi

# --- 2. AdminOrdersPanel: add 'delivered' to the status dropdown + a Delete button ---
mkdir -p "components"
cat > "components/AdminOrdersPanel.tsx" << '__VKV_PATCH_EOF__'
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
__VKV_PATCH_EOF__
echo "  updated: components/AdminOrdersPanel.tsx"

# --- 3. AccountOrdersLive: shipped stays "active", delivered/cancelled are "history", separate empty-history text ---
cat > "components/AccountOrdersLive.tsx" << '__VKV_PATCH_EOF__'
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
__VKV_PATCH_EOF__
echo "  updated: components/AccountOrdersLive.tsx"

# --- 4. Account page: pass the separate "history is empty" text ---
mkdir -p "app/[locale]/account"
cat > "app/[locale]/account/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/server';
import { AuthForm } from '@/components/AuthForm';
import { SignOutButton } from '@/components/SignOutButton';
import { AccountOrdersLive } from '@/components/AccountOrdersLive';
import { Reveal } from '@/components/Reveal';
import { Link } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';
import type { Order, Favorite } from '@/lib/types';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function AccountPage({
  params: { locale },
  searchParams,
}: {
  params: { locale: string };
  searchParams: { [key: string]: string | string[] | undefined };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('account');
  const authRequired = searchParams?.authRequired === '1';

  const supabase = createClient();
  let user = null;
  try {
    const {
      data: { user: authUser },
    } = await supabase.auth.getUser();
    user = authUser;
  } catch {
    user = null;
  }

  let orders: Order[] = [];
  let favorites: Favorite[] = [];
  let isAdmin = false;

  if (user) {
    const [{ data: orderRows }, { data: favoriteRows }, { data: profileRow }] = await Promise.all([
      supabase.from('orders').select('*').eq('user_id', user.id).order('created_at', { ascending: false }),
      supabase
        .from('favorites')
        .select('*, products(*)')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false }),
      supabase.from('profiles').select('role').eq('id', user.id).single(),
    ]);
    orders = (orderRows as Order[]) ?? [];
    favorites = (favoriteRows as Favorite[]) ?? [];
    isAdmin = profileRow?.role === 'admin';
  }

  return (
    <div className="mx-auto max-w-[1100px] px-6 py-20 md:px-10 md:py-28">
      {!user ? (
        <Reveal>
          {authRequired && (
            <p className="mb-8 max-w-sm border border-cocoa/40 bg-cocoa/5 px-5 py-4 font-body text-sm text-cocoa">
              {t('signInRequired')}
            </p>
          )}
          <AuthForm />
        </Reveal>
      ) : (
        <div className="flex flex-col gap-8">
          <div className="flex items-center justify-between">
            <h1 className="font-display text-4xl italic text-ink md:text-5xl">{t('ordersTitle')}</h1>
            <div className="flex items-center gap-6">
              {isAdmin && (
                <Link
                  href="/admin"
                  className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
                >
                  Open studio admin
                </Link>
              )}
              <SignOutButton />
            </div>
          </div>

          {/* Active + past orders update live: if an admin changes an
              order's status while this page is open (e.g. marks it
              Delivered or Cancelled), it moves between these sections
              immediately, no refresh needed. */}
          <AccountOrdersLive
            userId={user.id}
            locale={locale}
            initialOrders={orders}
            activeOrdersTitle={t('activeOrdersTitle')}
            pastOrdersTitle={t('pastOrdersTitle')}
            noOrdersText={t('noActiveOrders')}
            noPastOrdersText={t('noPastOrders')}
          />

          <Reveal delay={0.1}>
            <div className="bg-white p-8">
              <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {t('savedTitle')}
              </p>
              {favorites.length === 0 ? (
                <p className="mt-6 font-body text-stone">{t('noSaved')}</p>
              ) : (
                <div className="mt-8 grid grid-cols-2 gap-x-6 gap-y-10 sm:grid-cols-3">
                  {favorites.map((fav) => {
                    const product = fav.products;
                    if (!product) return null;
                    const name = pickLocalized(product.name, locale);
                    return (
                      <Link key={fav.id} href={`/catalog/${product.slug}`} className="group block">
                        <div className="relative aspect-[4/5] overflow-hidden bg-sand">
                          {product.images?.[0] && (
                            <Image
                              src={product.images[0]}
                              alt={name}
                              fill
                              sizes="(min-width: 768px) 20vw, 33vw"
                              className="object-cover transition-transform duration-700 group-hover:scale-105"
                            />
                          )}
                        </div>
                        <p className="mt-3 font-body text-sm text-ink">{name}</p>
                        <p className="font-mono text-xs text-stone">
                          {formatPrice(product.price_cents, product.currency)}
                        </p>
                      </Link>
                    );
                  })}
                </div>
              )}
            </div>
          </Reveal>
        </div>
      )}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/account/page.tsx"

# --- 5. Add the "noPastOrders" translation key to all 7 locale files ---
add_key() {
  file="$1"
  match="$2"
  insert="$3"
  if [ ! -f "$file" ]; then
    echo "  WARNING: $file not found — skipped."
    return
  fi
  if grep -qF "$match" "$file"; then
    sed -i "/$(printf '%s' "$match" | sed -e 's/[\/&]/\\&/g')/a\\    $insert" "$file"
    echo "  updated: $file"
  else
    echo "  WARNING: could not find matching line in $file — add manually:"
    echo "    $insert"
  fi
}

add_key "messages/en.json" '"pastOrdersTitle": "Order history",' '"noPastOrders": "Your order history is empty.",'
add_key "messages/ru.json" '"pastOrdersTitle": "История заказов",' '"noPastOrders": "История заказов пуста.",'
add_key "messages/de.json" '"pastOrdersTitle": "Bestellverlauf",' '"noPastOrders": "Ihr Bestellverlauf ist leer.",'
add_key "messages/es.json" '"pastOrdersTitle": "Historial de pedidos",' '"noPastOrders": "Tu historial de pedidos está vacío.",'
add_key "messages/fr.json" '"pastOrdersTitle": "Historique des commandes",' '"noPastOrders": "Votre historique de commandes est vide.",'
add_key "messages/it.json" '"pastOrdersTitle": "Storico ordini",' '"noPastOrders": "Lo storico dei tuoi ordini è vuoto.",'
add_key "messages/lv.json" '"pastOrdersTitle": "Pasūtījumu vēsture",' '"noPastOrders": "Jūsu pasūtījumu vēsture ir tukša.",'

echo ""
echo "IMPORTANT — double-check after running:"
echo "  1. Open lib/types.ts and confirm the Order status type now includes 'delivered'."
echo "  2. Open each messages/*.json and confirm the JSON is still valid (the sed insert is line-based;"
echo "     if a WARNING was printed above for any file, add that line manually)."
echo ""
echo "Done. git add -A && git commit -m \"Add delivered status, admin delete order, fix empty order-history text\" && git push"