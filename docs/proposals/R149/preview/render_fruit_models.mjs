// Usage: node render_fruit_models.mjs <dir with fruit_models.html, scenes.txt, node_modules/three, optional meshes.json / generated_meshes.json> <out dir>
// Reads the "SCENE name json" lines of dump_fruit_models.luau and writes <out dir>/<name>.png for every scene (headless Chromium, swiftshader).
// A scene's "tile" field sets the picture size; "plant" scenes get a ground disc, fruit close-ups a plain studio background.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:900,height:900}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/fruit_models.html`);await page.waitForFunction(()=>window.ready===true);
let meshes=0;
for(const f of ['meshes.json','generated_meshes.json']){
  const p=path.join(dir,f);if(!fs.existsSync(p))continue;
  meshes+=await page.evaluate(t=>window.addMeshes(JSON.parse(t)),fs.readFileSync(p,'utf8'));
}
console.log('mesh tables loaded:',meshes);
const standIns={};
for(const line of fs.readFileSync(path.join(dir,'scenes.txt'),'utf8').split('\n')){
  const m=line.match(/^SCENE (\S+) (.*)$/);if(!m)continue;
  const scene=JSON.parse(m[2]);const [w,h]=scene.tile||[360,360];
  const opts=scene.plant?{bg:0xa9d8f5}:{bg:0xdcebf5,noGround:true};
  const r=await page.evaluate(([s,w,h,o])=>window.shoot(s,w,h,o),[scene,w,h,opts]);
  if(r.standIns)standIns[m[1]]=r.standIns;
  fs.writeFileSync(path.join(out,m[1]+'.png'),Buffer.from(r.url.split(',')[1],'base64'));
}
fs.writeFileSync(path.join(out,'standins.json'),JSON.stringify(standIns));
console.log('rendered; scenes with stand-in meshes:',Object.keys(standIns).length);
await browser.close();server.close();
