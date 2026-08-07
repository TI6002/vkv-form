#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — log the resolved site URL at checkout time..."

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

echo "Done. git add -A && git commit -m \"Log resolved site URL for debugging\" && git push"