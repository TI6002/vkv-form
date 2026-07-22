'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { Heart } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { useRouter } from '@/lib/navigation';

/**
 * Heart-shaped save/like toggle. Works for signed-out visitors too — it
 * just sends them to /account to sign in first, then they can come back
 * and save it. Liked products show up on /account under "Saved objects".
 */
export function LikeButton({
  productId,
  variant = 'button',
}: {
  productId: string;
  variant?: 'button' | 'icon';
}) {
  const t = useTranslations('product');
  const router = useRouter();
  const supabase = createClient();

  const [userId, setUserId] = useState<string | null | undefined>(undefined); // undefined = not checked yet
  const [liked, setLiked] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let active = true;
    (async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!active) return;
      setUserId(user?.id ?? null);

      if (user) {
        const { data } = await supabase
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('product_id', productId)
          .maybeSingle();
        if (active) setLiked(!!data);
      }
    })();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [productId]);

  async function toggle(e?: React.MouseEvent) {
    e?.preventDefault();
    e?.stopPropagation();

    if (!userId) {
      router.push('/account');
      return;
    }

    setBusy(true);
    if (liked) {
      await supabase.from('favorites').delete().eq('user_id', userId).eq('product_id', productId);
      setLiked(false);
    } else {
      await supabase.from('favorites').insert({ user_id: userId, product_id: productId });
      setLiked(true);
    }
    setBusy(false);
  }

  if (variant === 'icon') {
    return (
      <button
        onClick={toggle}
        disabled={busy}
        aria-label={liked ? t('liked') : t('like')}
        className="flex h-9 w-9 items-center justify-center bg-cream/90 text-ink transition-transform hover:scale-105 disabled:opacity-50"
      >
        <Heart size={16} strokeWidth={1.5} fill={liked ? 'currentColor' : 'none'} />
      </button>
    );
  }

  return (
    <button
      onClick={toggle}
      disabled={busy}
      className="flex items-center justify-center gap-2 border border-ink px-7 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:bg-ink hover:text-cream disabled:opacity-50"
    >
      <Heart size={14} strokeWidth={1.5} fill={liked ? 'currentColor' : 'none'} />
      {liked ? t('liked') : t('like')}
    </button>
  );
}
