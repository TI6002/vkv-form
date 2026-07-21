import { NextResponse } from 'next/server';
import { stripe } from '@/lib/stripe';
import { createClient } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import type { CartLine } from '@/lib/types';

export async function POST(req: Request) {
  try {
    const { lines, email }: { lines: CartLine[]; email?: string } = await req.json();

    if (!lines || lines.length === 0) {
      return NextResponse.json({ error: 'Cart is empty' }, { status: 400 });
    }

    const totalCents = lines.reduce((sum, l) => sum + l.priceCents * l.quantity, 0);

    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const customerEmail = email || user?.email || '';

    const admin = createAdminClient();

    const { data: order, error: orderError } = await admin
      .from('orders')
      .insert({
        user_id: user?.id ?? null,
        email: customerEmail,
        status: 'pending',
        total_cents: totalCents,
        currency: 'EUR',
      })
      .select()
      .single();

    if (orderError || !order) {
      console.error('Order creation error:', orderError);
      return NextResponse.json({ error: 'Could not create order' }, { status: 500 });
    }

    const { error: itemsError } = await admin.from('order_items').insert(
      lines.map((line) => ({
        order_id: order.id,
        product_id: line.productId,
        product_name: line.name,
        quantity: line.quantity,
        unit_price_cents: line.priceCents,
      }))
    );

    if (itemsError) {
      console.error('Order items creation error:', itemsError);
      return NextResponse.json({ error: 'Could not create order' }, { status: 500 });
    }

    const origin = req.headers.get('origin') ?? process.env.NEXT_PUBLIC_SITE_URL;

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      customer_email: customerEmail || undefined,
      line_items: lines.map((line) => ({
        price_data: {
          currency: 'eur',
          product_data: {
            name: line.name,
            images: line.image ? [line.image] : undefined,
          },
          unit_amount: line.priceCents,
        },
        quantity: line.quantity,
      })),
      shipping_address_collection: {
        allowed_countries: ['FR', 'IT', 'ES', 'DE', 'LV', 'IE', 'PT', 'NL', 'BE', 'AT', 'LT', 'EE'],
      },
      success_url: `${origin}/account?checkout=success&order=${order.order_number}`,
      cancel_url: `${origin}/checkout?checkout=cancelled`,
      client_reference_id: user?.id,
      metadata: { order_id: order.id },
    });

    await admin.from('orders').update({ stripe_session_id: session.id }).eq('id', order.id);

    return NextResponse.json({ url: session.url, orderId: order.id });
  } catch (err) {
    console.error('Checkout error:', err);
    return NextResponse.json({ error: 'Could not create checkout session' }, { status: 500 });
  }
}