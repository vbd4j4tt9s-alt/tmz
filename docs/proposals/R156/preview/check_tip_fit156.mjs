// R156 preview check: does EVERY tip of TitleTips156 fit the tip line on each screen size (the line's box is the one TitleScreen104 lays out; TextScaled shrinks the text to fit,
// 11 px at the smallest)? Opens the rendered pages (<scratch>/png/pc_1.html, land_1.html, port_1.html), puts each tip into the TipLine label, runs the renderer's fit and reports
// the font size and the number of lines. Exits 1 if a tip does not fit its box or would need less than 11 px, or runs to more than 2 lines on a portrait phone / 1 line elsewhere.
// Usage: node check_tip_fit156.mjs <scratch dir> <TitleTips156.lua>
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const [scratch, listFile] = process.argv.slice(2);
const lua = fs.readFileSync(listFile, 'utf8');
const tips = [...lua.matchAll(/\{Kind='(\w+)',Text='((?:[^'\\]|\\.)*)'\}/g)].map(m => ({kind: m[1], text: m[2].replace(/\\'/g, "'")}));
const browser = await playwright.chromium.launch({args: ['--no-sandbox', '--font-render-hinting=none']});
let bad = 0;
const longest = {};
for (const [view, w, h, maxLines] of [['pc', 1920, 1080, 1], ['land', 844, 390, 1], ['port', 390, 844, 2]]) {
  const page = await (await browser.newContext({viewport: {width: w, height: h}})).newPage();
  await page.goto('file://' + path.join(scratch, 'png', view + '_1.html'));
  await page.evaluate(() => window.__ready);
  for (const tip of tips) {
    const r = await page.evaluate((text) => {
      const el = document.querySelector('[data-n="TipLine"]');
      const e = scaled.find(x => x.box.parentNode === el);
      e.span.innerHTML = richHtml('<font color="#77E542">tip:</font> ' + text);
      fitAll();
      const size = parseFloat(e.box.style.fontSize);
      const rc = e.span.getBoundingClientRect();
      const lines = Math.round(rc.height / (size * 1.12));
      return {size, lines, fits: e.span.scrollWidth <= e.w + 1 && rc.height <= e.h + 1, h: e.h, w: e.w};
    }, tip.text);
    const ok = r.fits && r.size >= 11 && r.lines <= maxLines;
    if (!ok) { bad++; console.log('FAIL', view, JSON.stringify(r), tip.text); }
    if (!longest[view] || r.size < longest[view].size) longest[view] = {size: r.size, lines: r.lines, text: tip.text};
  }
  await page.close();
}
await browser.close();
for (const [view, v] of Object.entries(longest)) console.log(`FIT ${view}: smallest text ${v.size}px, ${v.lines} line(s): "${v.text}"`);
console.log(`checked ${tips.length} tips x 3 sizes: ${bad ? bad + ' FAIL' : 'all fit'}`);
process.exit(bad ? 1 : 0);
