import { createClient } from '@/lib/supabase/server';
import { demoProducts } from '@/lib/demo-products';
import type { Product } from '@/lib/types';
export const dynamic = 'force-dynamic';

const supabaseConfigured =
  !!process.env.NEXT_PUBLIC_SUPABASE_URL && !!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export async function getProducts(): Promise<Product[]> {
  if (!supabaseConfigured) return demoProducts;
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('[getProducts] Supabase error — falling back to demo products:', error);
      return demoProducts;
    }
    if (!data || data.length === 0) return demoProducts;
    return data as Product[];
  } catch (err) {
    console.error('[getProducts] Unexpected error — falling back to demo products:', err);
    return demoProducts;
  }
}

export async function getProductBySlug(slug: string): Promise<Product | null> {
  if (!supabaseConfigured) return demoProducts.find((p) => p.slug === slug) ?? null;
  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .eq('slug', slug)
      .single();
    if (error) {
      console.error(`[getProductBySlug:${slug}] Supabase error:`, error);
      return demoProducts.find((p) => p.slug === slug) ?? null;
    }
    if (!data) return demoProducts.find((p) => p.slug === slug) ?? null;
    return data as Product;
  } catch (err) {
    console.error(`[getProductBySlug:${slug}] Unexpected error:`, err);
    return demoProducts.find((p) => p.slug === slug) ?? null;
  }
}
