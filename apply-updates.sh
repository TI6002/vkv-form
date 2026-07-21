#!/usr/bin/env bash
set -e
echo "Applying vkv.form updates..."

cat > "i18n.ts" << '__VKV_PATCH_EOF__'
import { getRequestConfig } from 'next-intl/server';

// The base language we write copy in. All other files under /messages
// are generated automatically — see scripts/translate-missing.mjs and README.md.
export const defaultLocale = 'en' as const;

export const locales = ['en', 'fr', 'it', 'es', 'de', 'ru', 'lv'] as const;

export type Locale = (typeof locales)[number];

export const localeNames: Record<Locale, string> = {
  en: 'English',
  fr: 'Français',
  it: 'Italiano',
  es: 'Español',
  de: 'Deutsch',
  ru: 'Русский',
  lv: 'Latviešu',
};

export default getRequestConfig(async ({ requestLocale }) => {
  // requestLocale reflects the actual /xx segment in the URL. Awaiting it
  // (instead of the old, now-deprecated synchronous `locale` param) is what
  // fixes the "switches to the wrong language" bug — the old API could
  // resolve locale from a stale cookie instead of the URL you're on.
  let locale = await requestLocale;

  if (!locale || !locales.includes(locale as Locale)) {
    locale = defaultLocale;
  }

  return {
    locale,
    messages: (await import(`./messages/${locale}.json`)).default,
  };
});
__VKV_PATCH_EOF__
echo "  updated: i18n.ts"

cat > "middleware.ts" << '__VKV_PATCH_EOF__'
import createMiddleware from 'next-intl/middleware';
import { locales, defaultLocale } from './i18n';

export default createMiddleware({
  locales,
  defaultLocale,
  localePrefix: 'as-needed', // English lives at "/", other locales at "/fr", "/ru", etc.
  localeDetection: false, // don't guess from Accept-Language/cookie — always trust the URL
});

export const config = {
  // Skip API routes, Next internals, and static files.
  matcher: ['/((?!api|_next|.*\\..*).*)'],
};
__VKV_PATCH_EOF__
echo "  updated: middleware.ts"

cat > "tailwind.config.ts" << '__VKV_PATCH_EOF__'
import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './app/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        cream: '#F6F2EA',
        paper: '#FBF9F5',
        sand: '#E7DBC7',
        taupe: '#A5967F',
        stone: '#726657',
        ink: '#211E1A',
        cocoa: '#3D2A1B',
        line: '#DCD0BC',
        white: '#FFFFFF',
      },
      fontFamily: {
        display: ['var(--font-display)', 'serif'],
        body: ['var(--font-body)', 'sans-serif'],
        mono: ['var(--font-mono)', 'monospace'],
      },
      letterSpacing: {
        widest2: '0.28em',
      },
      transitionTimingFunction: {
        signature: 'cubic-bezier(0.22, 1, 0.36, 1)',
      },
      keyframes: {
        fadeUp: {
          '0%': { opacity: '0', transform: 'translateY(18px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
      animation: {
        fadeUp: 'fadeUp 0.9s cubic-bezier(0.22, 1, 0.36, 1) forwards',
      },
    },
  },
  plugins: [],
};

export default config;
__VKV_PATCH_EOF__
echo "  updated: tailwind.config.ts"

cat > "package.json" << '__VKV_PATCH_EOF__'
{
  "name": "vkv-form",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "translate": "node scripts/translate-missing.mjs"
  },
  "dependencies": {
    "@stripe/stripe-js": "^4.7.0",
    "@supabase/ssr": "^0.5.2",
    "@supabase/supabase-js": "^2.45.4",
    "@vitalets/google-translate-api": "^9.2.0",
    "clsx": "^2.1.1",
    "framer-motion": "^11.11.17",
    "lucide-react": "^0.454.0",
    "next": "14.2.15",
    "next-intl": "3.26.3",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "stripe": "^17.1.0",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^20.14.2",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38",
    "tailwindcss": "^3.4.4",
    "typescript": "^5.5.2"
  }
}
__VKV_PATCH_EOF__
echo "  updated: package.json"

mkdir -p "lib"
cat > "lib/auth.ts" << '__VKV_PATCH_EOF__'
import { createClient } from '@/lib/supabase/server';

export type AdminCheckResult =
  | { ok: true; profile: { id: string; email: string; role: string } }
  | { ok: false; reason: 'no-session' | 'no-profile-row' | 'not-admin' | 'supabase-error'; detail?: string };

/**
 * Returns the signed-in user's profile (with role) or null.
 * "Admin" is just a row in public.profiles with role = 'admin' —
 * see supabase/schema.sql. Promote your own account by hand once
 * in the Supabase Table Editor after your first sign-up.
 */
export async function getCurrentProfile() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, email, role')
    .eq('id', user.id)
    .single();

  return profile ?? null;
}

export async function requireAdmin() {
  const profile = await getCurrentProfile();
  return profile?.role === 'admin' ? profile : null;
}

/**
 * Same check as requireAdmin(), but tells you *why* it failed instead of
 * just returning null. Use this on /admin so a misconfigured .env.local,
 * a missing profiles row, or a role that isn't literally "admin" all show
 * a different, actionable message instead of one generic "not allowed".
 */
export async function checkAdminAccess(): Promise<AdminCheckResult> {
  try {
    const supabase = createClient();
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError) return { ok: false, reason: 'supabase-error', detail: userError.message };
    if (!user) return { ok: false, reason: 'no-session' };

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, email, role')
      .eq('id', user.id)
      .single();

    if (profileError) return { ok: false, reason: 'supabase-error', detail: profileError.message };
    if (!profile) return { ok: false, reason: 'no-profile-row' };
    if (profile.role !== 'admin') return { ok: false, reason: 'not-admin' };

    return { ok: true, profile };
  } catch (err) {
    return {
      ok: false,
      reason: 'supabase-error',
      detail: err instanceof Error ? err.message : String(err),
    };
  }
}
__VKV_PATCH_EOF__
echo "  updated: lib/auth.ts"

mkdir -p "lib"
cat > "lib/types.ts" << '__VKV_PATCH_EOF__'
import type { Locale } from '@/i18n';

/** A piece of text stored once per language, e.g. { en: "Vase", ru: "Ваза" }. */
export type LocalizedText = Partial<Record<Locale, string>>;

export type Product = {
  id: string;
  slug: string;
  name: LocalizedText;
  price_cents: number;
  currency: string;
  description: LocalizedText;
  materials: LocalizedText | null;
  dimensions: LocalizedText | null;
  stock: number;
  images: string[];
  created_at: string;
};

export type CartLine = {
  productId: string;
  slug: string;
  name: string;
  priceCents: number;
  image: string | null;
  quantity: number;
};

export type Order = {
  id: string;
  user_id: string | null;
  email: string;
  status: 'pending' | 'paid' | 'shipped' | 'cancelled';
  total_cents: number;
  currency: string;
  stripe_session_id: string | null;
  created_at: string;
};
__VKV_PATCH_EOF__
echo "  updated: lib/types.ts"

mkdir -p "lib"
cat > "lib/localized.ts" << '__VKV_PATCH_EOF__'
import { defaultLocale, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Picks the right-language string out of a per-locale text field.
 * Falls back to English, then to whatever language happens to be
 * there, so a product never renders as a blank field just because
 * one language is missing a translation.
 */
export function pickLocalized(
  value: LocalizedText | null | undefined,
  locale: string
): string {
  if (!value) return '';
  const asLocale = locale as Locale;
  if (value[asLocale]) return value[asLocale] as string;
  if (value[defaultLocale]) return value[defaultLocale] as string;
  const first = Object.values(value).find(Boolean);
  return first ?? '';
}
__VKV_PATCH_EOF__
echo "  updated: lib/localized.ts"

mkdir -p "lib"
cat > "lib/translate-server.ts" << '__VKV_PATCH_EOF__'
import { translate } from '@vitalets/google-translate-api';
import { locales, defaultLocale, type Locale } from '@/i18n';
import type { LocalizedText } from '@/lib/types';

/**
 * Translates a single string into every locale in i18n.ts, using the same
 * free Google Translate wrapper as scripts/translate-missing.mjs. Source
 * language is auto-detected, so it doesn't matter whether the admin typed
 * the product copy in Russian, English, or anything else.
 */
export async function translateToAllLocales(text: string): Promise<LocalizedText> {
  const clean = (text ?? '').trim();
  const result: LocalizedText = { [defaultLocale]: clean };

  if (!clean) {
    for (const locale of locales) result[locale] = '';
    return result;
  }

  await Promise.all(
    locales.map(async (locale) => {
      try {
        const { text: translated } = await translate(clean, { to: locale });
        result[locale as Locale] = translated;
      } catch {
        // Translation API hiccup — fall back to the original text rather
        // than leaving the field blank.
        result[locale as Locale] = clean;
      }
    })
  );

  return result;
}
__VKV_PATCH_EOF__
echo "  updated: lib/translate-server.ts"

mkdir -p "lib"
cat > "lib/demo-products.ts" << '__VKV_PATCH_EOF__'
import type { Product } from './types';

export const demoProducts: Product[] = [
  {
    id: 'demo-1',
    slug: 'volta-vase',
    name: { en: 'Volta Vase' },
    price_cents: 18800,
    currency: 'EUR',
    description: {
      en: 'A hand-built stoneware vase with a soft asymmetric lean, left unglazed to show the raw clay body. Each one is thrown and altered by hand, so the exact curve varies slightly from piece to piece.',
    },
    materials: { en: 'Unglazed stoneware, sealed interior' },
    dimensions: { en: 'H 32 cm · Ø 16 cm' },
    stock: 4,
    images: ['/images/product-1.png'],
    created_at: new Date().toISOString(),
  },
  {
    id: 'demo-2',
    slug: 'muted-bowl-no-2',
    name: { en: 'Muted Bowl No. 2' },
    price_cents: 9400,
    currency: 'EUR',
    description: {
      en: 'A shallow bowl in tinted plaster with a soft, chalky surface. Suited to a single piece of fruit or a scatter of keys — it is meant to be used, not shelved.',
    },
    materials: { en: 'Tinted plaster, wax-sealed' },
    dimensions: { en: 'H 6 cm · Ø 24 cm' },
    stock: 7,
    images: ['/images/product-2.png'],
    created_at: new Date().toISOString(),
  },
  {
    id: 'demo-3',
    slug: 'still-form-obelisk',
    name: { en: 'Still Form Obelisk' },
    price_cents: 24200,
    currency: 'EUR',
    description: {
      en: 'A carved soft-stone obelisk, hand-finished with a matte, slightly porous surface. Reads as sculpture on its own, or as a quiet anchor on a shelf of smaller objects.',
    },
    materials: { en: 'Soft natural stone' },
    dimensions: { en: 'H 38 cm · W 8 cm · D 8 cm' },
    stock: 2,
    images: ['/images/product-3.png'],
    created_at: new Date().toISOString(),
  },
];
__VKV_PATCH_EOF__
echo "  updated: lib/demo-products.ts"

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
          className="font-display text-[22px] font-medium italic tracking-tight text-ink"
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

mkdir -p "components"
cat > "components/AuthForm.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export function AuthForm() {
  const t = useTranslations('account');
  const router = useRouter();
  const [mode, setMode] = useState<'signIn' | 'signUp'>('signIn');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const supabase = createClient();

    const { error } =
      mode === 'signIn'
        ? await supabase.auth.signInWithPassword({ email, password })
        : await supabase.auth.signUp({ email, password });

    setLoading(false);
    if (error) {
      setError(error.message || t('error'));
      return;
    }
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex max-w-sm flex-col gap-6">
      <h1 className="font-display text-3xl text-ink">
        {mode === 'signIn' ? t('signInTitle') : t('signUpTitle')}
      </h1>

      <div>
        <label className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('email')}
        </label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mt-2 w-full border-b border-line bg-transparent py-2 font-body text-ink focus:outline-none focus:border-ink"
        />
      </div>
      <div>
        <label className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('password')}
        </label>
        <input
          type="password"
          required
          minLength={6}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mt-2 w-full border-b border-line bg-transparent py-2 font-body text-ink focus:outline-none focus:border-ink"
        />
      </div>

      {error && <p className="font-body text-sm text-red-800">{error}</p>}

      <button
        type="submit"
        disabled={loading}
        className="bg-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
      >
        {mode === 'signIn' ? t('signIn') : t('signUp')}
      </button>

      <button
        type="button"
        onClick={() => setMode(mode === 'signIn' ? 'signUp' : 'signIn')}
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone underline underline-offset-4 text-left"
      >
        {mode === 'signIn' ? t('orSignUp') : t('orSignIn')}
      </button>
    </form>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/AuthForm.tsx"

mkdir -p "components"
cat > "components/ProductCard.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useLocale, useTranslations } from 'next-intl';
import Image from 'next/image';
import { Link } from '@/lib/navigation';
import type { Product } from '@/lib/types';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';

export function ProductCard({ product, index }: { product: Product; index: number }) {
  const t = useTranslations('catalog');
  const locale = useLocale();
  const image = product.images?.[0];
  const name = pickLocalized(product.name, locale);

  return (
    <Link href={`/catalog/${product.slug}`} className="group block">
      <div className="relative aspect-[4/5] overflow-hidden bg-sand">
        {image ? (
          <Image
            src={image}
            alt={name}
            fill
            sizes="(min-width: 768px) 33vw, 50vw"
            className="object-cover transition-transform duration-[1400ms] ease-signature group-hover:scale-[1.045]"
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
        <h3 className="font-display text-lg text-ink">{name}</h3>
        <span className="font-mono text-sm text-stone">
          {formatPrice(product.price_cents, product.currency)}
        </span>
      </div>
    </Link>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/ProductCard.tsx"

mkdir -p "components"
cat > "components/AddToCartForm.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useCart } from '@/context/CartContext';
import type { Product } from '@/lib/types';

export function AddToCartForm({ product, name }: { product: Product; name: string }) {
  const t = useTranslations('product');
  const { addItem } = useCart();
  const [quantity, setQuantity] = useState(1);
  const [justAdded, setJustAdded] = useState(false);
  const outOfStock = product.stock <= 0;

  function handleAdd() {
    addItem(
      {
        productId: product.id,
        slug: product.slug,
        name,
        priceCents: product.price_cents,
        image: product.images?.[0] ?? null,
      },
      quantity
    );
    setJustAdded(true);
    setTimeout(() => setJustAdded(false), 1800);
  }

  if (outOfStock) {
    return (
      <p className="mt-8 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
        {t('outOfStock')}
      </p>
    );
  }

  return (
    <div className="mt-8 flex items-center gap-4">
      <select
        value={quantity}
        onChange={(e) => setQuantity(Number(e.target.value))}
        aria-label={t('quantityLabel')}
        className="border border-line bg-transparent px-3 py-3.5 font-mono text-sm text-ink"
      >
        {Array.from({ length: Math.min(product.stock, 9) }, (_, i) => i + 1).map((n) => (
          <option key={n} value={n}>
            {n}
          </option>
        ))}
      </select>
      <button
        onClick={handleAdd}
        className="flex-1 bg-ink py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90"
      >
        {justAdded ? t('added') : t('addToCart')}
      </button>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/AddToCartForm.tsx"

mkdir -p "components"
cat > "components/AdminDashboard.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useState } from 'react';
import { useLocale, useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { pickLocalized } from '@/lib/localized';
import type { Product } from '@/lib/types';

const emptyForm = {
  id: '',
  name: '',
  slug: '',
  price: '',
  stock: '',
  description: '',
  materials: '',
  dimensions: '',
  images: [] as string[],
};

export function AdminDashboard() {
  const t = useTranslations('admin');
  const locale = useLocale();
  const supabase = createClient();

  const [products, setProducts] = useState<Product[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);

  async function loadProducts() {
    const { data } = await supabase
      .from('products')
      .select('*')
      .order('created_at', { ascending: false });
    setProducts((data as Product[]) ?? []);
  }

  useEffect(() => {
    loadProducts();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
  }

  function startEdit(p: Product) {
    setEditingId(p.id);
    setForm({
      id: p.id,
      // Show the version matching whatever language the admin is
      // currently browsing in — saving will re-translate from this
      // into every language, overwriting the old translations.
      name: pickLocalized(p.name, locale),
      slug: p.slug,
      price: (p.price_cents / 100).toString(),
      stock: p.stock.toString(),
      description: pickLocalized(p.description, locale),
      materials: pickLocalized(p.materials, locale),
      dimensions: pickLocalized(p.dimensions, locale),
      images: p.images ?? [],
    });
  }

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const path = `${Date.now()}-${file.name}`;
    const { error } = await supabase.storage
      .from('product-images')
      .upload(path, file, { cacheControl: '3600', upsert: false });

    if (!error) {
      const { data } = supabase.storage.from('product-images').getPublicUrl(path);
      setForm((f) => ({ ...f, images: [...f.images, data.publicUrl] }));
    }
    setUploading(false);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    try {
      // Translate whatever the admin typed (any language) into every
      // language configured in i18n.ts, via the free Google Translate
      // wrapper running server-side in this API route.
      const res = await fetch('/api/admin/translate-product', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.name,
          description: form.description,
          materials: form.materials || null,
          dimensions: form.dimensions || null,
        }),
      });

      if (!res.ok) throw new Error('Translation request failed');
      const translated = await res.json();

      const payload = {
        name: translated.name,
        slug: form.slug || form.name.toLowerCase().trim().replace(/\s+/g, '-'),
        price_cents: Math.round(parseFloat(form.price || '0') * 100),
        stock: parseInt(form.stock || '0', 10),
        description: translated.description,
        materials: translated.materials,
        dimensions: translated.dimensions,
        images: form.images,
        currency: 'EUR',
      };

      if (editingId) {
        await supabase.from('products').update(payload).eq('id', editingId);
      } else {
        await supabase.from('products').insert(payload);
      }

      resetForm();
      await loadProducts();
    } catch (err) {
      console.error('Save product error:', err);
      alert('Could not save this object — check the browser console for details.');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm(t('confirmDelete'))) return;
    await supabase.from('products').delete().eq('id', id);
    loadProducts();
  }

  return (
    <div className="grid gap-16 lg:grid-cols-[1fr_1.2fr]">
      {/* Product list */}
      <div>
        <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('productsTab')}
        </h2>
        {products.length === 0 ? (
          <p className="mt-6 font-body text-stone">{t('noProducts')}</p>
        ) : (
          <ul className="mt-6 divide-y divide-line border-t border-line">
            {products.map((p) => (
              <li key={p.id} className="flex items-center justify-between gap-4 py-4">
                <div className="flex items-center gap-4">
                  <div className="h-14 w-12 shrink-0 bg-sand">
                    {p.images?.[0] && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.images[0]} alt="" className="h-full w-full object-cover" />
                    )}
                  </div>
                  <div>
                    <p className="font-body text-sm text-ink">{pickLocalized(p.name, locale)}</p>
                    <p className="font-mono text-[11px] text-taupe">
                      {(p.price_cents / 100).toFixed(2)} € · stock {p.stock}
                    </p>
                  </div>
                </div>
                <div className="flex gap-4">
                  <button
                    onClick={() => startEdit(p)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
                  >
                    {t('edit')}
                  </button>
                  <button
                    onClick={() => handleDelete(p.id)}
                    className="font-mono text-[11px] uppercase tracking-widest2 text-red-800 underline underline-offset-4"
                  >
                    {t('delete')}
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Product form */}
      <div>
        <h2 className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {editingId ? t('edit') : t('newProduct')}
        </h2>
        <p className="mt-2 max-w-sm font-body text-xs leading-relaxed text-taupe">
          Type in any language below — saving automatically translates it into
          every language the site supports (currently shown in {locale.toUpperCase()}).
        </p>
        <form onSubmit={handleSave} className="mt-6 flex flex-col gap-5">
          <Field label={t('name')}>
            <input
              required
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              className="input"
            />
          </Field>
          <Field label={t('slug')}>
            <input
              value={form.slug}
              onChange={(e) => setForm((f) => ({ ...f, slug: e.target.value }))}
              placeholder="auto-generated from name if left blank"
              className="input"
            />
          </Field>
          <div className="grid grid-cols-2 gap-5">
            <Field label={t('price')}>
              <input
                required
                type="number"
                step="0.01"
                value={form.price}
                onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))}
                className="input"
              />
            </Field>
            <Field label={t('stock')}>
              <input
                required
                type="number"
                value={form.stock}
                onChange={(e) => setForm((f) => ({ ...f, stock: e.target.value }))}
                className="input"
              />
            </Field>
          </div>
          <Field label={t('description')}>
            <textarea
              required
              rows={4}
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              className="input"
            />
          </Field>
          <Field label={t('materials')}>
            <input
              value={form.materials}
              onChange={(e) => setForm((f) => ({ ...f, materials: e.target.value }))}
              className="input"
            />
          </Field>
          <Field label={t('dimensions')}>
            <input
              value={form.dimensions}
              onChange={(e) => setForm((f) => ({ ...f, dimensions: e.target.value }))}
              className="input"
            />
          </Field>

          <Field label={t('images')}>
            <div className="flex flex-wrap gap-3">
              {form.images.map((src, i) => (
                <div key={i} className="h-20 w-16 bg-sand">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={src} alt="" className="h-full w-full object-cover" />
                </div>
              ))}
            </div>
            <label className="mt-3 inline-block cursor-pointer font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4">
              {uploading ? t('saving') : t('uploadImage')}
              <input type="file" accept="image/*" onChange={handleUpload} className="hidden" />
            </label>
          </Field>

          <div className="mt-2 flex gap-4">
            <button
              type="submit"
              disabled={saving}
              className="bg-ink px-8 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-opacity hover:opacity-90 disabled:opacity-50"
            >
              {saving ? 'Translating & saving…' : t('save')}
            </button>
            {editingId && (
              <button
                type="button"
                onClick={resetForm}
                className="font-mono text-[11px] uppercase tracking-widest2 text-stone underline underline-offset-4"
              >
                {t('cancel')}
              </button>
            )}
          </div>
        </form>
      </div>

      <style jsx global>{`
        .input {
          width: 100%;
          border-bottom: 1px solid #dcd0bc;
          background: transparent;
          padding: 0.5rem 0;
          font-family: var(--font-body);
          color: #211e1a;
        }
        .input:focus {
          outline: none;
          border-color: #211e1a;
        }
      `}</style>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
        {label}
      </span>
      <div className="mt-2">{children}</div>
    </label>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/AdminDashboard.tsx"

mkdir -p "app/[locale]"
cat > "app/[locale]/layout.tsx" << '__VKV_PATCH_EOF__'
import type { Metadata } from 'next';
import { Playfair_Display, Inter, IBM_Plex_Mono } from 'next/font/google';
import { NextIntlClientProvider } from 'next-intl';
import { getMessages, unstable_setRequestLocale } from 'next-intl/server';
import { notFound } from 'next/navigation';
import { locales, type Locale } from '@/i18n';
import { CartProvider } from '@/context/CartContext';
import { Header } from '@/components/Header';
import { Footer } from '@/components/Footer';
import { CartDrawer } from '@/components/CartDrawer';
import '../globals.css';

const display = Playfair_Display({
  subsets: ['latin', 'latin-ext', 'cyrillic'],
  variable: '--font-display',
  weight: ['400', '500', '600', '700'],
  style: ['normal', 'italic'],
  display: 'swap',
});

const body = Inter({
  subsets: ['latin', 'latin-ext', 'cyrillic'],
  variable: '--font-body',
  weight: ['400', '500'],
  display: 'swap',
});

const mono = IBM_Plex_Mono({
  subsets: ['latin', 'latin-ext'],
  variable: '--font-mono',
  weight: ['400', '500'],
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'vkv.form',
  description:
    'Handmade sculptural objects in clay, plaster and stone — cast, carved and finished by hand, one at a time.',
};

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  if (!locales.includes(locale as Locale)) notFound();
  unstable_setRequestLocale(locale);
  const messages = await getMessages();

  return (
    <html lang={locale} className={`${display.variable} ${body.variable} ${mono.variable}`}>
      <body className="font-body bg-cream text-ink antialiased">
        <NextIntlClientProvider locale={locale} messages={messages}>
          <CartProvider>
            <Header />
            <main>{children}</main>
            <Footer />
            <CartDrawer />
          </CartProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/layout.tsx"

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
        <div className="absolute inset-0 bg-gradient-to-t from-ink/55 via-ink/10 to-transparent" />
        <div className="relative z-10 mx-auto w-full max-w-[1400px] px-6 pb-16 md:px-10 md:pb-24">
          <p className="font-mono text-[11px] uppercase tracking-widest2 text-cocoa">
            {t('heroEyebrow')}
          </p>
          <h1 className="mt-5 max-w-2xl font-display text-[13vw] leading-[0.95] text-cream md:text-[6.2vw]">
            {heroLines.map((line, i) => (
              <span key={i} className="block">
                {i === heroLines.length - 1 ? <em className="not-italic italic">{line}</em> : line}
              </span>
            ))}
          </h1>
          <p className="mt-7 max-w-md font-body text-base leading-relaxed text-cream/90">
            {t('heroSubtitle')}
          </p>
          <Link
            href="/catalog"
            className="mt-9 inline-block border border-cream/70 px-7 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-colors hover:bg-cream hover:text-ink"
          >
            {t('heroCta')}
          </Link>
        </div>
      </section>

      {/* Philosophy */}
      <section className="mx-auto max-w-[1400px] px-6 py-28 md:px-10 md:py-36">
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
      </section>

      {/* Featured catalogue */}
      <section className="mx-auto max-w-[1400px] px-6 pb-28 md:px-10 md:pb-36">
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
      </section>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/page.tsx"

mkdir -p "app/[locale]/catalog/[slug]"
cat > "app/[locale]/catalog/[slug]/page.tsx" << '__VKV_PATCH_EOF__'
import { notFound } from 'next/navigation';
import Image from 'next/image';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { AddToCartForm } from '@/components/AddToCartForm';
import { getProductBySlug } from '@/lib/products';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';

export default async function ProductPage({
  params: { locale, slug },
}: {
  params: { locale: string; slug: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('product');
  const product = await getProductBySlug(slug);
  if (!product) notFound();

  const name = pickLocalized(product.name, locale);
  const description = pickLocalized(product.description, locale);
  const materials = pickLocalized(product.materials, locale);
  const dimensions = pickLocalized(product.dimensions, locale);

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
                alt={name}
                fill
                priority
                sizes="(min-width: 768px) 50vw, 100vw"
                className="object-cover"
              />
            )}
          </div>
        </Reveal>

        <Reveal delay={0.1}>
          <h1 className="font-display text-4xl text-ink md:text-5xl">{name}</h1>
          <p className="mt-3 font-mono text-xl text-stone">
            {formatPrice(product.price_cents, product.currency)}
          </p>

          <p className="mt-8 font-body text-base leading-relaxed text-stone">
            {description}
          </p>

          <dl className="mt-8 space-y-3 border-t border-line pt-6">
            {materials && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('materialsLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{materials}</dd>
              </div>
            )}
            {dimensions && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('dimensionsLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{dimensions}</dd>
              </div>
            )}
          </dl>

          <AddToCartForm product={product} name={name} />

          <p className="mt-6 font-body text-xs leading-relaxed text-taupe">
            {t('shippingNote')}
          </p>
        </Reveal>
      </div>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/catalog/[slug]/page.tsx"

mkdir -p "app/api/admin/translate-product"
cat > "app/api/admin/translate-product/route.ts" << '__VKV_PATCH_EOF__'
import { NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/auth';
import { translateToAllLocales } from '@/lib/translate-server';

export async function POST(req: Request) {
  // Gate this behind admin auth — it's the one place in the app that calls
  // out to the translation API, and we don't want it open to anyone.
  const admin = await requireAdmin();
  if (!admin) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  try {
    const { name, description, materials, dimensions } = await req.json();

    const [nameT, descriptionT, materialsT, dimensionsT] = await Promise.all([
      translateToAllLocales(name ?? ''),
      translateToAllLocales(description ?? ''),
      materials ? translateToAllLocales(materials) : Promise.resolve(null),
      dimensions ? translateToAllLocales(dimensions) : Promise.resolve(null),
    ]);

    return NextResponse.json({
      name: nameT,
      description: descriptionT,
      materials: materialsT,
      dimensions: dimensionsT,
    });
  } catch (err) {
    console.error('Product translation error:', err);
    return NextResponse.json({ error: 'Translation failed' }, { status: 500 });
  }
}
__VKV_PATCH_EOF__
echo "  updated: app/api/admin/translate-product/route.ts"

mkdir -p "supabase"
cat > "supabase/schema.sql" << '__VKV_PATCH_EOF__'
-- ============================================================
-- vkv.form — Supabase schema
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Free tier is plenty for this: 500MB database, 1GB file storage,
-- 50k monthly active users on Auth. See README.md for setup order.
-- ============================================================

-- ---------- profiles ----------
-- One row per auth user. role='admin' unlocks /admin.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  role text not null default 'customer' check (role in ('customer', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are readable by their owner"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Profiles are editable by their owner"
  on public.profiles for update
  using (auth.uid() = id);

-- Auto-create a profile row whenever someone signs up.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- products ----------
-- name/description/materials/dimensions are jsonb so each can hold one
-- translation per language, e.g. {"en": "Vase", "ru": "Ваза"}. Filled in
-- automatically by the admin dashboard's translate-on-save — see
-- lib/translate-server.ts and app/api/admin/translate-product/route.ts.
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name jsonb not null default '{}'::jsonb,
  price_cents integer not null check (price_cents >= 0),
  currency text not null default 'EUR',
  description jsonb not null default '{}'::jsonb,
  materials jsonb,
  dimensions jsonb,
  stock integer not null default 0,
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.products enable row level security;

create policy "Products are readable by everyone"
  on public.products for select
  using (true);

create policy "Products are writable by admins only"
  on public.products for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ---------- orders ----------
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  email text not null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'shipped', 'cancelled')),
  total_cents integer not null default 0,
  currency text not null default 'EUR',
  stripe_session_id text,
  created_at timestamptz not null default now()
);

alter table public.orders enable row level security;

create policy "Users can read their own orders"
  on public.orders for select
  using (auth.uid() = user_id);

create policy "Admins can read all orders"
  on public.orders for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- Orders are written by the Stripe webhook using the service-role key,
-- which bypasses RLS entirely — no insert policy needed for anon/auth roles.

-- ---------- contact_messages ----------
create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  message text not null,
  created_at timestamptz not null default now()
);

alter table public.contact_messages enable row level security;

create policy "Admins can read contact messages"
  on public.contact_messages for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- Inserted via the service-role key from app/api/contact/route.ts.

-- ---------- newsletter_subscribers ----------
create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);

alter table public.newsletter_subscribers enable row level security;

create policy "Anyone can subscribe"
  on public.newsletter_subscribers for insert
  with check (true);

create policy "Admins can read subscribers"
  on public.newsletter_subscribers for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- Storage: bucket for product photos, uploaded from /admin.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

create policy "Product images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'product-images');

create policy "Admins can upload product images"
  on storage.objects for insert
  with check (
    bucket_id = 'product-images'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can delete product images"
  on storage.objects for delete
  using (
    bucket_id = 'product-images'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- After running this file:
-- 1. Sign up once through /account on your running site.
-- 2. In Table Editor → profiles, find your row and change role to 'admin'.
-- 3. Reload /admin — you can now add products and upload images.
-- ============================================================
__VKV_PATCH_EOF__
echo "  updated: supabase/schema.sql"

mkdir -p "supabase"
cat > "supabase/migration-i18n-products.sql" << '__VKV_PATCH_EOF__'
-- ============================================================
-- Migration: make products multi-language (run this ONCE)
-- ------------------------------------------------------------
-- You already ran the original supabase/schema.sql, which created
-- products.name/description/materials/dimensions as plain text. This
-- migration converts them to jsonb (one translation per language) without
-- losing any existing products — old text is kept as the "en" entry, and
-- the admin dashboard will fill in the rest next time you edit and save
-- that object.
--
-- Run this in Supabase → SQL Editor → New query → Run, once.
-- ============================================================

alter table public.products
  alter column name type jsonb using jsonb_build_object('en', name),
  alter column description type jsonb using jsonb_build_object('en', description),
  alter column materials type jsonb using (
    case when materials is null then null else jsonb_build_object('en', materials) end
  ),
  alter column dimensions type jsonb using (
    case when dimensions is null then null else jsonb_build_object('en', dimensions) end
  );

alter table public.products alter column name set default '{}'::jsonb;
alter table public.products alter column description set default '{}'::jsonb;

-- Done. Existing products now show their old text under English and
-- fall back to it in every other language until you re-save them from
-- /admin (which will translate them into all seven languages at once).
__VKV_PATCH_EOF__
echo "  updated: supabase/migration-i18n-products.sql"

echo
echo "Done. Now run:"
echo "  npm install"
echo "Then, in the Supabase SQL Editor, run supabase/migration-i18n-products.sql once (only if you already ran the original schema.sql before)."