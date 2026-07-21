import type { Locale } from '@/i18n';

export type LocalizedText = Partial<Record<Locale, string>>;

export type Product = {
  id: string;
  slug: string;
  name: LocalizedText;
  price_cents: number;
  currency: string;
  description: LocalizedText;
  materials: LocalizedText | null;
  dimensions: LocalizedText | null;
  stock: number;
  available: boolean;
  images: string[];
  created_at: string;
};

export type CartLine = {
  productId: string;
  slug: string;
  name: string;
  priceCents: number;
  image: string | null;
  quantity: number;
};

export type OrderItem = {
  id: string;
  order_id: string;
  product_id: string | null;
  product_name: string;
  quantity: number;
  unit_price_cents: number;
  created_at: string;
};

export type Order = {
  id: string;
  order_number: number;
  user_id: string | null;
  email: string;
  status: 'pending' | 'paid' | 'shipped' | 'cancelled';
  total_cents: number;
  currency: string;
  stripe_session_id: string | null;
  created_at: string;
  order_items?: OrderItem[];
};

export type Favorite = {
  id: string;
  user_id: string;
  product_id: string;
  created_at: string;
  products?: Product;
};