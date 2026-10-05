// Usage: node render_treadmills.mjs <dir with treadmills.html + node_modules/three> <scenes dir (before.txt, after.txt)> <out dir>
// R151 treadmill polish: serves <dir> (plus the belt images textures/) on localhost, opens treadmills.html in headless Chromium
// (software WebGL via playwright) and writes <out>/<before|after>_L<n>_<view>.png for every scene and view (the same cameras before and
// after), dusk variants of two views, and the belt animation frames <out>/gif_L<n>_<i>.png (20 frames at 12 fps: texture scroll, beam flow, chevrons).
// ONLY=a,b limits the views; LEVELS=1,5 limits the levels.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
import {fileURLToPath} from 'node:url';
const [dir,scenesDir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const here=path.dirname(fileURLToPath(import.meta.url));
const texDir=fs.existsSync(path.join(dir,'textures'))?path.join(dir,'textures'):path.join(here,'textures');
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json','.png':'image/png'};
const server=http.createServer((req,res)=>{let u=decodeURIComponent(req.url.split('?')[0]);
  const f=u.startsWith('/textures/')?path.join(texDir,u.slice(10)):path.join(dir,u);
  fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1400,height:1000}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/treadmills.html`);await page.waitForFunction(()=>window.ready===true,null,{timeout:60000});
const only=process.env.ONLY?process.env.ONLY.split(','):null;
const levels=process.env.LEVELS?process.env.LEVELS.split(',').map(Number):[1,2,3,4,5,6,7];
function scenes(which){
  const out={};
  for(const line of fs.readFileSync(path.join(scenesDir,which+'.txt'),'utf8').split('\n')){
    if(!line.startsWith('SCENE '))continue;
    const sp=line.indexOf(' ',6);out[line.slice(6,sp)]=JSON.parse(line.slice(sp+1));
  }
  return out;
}
const yawOf=v=>Math.atan2(v.belt[0],v.belt[2]);
async function shoot(scene,view,file,W=1280,H=720){
  const t0=Date.now();
  const url=await page.evaluate(([s,v,W,H])=>window.shoot(s,W,H,v),[scene,view,W,H]);
  fs.writeFileSync(path.join(out,file),Buffer.from(url.split(',')[1],'base64'));
  console.log('wrote',file,((Date.now()-t0)/1000).toFixed(1)+'s');
}
for(const which of ['before','after']){
  const all=scenes(which);
  for(const L of levels){
    const scene=all[which+'_L'+L];if(!scene)continue;
    for(const [name,v] of Object.entries(scene.views)){
      if(only&&!only.includes(name))continue;
      const view={pos:v.pos,look:v.look,fov:v.fov,owner:v.owner,shadowAt:v.look,shadowExtent:60,fogNear:300,fogFar:900,time:0,training:true};
      if(['runner','hero','belt'].includes(name))view.avatars=[[v.runner[0],v.runner[1],v.runner[2],yawOf(v),0xd23b3b]];
      await shoot(scene,view,`${which}_L${L}_${name}.png`);
      if(name==='corner'||name==='hero'){view.night=true;view.avatars=[];await shoot(scene,view,`${which}_L${L}_${name}_dusk.png`)}
    }
  }
}
// belt animation frames (after only): the belt view, 16 frames over 1.33 s while someone trains
if(!process.env.NO_GIF){
  const all=scenes('after');
  for(const L of (process.env.GIF_LEVELS||'1,4,5,7').split(',').map(Number)){
    const scene=all['after_L'+L];if(!scene)continue;const v=scene.views.belt;
    for(let i=0;i<20;i++){
      const view={pos:v.pos,look:v.look,fov:v.fov,shadowAt:v.look,shadowExtent:60,fogNear:300,fogFar:900,time:i/12,training:true,chevron:{c:v.runner,d:v.belt},
        avatars:[[v.runner[0],v.runner[1],v.runner[2],yawOf(v),0xd23b3b]]};
      await shoot(scene,view,`gif_L${L}_${String(i).padStart(2,'0')}.png`,640,360);
    }
  }
}
await browser.close();server.close();
