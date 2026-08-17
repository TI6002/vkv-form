#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — mark products sold after purchase, clear cart, show sold badge on saved items..."

mkdir -p "app/api/webhooks/stripe"
cat > "app/api/webhooks/stripe/route.ts" << '__VKV_PATCH_EOF__'
import { NextResponse } from 'next/server';
import { headers } from 'next/headers';
import { stripe } from '@/lib/stripe';
import { createAdminClient } from '@/lib/supabase/admin';
import { sendNewOrderEmail } from '@/lib/resend';

/**
 * Stripe calls this the moment a checkout is completed. It's the only
 * reliable point at which we should mark an order "paid" — never trust
 * the browser's redirect back to /account for that, since a person can
 * close the tab before it loads, or the redirect can simply fail.
 */
export async function POST(req: Request) {
  const body = await req.text();
  const signature = headers().get('stripe-signature');
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!signature || !webhookSecret) {
    console.error('Stripe webhook: missing signature header or STRIPE_WEBHOOK_SECRET.');
    return NextResponse.json({ error: 'Webhook not configured' }, { status: 400 });
  }

  let event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
  } catch (err) {
    console.error('Stripe webhook: signature verification failed:', err);
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as import('stripe').default.Checkout.Session;

    try {
      const lineItems = await stripe.checkout.sessions.listLineItems(session.id, {
        limit: 100,
        expand: ['data.price.product'],
      });

      const items = lineItems.data.map((line) => ({
        name: line.description ?? 'Item',
        quantity: line.quantity ?? 1,
        amount_total: line.amount_total ?? 0,
      }));

      const customerDetails = session.customer_details
        ? {
            name: session.customer_details.name,
            phone: session.customer_details.phone,
            address: session.customer_details.address
              ? {
                  line1: session.customer_details.address.line1,
                  line2: session.customer_details.address.line2,
                  city: session.customer_details.address.city,
                  postal_code: session.customer_details.address.postal_code,
                  country: session.customer_details.address.country,
                }
              : null,
          }
        : null;

      const supabase = createAdminClient();
      const { data: order, error } = await supabase
        .from('orders')
        .insert({
          user_id: session.metadata?.user_id || null,
          email: session.customer_details?.email || session.customer_email || '',
          status: 'paid',
          total_cents: session.amount_total ?? 0,
          currency: (session.currency ?? 'eur').toUpperCase(),
          stripe_session_id: session.id,
          items,
          customer_details: customerDetails,
        })
        .select()
        .single();

      if (error) {
        console.error('Stripe webhook: failed to save order:', error);
        return NextResponse.json({ error: 'Failed to save order' }, { status: 500 });
      }

      await sendNewOrderEmail({
        order_number: order.order_number,
        email: order.email,
        total_cents: order.total_cents,
        currency: order.currency,
        items: order.items,
        customer_details: order.customer_details,
      });

      // Mark each purchased piece as sold. Every product here is a
      // one-of-a-kind handmade object — there's no "quantity in
      // stock" concept, so a completed purchase always means that
      // exact piece is gone. product_id was attached as metadata on
      // the ephemeral Stripe Product created from price_data at
      // checkout time (see /api/checkout), which is why price.product
      // needs to be expanded above to read it back here.
      const productIds = lineItems.data
        .map((line) => {
          const product = line.price?.product;
          if (product && typeof product === 'object' && 'metadata' in product) {
            return (product.metadata as Record<string, string>)?.product_id;
          }
          return undefined;
        })
        .filter((id): id is string => Boolean(id));

      if (productIds.length > 0) {
        const { error: availabilityError } = await supabase
          .from('products')
          .update({ available: false })
          .in('id', productIds);

        if (availabilityError) {
          // Don't fail the whole webhook over this — the order itself
          // is already saved and the customer already paid. Log it
          // loudly so it can be fixed manually in /admin if needed.
          console.error(
            'Stripe webhook: order saved, but failed to mark product(s) as sold:',
            productIds,
            availabilityError
          );
        }
      }
    } catch (err) {
      console.error('Stripe webhook: unexpected error while processing session:', err);
      return NextResponse.json({ error: 'Processing failed' }, { status: 500 });
    }
  }

  return NextResponse.json({ received: true });
}
__VKV_PATCH_EOF__
echo "  updated: app/api/webhooks/stripe/route.ts"

mkdir -p "app/api/checkout"
cat > "app/api/checkout/route.ts" << '__VKV_PATCH_EOF__'
import { NextResponse } from 'next/server';
import { stripe } from '@/lib/stripe';
import { createClient } from '@/lib/supabase/server';

type CartLine = {
  productId: string;
  slug: string;
  name: string;
  priceCents: number;
  image: string | null;
};

/**
 * Creates the Stripe Checkout Session and nothing else. The actual
 * order row is created exactly once, by the webhook, after Stripe
 * confirms payment succeeded — not here. Pre-creating a "pending" order
 * at this step used to risk ending up with duplicate or orphaned rows
 * (one created here, another from the webhook, or a stray "pending"
 * order left behind if someone abandons checkout) — removing that step
 * makes the webhook the single source of truth for what actually got
 * paid for.
 */
export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { lines, email } = body as {
      lines: CartLine[];
      email?: string;
    };

    if (!lines || lines.length === 0) {
      console.error('Checkout: cart is empty or malformed. Received body:', JSON.stringify(body));
      return NextResponse.json({ error: 'Cart is empty' }, { status: 400 });
    }

    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    // Every piece is one-of-a-kind — re-check availability right before
    // charging anyone, not just when it was added to the cart. Someone
    // could easily have this in their cart from a while ago, and it may
    // have sold to someone else in the meantime.
    const { data: freshProducts, error: availabilityCheckError } = await supabase
      .from('products')
      .select('id, name, available')
      .in(
        'id',
        lines.map((l) => l.productId)
      );

    if (availabilityCheckError) {
      console.error('Checkout: failed to verify product availability:', availabilityCheckError);
      return NextResponse.json({ error: 'Could not verify availability' }, { status: 500 });
    }

    const soldItems = (freshProducts ?? []).filter((p) => !p.available);
    if (soldItems.length > 0) {
      return NextResponse.json(
        {
          error: 'sold_out',
          soldProductIds: soldItems.map((p) => p.id),
        },
        { status: 409 }
      );
    }

    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000';
    console.log('Checkout: NEXT_PUBLIC_SITE_URL resolved to:', JSON.stringify(siteUrl));

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      customer_email: email || user?.email || undefined,
      line_items: lines.map((item) => ({
        quantity: 1,
        price_data: {
          currency: 'eur',
          unit_amount: item.priceCents,
          product_data: {
            name: item.name,
            images: item.image ? [item.image] : undefined,
            metadata: { product_id: item.productId, slug: item.slug },
          },
        },
      })),
      metadata: {
        user_id: user?.id || '',
      },
      success_url: `${siteUrl}/account?order=success`,
      cancel_url: `${siteUrl}/checkout`,
    });

    return NextResponse.json({ url: session.url });
  } catch (err) {
    console.error('Checkout session creation failed:', err);
    return NextResponse.json({ error: 'Could not start checkout' }, { status: 500 });
  }
}
__VKV_PATCH_EOF__
echo "  updated: app/api/checkout/route.ts"

mkdir -p "context"
cat > "context/CartContext.tsx" << '__VKV_PATCH_EOF__'
'use client';

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import type { CartLine } from '@/lib/types';

type CartContextValue = {
  lines: CartLine[];
  isOpen: boolean;
  openCart: () => void;
  closeCart: () => void;
  addItem: (line: Omit<CartLine, 'quantity'>, quantity?: number) => void;
  removeItem: (productId: string) => void;
  setQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
  subtotalCents: number;
  count: number;
};

const CartContext = createContext<CartContextValue | null>(null);
const STORAGE_KEY = 'vkv-form-cart';

export function CartProvider({ children }: { children: ReactNode }) {
  const [lines, setLines] = useState<CartLine[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [hydrated, setHydrated] = useState(false);

  // Load persisted cart once on mount (client only).
  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (raw) setLines(JSON.parse(raw));
    } catch {
      // ignore corrupt storage
    }
    setHydrated(true);
  }, []);

  // Persist on every change, after the initial load.
  useEffect(() => {
    if (!hydrated) return;
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(lines));
  }, [lines, hydrated]);

  const addItem: CartContextValue['addItem'] = (line, quantity = 1) => {
    setLines((prev) => {
      const existing = prev.find((l) => l.productId === line.productId);
      if (existing) {
        return prev.map((l) =>
          l.productId === line.productId
            ? { ...l, quantity: l.quantity + quantity }
            : l
        );
      }
      return [...prev, { ...line, quantity }];
    });
    setIsOpen(true);
  };

  const removeItem = (productId: string) =>
    setLines((prev) => prev.filter((l) => l.productId !== productId));

  const setQuantity = (productId: string, quantity: number) =>
    setLines((prev) =>
      quantity <= 0
        ? prev.filter((l) => l.productId !== productId)
        : prev.map((l) => (l.productId === productId ? { ...l, quantity } : l))
    );

  // Called once payment succeeds (see ClearCartOnSuccess), so a piece
  // that's just been bought doesn't linger in the cart — and, since
  // it's now sold, can't accidentally be "bought" again by re-checking
  // out with a stale cart.
  const clearCart = () => setLines([]);

  const subtotalCents = useMemo(
    () => lines.reduce((sum, l) => sum + l.priceCents * l.quantity, 0),
    [lines]
  );
  const count = useMemo(
    () => lines.reduce((sum, l) => sum + l.quantity, 0),
    [lines]
  );

  return (
    <CartContext.Provider
      value={{
        lines,
        isOpen,
        openCart: () => setIsOpen(true),
        closeCart: () => setIsOpen(false),
        addItem,
        removeItem,
        setQuantity,
        clearCart,
        subtotalCents,
        count,
      }}
    >
      {children}
    </CartContext.Provider>
  );
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used within a CartProvider');
  return ctx;
}
__VKV_PATCH_EOF__
echo "  updated: context/CartContext.tsx"

mkdir -p "components"
cat > "components/ClearCartOnSuccess.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { useCart } from '@/context/CartContext';

/**
 * Renders nothing — just watches for ?order=success (set by the
 * Stripe success_url after a completed payment) and clears the cart
 * once. Without this, a bought item could sit in the browser's
 * localStorage cart and look purchasable again later, even though the
 * webhook already marked it sold.
 */
export function ClearCartOnSuccess() {
  const searchParams = useSearchParams();
  const { clearCart } = useCart();

  useEffect(() => {
    if (searchParams.get('order') === 'success') {
      clearCart();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return null;
}
__VKV_PATCH_EOF__
echo "  updated: components/ClearCartOnSuccess.tsx"

mkdir -p "app/[locale]/account"
cat > "app/[locale]/account/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/server';
import { AuthForm } from '@/components/AuthForm';
import { SignOutButton } from '@/components/SignOutButton';
import { OrderCard } from '@/components/OrderCard';
import { ClearCartOnSuccess } from '@/components/ClearCartOnSuccess';
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
          <ClearCartOnSuccess />
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
                    const sold = !product.available;
                    return (
                      <Link
                        key={fav.id}
                        href={`/catalog/${product.slug}`}
                        className="group block"
                      >
                        <div className="relative aspect-[4/5] overflow-hidden bg-sand">
                          {product.images?.[0] && (
                            <Image
                              src={product.images[0]}
                              alt={name}
                              fill
                              sizes="(min-width: 768px) 20vw, 33vw"
                              className={`object-cover transition-transform duration-700 ${
                                sold ? 'grayscale' : 'group-hover:scale-105'
                              }`}
                            />
                          )}
                          {sold && (
                            <span className="absolute left-2 top-2 bg-cream/90 px-2.5 py-1 font-mono text-[10px] uppercase tracking-widest2 text-ink">
                              Sold
                            </span>
                          )}
                        </div>
                        <p className="mt-3 font-body text-sm text-ink">{name}</p>
                        {sold ? (
                          <p className="font-mono text-xs text-taupe">No longer available</p>
                        ) : (
                          <p className="font-mono text-xs text-stone">
                            {formatPrice(product.price_cents, product.currency)}
                          </p>
                        )}
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

echo "Done. git add -A && git commit -m \"Mark products sold after purchase, clear cart, show sold badge\" && git push"