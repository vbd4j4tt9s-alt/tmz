// R151 preview: renders the FRAME lines of preview_frames.luau. Usage: node render_frames.mjs <dir with rare_pull.html + node_modules/three> <frames.txt> <outdir>
// For every frame: <name>_world.png (three.js, rare_pull.html), <name>_vp.png (the seed card's viewport, transparent) and a GUI scene list
// gui_scenes.json for R150's render_gui.mjs (one transparent overlay per ScreenGui: <name>_gui<i>.png).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
let playwright;try{playwright=require('playwright')}catch(e){playwright=require(path.join(process.env.PLAYWRIGHT_NODE_ROOT||'/opt/node22/lib/node_modules','playwright'))}
const [dir,framesPath,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await playwright.chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1400,height:1000}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/rare_pull.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:60000});
const guiScenes=[];const meta=[];
for(const line of fs.readFileSync(framesPath,'utf8').split('\n')){
  const m=line.match(/^FRAME (\S+) (.*)$/);if(!m)continue;
  const name=m[1];const f=JSON.parse(m[2]);
  const url=await page.evaluate(([f])=>window.shoot(f,f.w,f.h),[f]);
  fs.writeFileSync(path.join(out,name+'_world.png'),Buffer.from(url.split(',')[1],'base64'));
  let vp=null;
  if(f.viewport){const size=Math.max(64,Math.round(f.viewport.rect[2]));const u=await page.evaluate(([v,s])=>window.shootViewport(v,s),[f.viewport,size]);
    fs.writeFileSync(path.join(out,name+'_vp.png'),Buffer.from(u.split(',')[1],'base64'));vp={rect:f.viewport.rect,alpha:f.viewport.alpha,scale:f.viewport.scale}}
  f.guis.forEach((g,i)=>guiScenes.push({name:name+'_gui'+i,json:JSON.stringify(g),scale:1}));
  meta.push({name,w:f.w,h:f.h,label:f.label,tag:f.tag,kind:f.kind,grade:f.grade,blur:f.blur,guis:f.guis.length,vp});
  console.log('world',name);
}
fs.writeFileSync(path.join(out,'gui_scenes.json'),JSON.stringify(guiScenes));
fs.writeFileSync(path.join(out,'meta.json'),JSON.stringify(meta));
await browser.close();server.close();
