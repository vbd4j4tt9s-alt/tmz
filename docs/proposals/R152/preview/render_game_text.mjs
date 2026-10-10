// R152 preview: renders game_text.html (built by build_game_text_sheet.py) with headless Chromium (playwright) to ../game_text.png.
// Usage: PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node render_game_text.mjs [out.png]
import path from 'path';
import {fileURLToPath} from 'url';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const here = path.dirname(fileURLToPath(import.meta.url));
const out = process.argv[2] || path.join(here, '..', 'game_text.png');
const browser = await playwright.chromium.launch();
const page = await browser.newPage({viewport: {width: 1522, height: 1000}, deviceScaleFactor: 1});
await page.goto('file://' + path.join(here, 'game_text.html'));
await page.evaluate(() => document.fonts.load('20px F'));
await page.evaluate(() => document.fonts.ready);
await page.screenshot({path: out, fullPage: true});
await browser.close();
console.log('wrote', out);
