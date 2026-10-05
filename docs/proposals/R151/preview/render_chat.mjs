// R151 preview: draws the chat lines that PullAnnouncerClient writes (chat_lines.luau prints them as "LINE <rich text>") in a Roblox-style chat window with headless Chromium.
// The rich text goes in exactly as TextChatService receives it (<font color>, <b>, the five entities); only the window around it is drawn by hand. Usage:
//   node render_chat.mjs <chat.log> <out.png> [scale]
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const [logPath, outPath, scaleArg] = process.argv.slice(2);
const scale = Number(scaleArg || 2);
const lines = fs.readFileSync(logPath, 'utf8').split('\n').filter((l) => l.startsWith('LINE ')).map((l) => l.slice(5));
if (lines.length < 7) { console.error('expected 7 chat lines, got ' + lines.length); process.exit(1); }
// (the rich text is almost HTML already: <b> and the five entities are HTML as well; <font color="#RRGGBB"> becomes a span below)
const notes = [
  'In this server (Legendary and up): the rarity colour',
  'Mythic', 'Secret (its own colour is white)', 'Cosmic', 'King',
  'Other servers: gold 🌐 (a Setting switches it off)',
  'A hub record: amber 🏆',
];
const talk = [['Ava', 'nice garden!'], ['Max', 'who has a moon melon?']];
const rows = [];
rows.push({chat: `<span class="who">[${talk[0][0]}]:</span> ${talk[0][1]}`, note: ''});
lines.slice(0, 7).forEach((l, i) => rows.push({chat: l, note: notes[i]}));
rows.push({chat: `<span class="who">[${talk[1][0]}]:</span> ${talk[1][1]}`, note: ''});
const toHtml = (rich) => rich.replace(/<font color="(#[0-9A-Fa-f]{6})">/g, '<span style="color:$1">').replace(/<\/font>/g, '</span>');
const PAGE = `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0}
body{width:1000px;padding-bottom:18px;font-family:'Montserrat','Noto Sans','DejaVu Sans',sans-serif;background:#10141f;color:#e6eaf7}
h1{font-size:21px;margin:0;padding:16px 18px 2px;color:#ffe260}
p.sub{font-size:12.5px;margin:0;padding:0 18px 12px;color:#aab6d2;line-height:1.45}
.scene{margin:0 18px 16px;border-radius:10px;padding:14px;background:linear-gradient(180deg,#5da4d6 0%,#a9d8f0 45%,#6fb85c 46%,#3f8a46 100%)}
.grid{display:grid;grid-template-columns:520px 1fr;column-gap:16px;align-items:stretch}
.chat{background:rgba(22,24,28,.62);border-radius:8px;padding:6px 10px}
.line{font-size:15.5px;line-height:1.35;padding:3px 0;color:#fff;text-shadow:0 1px 2px rgba(0,0,0,.7);white-space:nowrap;overflow:hidden}
.who{color:#9ccbff}
.notes div{height:29.9px;box-sizing:border-box;padding:2px 0;display:flex;align-items:center}
.notes span{font-size:12.5px;line-height:1;color:#16202e;font-weight:700;background:rgba(255,255,255,.86);border-radius:11px;padding:5px 10px;white-space:nowrap}
.notes .empty{display:none}
b{font-weight:800}
</style></head><body>
<h1>R151 pull announcements: chat only</h1>
<p class="sub">No banner, no sound, no picture: one system line in the chat per announcement, written by the real PullAnnouncerClient and drawn here with the exact rich text that RBXGeneral:DisplaySystemMessage receives. Colours are the game's rarity colours (Secret's own colour is white: its word is bold).</p>
<div class="scene"><div class="grid"><div class="chat">${rows.map((r) => `<div class="line">${toHtml(r.chat)}</div>`).join('')}</div>
<div class="notes">${rows.map((r) => `<div>${r.note ? `<span>${r.note}</span>` : ''}</div>`).join('')}</div></div></div>
</body></html>`;
const browser = await playwright.chromium.launch();
const page = await browser.newPage({viewport: {width: 1000, height: 600}, deviceScaleFactor: scale});
await page.setContent(PAGE);
await page.waitForTimeout(200);
const box = await page.evaluate(() => { const b = document.body.getBoundingClientRect(); return {w: Math.ceil(b.width), h: Math.ceil(document.body.scrollHeight)}; });
await page.screenshot({path: outPath, clip: {x: 0, y: 0, width: box.w, height: box.h}});
await browser.close();
console.log('wrote ' + outPath + ' ' + box.w + 'x' + box.h + ' @' + scale + 'x');
