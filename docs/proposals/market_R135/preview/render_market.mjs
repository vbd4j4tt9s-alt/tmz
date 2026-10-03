// Usage: node render_market.mjs <dir with view.html, new.json, old.json, node_modules/three> <out dir>
// R135 fruit proposal: the market now ('old') vs the proposal ('new'), close on the fruit.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';
import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));const port=server.address().port;
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1600,height:900}});
page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${port}/view.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:60000});
const scenes={new:JSON.parse(fs.readFileSync(path.join(dir,'new.json'))),old:JSON.parse(fs.readFileSync(path.join(dir,'old.json')))};
const views=[];
for(const [tag,scene] of [['now','old'],['proposed','new']]){
  views.push({file:`fruit_${tag}_front`,scene,cam:[0,10,-62],at:[0,6,-6],fov:48});
  views.push({file:`fruit_${tag}_stand_left`,scene,cam:[-36,8,-33],at:[-23,2,-21.5],fov:42});
  views.push({file:`fruit_${tag}_stand_right`,scene,cam:[14,7,-34],at:[23,2,-21.5],fov:42});
  views.push({file:`fruit_${tag}_counter`,scene,cam:[0,10,-6],at:[0,5.6,3.4],fov:50});
}
for(const v of views){
  const url=await page.evaluate(([s,v])=>window.shoot(s,v,v.mode),[scenes[v.scene],v]);
  fs.writeFileSync(path.join(out,v.file+'.png'),Buffer.from(url.split(',')[1],'base64'));console.log('wrote',v.file);
}
await browser.close();server.close();
