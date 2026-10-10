// Usage: node render_weather.mjs <dir with weather.html, scenes.txt and node_modules/three> <out dir>
// Reads the "SCENE name json" lines of dump_weather.luau and writes <out dir>/{rain,blizzard,snowbiome,tiles}.png.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1280,height:720}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
page.on('pageerror',e=>console.log('pageerror:',e.message));
await page.goto(`http://localhost:${server.address().port}/weather.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:60000});
const scenes={};
for(const line of fs.readFileSync(path.join(dir,'scenes.txt'),'utf8').split('\n')){const m=line.match(/^SCENE (\w+) (.*)$/);if(m)scenes[m[1]]=JSON.parse(m[2])}
const rain=scenes.rain,bliz=scenes.blizzard,snow=scenes.snowbiome;
const [px,py,pz]=rain.player;const [sx,sy,sz]=snow.player;
const views=[
  // rain: behind the player in the base, looking at the track border (z = -110): rain stops at the border, splashes on the ground
  ['rain',rain,{W:1280,H:720,v:{fov:64,pos:[px+8,py+6,pz-24],look:[px-4,py-3,pz+58],bg:0x8f98a8,fog:[70,320],sky:0xb9c2d0,gnd:0x6b7380,light:1.05,sun:.35,floor:0x9a9886,rain:0xc4dcf4,rainWidth:1.7,rainOpacity:.6}}],
  // blizzard: looking back over the garden beds: patches lie around the beds, never on them
  ['blizzard',bliz,{W:1280,H:720,v:{fov:66,pos:[px+22,py+9,pz+12],look:[px-6,py-3,pz-52],bg:0xc9d1dc,fog:[60,300],sky:0xe4ebf4,gnd:0x9aa3b0,light:1.25,sun:.5,floor:0x9a9886,flake:1.05}}],
  // the Snow biome: the runner on the keys, edge drifts at both sides, border patches ahead, dust away from him
  ['snowbiome',snow,{W:1280,H:720,v:{fov:70,pos:[sx,sy+17,sz-42],look:[sx,sy-3,sz+52],bg:0xc3dff2,fog:[160,700],sky:0xf2f8ff,gnd:0x7d8da0,light:1.3,sun:1.5,floor:0xb0c2cc}}],
  // top view of the base: the tiles around the player on the 50-stud world grid, cut back from the track
  ['tiles',rain,{W:1280,H:720,v:{ortho:{w:380,h:214},pos:[px+10,400,pz-34],look:[px+10,0,pz-34],bg:0xcfd4da,floor:0xb9b7a4,overlay:true,light:1.6,sun:.2}}],
];
const stats={};
for(const [name,scene,{W,H,v}] of views){
  const url=await page.evaluate(([s,w,h,view])=>window.shoot(s,w,h,view),[scene,W,H,v]);
  fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(url.split(',')[1],'base64'));stats[name]=await page.evaluate(()=>window.stats);console.log('wrote',name,JSON.stringify(stats[name]));
}
fs.writeFileSync(path.join(out,'stats.json'),JSON.stringify(stats));
await browser.close();server.close();
