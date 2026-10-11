// R152 preview: draws the FRAME lines of preview_sale_money.luau (the real SaleMoneyEffects on the Roblox mock) with sale_money.html in headless Chromium (playwright).
// Usage: node render_sale_money.mjs <frames.txt> <out dir>   -> <layout>_strip.png (a time strip per layout) and <layout>_NNN.png (every sampled frame, for the GIFs)
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const here = path.dirname(fileURLToPath(import.meta.url));
const [framesFile, out] = process.argv.slice(2);
fs.mkdirSync(out, {recursive: true});
const byLayout = {};
for (const line of fs.readFileSync(framesFile, 'utf8').split('\n')) {
  const m = line.match(/^FRAME (\S+) (\S+) (\{.*\})$/);
  if (!m) continue;
  (byLayout[m[1]] = byLayout[m[1]] || []).push({t: Number(m[2]), data: JSON.parse(m[3])});
}
const scale = {desktop: 0.42, phone_landscape: 0.62, phone_portrait: 0.42};
// the moments of the strip: the pop, the rest, the first launches, the stream, the last landings
const moments = [0.0, 0.2, 0.5, 0.8, 1.0, 1.15, 1.3, 1.5, 1.8];
const browser = await playwright.chromium.launch();
const page = await browser.newPage({viewport: {width: 1900, height: 900}, deviceScaleFactor: 1});
await page.goto('file://' + path.join(here, 'sale_money.html'));
await page.waitForFunction(() => window.__ready === true);
await page.evaluate(() => document.fonts.ready);
for (const [layout, frames] of Object.entries(byLayout)) {
  const k = scale[layout] || 0.5;
  const pick = moments.map((t) => frames.reduce((a, b) => (Math.abs(b.t - t) < Math.abs(a.t - t) ? b : a)));
  await page.evaluate(([f, k, c]) => window.strip(f, k, c), [pick, k, pick.map((f) => 't = ' + f.t.toFixed(2) + ' s')]);
  await page.locator('#stage').screenshot({path: path.join(out, layout + '_strip.png')});
  const kk = layout === 'phone_landscape' ? 0.8 : 0.5;
  for (let i = 0; i < frames.length; i++) {
    await page.evaluate(([f, k]) => window.show(f, k, ''), [frames[i], kk]);
    await page.locator('#stage').screenshot({path: path.join(out, layout + '_' + String(i).padStart(3, '0') + '.png')});
  }
  console.log(layout, frames.length, 'frames');
}
await browser.close();
