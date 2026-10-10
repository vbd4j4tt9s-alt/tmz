// R151 speed popups preview. Usage: node render_preview.mjs <frames.log (sim_popups.luau output)> <reference_numbers.json> <outdir> [fontdir]
// Draws preview_page.html with headless Chromium (playwright): outdir/strip.png (the comparison sheet) and outdir/gif/g000.png.. (one image per
// 1/30 s of the side by side animation; make_gif.py joins them). Fredoka One (from @fontsource/fredoka-one, if installed in fontdir) stands in for
// Roblox's FredokaOne; the emoji is Noto Color Emoji.
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const HERE = path.dirname(new URL(import.meta.url).pathname);
const [framesPath, refPath, outDir, fontDir] = process.argv.slice(2);
fs.mkdirSync(path.join(outDir, 'gif'), {recursive: true});

const frames = {}; let style = null;
for (const line of fs.readFileSync(framesPath, 'utf8').split('\n')) {
  let m = line.match(/^FRAME (\S+) (\d+) (.*)$/);
  if (m) { (frames[m[1]] = frames[m[1]] || [])[+m[2]] = JSON.parse(m[3]); continue; }
  m = line.match(/^STYLE (.*)$/);
  if (m) style = JSON.parse(m[1]);
}
const data = {frames, style, ref: JSON.parse(fs.readFileSync(refPath, 'utf8'))};
let font = '';
const fontFile = fontDir && path.join(fontDir, 'node_modules/@fontsource/fredoka-one/files/fredoka-one-latin-400-normal.woff2');
if (fontFile && fs.existsSync(fontFile)) font = `@font-face{font-family:'RbxFredoka';font-weight:700;src:url('file://${fontFile}') format('woff2');}`;
else console.log('no Fredoka One font: falling back to DejaVu Sans');
let html = fs.readFileSync(path.join(HERE, 'preview_page.html'), 'utf8');
html = html.replace('/*FONT*/', font).replace('/*DATA*/null', JSON.stringify(data));
const pagePath = path.join(outDir, 'preview_page.html');
fs.writeFileSync(pagePath, html);

const browser = await playwright.chromium.launch();
const page = await browser.newPage({viewport: {width: 1800, height: 1200}, deviceScaleFactor: 1});
page.on('console', (m) => { if (m.type() === 'error') console.log('page:', m.text()); });
page.on('pageerror', (e) => console.log('pageerror:', e.message));
await page.goto('file://' + pagePath);
await page.waitForFunction(() => window.ready === true);
await page.evaluate(() => document.fonts.ready);
await page.locator('#strip').screenshot({path: path.join(outDir, 'strip.png')});
const n = data.frames.now.length;
for (let i = 0; i < n; i++) {
  await page.evaluate((k) => window.setGif(k), i);
  await page.locator('#gif').screenshot({path: path.join(outDir, 'gif', 'g' + String(i).padStart(3, '0') + '.png')});
}
console.log('rendered strip.png and', n, 'gif frames');
await browser.close();
