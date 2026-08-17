#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — taller gallery photos, less cropping..."

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

      {/*
        Gallery — group shots of pieces styled together (2-3 vases per
        photo), between Philosophy and the catalogue. One wide "accent"
        photo on top, two smaller ones below it side by side — clearer
        visual hierarchy than three equal photos in a row, and the wide
        aspect ratio suits rectangular/landscape photos far better than
        forcing everything into a tall portrait crop. Stacks to one
        column on mobile.

        Swap /images/gallery-1.jpg, gallery-2.jpg, gallery-3.jpg for
        the client's real photos — same folder as hero.png etc.
      */}
      <section className="bg-paper">
        <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
          <div className="flex flex-col gap-6 md:gap-8">
            <Reveal>
              <div className="relative aspect-[4/3] overflow-hidden bg-sand md:aspect-[16/9]">
                <Image
                  src="/images/gallery-1.jpg"
                  alt=""
                  fill
                  sizes="100vw"
                  className="object-cover"
                />
              </div>
            </Reveal>
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 md:gap-8">
              <Reveal delay={0.08}>
                <div className="relative aspect-square overflow-hidden bg-sand">
                  <Image
                    src="/images/gallery-2.jpg"
                    alt=""
                    fill
                    sizes="(min-width: 640px) 50vw, 100vw"
                    className="object-cover"
                  />
                </div>
              </Reveal>
              <Reveal delay={0.16}>
                <div className="relative aspect-square overflow-hidden bg-sand">
                  <Image
                    src="/images/gallery-3.jpg"
                    alt=""
                    fill
                    sizes="(min-width: 640px) 50vw, 100vw"
                    className="object-cover"
                  />
                </div>
              </Reveal>
            </div>
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

echo "Done. git add -A && git commit -m \"Taller gallery photos to reduce cropping\" && git push"