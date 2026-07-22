// Safe, one-off patch: adds ONLY product.like / product.liked if missing.
// Never overwrites existing values.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const messagesDir = path.join(__dirname, '..', 'messages');

const additions = {
  en: { like: 'Save', liked: 'Saved' },
  ru: { like: 'Сохранить', liked: 'Сохранено' },
  fr: { like: 'Enregistrer', liked: 'Enregistré' },
  es: { like: 'Guardar', liked: 'Guardado' },
  it: { like: 'Salva', liked: 'Salvato' },
  de: { like: 'Merken', liked: 'Gemerkt' },
  lv: { like: 'Saglabāt', liked: 'Saglabāts' },
};

for (const [locale, keys] of Object.entries(additions)) {
  const filePath = path.join(messagesDir, `${locale}.json`);
  let data;
  try {
    data = JSON.parse(readFileSync(filePath, 'utf-8'));
  } catch (err) {
    console.error(`Skipping ${locale}.json:`, err.message);
    continue;
  }
  if (!data.product) data.product = {};
  let added = 0;
  for (const [key, value] of Object.entries(keys)) {
    if (data.product[key] === undefined) {
      data.product[key] = value;
      added++;
    }
  }
  writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
  console.log(`${locale}.json — added ${added} missing key(s).`);
}
console.log('\nDone.');
