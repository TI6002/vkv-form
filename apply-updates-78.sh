#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix CartDrawer field names (lines, not items)..."

mkdir -p "components"
cat > "components/CartDrawer.tsx" << '__VKV_PATCH_EOF__'
'use client';

import Image from 'next/image';
import { motion } from 'framer-motion';
import { X } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import { useRouter } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';

/**
 * Always mounted (never unmounted/remounted) and just animated between
 * open/closed with transform + opacity — an earlier version used
 * AnimatePresence to mount/unmount this on open/close, which caused a
 * React DOM "removeChild" crash. Don't reintroduce that.
 *
 * Width fix: this used to be `max-w-md` (28rem / 448px) with no upper
 * bound tied to the actual viewport. On any phone narrower than 448px
 * (i.e. basically every phone), that made the open drawer itself wider
 * than the screen — which is what was causing the "image and text spill
 * off the edge" report on product pages, since the drawer is mounted
 * everywhere, not just on a dedicated cart page. `w-[min(100vw,28rem)]`
 * caps it at whichever is smaller: the screen width, or 448px.
 *
 * Field names matched exactly against context/CartContext.tsx: the cart
 * array is called `lines` (not `items`), and there's no separate
 * `currency` field on the context — every price on the site is EUR, so
 * that's passed straight to formatPrice instead of being read off cart.
 */
export function CartDrawer() {
  const t = useTranslations('cart');
  const { lines, isOpen, closeCart, removeItem, subtotalCents } = useCart();
  const router = useRouter();

  function goToCheckout() {
    closeCart();
    router.push('/checkout');
  }

  return (
    <>
      <motion.div
        aria-hidden={!isOpen}
        onClick={closeCart}
        initial={false}
        animate={{ opacity: isOpen ? 1 : 0 }}
        transition={{ duration: 0.25 }}
        className="fixed inset-0 z-50 bg-ink/30"
        style={{ pointerEvents: isOpen ? 'auto' : 'none' }}
      />

      <motion.aside
        aria-hidden={!isOpen}
        initial={false}
        animate={{ x: isOpen ? 0 : '100%' }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
        className="fixed right-0 top-0 z-50 flex h-full w-[min(100vw,28rem)] flex-col bg-paper"
        style={{ pointerEvents: isOpen ? 'auto' : 'none' }}
      >
        <div className="flex items-center justify-between border-b border-line px-6 py-5">
          <h2 className="font-display text-xl text-ink">{t('title')}</h2>
          <button onClick={closeCart} aria-label="Close cart" className="text-ink">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-6">
          {lines.length === 0 ? (
            <p className="font-body text-sm text-stone">{t('empty')}</p>
          ) : (
            <ul className="flex flex-col gap-6">
              {lines.map((line) => (
                <li key={line.productId} className="flex gap-4">
                  <div className="h-24 w-20 shrink-0 bg-sand">
                    {line.image && (
                      <Image
                        src={line.image}
                        alt=""
                        width={80}
                        height={96}
                        className="h-full w-full object-cover"
                      />
                    )}
                  </div>
                  <div className="flex flex-1 flex-col justify-between">
                    <div className="flex items-start justify-between gap-2">
                      <p className="break-words font-display text-base text-ink">{line.name}</p>
                      <p className="shrink-0 font-mono text-sm text-stone">
                        {formatPrice(line.priceCents * line.quantity, 'EUR')}
                      </p>
                    </div>
                    <div className="flex items-center justify-end">
                      <button
                        onClick={() => removeItem(line.productId)}
                        className="font-mono text-[11px] uppercase tracking-widest2 text-stone underline underline-offset-4 hover:text-ink"
                      >
                        {t('remove')}
                      </button>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>

        {lines.length > 0 && (
          <div className="border-t border-line px-6 py-6">
            <div className="flex items-baseline justify-between">
              <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {t('subtotal')}
              </span>
              <span className="font-display text-xl text-ink">
                {formatPrice(subtotalCents, 'EUR')}
              </span>
            </div>
            <p className="mt-2 font-body text-xs text-stone">{t('taxNote')}</p>
            <button
              onClick={goToCheckout}
              className="mt-5 w-full bg-ink py-4 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90"
            >
              {t('checkout')}
            </button>
          </div>
        )}
      </motion.aside>
    </>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/CartDrawer.tsx"

echo "Done. git add -A && git commit -m \"Fix CartDrawer field names to match CartContext\" && git push"