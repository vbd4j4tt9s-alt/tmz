// Usage: node shoot_seeds.mjs <dir with seeds.html + node_modules> <scene.json> <out.png>
// One row of seeds (dump_seeds.luau with ONLY / COLS) shot by seeds_R133's shootSeeds, labels removed.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,sceneFile,out]=process.argv.slice(2);
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1800,height:900}});
await page.goto(`http://localhost:${server.address().port}/seeds.html`);await page.waitForFunction(()=>window.ready===true);
const scene=JSON.parse(fs.readFileSync(sceneFile));scene.labels=[];
const url=await page.evaluate(s=>window.shootSeeds(s),scene);
fs.writeFileSync(out,Buffer.from(url.split(',')[1],'base64'));console.log('wrote',out);
await browser.close();server.close();
