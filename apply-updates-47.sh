#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates (round 48 — slide 1 photo only, slide 2 button lower)..."

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
  const products = (await getProducts()).slice(0, 3);

  const heroLines = t('heroTitle').split('\n');

  return (
    <div>
      {/*
        Hero slider — 3 slides. The first two are drafts for the client's
        two upcoming events (photo, title, link — all placeholder text
        below, meant to be edited). The third slide is the studio's
        regular homepage banner, unchanged.
      */}
      <HeroSlider
        slides={[
          // --- Slide 1: Event (photo only — add text/button back if you want them) ---
          <div key="event-1" className="relative h-full w-full">
            <Image
              src="/images/event-1.png"
              alt=""
              fill
              priority
              sizes="100vw"
              className="object-cover"
            />
          </div>,

          // --- Slide 2: Event (photo has its own text — just a centered button) ---
          <div key="event-2" className="relative h-full w-full">
            <Image
              src="/images/event-2.png"
              alt=""
              fill
              sizes="100vw"
              className="object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-end justify-center pb-20 md:pb-28">
              <Link
                href="/contact"
                className="border-2 border-white px-12 py-5 font-mono text-sm uppercase tracking-widest2 text-white transition-colors hover:bg-white hover:text-ink"
              >
                Explore
              </Link>
            </div>
          </div>,

          // --- Slide 3: the studio's regular homepage banner (unchanged) ---
          <div key="studio" className="relative h-full w-full">
            <Image
              src="/images/hero.png"
              alt=""
              fill
              sizes="100vw"
              className="object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-end">
              <div className="mx-auto w-full max-w-[1400px] px-6 pb-10 md:px-10 md:pb-16">
                <div className="max-w-xl">
                  <p className="hero-text-outline font-mono text-[11px] uppercase tracking-widest2 text-white">
                    {t('heroEyebrow')}
                  </p>
                  <h1 className="hero-text-outline mt-5 font-display text-[11vw] leading-[0.98] text-white md:text-[4.4vw]">
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
                  <p className="hero-text-outline mt-6 font-body text-base leading-relaxed text-white">
                    {t('heroSubtitle')}
                  </p>
                  <Link
                    href="/catalog"
                    className="mt-8 inline-block border border-white px-7 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-white transition-colors hover:bg-white hover:text-ink"
                  >
                    {t('heroCta')}
                  </Link>
                </div>
              </div>
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
          <div className="mt-6 grid gap-10 md:grid-cols-2 md:gap-20">
            <Reveal>
              <h2 className="font-display text-4xl leading-[1.1] text-ink md:text-5xl">
                {t('philosophyTitle')}
              </h2>
            </Reveal>
            <Reveal delay={0.1}>
              <p className="font-body text-lg leading-relaxed text-stone">
                {t('philosophyBody')}
              </p>
            </Reveal>
          </div>
        </div>
      </section>

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

echo "Done. Restart npm run dev after this."