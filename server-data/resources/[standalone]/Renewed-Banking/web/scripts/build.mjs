import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root = resolve(import.meta.dirname, '..');
await mkdir(resolve(root, 'dist/assets'), { recursive: true });
// The bank (index) and the ATM screen painted on the machines (atm).
for (const [page, script, style] of [['index', 'main', 'styles'], ['atm', 'atm', 'atm']]) {
  const asset = page === 'index' ? 'app' : page;
  const source = await readFile(resolve(root, `src/${script}.ts`), 'utf8');
  await writeFile(resolve(root, `dist/assets/${asset}.js`), source);
  await cp(resolve(root, `src/${style}.css`), resolve(root, `dist/assets/${asset}.css`));
  await cp(resolve(root, `src/${page}.html`), resolve(root, `dist/${page}.html`));
}
console.log('Renewed Banking UI built.');
