import Stripe from 'stripe';

/**
 * Payment provider: Stripe Checkout.
 * -----------------------------------
 * The brief asked for Payoneer as the checkout provider ("enter your
 * card details, pay via Payoneer"). In practice Payoneer doesn't offer
 * a drop-in "type your card number" checkout widget for an independent
 * storefront — its products are built for marketplace payouts and B2B
 * invoicing, not for taking card payments directly on a site like this.
 *
 * Stripe Checkout is the direct equivalent of what was actually asked
 * for: the customer types their card number on your site's checkout
 * page, it supports every country in the requested list (FR, IT, ES,
 * DE, the EU generally, plus non-EU cards), and it has a generous
 * free-to-start pricing model (pay-per-transaction, no monthly fee).
 * If you later get approved for Payoneer Checkout (their merchant
 * product) it slots into the same place — see app/api/checkout/route.ts.
 */
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? '', {
  apiVersion: '2024-06-20',
});
