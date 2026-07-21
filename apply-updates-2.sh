#!/usr/bin/env bash
set -e
echo "Applying vkv.form updates (round 2)..."

mkdir -p "components"
cat > "components/Footer.tsx" << '__VKV_PATCH_EOF__'
import { useTranslations } from 'next-intl';
import { Link } from '@/lib/navigation';
import { NewsletterForm } from './NewsletterForm';
import { Instagram, Facebook } from 'lucide-react';

export function Footer() {
  const t = useTranslations('footer');
  const tn = useTranslations('nav');

  return (
    <footer className="border-t border-line bg-cream">
      <div className="mx-auto max-w-[1400px] px-6 py-10 md:px-10 md:py-12">
        <div className="grid gap-10 md:grid-cols-[1.3fr_1fr_1fr]">
          <div>
            <p className="font-display text-lg italic text-cocoa">vkv.form</p>
            <p className="mt-3 max-w-xs font-body text-xs leading-relaxed text-stone">
              {t('newsletterBody')}
            </p>
            <div className="mt-4">
              <NewsletterForm />
            </div>
          </div>

          <div>
            <p className="font-mono text-[10px] uppercase tracking-widest2 text-stone">
              {tn('catalog')}
            </p>
            <nav className="mt-3 flex flex-col gap-2">
              <Link href="/catalog" className="font-body text-sm text-ink hover:text-stone">
                {tn('catalog')}
              </Link>
              <Link href="/about" className="font-body text-sm text-ink hover:text-stone">
                {tn('about')}
              </Link>
              <Link href="/contact" className="font-body text-sm text-ink hover:text-stone">
                {tn('contact')}
              </Link>
            </nav>
          </div>

          <div>
            <p className="font-mono text-[10px] uppercase tracking-widest2 text-stone">
              Studio
            </p>
            <div className="mt-3 flex gap-4">
              <a
                href="https://www.instagram.com/vkv.form"
                target="_blank"
                rel="noreferrer"
                aria-label="Instagram"
                className="text-ink hover:text-stone"
              >
                <Instagram size={16} strokeWidth={1.5} />
              </a>
              <a
                href="https://www.facebook.com"
                target="_blank"
                rel="noreferrer"
                aria-label="Facebook"
                className="text-ink hover:text-stone"
              >
                <Facebook size={16} strokeWidth={1.5} />
              </a>
            </div>
          </div>
        </div>

        <div className="mt-8 flex flex-col-reverse items-start justify-between gap-3 border-t border-line pt-4 md:flex-row md:items-center">
          <p className="font-mono text-[10px] uppercase tracking-widest2 text-stone">
            © {new Date().getFullYear()} vkv.form — {t('rights')}
          </p>
        </div>
      </div>
    </footer>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/Footer.tsx"

mkdir -p "components"
cat > "components/Header.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useTranslations } from 'next-intl';
import { useState } from 'react';
import { Link, usePathname } from '@/lib/navigation';
import { LanguageSwitcher } from './LanguageSwitcher';
import { useCart } from '@/context/CartContext';
import { Menu, X, ShoppingBag, User } from 'lucide-react';

export function Header() {
  const t = useTranslations('nav');
  const pathname = usePathname();
  const { count, openCart } = useCart();
  const [menuOpen, setMenuOpen] = useState(false);

  const links = [
    { href: '/', label: t('home') },
    { href: '/catalog', label: t('catalog') },
    { href: '/about', label: t('about') },
    { href: '/contact', label: t('contact') },
  ];

  return (
    <header className="sticky top-0 z-40 border-b border-line bg-cream/90 backdrop-blur-sm">
      <div className="mx-auto flex max-w-[1400px] items-center justify-between px-6 py-5 md:px-10">
        <Link
          href="/"
          className="font-display text-[22px] font-medium italic tracking-tight text-cocoa"
        >
          vkv.form
        </Link>

        <nav className="hidden md:flex items-center gap-9">
          {links.map((l) => {
            const active =
              l.href === '/' ? pathname === '/' : pathname.startsWith(l.href);
            return (
              <Link
                key={l.href}
                href={l.href}
                className={`font-mono text-[11px] uppercase tracking-widest2 transition-colors ${
                  active ? 'text-ink' : 'text-stone hover:text-ink'
                }`}
              >
                {l.label}
              </Link>
            );
          })}
        </nav>

        <div className="flex items-center gap-6">
          <LanguageSwitcher />
          <Link
            href="/account"
            aria-label={t('account')}
            className="hidden sm:block text-stone hover:text-ink transition-colors"
          >
            <User size={18} strokeWidth={1.5} />
          </Link>
          <button
            onClick={openCart}
            aria-label={t('cart')}
            className="relative text-stone hover:text-ink transition-colors"
          >
            <ShoppingBag size={18} strokeWidth={1.5} />
            {count > 0 && (
              <span className="absolute -right-2 -top-2 flex h-4 w-4 items-center justify-center rounded-full bg-ink font-mono text-[9px] text-cream">
                {count}
              </span>
            )}
          </button>
          <button
            className="md:hidden text-ink"
            onClick={() => setMenuOpen((v) => !v)}
            aria-label="Menu"
          >
            {menuOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </div>

      {menuOpen && (
        <nav className="md:hidden flex flex-col gap-1 border-t border-line px-6 py-4">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              onClick={() => setMenuOpen(false)}
              className="py-2.5 font-body text-base text-ink"
            >
              {l.label}
            </Link>
          ))}
          <Link
            href="/account"
            onClick={() => setMenuOpen(false)}
            className="py-2.5 font-body text-base text-ink"
          >
            {t('account')}
          </Link>
        </nav>
      )}
    </header>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/Header.tsx"

mkdir -p "app/[locale]"
cat > "app/[locale]/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { ProductCard } from '@/components/ProductCard';
import { getProducts } from '@/lib/products';

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
      {/* Hero */}
      <section className="relative flex min-h-[92vh] items-end overflow-hidden">
        {/*
          Drop your own photo in as public/images/hero.png (landscape,
          ideally 1800px+ wide) and it replaces this automatically — no
          code change needed. Falls back to a placeholder until then.
        */}
        <Image
          src="/images/hero.png"
          alt=""
          fill
          priority
          sizes="100vw"
          className="object-cover"
        />

        {/*
          Text sits on its own solid card rather than directly on the photo,
          so it stays fully readable no matter how busy or light the photo
          underneath is — no gradient-guessing needed.
        */}
        <div className="relative z-10 mx-auto w-full max-w-[1400px] px-6 pb-10 md:px-10 md:pb-16">
          <div className="max-w-xl bg-cream/95 px-7 py-9 shadow-[0_20px_60px_-20px_rgba(33,30,26,0.35)] backdrop-blur-[2px] md:px-11 md:py-12">
            <p className="font-mono text-[11px] uppercase tracking-widest2 text-cocoa">
              {t('heroEyebrow')}
            </p>
            <h1 className="mt-5 font-display text-[11vw] leading-[0.98] text-ink md:text-[4.4vw]">
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
            <p className="mt-6 font-body text-base leading-relaxed text-stone">
              {t('heroSubtitle')}
            </p>
            <Link
              href="/catalog"
              className="mt-8 inline-block border border-ink px-7 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream"
            >
              {t('heroCta')}
            </Link>
          </div>
        </div>
      </section>

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

mkdir -p "lib"
cat > "lib/localized.ts" << '__VKV_PATCH_EOF__'
import { defaultLocale, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Picks the right-language string out of a per-locale text field.
 * Falls back to English, then to whatever language happens to be
 * there, so a product never renders as a blank field just because
 * one language is missing a translation.
 *
 * Defensive on purpose: if the `products` table hasn't been migrated
 * to jsonb yet (see supabase/migration-i18n-products.sql), Postgres can
 * hand this a plain string — sometimes even a JSON-encoded string like
 * '{"en":"Vase"}' — instead of a real object. Blindly doing
 * Object.values(value) on a string returns its individual characters,
 * which is exactly how a product name could end up rendering as a
 * lone "{". This function checks the actual type first so that can't happen.
 */
export function pickLocalized(
  value: LocalizedText | string | null | undefined,
  locale: string
): string {
  if (!value) return '';

  // Column not migrated yet, or a JSON-encoded string ended up stored as
  // plain text — try to parse it back into an object; otherwise treat it
  // as the plain string it is.
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed.startsWith('{')) {
      try {
        return pickLocalized(JSON.parse(trimmed), locale);
      } catch {
        return value;
      }
    }
    return value;
  }

  if (typeof value !== 'object') return '';

  const asLocale = locale as Locale;
  if (value[asLocale]) return value[asLocale] as string;
  if (value[defaultLocale]) return value[defaultLocale] as string;

  const first = Object.values(value).find((v) => typeof v === 'string' && v);
  return (first as string) ?? '';
}
__VKV_PATCH_EOF__
echo "  updated: lib/localized.ts"

echo
echo "Done."