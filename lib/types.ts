import type { Locale } from '@/i18n';
export const dynamic = 'force-dynamic';

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
  height: LocalizedText | null;
  circumference: LocalizedText | null;
  depth: LocalizedText | null;
  width: LocalizedText | null;
  weight: LocalizedText | null;
  stock: number;
  available: boolean;
  images: string[];
  created_at: string;
};

export type CollectionItem = {
  id: string;
  name: LocalizedText;
  description: LocalizedText;
  images: string[];
  sold_year: string | null;
  created_at: string;
};

export type AboutPost = {
  id: string;
  title: LocalizedText;
  body: LocalizedText;
  images: string[];
  created_at: string;
};

/** Keyed the same way as messages/en.json's "about" section — the public
 * page falls back to that file's English copy for any key an admin
 * hasn't filled in yet. */
export type AboutContentMap = Record<string, LocalizedText>;

export type CartLine = {
  productId: string;
  slug: string;
  name: string;
  priceCents: number;
  image: string | null;
  quantity: number;
};

/** One line of what was actually bought, captured from the Stripe session
 * by the webhook — stored as part of the `items` jsonb column on `orders`. */
export type OrderLineItem = {
  name: string;
  quantity: number;
  amount_total: number;
};

export type CustomerAddress = {
  line1?: string | null;
  line2?: string | null;
  city?: string | null;
  postal_code?: string | null;
  country?: string | null;
};

export type CustomerDetails = {
  name?: string | null;
  email?: string | null;
  phone?: string | null;
  address?: CustomerAddress | null;
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
  items: OrderLineItem[];
  customer_details: CustomerDetails | null;
};

export type Favorite = {
  id: string;
  user_id: string;
  product_id: string;
  created_at: string;
  products?: Product;
};
