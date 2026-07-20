import type { Product } from './types';

export const demoProducts: Product[] = [
  {
    id: 'demo-1',
    slug: 'volta-vase',
    name: 'Volta Vase',
    price_cents: 18800,
    currency: 'EUR',
    description:
      'A hand-built stoneware vase with a soft asymmetric lean, left unglazed to show the raw clay body. Each one is thrown and altered by hand, so the exact curve varies slightly from piece to piece.',
    materials: 'Unglazed stoneware, sealed interior',
    dimensions: 'H 32 cm · Ø 16 cm',
    stock: 4,
    images: ['https://picsum.photos/seed/vkv-volta/1000/1250'],
    created_at: new Date().toISOString(),
  },
  {
    id: 'demo-2',
    slug: 'muted-bowl-no-2',
    name: 'Muted Bowl No. 2',
    price_cents: 9400,
    currency: 'EUR',
    description:
      'A shallow bowl in tinted plaster with a soft, chalky surface. Suited to a single piece of fruit or a scatter of keys — it is meant to be used, not shelved.',
    materials: 'Tinted plaster, wax-sealed',
    dimensions: 'H 6 cm · Ø 24 cm',
    stock: 7,
    images: ['https://picsum.photos/seed/vkv-bowl/1000/1250'],
    created_at: new Date().toISOString(),
  },
  {
    id: 'demo-3',
    slug: 'still-form-obelisk',
    name: 'Still Form Obelisk',
    price_cents: 24200,
    currency: 'EUR',
    description:
      'A carved soft-stone obelisk, hand-finished with a matte, slightly porous surface. Reads as sculpture on its own, or as a quiet anchor on a shelf of smaller objects.',
    materials: 'Soft natural stone',
    dimensions: 'H 38 cm · W 8 cm · D 8 cm',
    stock: 2,
    images: ['https://picsum.photos/seed/vkv-obelisk/1000/1250'],
    created_at: new Date().toISOString(),
  },
];
