#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — live-refresh Saved items on the account page..."

mkdir -p "components"
cat > "components/AccountFavoritesLive.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/client';
import { Link } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';
import type { Favorite } from '@/lib/types';

const POLL_INTERVAL_MS = 5000;

/**
 * Renders the "Saved items" grid on /account and keeps it in sync with
 * the database by polling every few seconds — the same approach used
 * for order status on this page. Liking/unliking a product from the
 * catalog is a separate page (and possibly a page the router already
 * cached from an earlier visit), so this page's server-rendered data
 * can otherwise sit stale until a manual refresh; polling fixes that
 * without depending on any extra Supabase Realtime setup.
 */
export function AccountFavoritesLive({
  userId,
  locale,
  initialFavorites,
  savedTitle,
  noSavedText,
}: {
  userId: string;
  locale: string;
  initialFavorites: Favorite[];
  savedTitle: string;
  noSavedText: string;
}) {
  const supabase = createClient();
  const [favorites, setFavorites] = useState<Favorite[]>(initialFavorites);

  useEffect(() => {
    let cancelled = false;

    async function refetch() {
      const { data, error } = await supabase
        .from('favorites')
        .select('*, products(*)')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });
      if (cancelled) return;
      if (error) {
        console.error('Could not refresh saved items:', error);
        return;
      }
      setFavorites((data as Favorite[]) ?? []);
    }

    // Refresh right away (covers "just navigated back to this page"),
    // then keep polling, and also refresh whenever the tab regains
    // focus so switching back to it feels instant.
    refetch();
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

  return (
    <div className="bg-white p-8">
      <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
        {savedTitle}
      </p>
      {favorites.length === 0 ? (
        <p className="mt-6 font-body text-stone">{noSavedText}</p>
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
  );
}
__VKV_PATCH_EOF__
echo "  created: components/AccountFavoritesLive.tsx"

mkdir -p "app/[locale]/account"
cat > "app/[locale]/account/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { createClient } from '@/lib/supabase/server';
import { AuthForm } from '@/components/AuthForm';
import { SignOutButton } from '@/components/SignOutButton';
import { AccountOrdersLive } from '@/components/AccountOrdersLive';
import { AccountFavoritesLive } from '@/components/AccountFavoritesLive';
import { Reveal } from '@/components/Reveal';
import { Link } from '@/lib/navigation';
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

          {/* Saved items also update live: liking/unliking a product on
              another page shows up here without needing a manual
              refresh of this page. */}
          <Reveal delay={0.1}>
            <AccountFavoritesLive
              userId={user.id}
              locale={locale}
              initialFavorites={favorites}
              savedTitle={t('savedTitle')}
              noSavedText={t('noSaved')}
            />
          </Reveal>
        </div>
      )}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/account/page.tsx"

echo ""
echo "Done. git add -A && git commit -m \"Live-refresh Saved items on account page\" && git push"