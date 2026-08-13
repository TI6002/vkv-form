import { createClient } from '@/lib/supabase/server';
import type { CollectionItem } from '@/lib/types';
export const dynamic = 'force-dynamic';

/**
 * Fetches Collection Book items in the admin-controlled manual order
 * (sort_order — set by the up/down buttons in /admin). Items that
 * haven't been manually ordered yet have sort_order = null, which
 * Postgres places last in ascending order automatically — so newly
 * archived pieces always land at the end until the admin moves them.
 * Among those, newest first.
 */
export async function getCollectionItems(): Promise<CollectionItem[]> {
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('collection_items')
      .select('*')
      .order('sort_order', { ascending: true, nullsFirst: false })
      .order('created_at', { ascending: false });
    if (error) {
      console.error('[getCollectionItems] Supabase error:', error);
      return [];
    }
    return (data as CollectionItem[]) ?? [];
  } catch (err) {
    console.error('[getCollectionItems] Unexpected error:', err);
    return [];
  }
}
