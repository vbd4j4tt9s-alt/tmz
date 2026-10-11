// Usage: node render_zfight.mjs <dir with zfight.html, views.json, node_modules/three> <out dir>
// Serves the folder on localhost, opens zfight.html in headless Chromium (software WebGL) and saves view<i>_before.png / _after.png.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';
import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));const port=server.address().port;
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:800,height:450}});
page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${port}/zfight.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:60000});
const data=JSON.parse(fs.readFileSync(path.join(dir,'views.json')));
for(const [i,v] of data.views.entries()){
  for(const which of ['before','after']){
    const url=await page.evaluate(([d,v])=>window.shoot(d,v),[v[which],{cam:v.cam,at:v.at,fov:v.fov}]);
    fs.writeFileSync(path.join(out,`view${i}_${which}.png`),Buffer.from(url.split(',')[1],'base64'));
  }
  console.log('rendered',v.name);
}
await browser.close();server.close();
