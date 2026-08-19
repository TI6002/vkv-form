#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — add 4th gallery photo, remove price from catalog cards..."

mkdir -p "app/[locale]"
cat > "app/[locale]/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { ProductCard } from '@/components/ProductCard';
import { HeroSlider } from '@/components/HeroSlider';
import { getProducts } from '@/lib/products';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function HomePage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('home');
  const products = (await getProducts()).filter((p) => p.available).slice(0, 3);

  const heroLines = t('heroTitle').split('\n');

  return (
    <div>
      {/*
        Hero slider — 3 slides. The studio's main banner is first, shows
        ONLY the hero title, top-center, on both mobile and desktop. The
        two event slides follow it.
      */}
      <HeroSlider
        slides={[
          <div key="studio" className="relative h-full w-full">
            <Image
              src="/images/hero.png"
              alt=""
              fill
              priority
              sizes="100vw"
              className="object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-start justify-center pt-14 md:pt-20">
              <div className="mx-auto w-full max-w-[1400px] px-6 text-center md:px-10">
                <div className="mx-auto max-w-2xl">
                  <h1 className="hero-text-outline font-display text-[11vw] leading-[0.98] text-white md:text-[4.4vw]">
                    {heroLines.map((line, i) => (
                      <span key={i} className="block">
                        {i === heroLines.length - 1 ? (
                          <em className="not-italic italic">{line}</em>
                        ) : (
                          line
                        )}
                      </span>
                    ))}
                  </h1>
                </div>
              </div>
            </div>
          </div>,

          <div key="event-1" className="relative h-full w-full bg-ink">
            <Image
              src="/images/event-1.png"
              alt=""
              fill
              sizes="100vw"
              className="object-contain sm:object-cover"
            />
          </div>,

          <div key="event-2" className="relative h-full w-full bg-ink">
            <Image
              src="/images/event-2.png"
              alt=""
              fill
              sizes="100vw"
              className="object-contain sm:object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-end justify-center pb-20 md:pb-28">
              <Link
                href="https://www.1000vases.com/about"
                className="border-2 border-white px-12 py-5 font-mono text-sm uppercase tracking-widest2 text-white transition-colors hover:bg-white hover:text-ink"
              >
                Explore
              </Link>
            </div>
          </div>,
        ]}
      />

      {/* Philosophy — white panel */}
      <section className="bg-white">
        <div className="mx-auto max-w-[1400px] px-6 py-28 md:px-10 md:py-36">
          <Reveal>
            <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              {t('philosophyEyebrow')}
            </p>
          </Reveal>
          <Reveal delay={0.1}>
            <h2 className="mt-6 max-w-2xl font-display text-2xl italic leading-[1.5] text-ink md:text-3xl">
              {t('philosophyTitle')}
            </h2>
          </Reveal>
        </div>
      </section>

      {/*
        Gallery — same HeroSlider component as the top banner, just with
        a different set of slides: group shots of pieces styled together
        (2-3 vases per photo), between Philosophy and the catalogue.
        object-contain on purpose (not object-cover) — these photos
        showed tall vases that were getting cropped badly with a forced
        aspect ratio + cover, so the whole photo is always shown, with a
        bg-sand letterbox filling any gap instead of cropping content.

        Swap /images/gallery-1.jpg .. gallery-4.jpg for the client's
        real photos — same folder as hero.png etc. Add more slides here
        the same way if there end up being more than 4.
      */}
      <HeroSlider
        slides={[
          <div key="gallery-1" className="relative h-full w-full bg-sand">
            <Image
              src="/images/gallery-1.jpg"
              alt=""
              fill
              sizes="100vw"
              className="object-contain"
            />
          </div>,
          <div key="gallery-2" className="relative h-full w-full bg-sand">
            <Image
              src="/images/gallery-2.jpg"
              alt=""
              fill
              sizes="100vw"
              className="object-contain"
            />
          </div>,
          <div key="gallery-3" className="relative h-full w-full bg-sand">
            <Image
              src="/images/gallery-3.jpg"
              alt=""
              fill
              sizes="100vw"
              className="object-contain"
            />
          </div>,
          <div key="gallery-4" className="relative h-full w-full bg-sand">
            <Image
              src="/images/gallery-4.jpg"
              alt=""
              fill
              sizes="100vw"
              className="object-contain"
            />
          </div>,
        ]}
      />

      {/* Featured catalogue — beige panel, alternating with the white one above */}
      <section className="bg-cream">
        <div className="mx-auto max-w-[1400px] px-6 py-28 md:px-10 md:py-36">
          <Reveal>
            <div className="flex items-end justify-between border-b border-line pb-6">
              <div>
                <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                  {t('catalogEyebrow')}
                </p>
                <h2 className="mt-3 font-display text-3xl text-ink md:text-4xl">
                  {t('catalogTitle')}
                </h2>
              </div>
              <span className="hidden font-mono text-[11px] uppercase tracking-widest2 text-taupe md:block">
                {t('featuredEyebrow')}
              </span>
            </div>
          </Reveal>

          <div className="mt-12 grid grid-cols-1 gap-x-8 gap-y-14 sm:grid-cols-2 md:grid-cols-3">
            {products.map((p, i) => (
              <Reveal key={p.id} delay={i * 0.08}>
                <ProductCard product={p} index={i} />
              </Reveal>
            ))}
          </div>

          <Reveal delay={0.15}>
            <div className="mt-16 text-center">
              <Link
                href="/catalog"
                className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
              >
                {t('catalogCta')}
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/page.tsx"

mkdir -p "components"
cat > "components/ProductCard.tsx" << '__VKV_PATCH_EOF__'
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
__VKV_PATCH_EOF__
echo "  updated: components/ProductCard.tsx"

echo "Done. git add -A && git commit -m \"Add 4th gallery photo, remove price from catalog cards\" && git push"