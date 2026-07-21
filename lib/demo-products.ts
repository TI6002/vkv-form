import type { Product } from './types';

export const demoProducts: Product[] = [
  {
    id: 'demo-1',
    slug: 'volta-vase',
    name: { en: 'Volta Vase' },
    price_cents: 18800,
    currency: 'EUR',
    description: {
      en: 'A hand-built stoneware vase with a soft asymmetric lean, left unglazed to show the raw clay body. Each one is thrown and altered by hand, so the exact curve varies slightly from piece to piece.',
    },
    materials: { en: 'Unglazed stoneware, sealed interior' },
    dimensions: { en: 'H 32 cm · Ø 16 cm' },
    stock: 4,
    images: ['/images/product-1.png'],
    created_at: new Date().toISOString(),
  },
  {
    id: 'demo-2',
    slug: 'muted-bowl-no-2',
    name: { en: 'Muted Bowl No. 2' },
    price_cents: 9400,
    currency: 'EUR',
    description: {
      en: 'A shallow bowl in tinted plaster with a soft, chalky surface. Suited to a single piece of fruit or a scatter of keys — it is meant to be used, not shelved.',
    },
    materials: { en: 'Tinted plaster, wax-sealed' },
    dimensions: { en: 'H 6 cm · Ø 24 cm' },
    stock: 7,
    images: ['/images/product-2.png'],
    created_at: new Date().toISOString(),
  },
  {
    id: 'demo-3',
    slug: 'still-form-obelisk',
    name: { en: 'Still Form Obelisk' },
    price_cents: 24200,
    currency: 'EUR',
    description: {
      en: 'A carved soft-stone obelisk, hand-finished with a matte, slightly porous surface. Reads as sculpture on its own, or as a quiet anchor on a shelf of smaller objects.',
    },
    materials: { en: 'Soft natural stone' },
    dimensions: { en: 'H 38 cm · W 8 cm · D 8 cm' },
    stock: 2,
    images: ['/images/product-3.png'],
    created_at: new Date().toISOString(),
  },
];
