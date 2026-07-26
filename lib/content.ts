import { createClient } from '@/lib/supabase/server';
import type { AboutContentMap, AboutPost, CollectionItem } from '@/lib/types';

const supabaseConfigured =
  !!process.env.NEXT_PUBLIC_SUPABASE_URL && !!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

/** Every editable field on /about, keyed the same as messages/en.json's
 * "about" section, so the page can fall back to that built-in copy for
 * anything the admin hasn't filled in yet. */
export async function getAboutContent(): Promise<AboutContentMap> {
  if (!supabaseConfigured) return {};
  try {
    const supabase = createClient();
    const { data, error } = await supabase.from('about_content').select('key, value');
    if (error || !data) return {};
    const map: AboutContentMap = {};
    for (const row of data) map[row.key] = row.value ?? {};
    return map;
  } catch {
    return {};
  }
}

export async function getAboutPosts(): Promise<AboutPost[]> {
  if (!supabaseConfigured) return [];
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('about_posts')
      .select('*')
      .order('created_at', { ascending: false });
    if (error || !data) return [];
    return data as AboutPost[];
  } catch {
    return [];
  }
}

export async function getAboutPostById(id: string): Promise<AboutPost | null> {
  if (!supabaseConfigured) return null;
  try {
    const supabase = createClient();
    const { data, error } = await supabase.from('about_posts').select('*').eq('id', id).single();
    if (error || !data) return null;
    return data as AboutPost;
  } catch {
    return null;
  }
}

export async function getCollectionItems(): Promise<CollectionItem[]> {
  if (!supabaseConfigured) return [];
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('collection_items')
      .select('*')
      .order('created_at', { ascending: false });
    if (error || !data) return [];
    return data as CollectionItem[];
  } catch {
    return [];
  }
}
