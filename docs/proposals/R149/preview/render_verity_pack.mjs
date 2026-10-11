// Usage: node render_verity_pack.mjs <dir with verity_pack.html and node_modules/three> <scenes.txt> <out dir> <prefix>
// Reads the "SCENE name json" lines of dump_verity_pack.luau and writes <out dir>/<prefix>_<name>.png for every scene. The hotbar scene is
// rendered at the size of a hotbar slot picture (72 x 72), the others at 560 x 672 on a sky backdrop.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,scenes,out,prefix]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:700,height:800}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/verity_pack.html`);await page.waitForFunction(()=>window.ready===true);
for(const line of fs.readFileSync(scenes,'utf8').split('\n')){
  const m=line.match(/^SCENE (\S+) (.*)$/);if(!m)continue;
  const scene=JSON.parse(m[2]);const hotbar=m[1].endsWith('_hotbar');
  const url=await page.evaluate(([s,w,h,o])=>window.shoot(s,w,h,o),[scene,hotbar?72:560,hotbar?72:672,{bg:hotbar?0x252b44:0xa9d8f5}]);
  fs.writeFileSync(path.join(out,prefix+'_'+m[1]+'.png'),Buffer.from(url.split(',')[1],'base64'));console.log('wrote',prefix+'_'+m[1]);
}
await browser.close();server.close();
