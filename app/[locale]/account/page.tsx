import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { createClient } from '@/lib/supabase/server';
import { AuthForm } from '@/components/AuthForm';
import { SignOutButton } from '@/components/SignOutButton';
import { Reveal } from '@/components/Reveal';
import { Link } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';
import type { Order } from '@/lib/types';

export default async function AccountPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('account');

  let user = null;
  let orders: Order[] = [];
  let isAdmin = false;

  try {
    const supabase = createClient();
    const {
      data: { user: sessionUser },
    } = await supabase.auth.getUser();
    user = sessionUser;

    if (user) {
      const [{ data: orderData }, { data: profile }] = await Promise.all([
        supabase
          .from('orders')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', { ascending: false }),
        supabase.from('profiles').select('role').eq('id', user.id).single(),
      ]);
      orders = (orderData as Order[]) ?? [];
      isAdmin = profile?.role === 'admin';
    }
  } catch {
    // Supabase not configured yet — show the sign-in form as a preview.
  }

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
      {!user ? (
        <Reveal>
          <AuthForm />
        </Reveal>
      ) : (
        <Reveal>
          <div className="flex items-center justify-between">
            <h1 className="font-display text-3xl text-ink">{t('ordersTitle')}</h1>
            <SignOutButton />
          </div>

          {isAdmin && (
            <Link
              href="/admin"
              className="mt-6 inline-block border border-ink px-6 py-3 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream"
            >
              Open studio admin →
            </Link>
          )}

          {orders.length === 0 ? (
            <p className="mt-10 font-body text-stone">{t('noOrders')}</p>
          ) : (
            <ul className="mt-10 divide-y divide-line border-t border-line">
              {orders.map((order) => (
                <li key={order.id} className="flex items-center justify-between py-5">
                  <div>
                    <p className="font-body text-sm text-ink">
                      {t('orderNumber')} #{order.id.slice(0, 8)}
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
        </Reveal>
      )}
    </div>
  );
}