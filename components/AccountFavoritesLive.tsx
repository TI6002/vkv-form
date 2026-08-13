'use client';

import { useEffect, useState } from 'react';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/client';
import { Link } from '@/lib/navigation';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';
import type { Favorite } from '@/lib/types';

const POLL_INTERVAL_MS = 5000;

/**
 * Renders the "Saved items" grid on /account and keeps it in sync with
 * the database by polling every few seconds — the same approach used
 * for order status on this page. Liking/unliking a product from the
 * catalog is a separate page (and possibly a page the router already
 * cached from an earlier visit), so this page's server-rendered data
 * can otherwise sit stale until a manual refresh; polling fixes that
 * without depending on any extra Supabase Realtime setup.
 */
export function AccountFavoritesLive({
  userId,
  locale,
  initialFavorites,
  savedTitle,
  noSavedText,
}: {
  userId: string;
  locale: string;
  initialFavorites: Favorite[];
  savedTitle: string;
  noSavedText: string;
}) {
  const supabase = createClient();
  const [favorites, setFavorites] = useState<Favorite[]>(initialFavorites);

  useEffect(() => {
    let cancelled = false;

    async function refetch() {
      const { data, error } = await supabase
        .from('favorites')
        .select('*, products(*)')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });
      if (cancelled) return;
      if (error) {
        console.error('Could not refresh saved items:', error);
        return;
      }
      setFavorites((data as Favorite[]) ?? []);
    }

    // Refresh right away (covers "just navigated back to this page"),
    // then keep polling, and also refresh whenever the tab regains
    // focus so switching back to it feels instant.
    refetch();
    const interval = setInterval(refetch, POLL_INTERVAL_MS);

    function handleVisibility() {
      if (document.visibilityState === 'visible') refetch();
    }
    document.addEventListener('visibilitychange', handleVisibility);

    return () => {
      cancelled = true;
      clearInterval(interval);
      document.removeEventListener('visibilitychange', handleVisibility);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  return (
    <div className="bg-white p-8">
      <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
        {savedTitle}
      </p>
      {favorites.length === 0 ? (
        <p className="mt-6 font-body text-stone">{noSavedText}</p>
      ) : (
        <div className="mt-8 grid grid-cols-2 gap-x-6 gap-y-10 sm:grid-cols-3">
          {favorites.map((fav) => {
            const product = fav.products;
            if (!product) return null;
            const name = pickLocalized(product.name, locale);
            return (
              <Link key={fav.id} href={`/catalog/${product.slug}`} className="group block">
                <div className="relative aspect-[4/5] overflow-hidden bg-sand">
                  {product.images?.[0] && (
                    <Image
                      src={product.images[0]}
                      alt={name}
                      fill
                      sizes="(min-width: 768px) 20vw, 33vw"
                      className="object-cover transition-transform duration-700 group-hover:scale-105"
                    />
                  )}
                </div>
                <p className="mt-3 font-body text-sm text-ink">{name}</p>
                <p className="font-mono text-xs text-stone">
                  {formatPrice(product.price_cents, product.currency)}
                </p>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
