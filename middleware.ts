import createMiddleware from 'next-intl/middleware';
import { locales, defaultLocale } from './i18n';

export default createMiddleware({
  locales,
  defaultLocale,
  localePrefix: 'as-needed', // English lives at "/", other locales at "/fr", "/ru", etc.
});

export const config = {
  // Skip API routes, Next internals, and static files.
  matcher: ['/((?!api|_next|.*\\..*).*)'],
};
