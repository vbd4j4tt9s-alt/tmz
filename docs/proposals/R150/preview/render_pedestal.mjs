// Usage: node render_pedestal.mjs <dir with pedestal.html and node_modules/three> <scenes.txt> <out dir> <prefix> [width height]
// Reads the "SCENE name json" lines of dump_pedestal.luau / dump_base.luau and writes <out dir>/<prefix>_<name>.png for every scene
// (default 640 x 460, a sky backdrop; a scene whose view carries "w" / "h" is rendered at that size).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,scenes,out,prefix,W0,H0]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1400,height:1000}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/pedestal.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:60000});
for(const line of fs.readFileSync(scenes,'utf8').split('\n')){
  const m=line.match(/^SCENE (\S+) (.*)$/);if(!m)continue;
  const scene=JSON.parse(m[2]);const w=scene.view.w||+W0||640,h=scene.view.h||+H0||460;
  const url=await page.evaluate(([s,w,h,o])=>window.shoot(s,w,h,o),[scene,w,h,scene.view.opts||{}]);
  fs.writeFileSync(path.join(out,prefix+'_'+m[1]+'.png'),Buffer.from(url.split(',')[1],'base64'));console.log('wrote',prefix+'_'+m[1]);
}
await browser.close();server.close();
