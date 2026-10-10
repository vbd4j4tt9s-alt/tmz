// Usage: node render_cloudy.mjs <dir with cloudy.html + node_modules/three> <views.json> <out dir> <scene name>=<scene.json>[@views] [...]
// Serves <dir> on localhost, opens cloudy.html in headless Chromium (software WebGL, playwright) and writes <out>/<scene>_<view>.png for every
// view in views.json (1280 x 720) and <out>/<scene>_plan.png (the orthographic top view). Scene files are the "SCENE" lines of
// cloudy_scene.luau (R151 Cloudy sky preview) (JSON). <scene.json>@view1,view2 renders only those views (and "plan") of that scene; VIEWS=a,b limits all scenes.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,viewsFile,out,...specs]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1400,height:1100}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/cloudy.html`);await page.waitForFunction(()=>window.ready===true);
const V=JSON.parse(fs.readFileSync(viewsFile,'utf8'));
const only=process.env.VIEWS?process.env.VIEWS.split(','):null;
for(const spec of specs){
  const [name,rest]=spec.split('=');const [file,list]=rest.split('@');const sceneViews=list?list.split(','):null;
  const scene=JSON.parse(fs.readFileSync(file,'utf8'));
  await page.evaluate(s=>{window.__scene=s},scene);
  for(const v of V.views){
    if(only&&!only.includes(v.name))continue;
    if(sceneViews&&!sceneViews.includes(v.name))continue;
    const t0=Date.now();
    const url=await page.evaluate(([v])=>window.shoot(window.__scene,1280,720,v),[v]);
    fs.writeFileSync(path.join(out,`${name}_${v.name}.png`),Buffer.from(url.split(',')[1],'base64'));
    console.log('wrote',name,v.name,((Date.now()-t0)/1000).toFixed(1)+'s');
  }
  if(V.plan&&(!only||only.includes('plan'))&&(!sceneViews||sceneViews.includes('plan'))){
    const p=V.plan;
    const url=await page.evaluate(([p])=>window.shoot(window.__scene,p.w,p.h,{ortho:p.ortho,shadowAt:[p.ortho[0],4,p.ortho[1]],shadowExtent:420,clip:[-420,420,-700,-60]}),[p]);
    fs.writeFileSync(path.join(out,`${name}_plan.png`),Buffer.from(url.split(',')[1],'base64'));console.log('wrote',name,'plan');
  }
}
await browser.close();server.close();
