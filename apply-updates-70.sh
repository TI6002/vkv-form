#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — live order status updates on the account page..."

mkdir -p "components"
cat > "components/AccountOrdersLive.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { OrderCard } from './OrderCard';
import { Reveal } from './Reveal';
import type { Order } from '@/lib/types';

/**
 * Renders the "Active orders" / "Past orders" sections on /account and
 * keeps them in sync in real time. If an admin changes an order's
 * status in /admin (e.g. Pending → Cancelled, or Paid → Shipped) while
 * the customer has this page open, the order moves between sections
 * immediately — no page refresh needed.
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
}: {
  userId: string;
  locale: string;
  initialOrders: Order[];
  activeOrdersTitle: string;
  pastOrdersTitle: string;
  noOrdersText: string;
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

  const activeOrders = orders.filter((o) => o.status === 'pending' || o.status === 'paid');
  const pastOrders = orders.filter((o) => o.status === 'shipped' || o.status === 'cancelled');

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
            <p className="mt-6 font-body text-stone">{noOrdersText}</p>
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
echo "  created: components/AccountOrdersLive.tsx"

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
              Cancelled or Shipped), it moves between these sections
              immediately, no refresh needed. */}
          <AccountOrdersLive
            userId={user.id}
            locale={locale}
            initialOrders={orders}
            activeOrdersTitle={t('activeOrdersTitle')}
            pastOrdersTitle={t('pastOrdersTitle')}
            noOrdersText={t('noActiveOrders')}
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

echo ""
echo "IMPORTANT — one-time setup in Supabase, if not already done for 'orders':"
echo "  Run this in the Supabase SQL editor:"
echo "    alter publication supabase_realtime add table orders;"
echo "  (Or: Dashboard -> Database -> Replication -> enable the 'orders' table.)"
echo "  Without this, order status will still update on next page load, just not instantly."
echo ""
echo "Done. git add -A && git commit -m \"Live order status updates on account page via Realtime\" && git push"