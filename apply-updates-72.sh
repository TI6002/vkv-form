#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — smaller, more elegant philosophy text size..."

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
        Hero slider — 3 slides. The studio's main banner is now first
        (was third) — it shows ONLY the hero title, nothing else, per
        request. The two event slides follow it.

        Event slides use posters that have their own text baked into
        the photo. On phones, a tall/narrow slider box combined with
        object-cover zoomed in and cut that text off at the edges —
        object-contain (mobile) shows the whole poster instead, with a
        small solid-colour margin above/below when needed; from tablet
        width up there's enough room that object-cover (full bleed, no
        margin) looks better, so it switches back at `sm:`.
      */}
      <HeroSlider
        slides={[
          // --- Slide 1: the studio's main banner (moved from 3rd to 1st) ---
          // Only the hero title is shown here — no eyebrow, subtitle or CTA.
          <div key="studio" className="relative h-full w-full">
            <Image
              src="/images/hero.png"
              alt=""
              fill
              priority
              sizes="100vw"
              className="object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-end">
              <div className="mx-auto w-full max-w-[1400px] px-6 pb-10 md:px-10 md:pb-16">
                <div className="max-w-xl">
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

          // --- Slide 2: Event (photo only — add text/button back if you want them) ---
          <div key="event-1" className="relative h-full w-full bg-ink">
            <Image
              src="/images/event-1.png"
              alt=""
              fill
              sizes="100vw"
              className="object-contain sm:object-cover"
            />
          </div>,

          // --- Slide 3: Event (photo has its own text — just a centered button) ---
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

echo "Done. git add -A && git commit -m \"Smaller, more elegant philosophy text size\" && git push"