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
    { href: '/catalog', label: t('catalog') },
    { href: '/about', label: t('about') },
    { href: '/contact', label: t('contact') },
  ];

  return (
    <header className="sticky top-0 z-40 border-b border-line bg-cream/90 backdrop-blur-sm">
      <div className="mx-auto flex max-w-[1400px] items-center justify-between px-6 py-5 md:px-10">
        <Link
          href="/"
          className="font-display text-[22px] italic tracking-tight text-ink"
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
