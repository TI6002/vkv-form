'use client';

import { useLocale, useTranslations } from 'next-intl';
import Image from 'next/image';
import { Link } from '@/lib/navigation';
import type { Product } from '@/lib/types';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';
import { LikeButton } from './LikeButton';

export function ProductCard({ product, index }: { product: Product; index: number }) {
  const t = useTranslations('catalog');
  const tp = useTranslations('product');
  const locale = useLocale();
  const image = product.images?.[0];
  const name = pickLocalized(product.name, locale);
  const available = product.available;

  return (
    <Link href={`/catalog/${product.slug}`} className="group block">
      <div className="relative aspect-[4/5] overflow-hidden bg-sand">
        {image ? (
          <Image
            src={image}
            alt={name}
            fill
            sizes="(min-width: 768px) 33vw, 50vw"
            className={`object-cover transition-transform duration-[1400ms] ease-signature group-hover:scale-[1.045] ${
              available ? '' : 'opacity-60'
            }`}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center font-mono text-xs text-taupe">
            No image
          </div>
        )}
        <span className="absolute left-4 top-4 font-mono text-[10px] uppercase tracking-widest2 text-stone/80">
          {String(index + 1).padStart(2, '0')}
        </span>
        <div className="absolute right-3 top-3">
          <LikeButton productId={product.id} variant="icon" />
        </div>
        {!available && (
          <span className="absolute bottom-3 left-3 bg-ink/85 px-2.5 py-1 font-mono text-[10px] uppercase tracking-widest2 text-cream">
            {tp('outOfStock')}
          </span>
        )}
      </div>
      <div className="mt-4 flex items-baseline justify-between">
        <h3 className="font-display text-lg text-ink">{name}</h3>
        <span className="font-mono text-sm text-stone">
          {formatPrice(product.price_cents, product.currency)}
        </span>
      </div>
    </Link>
  );
}
