import type { Locale } from '@/i18n';

/** A piece of text stored once per language, e.g. { en: "Vase", ru: "Ваза" }. */
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

export type Order = {
  id: string;
  user_id: string | null;
  email: string;
  status: 'pending' | 'paid' | 'shipped' | 'cancelled';
  total_cents: number;
  currency: string;
  stripe_session_id: string | null;
  created_at: string;
};
