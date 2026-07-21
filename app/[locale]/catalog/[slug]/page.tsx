import { notFound } from 'next/navigation';
import Image from 'next/image';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { AddToCartForm } from '@/components/AddToCartForm';
import { getProductBySlug } from '@/lib/products';
import { formatPrice } from '@/lib/format';

export default async function ProductPage({
  params: { locale, slug },
}: {
  params: { locale: string; slug: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('product');
  const product = await getProductBySlug(slug);
  if (!product) notFound();

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-24">
      <Link
        href="/catalog"
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone hover:text-ink"
      >
        ← {t('back')}
      </Link>

      <div className="mt-8 grid gap-14 md:grid-cols-2 md:gap-20">
        <Reveal>
          <div className="relative aspect-[4/5] bg-sand">
            {product.images?.[0] && (
              <Image
                src={product.images[0]}
                alt={product.name}
                fill
                priority
                sizes="(min-width: 768px) 50vw, 100vw"
                className="object-cover"
              />
            )}
          </div>
        </Reveal>

        <Reveal delay={0.1}>
          <h1 className="font-display text-4xl text-ink md:text-5xl">{product.name}</h1>
          <p className="mt-3 font-mono text-xl text-stone">
            {formatPrice(product.price_cents, product.currency)}
          </p>

          <p className="mt-8 font-body text-base leading-relaxed text-stone">
            {product.description}
          </p>

          <dl className="mt-8 space-y-3 border-t border-line pt-6">
            {product.materials && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('materialsLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{product.materials}</dd>
              </div>
            )}
            {product.dimensions && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('dimensionsLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{product.dimensions}</dd>
              </div>
            )}
          </dl>

          <AddToCartForm product={product} />

          <p className="mt-6 font-body text-xs leading-relaxed text-taupe">
            {t('shippingNote')}
          </p>
        </Reveal>
      </div>
    </div>
  );
}