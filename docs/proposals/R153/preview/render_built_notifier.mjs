// R153 built-notifier preview. Usage: node render_built_notifier.mjs <built.json (the JSON line of dump_built_notifier.luau)> <font dir (npm install --prefix, see run script)> <out.png>
// Fills biome_notifier_built.html with the real implementation's numbers and the stand-in fonts (Fredoka One for FredokaOne, Montserrat for GothamMedium), draws it with headless Chromium (playwright) and saves the sheet as one PNG.
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const HERE = path.dirname(new URL(import.meta.url).pathname);
const [builtJson, fontDir, outPng] = process.argv.slice(2);
const b64 = (f) => fs.readFileSync(f).toString('base64');
const fp = (pkg, file) => path.join(fontDir, 'node_modules/@fontsource', pkg, 'files', file);
const face = (family, weight, file) => `@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/woff2;base64,${b64(file)}) format('woff2');}`;
const css = [
  face('Fredoka One', 400, fp('fredoka-one', 'fredoka-one-latin-400-normal.woff2')),
  ...[500, 600, 700].map((w) => face('Mont', w, fp('montserrat', `montserrat-latin-${w}-normal.woff2`))),
].join('\n');
const built = JSON.parse(fs.readFileSync(builtJson, 'utf8'));
let html = fs.readFileSync(path.join(HERE, 'biome_notifier_built.html'), 'utf8');
html = html.replace('/*FONTS*/', css).replace('/*DATA*/null', JSON.stringify({built}));
const pagePath = path.join(path.dirname(path.resolve(outPng)), 'biome_notifier_built_page.html');
fs.writeFileSync(pagePath, html);
const browser = await playwright.chromium.launch();
const page = await browser.newPage({viewport: {width: 1800, height: 1200}, deviceScaleFactor: 1});
page.on('console', (m) => { if (m.type() === 'error') console.log('page:', m.text()); });
page.on('pageerror', (e) => console.log('pageerror:', e.message));
await page.goto('file://' + pagePath);
await page.waitForFunction(() => window.ready === true, null, {timeout: 60000});
await page.evaluate(() => document.fonts.ready);
await page.locator('#sheet').screenshot({path: outPng});
console.log('wrote', outPng);
await browser.close();
