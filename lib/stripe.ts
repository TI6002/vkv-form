import Stripe from 'stripe';

/**
 * Lazy Stripe client, exposed as the same `stripe` export other files
 * already import — but the real Stripe instance isn't constructed until
 * the first time it's actually used, not the moment this file loads.
 *
 * Why this matters: Next.js "collects page data" for every API route
 * during the production build, which imports this file. Constructing
 * `new Stripe(...)` at the top level throws immediately if
 * STRIPE_SECRET_KEY looks missing/empty in that specific build step,
 * which fails the entire build — even though the key is set correctly
 * for the app at runtime. Deferring construction avoids that entirely.
 */
let _instance: Stripe | null = null;

function getInstance(): Stripe {
  if (_instance) return _instance;

  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) {
    throw new Error(
      'STRIPE_SECRET_KEY is not set — add it to your environment variables.'
    );
  }

  // No apiVersion pinned on purpose — the Stripe SDK's TypeScript types
  // require this to match a specific literal tied to the installed
  // package version exactly, which broke the build when the installed
  // version didn't match. Omitting it just uses the account's default
  // API version, which is simpler and won't drift out of sync again.
  _instance = new Stripe(key);
  return _instance;
}

export const stripe: Stripe = new Proxy({} as Stripe, {
  get(_target, prop, receiver) {
    const real = getInstance();
    const value = Reflect.get(real, prop, receiver);
    return typeof value === 'function' ? value.bind(real) : value;
  },
});
