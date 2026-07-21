'use client';

import { useEffect, useState } from 'react';
import { Heart } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';
import { useRouter } from '@/lib/navigation';

export function FavoriteButton({ productId }: { productId: string }) {
  const t = useTranslations('product');
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [isFavorited, setIsFavorited] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    (async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) {
        const { data } = await supabase
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('product_id', productId)
          .maybeSingle();
        setIsFavorited(!!data);
      }
      setLoading(false);
    })();
  }, [productId]);

  async function toggle() {
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      router.push('/account');
      return;
    }

    if (isFavorited) {
      await supabase.from('favorites').delete().eq('user_id', user.id).eq('product_id', productId);
      setIsFavorited(false);
    } else {
      await supabase.from('favorites').insert({ user_id: user.id, product_id: productId });
      setIsFavorited(true);
    }
  }

  return (
    <button
      onClick={toggle}
      disabled={loading}
      aria-pressed={isFavorited}
      className="flex items-center gap-2 border border-line px-5 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-ink transition-colors hover:border-ink disabled:opacity-50"
    >
      <Heart size={16} strokeWidth={1.5} fill={isFavorited ? 'currentColor' : 'none'} />
      {isFavorited ? t('saved') : t('save')}
    </button>
  );
}