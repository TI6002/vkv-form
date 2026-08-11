'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

/**
 * Full-bleed hero slider, like the reference site (joannenajjar.com) —
 * each slide is its own full-screen block passed in as children, with
 * arrows + a "1 / 3" counter + auto-advance (paused on hover/interaction).
 */
export function HeroSlider({ slides }: { slides: ReactNode[] }) {
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(false);
  const count = slides.length;
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  function goTo(i: number) {
    setIndex(((i % count) + count) % count);
  }
  function next() {
    goTo(index + 1);
  }
  function prev() {
    goTo(index - 1);
  }

  useEffect(() => {
    if (paused || count <= 1) return;
    timerRef.current = setInterval(() => {
      setIndex((i) => (i + 1) % count);
    }, 6000);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paused, count]);

  return (
    <div
      // Shorter on phones so images that switch to object-contain
      // (see HomePage — event slides with baked-in text) don't leave
      // huge empty letterbox bars; back up to the original full-bleed
      // height from tablet width up.
      className="relative h-[70vh] w-full overflow-hidden sm:h-[80vh] md:h-[92vh]"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
    >
      {slides.map((slide, i) => (
        <div
          key={i}
          aria-hidden={i !== index}
          className={`absolute inset-0 transition-opacity duration-[1200ms] ease-signature ${
            i === index ? 'z-10 opacity-100' : 'pointer-events-none z-0 opacity-0'
          }`}
        >
          {slide}
        </div>
      ))}

      {count > 1 && (
        <>
          <button
            onClick={prev}
            aria-label="Previous slide"
            className="absolute left-4 top-1/2 z-20 flex h-10 w-10 -translate-y-1/2 items-center justify-center bg-cream/80 text-ink transition-colors hover:bg-cream md:left-8"
          >
            <ChevronLeft size={20} />
          </button>
          <button
            onClick={next}
            aria-label="Next slide"
            className="absolute right-4 top-1/2 z-20 flex h-10 w-10 -translate-y-1/2 items-center justify-center bg-cream/80 text-ink transition-colors hover:bg-cream md:right-8"
          >
            <ChevronRight size={20} />
          </button>

          <div className="absolute bottom-6 right-6 z-20 flex items-center gap-3 md:bottom-8 md:right-10">
            <span className="font-mono text-[11px] tracking-widest2 text-white [text-shadow:0_1px_4px_rgba(0,0,0,0.5)]">
              {index + 1} / {count}
            </span>
            <div className="flex gap-1.5">
              {slides.map((_, i) => (
                <button
                  key={i}
                  onClick={() => goTo(i)}
                  aria-label={`Go to slide ${i + 1}`}
                  className={`h-1.5 w-1.5 rounded-full transition-all ${
                    i === index ? 'w-4 bg-white' : 'bg-white/50'
                  }`}
                />
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
