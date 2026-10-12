// Builds the static site into dist/. No dependencies: node build.mjs
import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { round, shot } from './src/shots.mjs';

const SITE = 'https://mollygram.dev';
const REPO = 'https://github.com/mollybyte/mollygram';
const here = (p) => new URL(p, import.meta.url);

const css = (await readFile(here('src/site.css'), 'utf8'))
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/\s+/g, ' ')
  .replace(/\s*([{};,>])\s*/g, '$1')
  .replace(/;}/g, '}')
  .trim();

// The tile from docs/assets/icon.svg, inline so the header needs no request.
const logo = (await readFile(here('../docs/assets/icon.svg'), 'utf8'))
  .replace(/<svg[^>]*>/, '<svg width="26" height="26" viewBox="6 6 88 88" aria-hidden="true">')
  .replace(/\s*\n\s*/g, '');

function page(template) {
  return template
    .replace(/{{CSS}}/g, () => css)
    .replace(/{{LOGO}}/g, () => logo)
    .replace(/{{ROUND}}/g, () => round(280, '0:04 / 0:12'))
    .replace(/{{SHOT:(\w+)(?::(\w+))?}}/g, (_, screen, size) => shot(screen, size))
    .replace(/{{SITE}}/g, SITE)
    .replace(/{{REPO}}/g, REPO)
    .replace(/{{RELEASES}}/g, `${REPO}/releases`);
}

const dist = here('dist/');
await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
await cp(here('public/'), dist, { recursive: true });
await cp(here('../docs/assets/icon.svg'), new URL('icon.svg', dist));
for (const name of ['index.html', '404.html']) {
  const html = page(await readFile(here(`src/${name}`), 'utf8'));
  if (/{{[A-Z]/.test(html)) throw new Error(`unreplaced placeholder in ${name}`);
  await writeFile(new URL(name, dist), html);
}
console.log('Built website/dist');
