#!/usr/bin/env bash
set -e
echo "Applying vkv.form updates (round 8 — error boundary)..."

mkdir -p "app/[locale]"
cat > "app/[locale]/error.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect } from 'react';

/**
 * Next.js calls this automatically whenever a runtime error is thrown
 * anywhere inside app/[locale]/**. Instead of the page being stuck (or,
 * in dev, the red crash overlay), the person sees a plain "something
 * went wrong" screen with a button that re-renders just this part of
 * the tree — no full page reload needed.
 *
 * This does not fix whatever throws the error in the first place, but it
 * means a one-off glitch (e.g. a browser extension mutating the page's
 * DOM behind React's back, which is what "NotFoundError: removeChild"
 * usually is) is one click to recover from instead of a dead end.
 */
export default function LocaleError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('Caught by app/[locale]/error.tsx:', error);
  }, [error]);

  return (
    <div className="mx-auto flex min-h-[70vh] max-w-[1400px] flex-col items-center justify-center px-6 text-center">
      <p className="font-mono text-[11px] uppercase tracking-widest2 text-taupe">
        Something went wrong
      </p>
      <h1 className="mt-4 font-display text-3xl text-ink">
        This page hit a snag.
      </h1>
      <p className="mt-4 max-w-md font-body text-sm leading-relaxed text-stone">
        This is often caused by a browser extension (translators, grammar
        checkers, ad blockers) editing the page behind the scenes. Try again
        below — if it keeps happening, try this same page in an incognito
        window with extensions off.
      </p>
      <button
        onClick={() => reset()}
        className="mt-8 border border-ink px-7 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream"
      >
        Try again
      </button>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/error.tsx"

echo
echo "Done. Restart npm run dev after this."