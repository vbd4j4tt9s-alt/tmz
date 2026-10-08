// R154 preview: renders the FRAME lines of preview_cinematic154.luau (R152's render_frames152.mjs with the R154 page: the dutch tilt,
// depth of field and the stand-in garden). Usage: node render_cinematic154.mjs <dir with cinematic.html, art/*.png, node_modules/three>
// <frames.txt> <outdir>. Writes <name>_world.png per frame, the GUI scene list gui_scenes.json for render_gui152.mjs (R152's patched copy of
// R150's renderer: <name>_under<i>.png and <name>_gui<i>.png) and meta.json (label, shot, move, clock, grade, blur per frame).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
let playwright;try{playwright=require('playwright')}catch(e){playwright=require(path.join(process.env.PLAYWRIGHT_NODE_ROOT||'/opt/node22/lib/node_modules','playwright'))}
const [dir,framesPath,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json','.png':'image/png'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await playwright.chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1400,height:1000}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/cinematic.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:120000});
const guiScenes=[];const meta=[];const beats=[];
for(const line of fs.readFileSync(framesPath,'utf8').split('\n')){
  const b=line.match(/^BEATS (\d+) (.*)$/);if(b){beats.push({rank:+b[1],...JSON.parse(b[2])});continue}
  const m=line.match(/^FRAME (\S+) (.*)$/);if(!m)continue;
  const name=m[1];const f=JSON.parse(m[2]);
  const png=path.join(out,name+'_world.png');
  if(!fs.existsSync(png)||process.env.FORCE){const url=await page.evaluate(([f])=>window.shoot(f,f.w,f.h),[f]);fs.writeFileSync(png,Buffer.from(url.split(',')[1],'base64'))}
  (f.under||[]).forEach((g,i)=>guiScenes.push({name:name+'_under'+i,json:JSON.stringify(g),scale:1}));
  f.guis.forEach((g,i)=>guiScenes.push({name:name+'_gui'+i,json:JSON.stringify(g),scale:1}));
  meta.push({name,w:f.w,h:f.h,label:f.label,tag:f.tag,kind:f.kind,shot:f.shot,move:f.move,t:f.t,fov:f.fov,dof:f.dof,grade:f.grade,blur:f.blur,under:(f.under||[]).length,guis:f.guis.length});
  console.log('world',name);
}
fs.writeFileSync(path.join(out,'gui_scenes.json'),JSON.stringify(guiScenes));
fs.writeFileSync(path.join(out,'meta.json'),JSON.stringify(meta));
fs.writeFileSync(path.join(out,'beats.json'),JSON.stringify(beats));
await browser.close();server.close();
