// Usage: node render_growth.mjs <dir with fruit_models.html, scenes.txt, node_modules/three (+ playwright)> <out dir>
// Reads the "SCENE name json" lines of dump_growth.luau and writes <out dir>/<name>.png (headless Chromium, swiftshader). Same drawer as the
// fruit-model preview (fruit_models.html); every scene of one plant uses the same fixed camera, so sizes compare honestly frame to frame.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:900,height:900}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/fruit_models.html`);await page.waitForFunction(()=>window.ready===true);
let count=0;
for(const line of fs.readFileSync(path.join(dir,'scenes.txt'),'utf8').split('\n')){
  const m=line.match(/^SCENE (\S+) (.*)$/);if(!m)continue;
  const scene=JSON.parse(m[2]);const [w,h]=scene.tile||[300,330];
  const r=await page.evaluate(([s,w,h,o])=>window.shoot(s,w,h,o),[scene,w*2,h*2,{bg:0xa9d8f5}]);
  fs.writeFileSync(path.join(out,m[1]+'.png'),Buffer.from(r.url.split(',')[1],'base64'));count++;
}
console.log('rendered',count,'scenes');
await browser.close();server.close();
