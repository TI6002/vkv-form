#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates (round 10 — profile page layout)..."

mkdir -p "app/[locale]/account"
cat > "app/[locale]/account/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/server';
import { AuthForm } from '@/components/AuthForm';
import { SignOutButton } from '@/components/SignOutButton';
import { Reveal } from '@/components/Reveal';
import { Link } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';
import type { Order, Favorite } from '@/lib/types';

export default async function AccountPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('account');

  let user = null;
  let orders: Order[] = [];
  let favorites: Favorite[] = [];
  let isAdmin = false;

  try {
    const supabase = createClient();
    const {
      data: { user: sessionUser },
    } = await supabase.auth.getUser();
    user = sessionUser;

    if (user) {
      const [{ data: orderData }, { data: profile }, { data: favData }] = await Promise.all([
        supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', user.id)
          .order('created_at', { ascending: false }),
        supabase.from('profiles').select('role').eq('id', user.id).single(),
        supabase
          .from('favorites')
          .select('*, products(*)')
          .eq('user_id', user.id)
          .order('created_at', { ascending: false }),
      ]);
      orders = (orderData as Order[]) ?? [];
      isAdmin = profile?.role === 'admin';
      favorites = (favData as Favorite[]) ?? [];
    }
  } catch {
    // Supabase not configured yet — show the sign-in form as a preview.
  }

  const activeOrders = orders.filter((o) => o.status === 'pending' || o.status === 'paid');
  const pastOrders = orders.filter((o) => o.status === 'shipped' || o.status === 'cancelled');

  return (
    <div className="mx-auto max-w-[1100px] px-6 py-20 md:px-10 md:py-28">
      {!user ? (
        <Reveal>
          <AuthForm />
        </Reveal>
      ) : (
        <div className="flex flex-col gap-8">
          {/* Page header — not a card, just the top bar */}
          <Reveal>
            <div className="flex flex-wrap items-center justify-between gap-4">
              <h1 className="font-display text-3xl text-ink">{t('ordersTitle')}</h1>
              <div className="flex items-center gap-5">
                {isAdmin && (
                  <Link
                    href="/admin"
                    className="border border-ink px-5 py-2.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream"
                  >
                    Open studio admin →
                  </Link>
                )}
                <SignOutButton />
              </div>
            </div>
          </Reveal>

          {/* Active orders — its own block */}
          <Reveal delay={0.05}>
            <section className="border border-line bg-white p-7 md:p-9">
              <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {t('activeOrdersTitle')}
              </h2>
              {activeOrders.length === 0 ? (
                <p className="mt-4 font-body text-sm text-stone">{t('noActiveOrders')}</p>
              ) : (
                <ul className="mt-5 divide-y divide-line">
                  {activeOrders.map((order) => (
                    <li key={order.id} className="py-5 first:pt-0 last:pb-0">
                      <div className="flex items-center justify-between">
                        <p className="font-body text-sm text-ink">
                          {t('orderNumber')} #{order.order_number}
                        </p>
                        <p className="font-mono text-sm text-ink">
                          {formatPrice(order.total_cents, order.currency)}
                        </p>
                      </div>
                      <p className="mt-1 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                        {t('orderStatus')}: {order.status}
                      </p>
                      {order.order_items && order.order_items.length > 0 && (
                        <ul className="mt-2 space-y-0.5">
                          {order.order_items.map((item) => (
                            <li key={item.id} className="font-body text-xs text-stone">
                              {item.quantity}× {item.product_name}
                            </li>
                          ))}
                        </ul>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </Reveal>

          {/* Order history — its own block */}
          <Reveal delay={0.1}>
            <section className="border border-line bg-paper p-7 md:p-9">
              <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {t('pastOrdersTitle')}
              </h2>
              {pastOrders.length === 0 ? (
                <p className="mt-4 font-body text-sm text-stone">{t('noOrders')}</p>
              ) : (
                <ul className="mt-5 divide-y divide-line">
                  {pastOrders.map((order) => (
                    <li key={order.id} className="flex items-center justify-between py-4 first:pt-0 last:pb-0">
                      <div>
                        <p className="font-body text-sm text-ink">
                          {t('orderNumber')} #{order.order_number}
                        </p>
                        <p className="mt-1 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                          {t('orderStatus')}: {order.status}
                        </p>
                      </div>
                      <p className="font-mono text-sm text-ink">
                        {formatPrice(order.total_cents, order.currency)}
                      </p>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </Reveal>

          {/* Saved items — its own block, cards styled exactly like the catalog grid */}
          <Reveal delay={0.15}>
            <section className="border border-line bg-white p-7 md:p-9">
              <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {t('savedTitle')}
              </h2>
              {favorites.length === 0 ? (
                <p className="mt-4 font-body text-sm text-stone">{t('noSaved')}</p>
              ) : (
                <div className="mt-6 grid grid-cols-2 gap-x-6 gap-y-10 sm:grid-cols-3 md:grid-cols-4">
                  {favorites.map(
                    (fav) =>
                      fav.products && (
                        <Link
                          key={fav.id}
                          href={`/catalog/${fav.products.slug}`}
                          className="group block"
                        >
                          <div className="relative aspect-[4/5] overflow-hidden bg-sand">
                            {fav.products.images?.[0] ? (
                              <Image
                                src={fav.products.images[0]}
                                alt={pickLocalized(fav.products.name, locale)}
                                fill
                                sizes="(min-width: 768px) 25vw, 50vw"
                                className="object-cover transition-transform duration-[1400ms] ease-signature group-hover:scale-[1.045]"
                              />
                            ) : (
                              <div className="flex h-full w-full items-center justify-center font-mono text-xs text-taupe">
                                No image
                              </div>
                            )}
                          </div>
                          <div className="mt-4 flex items-baseline justify-between">
                            <h3 className="font-display text-lg text-ink">
                              {pickLocalized(fav.products.name, locale)}
                            </h3>
                            <span className="font-mono text-sm text-stone">
                              {formatPrice(fav.products.price_cents, fav.products.currency)}
                            </span>
                          </div>
                        </Link>
                      )
                  )}
                </div>
              )}
            </section>
          </Reveal>
        </div>
      )}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/account/page.tsx"

echo "Done. Restart npm run dev after this."