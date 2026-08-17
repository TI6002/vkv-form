#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix implicit any in webhook map callback..."

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
        // Mark sold first — non-destructive, and this is what makes the
        // "out of stock" badge appear live (via Supabase Realtime) for
        // anyone who has the product's page open right now.
        const { error: availabilityError } = await supabase
          .from('products')
          .update({ available: false })
          .in('id', productIds);

        if (availabilityError) {
          console.error(
            'Stripe webhook: order saved, but failed to mark product(s) as sold:',
            productIds,
            availabilityError
          );
        }

        // Fetch the full product rows — need all their fields (name,
        // description, materials, dimensions, images) to carry over
        // into the Collection Book entry.
        const { data: soldProducts, error: fetchError } = await supabase
          .from('products')
          .select('*')
          .in('id', productIds);

        if (fetchError) {
          console.error(
            'Stripe webhook: order saved, but could not load sold product(s) to archive them:',
            productIds,
            fetchError
          );
        } else if (soldProducts && soldProducts.length > 0) {
          const soldYear = String(new Date().getFullYear());

          const collectionRows = soldProducts.map((p: any) => ({
            name: p.name,
            description: p.description,
            materials: p.materials,
            height: p.height,
            width: p.width,
            circumference: p.circumference,
            depth: p.depth,
            weight: p.weight,
            images: p.images,
            sold_year: soldYear,
          }));

          const { error: insertError } = await supabase
            .from('collection_items')
            .insert(collectionRows);

          if (insertError) {
            console.error(
              'Stripe webhook: order saved and product(s) marked sold, but failed to add to Collection Book:',
              productIds,
              insertError
            );
          }
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

echo "Done. git add -A && git commit -m \"Fix implicit any in webhook\" && git push"