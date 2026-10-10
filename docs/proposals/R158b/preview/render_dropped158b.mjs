// R158b preview: R156's render_pyramid.mjs for dropped158b.html (R156's pyramid.html + beams + a pack-only mask pass).
// Usage: node render_dropped158b.mjs <dir with dropped158b.html + node_modules/three> <jobs.json> <out dir>
// jobs.json: [{"id": "forest_near_after", "scene": "forest_after.json", "view": {pos, look, fov, ...}, "mask": true|false}, ...]
// Serves <dir> on localhost, opens dropped158b.html in headless Chromium (software WebGL, playwright) and writes <out>/<id>.png (1920 x 1080, the picture) and, when
// "mask" is set, <out>/<id>_mask.png (only the pack, white on black, the same camera: what the Highlight is drawn from).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,jobsFile,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1400,height:1100}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/dropped158b.html`);await page.waitForFunction(()=>window.ready===true);
const jobs=JSON.parse(fs.readFileSync(jobsFile,'utf8'));const cache={};
for(const j of jobs){
  const t0=Date.now();
  const file=path.join(dir,j.scene);cache[file]=cache[file]||JSON.parse(fs.readFileSync(file,'utf8'));
  await page.evaluate(s=>{window.__scene=s},cache[file]);
  const url=await page.evaluate(([v])=>window.shoot(window.__scene,1920,1080,v),[j.view]);
  fs.writeFileSync(path.join(out,`${j.id}.png`),Buffer.from(url.split(',')[1],'base64'));
  if(j.mask){
    const m=await page.evaluate(([v])=>window.shootMask(window.__scene,1920,1080,v),[j.view]);
    fs.writeFileSync(path.join(out,`${j.id}_mask.png`),Buffer.from(m.split(',')[1],'base64'));
  }
  console.log('wrote',j.id,((Date.now()-t0)/1000).toFixed(1)+'s');
}
await browser.close();server.close();
