// R156 preview check, on the rendered pages (<scratch>/png/pc_1.html, land_1.html, port_1.html):
//  1. FIT: every tip of TitleTips156 (the RichText lines the scene printed, TIPLINE, made by the real TitleTips156.Line) fits the tip line's box on each screen size (TextScaled shrinks the
//     text to fit, 11 px at the smallest; one line on a PC / landscape phone, two on a portrait phone).
//  2. NO OVERLAP: the tip line's box, grown by the pulse (+5%) and the bob (1.5 px), keeps 4 px clear of the logo's box (the pack art is inside it) and of the button grown by its hover
//     scale (3.5%), and it is vertically centred in the gap between the two (to within the 1.5 px bob).
// Exits 1 on any failure.   Usage: node check_tip_fit156.mjs <scratch dir>
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const scratch = process.argv[2];
const lines = fs.readFileSync(path.join(scratch, 'pc', 'scenes.log'), 'utf8').split('\n').filter(l => l.startsWith('TIPLINE\t')).map(l => l.split('\t'));
const browser = await playwright.chromium.launch({args: ['--no-sandbox', '--font-render-hinting=none']});
let bad = 0;
const smallest = {};
for (const [view, w, h, maxLines] of [['pc', 1920, 1080, 1], ['land', 844, 390, 1], ['port', 390, 844, 2]]) {
  const page = await (await browser.newContext({viewport: {width: w, height: h}})).newPage();
  await page.goto('file://' + path.join(scratch, 'png', view + '_1.html'));
  await page.evaluate(() => window.__ready);
  for (const [, kind, rich] of lines) {
    const r = await page.evaluate((rich) => {
      const el = document.querySelector('[data-n="TipLine"]');
      const e = scaled.find(x => x.box.parentNode === el);
      e.span.innerHTML = richHtml(rich);
      fitAll();
      const size = parseFloat(e.box.style.fontSize);
      const rc = e.span.getBoundingClientRect();
      const lines = Math.round(rc.height / (size * 1.12));
      return {size, lines, fits: e.span.scrollWidth <= e.w + 1 && rc.height <= e.h + 1};
    }, rich);
    const ok = r.fits && r.size >= 11 && r.lines <= maxLines;
    if (!ok) { bad++; console.log('FAIL fit', view, JSON.stringify(r), rich); }
    if (!smallest[view] || r.size < smallest[view].size) smallest[view] = {size: r.size, lines: r.lines, text: rich.replace(/<[^>]+>/g, '')};
  }
  // overlap + centring (the page shows tip 1 settled at pulse scale 1: the real boxes)
  const g = await page.evaluate(() => {
    const rect = n => { const r = document.querySelector('[data-n="' + n + '"]').getBoundingClientRect(); return {l: r.left, t: r.top, r: r.right, b: r.bottom}; };
    return {logo: rect('Logo'), tip: rect('TipLine'), button: rect('ClickToStart')};
  });
  const grow = (r, f, px) => { const cx = (r.l + r.r) / 2, cy = (r.t + r.b) / 2, hw = (r.r - r.l) / 2 * f + px, hh = (r.b - r.t) / 2 * f + px; return {l: cx - hw, r: cx + hw, t: cy - hh, b: cy + hh}; };
  const tip = grow(g.tip, 1.05, 1.5), button = grow(g.button, 1.035, 0), logo = g.logo;
  const clearAbove = tip.t - logo.b, clearBelow = button.t - tip.b;
  const centred = Math.abs((g.tip.t + g.tip.b) / 2 - (logo.b + g.button.t) / 2); // (the rendered frame includes the bob, up to 1.5 px)
  console.log(`OVERLAP ${view}: logo bottom ${logo.b.toFixed(1)}, tip box ${g.tip.t.toFixed(1)}..${g.tip.b.toFixed(1)} (pulsing ${tip.t.toFixed(1)}..${tip.b.toFixed(1)}), button top ${g.button.t.toFixed(1)} (hovered ${button.t.toFixed(1)}): air above ${clearAbove.toFixed(1)} px, below ${clearBelow.toFixed(1)} px, off-centre by ${centred.toFixed(2)} px`);
  if (clearAbove < 4 || clearBelow < 4 || centred > 1.6) { bad++; console.log('FAIL overlap / centring', view); }
  const horizontal = tip.l >= 0 && tip.r <= w;
  if (!horizontal) { bad++; console.log('FAIL the pulsing tip box leaves the screen', view, tip.l, tip.r); }
  await page.close();
}
await browser.close();
for (const [view, v] of Object.entries(smallest)) console.log(`FIT ${view}: smallest text ${v.size}px, ${v.lines} line(s): "${v.text}"`);
console.log(`checked ${lines.length} tips x 3 sizes (fit) and 3 sizes (no overlap, centred): ${bad ? bad + ' FAIL' : 'all good'}`);
process.exit(bad ? 1 : 0);
