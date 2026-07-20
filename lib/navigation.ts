import { createSharedPathnamesNavigation } from 'next-intl/navigation';
import { locales, defaultLocale } from '@/i18n';

export const { Link, useRouter, usePathname, redirect } =
  createSharedPathnamesNavigation({ locales, defaultLocale, localePrefix: 'as-needed' });
