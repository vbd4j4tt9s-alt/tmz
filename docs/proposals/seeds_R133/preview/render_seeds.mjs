// Usage: node render_seeds.mjs <dir with seeds.html, the *.json scenes, node_modules> <out dir>
// Renders: seeds_now.png (the game now), seeds_proposed.png (this proposal), seeds_fixes_before/after.png (the
// redesigned seeds: R132 proposal vs now) and fx_00..15.png (the rarity effect ladder over time; run.sh makes the GIF).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1800,height:1500}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/seeds.html`);await page.waitForFunction(()=>window.ready===true);
const jobs=[['old','seeds_now'],['new','seeds_proposed'],['close_v2','seeds_fixes_before'],['close_new','seeds_fixes_after']];
for(let t=0;t<16;t++)jobs.push([`fx_${t}`,path.join('fx',`fx_${String(t).padStart(2,'0')}`)]);
fs.mkdirSync(path.join(dir,'fx'),{recursive:true});
for(const [name,file] of jobs){
  const scene=JSON.parse(fs.readFileSync(path.join(dir,`${name}.json`)));
  const url=await page.evaluate(s=>window.shootSeeds(s),scene);
  const target=file.startsWith('fx')?path.join(dir,file+'.png'):path.join(out,file+'.png');
  fs.writeFileSync(target,Buffer.from(url.split(',')[1],'base64'));console.log('wrote',file);
}
await browser.close();server.close();
