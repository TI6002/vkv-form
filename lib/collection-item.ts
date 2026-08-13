import { createClient } from '@/lib/supabase/server';
import type { CollectionItem } from '@/lib/types';

export async function getCollectionItemById(id: string): Promise<CollectionItem | null> {
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('collection_items')
      .select('*')
      .eq('id', id)
      .single();
    if (error) {
      console.error(`[getCollectionItemById:${id}] Supabase error:`, error);
      return null;
    }
    return (data as CollectionItem) ?? null;
  } catch (err) {
    console.error(`[getCollectionItemById:${id}] Unexpected error:`, err);
    return null;
  }
}
