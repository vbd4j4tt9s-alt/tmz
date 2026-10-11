// R150 preview: draws the nested GUI JSON of dump_tree.luau with headless Chromium (playwright). Layout follows Roblox: a child's
// UDim2 resolves against its parent's UNSCALED size, AnchorPoint is the pivot of position / UIScale (rotation turns about the centre), UICorner radius =
// scale * min side + offset, UIStroke (Border) draws outside the frame, UIGradient multiplies the background colour, siblings are
// stacked by ZIndex (every child starts a stacking context, so a child never interleaves with another sibling's subtree),
// ClipsDescendants clips to the RECTANGLE (not the rounded corners), TextScaled shrinks to fit between MinTextSize and MaxTextSize.
// Approximations: Montserrat (900 / 700) stands in for GothamBlack / GothamBold, a gradient's Offset is ignored, and a stroke gradient
// is drawn as its mid colour.
// Usage: node render_gui.mjs <scenes.json> <outdir> [fontdir]
//   scenes.json = [{name, json (dump_tree output), scale, bg (css), crop:[x,y,w,h] | null, pad}]
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(process.env.PLAYWRIGHT_NODE_ROOT || '/opt/node22/lib/node_modules', 'playwright')); }
const [scenesPath, outDir, fontDir] = process.argv.slice(2);
const scenes = JSON.parse(fs.readFileSync(scenesPath, 'utf8'));
fs.mkdirSync(outDir, {recursive: true});

function fontCss() {
  const files = {900: 'montserrat-latin-900-normal.woff2', 700: 'montserrat-latin-700-normal.woff2', 400: 'montserrat-latin-500-normal.woff2'};
  let css = '';
  for (const [weight, file] of Object.entries(files)) {
    const p = fontDir && path.join(fontDir, file);
    if (p && fs.existsSync(p)) css += `@font-face{font-family:'RbxFont';font-weight:${weight};src:url('file://${p}') format('woff2');}\n`;
  }
  return css;
}
const PAGE = (scene) => `<!doctype html><html><head><meta charset="utf-8"><style>
${fontCss()}
html,body{margin:0;padding:0;background:transparent;}
#stage{position:relative;overflow:hidden;font-family:'RbxFont','DejaVu Sans','Noto Color Emoji',sans-serif;}
#stage div{box-sizing:border-box;}
.t{position:absolute;left:0;top:0;width:100%;height:100%;display:flex;overflow:visible;line-height:1.12;}
.t span{display:block;}
</style></head><body><div id="stage"></div>
<script>
const SCENE=${JSON.stringify(scene)};
const rgb=(c,a=1)=>'rgba('+c[0]+','+c[1]+','+c[2]+','+a+')';
function sample(keys,t){ if(!keys||!keys.length) return null; if(t<=keys[0][0]) return keys[0][1]; for(let i=0;i<keys.length-1;i++){const [t0,v0]=keys[i],[t1,v1]=keys[i+1]; if(t<=t1){const u=t1===t0?0:(t-t0)/(t1-t0); return Array.isArray(v0)?v0.map((x,j)=>x+(v1[j]-x)*u):v0+(v1-v0)*u;}} return keys[keys.length-1][1]; }
function gradientCss(g, base, bgA){
  const times=new Set([0,1]); (g.color||[]).forEach(k=>times.add(k[0])); (g.alpha||[]).forEach(k=>times.add(k[0]));
  const stops=[...times].sort((a,b)=>a-b).map(t=>{
    const c=g.color?sample(g.color,t):[255,255,255]; const a=g.alpha?sample(g.alpha,t):0;
    const col=[base[0]*c[0]/255,base[1]*c[1]/255,base[2]*c[2]/255].map(Math.round);
    return rgb(col,(1-bgA)*(1-a))+' '+(t*100).toFixed(2)+'%';
  });
  return 'linear-gradient('+(g.rot+90)+'deg,'+stops.join(',')+')';
}
function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
function richHtml(s){ // <font color="#rrggbb">..</font> runs; everything else literal
  let out='',pos=0; const re=/<font color="#([0-9A-Fa-f]{6})">(.*?)<\\/font>/g; let m;
  while((m=re.exec(s))){ out+=esc(s.slice(pos,m.index).replace(/<[^>]+>/g,'')); out+='<span style="display:inline;color:#'+m[1]+'">'+esc(m[2])+'</span>'; pos=m.index+m[0].length; }
  return out+esc(s.slice(pos).replace(/<[^>]+>/g,''));
}
const scaled=[];
function build(n,pw,ph,parent){
  if(!n.vis) return;
  const w=n.size[0]*pw+n.size[1], h=n.size[2]*ph+n.size[3];
  const ax=n.pos[0]*pw+n.pos[1], ay=n.pos[2]*ph+n.pos[3];
  const el=document.createElement('div'); el.dataset.n=n.n;
  const s=el.style; s.position='absolute'; s.left=(ax-n.ap[0]*w)+'px'; s.top=(ay-n.ap[1]*h)+'px'; s.width=w+'px'; s.height=h+'px'; s.zIndex=n.z;
  s.transformOrigin=(n.ap[0]*100)+'% '+(n.ap[1]*100)+'%';
  // UIScale scales about the AnchorPoint (the transform origin); Roblox rotates about the CENTRE whatever the AnchorPoint (R150 review), so the rotation is
  // wrapped in translate(c) ... translate(-c) with c = centre - anchor point.
  const tf=[]; if(n.scale!==1) tf.push('scale('+n.scale+')');
  if(n.rot){ const cx=(0.5-n.ap[0])*w, cy=(0.5-n.ap[1])*h; tf.push(cx||cy?'translate('+cx+'px,'+cy+'px) rotate('+n.rot+'deg) translate('+(-cx)+'px,'+(-cy)+'px)':'rotate('+n.rot+'deg)'); }
  if(tf.length) s.transform=tf.join(' ');
  if(n.clip) s.overflow='hidden';
  if(n.cr){ s.borderRadius=Math.max(0,Math.min(n.cr[0]*Math.min(w,h)+n.cr[1],Math.min(w,h)/2))+'px'; }
  if(n.bg){ if(n.grad) s.background=gradientCss(n.grad,n.bg,n.bgA); else s.background=rgb(n.bg,1-n.bgA); }
  const shadows=[]; let extra=0;
  for(const st of n.strokes){ if(st.mode!=='Border'&&n.text) continue; const col=st.grad&&st.grad.color?sample(st.grad.color,.5):st.color; shadows.push('0 0 0 '+(extra+st.t)+'px '+rgb(col,1-st.a)); extra+=0; }
  if(shadows.length) s.boxShadow=shadows.join(',');
  parent.appendChild(el);
  if(n.text){
    const t=n.text; const box=document.createElement('div'); box.className='t'; el.appendChild(box);
    const span=document.createElement('span'); box.appendChild(span);
    if(t.rich) span.innerHTML=richHtml(t.s); else span.textContent=t.s;
    const font=t.font==='GothamBlack'?900:t.font==='GothamBold'?700:400;
    box.style.fontWeight=font; box.style.color=rgb(t.color,1-t.alpha);
    box.style.justifyContent=t.x==='Left'?'flex-start':t.x==='Right'?'flex-end':'center'; box.style.alignItems=t.y==='Top'?'flex-start':t.y==='Bottom'?'flex-end':'center'; box.style.textAlign=t.x==='Left'?'left':t.x==='Right'?'right':'center';
    box.style.whiteSpace=t.wrap||t.scaled?'normal':'nowrap'; box.style.fontSize=t.size+'px';
    if(t.strokeA<1){ const sw=Math.max(1,Math.round(t.size/9)); span.style.webkitTextStroke=sw+'px '+rgb(t.stroke,1-t.strokeA); span.style.paintOrder='stroke fill'; }
    if(t.scaled) scaled.push({box,span,t,w,h});
  }
  for(const c of n.kids) build(c,w,h,el);
}
const stage=document.getElementById('stage'); stage.style.width=SCENE.canvas[0]+'px'; stage.style.height=SCENE.canvas[1]+'px';
for(const c of SCENE.kids) build(c,SCENE.canvas[0],SCENE.canvas[1],stage);
function fits(e){ return e.span.scrollWidth<=e.w+1 && e.span.getBoundingClientRect().height<=e.h+1; }
for(const e of scaled){
  const max=e.t.max||Math.max(8,e.h), min=e.t.min||8; let size=Math.min(max,Math.max(min,Math.floor(e.h)));
  e.box.style.fontSize=size+'px';
  while(size>min && !fits(e)){ size-=1; e.box.style.fontSize=size+'px'; }
}
window.__ready=document.fonts.ready.then(()=>true);
</script></body></html>`;

const browser = await playwright.chromium.launch({args: ['--no-sandbox', '--font-render-hinting=none']});
for (const sc of scenes) {
  const data = JSON.parse(sc.json);
  const k = sc.scale || 1;
  const ctx = await browser.newContext({viewport: {width: Math.ceil(data.canvas[0]), height: Math.ceil(data.canvas[1])}, deviceScaleFactor: k});
  const page = await ctx.newPage();
  const file = path.join(outDir, sc.name + '.html');
  fs.writeFileSync(file, PAGE(data));
  await page.goto('file://' + file);
  await page.evaluate(() => window.__ready);
  await page.addStyleTag({content: `body{background:${sc.bg || 'transparent'};}`});
  const clip = sc.crop ? {x: Math.max(0, sc.crop[0]), y: Math.max(0, sc.crop[1]), width: sc.crop[2], height: sc.crop[3]} : {x: 0, y: 0, width: data.canvas[0], height: data.canvas[1]};
  await page.screenshot({path: path.join(outDir, sc.name + '.png'), clip, omitBackground: !sc.bg});
  await ctx.close();
}
await browser.close();
console.log('rendered', scenes.length, 'scenes');
