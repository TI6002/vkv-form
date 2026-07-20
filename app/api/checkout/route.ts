import { NextResponse } from 'next/server';
import { stripe } from '@/lib/stripe';
import type { CartLine } from '@/lib/types';

export async function POST(req: Request) {
  try {
    const { lines }: { lines: CartLine[] } = await req.json();

    if (!lines || lines.length === 0) {
      return NextResponse.json({ error: 'Cart is empty' }, { status: 400 });
    }

    const origin = req.headers.get('origin') ?? process.env.NEXT_PUBLIC_SITE_URL;

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
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
      success_url: `${origin}/account?checkout=success`,
      cancel_url: `${origin}/?checkout=cancelled`,
      metadata: {
        cart: JSON.stringify(
          lines.map((l) => ({ id: l.productId, qty: l.quantity }))
        ),
      },
    });

    return NextResponse.json({ url: session.url });
  } catch (err) {
    console.error('Checkout error:', err);
    return NextResponse.json({ error: 'Could not create checkout session' }, { status: 500 });
  }
}
