// Usage: node render_hub.mjs <dir with hub.html and node_modules/three> <hub_views.json (hub_scenes.py)> <out dir> [only view names, comma separated]
// For each state (empty, champions) loads the scene in hub.html (headless Chromium via playwright, swiftshader) and writes <out dir>/<state>_<view>.png and
// <out dir>/<state>_<view>.json (the screen positions of the view's labels, for make_sheet.py).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,views,out,only]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const want=only?new Set(only.split(',')):null;
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1900,height:1000}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
page.on('pageerror',e=>console.log('pageerror:',e.message));
await page.goto(`http://localhost:${server.address().port}/hub.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:60000});
const states=JSON.parse(fs.readFileSync(views,'utf8'));
for(const [state,scene] of Object.entries(states)){
  await page.evaluate(s=>window.setScene(s),scene);
  for(const v of scene.views){
    if(want&&!want.has(v.name))continue;
    const r=await page.evaluate(v=>window.shoot(v),v);
    fs.writeFileSync(path.join(out,`${state}_${v.name}.png`),Buffer.from(r.url.split(',')[1],'base64'));
    fs.writeFileSync(path.join(out,`${state}_${v.name}.json`),JSON.stringify({view:v,labels:r.labels,frames:scene.frames}));
    console.log('wrote',`${state}_${v.name}`);
  }
}
await browser.close();server.close();
