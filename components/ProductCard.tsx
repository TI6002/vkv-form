import Image from 'next/image';
import { useLocale } from 'next-intl';
import { Link } from '@/lib/navigation';
import { pickLocalized } from '@/lib/localized';
import type { Product } from '@/lib/types';

/**
 * Price is shown only on the product's own page now, not here in the
 * catalogue grid — the card is just photo + name, price only appears
 * once someone opens the piece.
 */
export function ProductCard({ product, index }: { product: Product; index?: number }) {
  const locale = useLocale();
  const name = pickLocalized(product.name, locale);

  return (
    <Link href={`/catalog/${product.slug}`} className="group block">
      <div className="relative aspect-[4/5] overflow-hidden bg-sand">
        {product.images?.[0] && (
          <Image
            src={product.images[0]}
            alt={name}
            fill
            sizes="(min-width: 1024px) 33vw, (min-width: 640px) 50vw, 100vw"
            priority={index !== undefined && index < 3}
            className="object-cover transition-transform duration-700 group-hover:scale-105"
          />
        )}
      </div>
      <p className="mt-4 font-display text-lg text-ink">{name}</p>
    </Link>
  );
}
