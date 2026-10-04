// Usage: node render_seeds_new.mjs <dir with seeds_new.html, scenes.txt and node_modules/three> <out dir>
// Reads the "SCENE name json" lines of dump_seeds_new.luau and writes <out dir>/<name>.png for every scene.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:900,height:1100}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/seeds_new.html`);await page.waitForFunction(()=>window.ready===true);
for(const line of fs.readFileSync(path.join(dir,'scenes.txt'),'utf8').split('\n')){
  const m=line.match(/^SCENE (\S+) (.*)$/);if(!m)continue;
  const scene=JSON.parse(m[2]);const seed=m[1].startsWith('seed');
  const url=await page.evaluate(([s,w,h,o])=>window.shoot(s,w,h,o),[scene,600,900,seed?{bg:0xcfe8f7,noGround:true}:{}]);
  fs.writeFileSync(path.join(out,m[1]+'.png'),Buffer.from(url.split(',')[1],'base64'));console.log('wrote',m[1]);
}
await browser.close();server.close();
