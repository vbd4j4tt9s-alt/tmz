// Usage: node render_market.mjs <dir with view.html, new.json, old.json, node_modules/three> <out dir>
// Serves the folder on localhost, opens view.html in headless Chromium (software WebGL) and saves one PNG per view.
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
// Views (offsets from the market centre; the front faces -Z).
const views=[
  {file:'market_polished_hero',scene:'new',cam:[-66,22,-86],at:[-15,9,-10],fov:45},
  {file:'market_now_hero',scene:'old',cam:[-66,22,-86],at:[-15,9,-10],fov:45},
  {file:'market_polished_front',scene:'new',cam:[0,10,-66],at:[0,10,0],fov:45},
  {file:'market_now_front',scene:'old',cam:[0,10,-66],at:[0,10,0],fov:45},
  {file:'market_polished_inside',scene:'new',cam:[8,9,-16],at:[0,6.5,6],fov:55},
  {file:'market_polished_fruit_of_the_hour',scene:'new',cam:[-9,8,-43],at:[-20,5.5,-30],fov:45},
  {file:'market_polished_dusk',scene:'new',cam:[-66,22,-86],at:[-15,9,-10],fov:45,mode:'dusk'},
];
for(const v of views){
  const t=Date.now();
  const url=await page.evaluate(([s,v])=>window.shoot(s,v,v.mode),[scenes[v.scene],v]);
  fs.writeFileSync(path.join(out,v.file+'.png'),Buffer.from(url.split(',')[1],'base64'));
  console.log('wrote',v.file,(Date.now()-t)+'ms');
}
await browser.close();server.close();
