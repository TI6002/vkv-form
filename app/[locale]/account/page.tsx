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
