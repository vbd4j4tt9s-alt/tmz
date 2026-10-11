// Usage: node render_verity.mjs <dir with view.html, scene.json and node_modules/three> <out dir>
// Serves the folder on localhost, opens view.html in headless Chromium (software WebGL) and saves the PNGs. Views are absolute Roblox
// coordinates: the approach path round the market's side (the way players walk from the spawn at z -141), an aerial from behind
// the spawn, and a close look at her from the market side.
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
page.on('pageerror',e=>console.log('pageerror:',e.message));
await page.goto(`http://localhost:${port}/view.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:60000});
const scene=JSON.parse(fs.readFileSync(path.join(dir,'scene.json')));
// Avatars for scale: two walking round the market's west side toward her, one standing in front of her.
scene.people=[[-40,4,-232,0xd1495b],[-37,4,-262,0x3a86ff],[-22,4,-322,0xffbe0b]];
const [vx,vy,vz]=scene.verity;
const views=[
  {file:'verity_npc',cam:[-52,13,-252],at:[-4,15,-338],fov:52},                  // the main picture: on the path round the market, looking past it to her
  {file:'verity_npc_aerial',cam:[-120,64,-168],at:[0,12,-300],fov:46},          // from behind the spawn: the market, then her
  {file:'verity_npc_close',cam:[-30,9,-306],at:[0,15,-340],fov:58},             // standing in front of her, from the market side
];
for(const v of views){
  const t=Date.now();
  const url=await page.evaluate(([s,v])=>window.shoot(s,v,v.mode),[scene,v]);
  fs.writeFileSync(path.join(out,v.file+'.png'),Buffer.from(url.split(',')[1],'base64'));
  console.log('wrote',v.file,(Date.now()-t)+'ms');
}
await browser.close();server.close();
