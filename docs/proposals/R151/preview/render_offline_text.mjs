// R151 preview of the Esc-menu "Plants grow offline" text: R150's render_gui.mjs layout (UDim2 against the parent's size, AnchorPoint,
// ZIndex siblings, emoji) plus what this GUI needs: a UIGradient on TEXT (white letters x the gradient = the gradient's colours, drawn
// with background-clip:text), a Contextual UIStroke on text (drawn OUTSIDE the letters: a stroke-only copy behind the gradient copy),
// Fredoka One for FredokaOne, and per-scene HTML layers under the GUI (a stand-in game view) and over it (a stand-in of Roblox's own
// menu, which Roblox draws above every game GUI). The GUI root sits at the device safe-area offset of the screen.
// Usage: node render_offline_text.mjs <scenes.json> <outdir> <fredoka.woff2> [montserrat dir]
//   scenes.json = [{name, json (dump_tree output), screen:[w,h], offset:[x,y], under, over, scale}]
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const [scenesPath, outDir, fredoka, montDir] = process.argv.slice(2);
const scenes = JSON.parse(fs.readFileSync(scenesPath, 'utf8'));
fs.mkdirSync(outDir, {recursive: true});
function fontCss() {
  let css = '';
  if (fredoka && fs.existsSync(fredoka)) css += `@font-face{font-family:'Fredoka One';src:url('file://${fredoka}') format('woff2');}\n`;
  for (const [w, f] of [[500, 'montserrat-latin-500-normal.woff2'], [700, 'montserrat-latin-700-normal.woff2']]) {
    const p = montDir && path.join(montDir, f);
    if (p && fs.existsSync(p)) css += `@font-face{font-family:'UiFont';font-weight:${w};src:url('file://${p}') format('woff2');}\n`;
  }
  return css;
}
const PAGE = (scene, data) => `<!doctype html><html><head><meta charset="utf-8"><style>
${fontCss()}
html,body{margin:0;padding:0;background:#000;}
#stage{position:relative;overflow:hidden;font-family:'UiFont','DejaVu Sans','Noto Color Emoji',sans-serif;}
#stage div{box-sizing:border-box;}
.t{position:absolute;left:0;top:0;width:100%;height:100%;display:flex;overflow:visible;line-height:1.12;}
.t span{display:block;white-space:nowrap;}
.layer{position:absolute;left:0;top:0;width:100%;height:100%;}
</style></head><body><div id="stage"><div class="layer" id="under" style="z-index:0">${scene.under || ''}</div><div class="layer" id="gui" style="z-index:1"></div><div class="layer" id="over" style="z-index:2">${scene.over || ''}</div></div>
<script>
const DATA=${JSON.stringify(data)};const OFF=${JSON.stringify(scene.offset || [0, 0])};const SCREEN=${JSON.stringify(scene.screen)};
const rgb=(c,a=1)=>'rgba('+c[0]+','+c[1]+','+c[2]+','+a+')';
function sample(keys,t){ if(!keys||!keys.length) return null; if(t<=keys[0][0]) return keys[0][1]; for(let i=0;i<keys.length-1;i++){const [t0,v0]=keys[i],[t1,v1]=keys[i+1]; if(t<=t1){const u=t1===t0?0:(t-t0)/(t1-t0); return Array.isArray(v0)?v0.map((x,j)=>x+(v1[j]-x)*u):v0+(v1-v0)*u;}} return keys[keys.length-1][1]; }
function gradientCss(g, base){
  const times=new Set([0,1]); (g.color||[]).forEach(k=>times.add(k[0]));
  const stops=[...times].sort((a,b)=>a-b).map(t=>{ const c=g.color?sample(g.color,t):[255,255,255];
    return rgb([base[0]*c[0]/255,base[1]*c[1]/255,base[2]*c[2]/255].map(Math.round))+' '+(t*100).toFixed(2)+'%'; });
  return 'linear-gradient('+(g.rot+90)+'deg,'+stops.join(',')+')';
}
function fontFamily(name){ return name==='FredokaOne'?"'Fredoka One','Noto Color Emoji',sans-serif":"'UiFont','DejaVu Sans','Noto Color Emoji',sans-serif"; }
function textBox(n,el,cls){
  const t=n.text; const box=document.createElement('div'); box.className='t'; el.appendChild(box);
  const span=document.createElement('span'); span.textContent=t.s; box.appendChild(span);
  box.style.fontFamily=fontFamily(t.font); box.style.fontSize=t.size+'px';
  box.style.justifyContent=t.x==='Left'?'flex-start':t.x==='Right'?'flex-end':'center'; box.style.alignItems=t.y==='Top'?'flex-start':t.y==='Bottom'?'flex-end':'center';
  return span;
}
function build(n,pw,ph,parent){
  if(!n.vis) return;
  const w=n.size[0]*pw+n.size[1], h=n.size[2]*ph+n.size[3];
  const ax=n.pos[0]*pw+n.pos[1], ay=n.pos[2]*ph+n.pos[3];
  const el=document.createElement('div'); el.dataset.n=n.n;
  const s=el.style; s.position='absolute'; s.left=(ax-n.ap[0]*w)+'px'; s.top=(ay-n.ap[1]*h)+'px'; s.width=w+'px'; s.height=h+'px'; s.zIndex=n.z;
  if(n.bg) s.background=rgb(n.bg,1-n.bgA);
  parent.appendChild(el);
  if(n.text){
    const stroke=n.strokes.find(st=>st.mode!=='Border');
    if(stroke){ // outside outline: a stroke-only copy behind (a centred stroke twice as wide shows its outer half)
      const back=textBox(n,el); back.style.color=rgb(stroke.color,1-stroke.a); back.style.webkitTextStroke=(stroke.t*2)+'px '+rgb(stroke.color,1-stroke.a);
    }
    const front=textBox(n,el);
    if(n.grad){ front.style.backgroundImage=gradientCss(n.grad,n.text.color); front.style.webkitBackgroundClip='text'; front.style.backgroundClip='text'; front.style.color='transparent'; }
    else front.style.color=rgb(n.text.color,1-n.text.alpha);
  }
  for(const c of n.kids) build(c,w,h,el);
}
const stage=document.getElementById('stage'); stage.style.width=SCREEN[0]+'px'; stage.style.height=SCREEN[1]+'px';
const root=document.getElementById('gui'); root.style.left=OFF[0]+'px'; root.style.top=OFF[1]+'px'; root.style.width=DATA.canvas[0]+'px'; root.style.height=DATA.canvas[1]+'px';
for(const c of DATA.kids) build(c,DATA.canvas[0],DATA.canvas[1],root);
window.__ready=document.fonts.ready.then(()=>true);
</script></body></html>`;
const browser = await playwright.chromium.launch({args: ['--no-sandbox', '--font-render-hinting=none']});
for (const sc of scenes) {
  const data = JSON.parse(sc.json);
  const ctx = await browser.newContext({viewport: {width: sc.screen[0], height: sc.screen[1]}, deviceScaleFactor: sc.scale || 1});
  const page = await ctx.newPage();
  const file = path.join(outDir, sc.name + '.html');
  fs.writeFileSync(file, PAGE(sc, data));
  await page.goto('file://' + file);
  await page.evaluate(() => window.__ready);
  await page.waitForTimeout(150);
  await page.screenshot({path: path.join(outDir, sc.name + '.png'), clip: {x: 0, y: 0, width: sc.screen[0], height: sc.screen[1]}});
  await ctx.close();
}
await browser.close();
console.log('rendered', scenes.length, 'scenes');
