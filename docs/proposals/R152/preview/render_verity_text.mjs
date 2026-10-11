// R152 preview: draws Verity's quest window with her new texts (verity_text.html, texts from copy.json) with headless Chromium (playwright).
// Usage: node render_verity_text.mjs [out.png]   (default: ../verity_text.png)
// copy.json = the strings of VerityConfig (Quest, RewardText, Thanks, Notice, Dialog, Hint, Reasons, Event, prompt) and NoticeCopy83.Arrival(); it is
// printed by running the two real modules on the Roblox mock (see verity_text.md, "How the preview is made"), so it never drifts from the code.
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const here = path.dirname(fileURLToPath(import.meta.url));
const out = process.argv[2] || path.join(here, '..', 'verity_text.png');
const copy = JSON.parse(fs.readFileSync(path.join(here, 'copy.json'), 'utf8'));
const browser = await playwright.chromium.launch();
const page = await browser.newPage({viewport: {width: 1522, height: 1000}, deviceScaleFactor: 1});
await page.goto('file://' + path.join(here, 'verity_text.html'));
await page.evaluate(() => document.fonts.load('20px F'));
await page.evaluate(() => document.fonts.ready);
await page.evaluate((c) => window.draw(c), copy);
await page.waitForFunction(() => window.__ready === true);
await page.evaluate(() => document.fonts.ready);
// any label the fitter had to cut ("...") is a problem: say so
const cut = await page.evaluate(() => [...document.querySelectorAll('.lbl')].filter((d) => d.dataset.cut).map((d) => d.textContent));
if (cut.length) console.log('CUT LABELS:', JSON.stringify(cut));
// the smallest fitted sizes (the stat box titles are 8 px in the sideways layout, as before R152: their box is 12 px high there)
const small = await page.evaluate(() => [...document.querySelectorAll('.lbl')].filter((d) => Number(d.dataset.size) > 0 && Number(d.dataset.size) < 12).map((d) => d.dataset.size + 'px ' + d.textContent));
console.log('labels fitted below 12 px:', [...new Set(small)].join(' | '));
await page.screenshot({path: out, fullPage: true});
await browser.close();
console.log('wrote', out);
