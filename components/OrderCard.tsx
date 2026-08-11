import type { Order } from '@/lib/types';

const STATUS_LABEL: Record<Order['status'], string> = {
  pending: 'Pending payment',
  paid: 'Paid',
  shipped: 'Shipped',
  delivered: 'Delivered',
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
