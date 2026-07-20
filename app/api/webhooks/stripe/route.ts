import { NextResponse } from 'next/server';
import { stripe } from '@/lib/stripe';
import { createAdminClient } from '@/lib/supabase/admin';
import Stripe from 'stripe';

export async function POST(req: Request) {
  const body = await req.text();
  const signature = req.headers.get('stripe-signature');

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature!,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session;
    const supabase = createAdminClient();

    await supabase.from('orders').insert({
      email: session.customer_details?.email ?? 'unknown',
      status: 'paid',
      total_cents: session.amount_total ?? 0,
      currency: (session.currency ?? 'eur').toUpperCase(),
      stripe_session_id: session.id,
    });

    // Optionally decrement stock here by parsing session.metadata.cart.
  }

  return NextResponse.json({ received: true });
}
