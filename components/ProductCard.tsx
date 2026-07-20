'use client';

import { useTranslations } from 'next-intl';
import { Link } from '@/lib/navigation';
import type { Product } from '@/lib/types';
import { formatPrice } from '@/lib/format';

export function ProductCard({ product, index }: { product: Product; index: number }) {
  const t = useTranslations('catalog');
  const image = product.images?.[0];

  return (
    <Link href={`/catalog/${product.slug}`} className="group block">
      <div className="relative aspect-[4/5] overflow-hidden bg-sand">
        {image ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={image}
            alt={product.name}
            className="h-full w-full object-cover transition-transform duration-[1400ms] ease-signature group-hover:scale-[1.045]"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center font-mono text-xs text-taupe">
            No image
          </div>
        )}
        <span className="absolute left-4 top-4 font-mono text-[10px] uppercase tracking-widest2 text-stone/80">
          {String(index + 1).padStart(2, '0')}
        </span>
      </div>
      <div className="mt-4 flex items-baseline justify-between">
        <h3 className="font-display text-lg text-ink">{product.name}</h3>
        <span className="font-mono text-sm text-stone">
          {formatPrice(product.price_cents, product.currency)}
        </span>
      </div>
    </Link>
  );
}
