// Usage: node render_keyboard.mjs <dir with keyboard.html, scenes.txt and node_modules/three> <out dir>
// Reads the "SCENE keyboard json" line of dump_keyboard.luau and writes <out dir>/runner.png (a runner's-eye view down the track across
// the Jungle / Desert border) and <out dir>/top.png (a top view, full width, +Z up the image so the legends read upright).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1280,height:900}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/keyboard.html`);await page.waitForFunction(()=>window.ready===true);
let scene=null;
for(const line of fs.readFileSync(path.join(dir,'scenes.txt'),'utf8').split('\n')){const m=line.match(/^SCENE keyboard (.*)$/);if(m)scene=JSON.parse(m[1])}
const [rx,ry,rz]=scene.runner;
const views={
  // behind and above the runner, looking down the track (+Z); the Desert spacebar crosses the track 22 studs ahead
  runner:{W:1280,H:720,v:{fov:62,pos:[rx,ry+9.5,rz-15],look:[rx,ry+1,rz+34],avatar:true,bg:0xbfdff5,fog:[600,2600]}},
  // straight down over the border, the whole 180-wide floor in view
  top:{W:900,H:1100,v:{ortho:{w:190,h:232},pos:[0,400,rz+16],look:[0,0,rz+16],avatar:true,bg:0x9ccf8a}},
};
for(const [name,{W,H,v}] of Object.entries(views)){
  const url=await page.evaluate(([s,w,h,view])=>window.shoot(s,w,h,view),[scene,W,H,v]);
  fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(url.split(',')[1],'base64'));console.log('wrote',name);
}
await browser.close();server.close();
