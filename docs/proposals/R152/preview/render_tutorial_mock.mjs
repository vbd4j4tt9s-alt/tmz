// R152 tutorial mock-up: renders tutorial_mock.html with headless Chromium (playwright) to docs/proposals/R152/tutorial.png.
// Usage: node render_tutorial_mock.mjs [out.png]
import path from 'path';
import {fileURLToPath} from 'url';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const here = path.dirname(fileURLToPath(import.meta.url));
const out = process.argv[2] || path.join(here, '..', 'tutorial.png');
const browser = await playwright.chromium.launch();
const page = await browser.newPage({viewport: {width: 1800, height: 1000}, deviceScaleFactor: 1});
await page.goto('file://' + path.join(here, 'tutorial_mock.html'));
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(300);
const sheet = await page.$('#sheet');
await sheet.screenshot({path: out});
await browser.close();
console.log('wrote', out);
