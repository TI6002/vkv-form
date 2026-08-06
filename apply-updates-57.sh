#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — Stripe webhook, new-order email, itemized order display..."

mkdir -p "lib/supabase"
cat > "lib/supabase/admin.ts" << '__VKV_PATCH_EOF__'
import { createClient as createSupabaseClient } from '@supabase/supabase-js';

/**
 * Admin (service-role) Supabase client — bypasses RLS entirely. Used
 * only in trusted server-side code like the Stripe webhook, which needs
 * to write an order row without a signed-in user's session (Stripe
 * calls this endpoint directly, there's no browser session involved).
 * Never import this into anything that runs in the browser.
 */
let _admin: ReturnType<typeof createSupabaseClient> | null = null;

export function createAdminClient() {
  if (_admin) return _admin;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error(
      'NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set.'
    );
  }

  _admin = createSupabaseClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return _admin;
}
__VKV_PATCH_EOF__
echo "  updated: lib/supabase/admin.ts"

mkdir -p "lib"
cat > "lib/resend.ts" << '__VKV_PATCH_EOF__'
import { Resend } from 'resend';

let _resend: Resend | null = null;

function getResend(): Resend {
  if (_resend) return _resend;
  const key = process.env.RESEND_API_KEY;
  if (!key) throw new Error('RESEND_API_KEY is not set.');
  _resend = new Resend(key);
  return _resend;
}

type OrderForEmail = {
  order_number: number;
  email: string;
  total_cents: number;
  currency: string;
  items: { name: string; quantity: number; amount_total: number }[];
  customer_details?: {
    name?: string | null;
    phone?: string | null;
    address?: Record<string, string | null> | null;
  } | null;
};

function formatMoney(cents: number, currency: string) {
  return new Intl.NumberFormat('en-GB', {
    style: 'currency',
    currency: currency.toUpperCase(),
  }).format(cents / 100);
}

/**
 * Notifies the studio inbox (CONTACT_EMAIL) whenever a new order comes
 * in. Failing to send this should never break the checkout flow itself
 * — the order is already saved in the database either way — so errors
 * here are only logged, never thrown back up to the caller.
 *
 * Note: sends from Resend's default onboarding@resend.dev address until
 * a real sending domain is verified in the Resend dashboard. That's
 * fine for getting notifications working now; verifying vkvform.com in
 * Resend later lets this send from an address on that domain instead.
 */
export async function sendNewOrderEmail(order: OrderForEmail) {
  const to = process.env.CONTACT_EMAIL;
  if (!to) {
    console.warn('CONTACT_EMAIL is not set — skipping new-order email.');
    return;
  }

  const itemLines = order.items
    .map((item) => `  • ${item.name} × ${item.quantity} — ${formatMoney(item.amount_total, order.currency)}`)
    .join('\n');

  const addressLine = order.customer_details?.address
    ? Object.values(order.customer_details.address).filter(Boolean).join(', ')
    : '';

  const text = [
    `New order #${order.order_number}`,
    '',
    `Customer: ${order.customer_details?.name || order.email}`,
    `Email: ${order.email}`,
    order.customer_details?.phone ? `Phone: ${order.customer_details.phone}` : '',
    addressLine ? `Address: ${addressLine}` : '',
    '',
    'Items:',
    itemLines,
    '',
    `Total: ${formatMoney(order.total_cents, order.currency)}`,
  ]
    .filter(Boolean)
    .join('\n');

  try {
    await getResend().emails.send({
      from: 'vkv.form orders <onboarding@resend.dev>',
      to,
      subject: `New order #${order.order_number} — ${formatMoney(order.total_cents, order.currency)}`,
      text,
    });
  } catch (err) {
    console.error('Failed to send new-order notification email:', err);
  }
}
__VKV_PATCH_EOF__
echo "  updated: lib/resend.ts"

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
    } catch (err) {
      console.error('Stripe webhook: unexpected error while processing session:', err);
      return NextResponse.json({ error: 'Processing failed' }, { status: 500 });
    }
  }

  return NextResponse.json({ received: true });
}
__VKV_PATCH_EOF__
echo "  updated: app/api/webhooks/stripe/route.ts"

mkdir -p "components"
cat > "components/OrderCard.tsx" << '__VKV_PATCH_EOF__'
import type { Order } from '@/lib/types';

const STATUS_LABEL: Record<Order['status'], string> = {
  pending: 'Pending payment',
  paid: 'Paid',
  shipped: 'Shipped',
  cancelled: 'Cancelled',
};

const STATUS_COLOR: Record<Order['status'], string> = {
  pending: 'text-taupe',
  paid: 'text-ink',
  shipped: 'text-stone',
  cancelled: 'text-red-800',
};

function formatMoney(cents: number, currency: string) {
  return new Intl.NumberFormat('en-GB', {
    style: 'currency',
    currency: (currency || 'EUR').toUpperCase(),
  }).format(cents / 100);
}

/**
 * Shows a full order — what was actually bought, not just a bare
 * "Order #3" — used on the account page and in the admin orders panel.
 */
export function OrderCard({ order, locale = 'en' }: { order: Order; locale?: string }) {
  const items = order.items ?? [];

  return (
    <div className="border border-line p-5">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <p className="font-mono text-[11px] uppercase tracking-widest2 text-ink">
            Order #{order.order_number}
          </p>
          <p className="mt-1 font-mono text-[11px] text-taupe">
            {new Date(order.created_at).toLocaleDateString(locale, {
              year: 'numeric',
              month: 'long',
              day: 'numeric',
            })}
          </p>
        </div>
        <span
          className={`font-mono text-[11px] uppercase tracking-widest2 ${STATUS_COLOR[order.status]}`}
        >
          {STATUS_LABEL[order.status]}
        </span>
      </div>

      {items.length > 0 && (
        <ul className="mt-4 flex flex-col gap-1.5 border-t border-line pt-4">
          {items.map((item, i) => (
            <li key={i} className="flex justify-between gap-4 font-body text-sm text-ink">
              <span>
                {item.name}
                {item.quantity > 1 ? ` × ${item.quantity}` : ''}
              </span>
              <span className="shrink-0 text-stone">
                {formatMoney(item.amount_total, order.currency)}
              </span>
            </li>
          ))}
        </ul>
      )}

      <div className="mt-4 flex justify-between border-t border-line pt-4">
        <span className="font-mono text-[11px] uppercase tracking-widest2 text-taupe">
          Total
        </span>
        <span className="font-mono text-sm text-ink">
          {formatMoney(order.total_cents, order.currency)}
        </span>
      </div>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/OrderCard.tsx"

echo "Done."