// Usage: node render_keyboard149.mjs <dir with keyboard149.html and node_modules/three> <scenes file> <out dir> <prefix>
// Reads the "SCENE <name> json" lines of dump_keyboard149.luau and writes <out>/<prefix>_<view>.png for the views below (the same cameras
// for the R148 "before" and the R149 "after" scenes, so the two can be put side by side).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,scenesFile,out,prefix]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1280,height:900}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/keyboard149.html`);await page.waitForFunction(()=>window.ready===true);
const scenes={};
for(const line of fs.readFileSync(scenesFile,'utf8').split('\n')){const m=line.match(/^SCENE (\w+) (.*)$/);if(m)scenes[m[1]]=JSON.parse(m[2])}
const fog=[500,3200];
const views=[
  // behind and above the runner, looking down the track (+Z): the Desert spacebar 60 studs ahead
  ['runner','jungle',{fov:62,pos:[0,10.5,-16],look:[0,1,40],avatar:true,fog}],
  // the owner's screenshot angle: higher and steeper, a lot of track in view
  ['overview','jungle',{fov:62,pos:[6,34,-34],look:[0,0,50],avatar:true,fog}],
  // close to the keys, low: how tall they are
  ['closeup','jungle',{fov:55,pos:[7,4.2,-9],look:[0,.6,8],avatar:true,fog}],
  // the long view: Snow, Lava 150 studs ahead, ~1000 studs of track
  ['long','snow',{fov:58,pos:[0,16,-22],look:[0,1,260],avatar:true,fog}],
  ['crystal','crystal',{fov:62,pos:[0,12,-18],look:[0,1,60],avatar:true,fog}],
];
for(const [name,sceneName,v] of views){
  const scene=scenes[sceneName];if(!scene){console.log('missing scene',sceneName);continue}
  const [rx,ry,rz]=scene.runner;
  const view={...v,pos:[rx+v.pos[0],ry+v.pos[1],rz+v.pos[2]],look:[rx+v.look[0],ry+v.look[1],rz+v.look[2]]};
  const url=await page.evaluate(([s,w,h,view])=>window.shoot(s,w,h,view),[scene,1280,720,view]);
  fs.writeFileSync(path.join(out,`${prefix}_${name}.png`),Buffer.from(url.split(',')[1],'base64'));console.log('wrote',prefix,name,scene.counts.parts,'parts',scene.counts.guis,'guis');
}
await browser.close();server.close();
