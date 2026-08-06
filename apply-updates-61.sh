#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — itemized order display on account page and admin panel..."

mkdir -p "app/[locale]/account"
cat > "app/[locale]/account/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/server';
import { AuthForm } from '@/components/AuthForm';
import { SignOutButton } from '@/components/SignOutButton';
import { OrderCard } from '@/components/OrderCard';
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

  if (user) {
    const [{ data: orderRows }, { data: favoriteRows }] = await Promise.all([
      supabase.from('orders').select('*').eq('user_id', user.id).order('created_at', { ascending: false }),
      supabase
        .from('favorites')
        .select('*, products(*)')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false }),
    ]);
    orders = (orderRows as Order[]) ?? [];
    favorites = (favoriteRows as Favorite[]) ?? [];
  }

  const activeOrders = orders.filter((o) => o.status === 'pending' || o.status === 'paid');
  const pastOrders = orders.filter((o) => o.status === 'shipped' || o.status === 'cancelled');

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
            <h1 className="font-display text-4xl italic text-ink md:text-5xl">{t('title')}</h1>
            <SignOutButton />
          </div>

          <Reveal>
            <div className="bg-white p-8">
              <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {t('activeOrdersTitle')}
              </p>
              {activeOrders.length === 0 ? (
                <p className="mt-6 font-body text-stone">{t('noActiveOrders')}</p>
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
                {t('pastOrdersTitle')}
              </p>
              {pastOrders.length === 0 ? (
                <p className="mt-6 font-body text-stone">
                  {t('noActiveOrders') /* reused: "no orders yet" copy */}
                </p>
              ) : (
                <div className="mt-6 flex flex-col gap-4">
                  {pastOrders.map((order) => (
                    <OrderCard key={order.id} order={order} locale={locale} />
                  ))}
                </div>
              )}
            </div>
          </Reveal>

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

mkdir -p "components"
cat > "components/AdminOrdersPanel.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { OrderCard } from './OrderCard';
import type { Order } from '@/lib/types';

const STATUSES: Order['status'][] = ['pending', 'paid', 'shipped', 'cancelled'];

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

  if (loading) return <p className="mt-6 font-body text-stone">Loading…</p>;

  if (orders.length === 0) {
    return <p className="mt-6 font-body text-stone">No orders yet.</p>;
  }

  return (
    <div className="mt-6 flex flex-col gap-5">
      {orders.map((order) => (
        <div key={order.id} className="relative">
          <OrderCard order={order} />
          <div className="mt-2 flex items-center gap-3 border border-t-0 border-line bg-cream px-5 py-3">
            <span className="font-mono text-[11px] uppercase tracking-widest2 text-taupe">
              {order.email}
            </span>
            <div className="ml-auto flex items-center gap-2">
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
          </div>
        </div>
      ))}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/AdminOrdersPanel.tsx"

echo "Done. git add -A && git commit -m \"Wire up itemized order display\" && git push"