// Renders public/og.png (1200x630) from the built page with Playwright.
// Run after a change to the hero: node build.mjs && node scripts/og.mjs
import { chromium } from 'playwright';

const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1200, height: 630 }, colorScheme: 'light' });
await p.goto(new URL('../dist/index.html', import.meta.url).href);
await p.addStyleTag({
  content: `.top,.kicker,.hero .lead,.cta,.fine{display:none}
  .hero{padding:58px 56px 0}h1{font-size:60px}
  .hero-shot{margin-top:44px}`,
});
await p.screenshot({ path: new URL('../public/og.png', import.meta.url).pathname });
await b.close();
