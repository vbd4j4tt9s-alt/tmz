// R156: R151's render_base_area.mjs for pyramid.html (the Desert pyramid preview).
// Usage: node render_pyramid.mjs <dir with pyramid.html + node_modules/three> <views.json> <out dir> <scene name>=<scene.json>[@views] [...]
// Serves <dir> on localhost, opens pyramid.html in headless Chromium (software WebGL, playwright) and writes <out>/<scene>_<view>.png for every
// view in views.json (1280 x 720). Scene files are R152 sweep scenes ("SCENE" lines of run_variant.sh, cut by make_pyramid_preview156.py).
// <scene.json>@view1,view2 renders only those views of that scene; VIEWS=a,b limits all scenes.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,viewsFile,out,...specs]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1400,height:1100}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/pyramid.html`);await page.waitForFunction(()=>window.ready===true);
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
}
await browser.close();server.close();
