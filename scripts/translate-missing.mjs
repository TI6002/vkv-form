/**
 * Automated translation for /messages/*.json
 * ------------------------------------------
 * You never translate anything by hand. Write copy once, in English, in
 * messages/en.json. Run:
 *
 *    npm run translate
 *
 * This walks every other locale in i18n.ts, finds any string that is new
 * or changed in en.json, and machine-translates just that string — existing
 * translations are left untouched so you can hand-polish a line later
 * without it being overwritten next run.
 *
 * Uses @vitalets/google-translate-api, a free wrapper around Google
 * Translate's public web endpoint — no API key, no billing account.
 * If you later want higher-volume / higher-quality translation, swap the
 * translateText() function below for the paid Google Cloud Translate API
 * or DeepL API — same script, one function to change.
 */
import { translate } from '@vitalets/google-translate-api';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const messagesDir = path.join(__dirname, '..', 'messages');

// Keep this in sync with i18n.ts locales.
const targetLocales = ['fr', 'it', 'es', 'de', 'ru', 'lv'];
const sourceLocale = 'en';

async function readJson(file) {
  try {
    const raw = await readFile(file, 'utf-8');
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function translateText(text, targetLang) {
  if (!text.trim()) return text;
  const { text: translated } = await translate(text, { to: targetLang });
  return translated;
}

/**
 * Recursively fills `target` with translations of any key in `source`
 * that is missing from `target`. Mutates and returns `target`.
 */
async function fillMissing(source, target, targetLang, keyPath = []) {
  for (const [key, value] of Object.entries(source)) {
    const nextPath = [...keyPath, key];
    if (isPlainObject(value)) {
      if (!isPlainObject(target[key])) target[key] = {};
      await fillMissing(value, target[key], targetLang, nextPath);
    } else if (typeof value === 'string') {
      if (typeof target[key] !== 'string') {
        const translated = await translateText(value, targetLang);
        target[key] = translated;
        console.log(`  [${targetLang}] ${nextPath.join('.')} -> "${translated}"`);
      }
    }
  }
  return target;
}

async function main() {
  const sourcePath = path.join(messagesDir, `${sourceLocale}.json`);
  const source = await readJson(sourcePath);

  for (const locale of targetLocales) {
    console.log(`\nTranslating missing strings into "${locale}"...`);
    const targetPath = path.join(messagesDir, `${locale}.json`);
    const existing = await readJson(targetPath);
    const filled = await fillMissing(source, existing, locale);
    await writeFile(targetPath, JSON.stringify(filled, null, 2) + '\n', 'utf-8');
    console.log(`Saved ${targetPath}`);
  }

  console.log('\nDone. Review the new files — machine translation is a first draft, not a final one.');
}

main().catch((err) => {
  console.error('Translation run failed:', err);
  process.exit(1);
});
