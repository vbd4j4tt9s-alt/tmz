// R153 biome notifier preview. Usage: node render_biome_notifier.mjs <logo dir (decode_logos.py output)> <font dir (npm install --prefix, see run script)> <out.png> [metrics.json]
// Fills biome_notifier_preview.html with the real logos (as data: URIs) and fonts (Fredoka One for the game's FredokaOne, Montserrat for GothamBold),
// draws it with headless Chromium (playwright) and saves the whole sheet as one PNG.
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const HERE = path.dirname(new URL(import.meta.url).pathname);
const [logoDir, fontDir, outPng, metricsOut] = process.argv.slice(2);

const b64 = (f) => fs.readFileSync(f).toString('base64');
const logos = {};
for (const k of ['Forest', 'Desert', 'Snow', 'Lava', 'Crystal', 'Jungle', 'Storm']) logos[k] = 'data:image/png;base64,' + b64(path.join(logoDir, `logo_${k}.png`));
const fp = (pkg, file) => path.join(fontDir, 'node_modules/@fontsource', pkg, 'files', file);
const face = (family, weight, file) => `@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/woff2;base64,${b64(file)}) format('woff2');}`;
const css = [
  face('Fredoka One', 400, fp('fredoka-one', 'fredoka-one-latin-400-normal.woff2')),
  ...[500, 600, 700].map((w) => face('Mont', w, fp('montserrat', `montserrat-latin-${w}-normal.woff2`))),
].join('\n');
let html = fs.readFileSync(path.join(HERE, 'biome_notifier_preview.html'), 'utf8');
html = html.replace('/*FONTS*/', css).replace('/*DATA*/null', JSON.stringify({logos}));
const pagePath = path.join(path.dirname(path.resolve(outPng)), 'biome_notifier_page.html');
fs.writeFileSync(pagePath, html);

const browser = await playwright.chromium.launch();
const page = await browser.newPage({viewport: {width: 1800, height: 1200}, deviceScaleFactor: 1});
page.on('console', (m) => { if (m.type() === 'error') console.log('page:', m.text()); });
page.on('pageerror', (e) => console.log('pageerror:', e.message));
await page.goto('file://' + pagePath);
await page.waitForFunction(() => window.ready === true, null, {timeout: 60000});
await page.evaluate(() => document.fonts.ready);
await page.locator('#sheet').screenshot({path: outPng});
if (metricsOut) fs.writeFileSync(metricsOut, JSON.stringify(await page.evaluate(() => window.METRICS), null, 1));
console.log('wrote', outPng);
await browser.close();
