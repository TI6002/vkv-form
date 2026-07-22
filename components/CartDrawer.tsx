'use client';

import { useTranslations } from 'next-intl';
import { motion } from 'framer-motion';
import { useCart } from '@/context/CartContext';
import { Link, useRouter } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';
import { X } from 'lucide-react';

/**
 * No AnimatePresence here on purpose. AnimatePresence + Next.js App Router
 * client-side navigation is a well-documented combination that throws
 * "NotFoundError: removeChild" — framer-motion's exit-animation tracking
 * gets confused when a route change unmounts part of the tree at the same
 * time. Instead, this drawer is *always* mounted and just animates its
 * opacity/position between open and closed — nothing ever gets added to or
 * removed from the React tree, so there's nothing for that bug to trigger on.
 */
export function CartDrawer() {
  const t = useTranslations('cart');
  const router = useRouter();
  const { isOpen, closeCart, lines, removeItem, subtotalCents } = useCart();

  function handleGoToCheckout() {
    closeCart();
    router.push('/checkout');
  }

  return (
    <>
      <motion.div
        className="fixed inset-0 z-50 bg-ink/30"
        initial={false}
        animate={{ opacity: isOpen ? 1 : 0 }}
        transition={{ duration: 0.3 }}
        style={{ pointerEvents: isOpen ? 'auto' : 'none' }}
        onClick={closeCart}
        aria-hidden={!isOpen}
      />
      <motion.aside
        className="fixed right-0 top-0 z-50 flex h-full w-full max-w-md flex-col bg-paper"
        initial={false}
        animate={{ x: isOpen ? 0 : '100%' }}
        transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        style={{ pointerEvents: isOpen ? 'auto' : 'none' }}
        aria-hidden={!isOpen}
      >
        <div className="flex items-center justify-between border-b border-line px-6 py-5">
          <h2 className="font-display text-xl text-ink">{t('title')}</h2>
          <button onClick={closeCart} aria-label="Close" className="text-ink">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-6">
          {lines.length === 0 ? (
            <div className="flex h-full flex-col items-center justify-center gap-4 text-center">
              <p className="font-body text-sm text-stone">{t('empty')}</p>
              <Link
                href="/catalog"
                onClick={closeCart}
                className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
              >
                {t('continue')}
              </Link>
            </div>
          ) : (
            <ul className="flex flex-col gap-6">
              {lines.map((line) => (
                <li key={line.productId} className="flex gap-4">
                  <div className="h-24 w-20 shrink-0 bg-sand">
                    {line.image && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={line.image} alt={line.name} className="h-full w-full object-cover" />
                    )}
                  </div>
                  <div className="flex flex-1 flex-col justify-between">
                    <div className="flex items-start justify-between gap-2">
                      <p className="font-display text-base text-ink">{line.name}</p>
                      <p className="font-mono text-sm text-stone">
                        {formatPrice(line.priceCents * line.quantity)}
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
                {formatPrice(subtotalCents)}
              </span>
            </div>
            <p className="mt-2 font-body text-xs text-stone">{t('taxNote')}</p>
            <button
              onClick={handleGoToCheckout}
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
