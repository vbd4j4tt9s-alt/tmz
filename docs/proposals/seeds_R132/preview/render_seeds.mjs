// Usage: node render_seeds.mjs <dir with seeds.html, seeds_old.json, seeds_new.json, node_modules> <out dir>
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1800,height:1500}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/seeds.html`);await page.waitForFunction(()=>window.ready===true);
for(const which of ['old','new']){
  const scene=JSON.parse(fs.readFileSync(path.join(dir,`seeds_${which}.json`)));
  const url=await page.evaluate(s=>window.shootSeeds(s),scene);
  fs.writeFileSync(path.join(out,`seeds_${which==='old'?'now':'proposed'}.png`),Buffer.from(url.split(',')[1],'base64'));console.log('wrote',which);
}
await browser.close();server.close();
