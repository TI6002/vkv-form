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
