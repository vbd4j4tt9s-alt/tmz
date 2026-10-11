// R158 bats: render swing_render158.html shots in headless Chromium (playwright, software WebGL).
// Usage: node render_swing158.mjs <dir with swing_render158.html + node_modules/three> <poses.jsonl> <jobs.json> <out dir>
// jobs.json: [{out, sys, rig, t, view, w, h, sector?, box?, trails?: [{sys, rig, from, to, color, width, which?}]}]
// A job's pose is the dumped frame of (sys, rig) nearest to t; a trail is the bat tip (or mid-barrel) path over [from, to] of the dumped frames.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,posesFile,jobsFile,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:900,height:900}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/swing_render158.html`);await page.waitForFunction(()=>window.ready===true);
const frames=fs.readFileSync(posesFile,'utf8').trim().split('\n').map(l=>JSON.parse(l)).filter(f=>!f.meta);
const pick=(sys,rig)=>frames.filter(f=>f.sys===sys&&f.rig===rig);
const nearest=(sys,rig,t)=>pick(sys,rig).reduce((a,b)=>Math.abs(b.t-t)<Math.abs(a.t-t)?b:a);
const jobs=JSON.parse(fs.readFileSync(jobsFile,'utf8'));
const tipCache={};
for(const job of jobs){
  const trails=[];
  for(const tr of job.trails||[]){
    const key=`${tr.sys}/${tr.rig}/${tr.which||'tip'}`;
    if(!tipCache[key]){const fs_=pick(tr.sys,tr.rig);tipCache[key]={t:fs_.map(f=>f.t),p:await page.evaluate(([f,w])=>window.tips(f,w),[fs_,tr.which||'tip'])}}
    const c=tipCache[key];const points=[];for(let i=0;i<c.t.length;i++)if(c.t[i]>=tr.from-1e-6&&c.t[i]<=tr.to+1e-6)points.push(c.p[i]);
    trails.push({points,color:tr.color,width:tr.width});
  }
  const span=async(sys,rig,from,to,which)=>{const fs_=pick(sys,rig).filter(f=>f.t>=from-1e-6&&f.t<=to+1e-6);return await page.evaluate(([f,w])=>window.tips(f,w),[fs_,which])};
  let ribbon=null,burst=null;
  if(job.ribbon){const r=job.ribbon;ribbon={mids:await span(r.sys,r.rig,r.from,r.to,'mid'),tips:await span(r.sys,r.rig,r.from,r.to,'tip'),color:r.color,opacity:r.opacity}}
  if(job.burst){const b=job.burst;const f=nearest(b.sys,b.rig,b.t);burst={at:(await page.evaluate(([f,w])=>window.tips([f],w),[f,b.which||'tip']))[0],size:b.size,color:b.color}}
  const frame=nearest(job.sys,job.rig,job.t);
  const url=await page.evaluate(([f,v,w,h,o])=>window.shoot(f,v,w,h,o),[frame,job.view,job.w,job.h,{sector:job.sector,box:job.box,trail:trails,ribbon,burst}]);
  fs.writeFileSync(path.join(out,job.out),Buffer.from(url.split(',')[1],'base64'));
}
// the tip paths as numbers, for animation.md (studs, character space at the game's scale)
const report={};for(const [k,v] of Object.entries(tipCache))report[k]=v.t.map((t,i)=>[+t.toFixed(4),...v.p[i].map(x=>+x.toFixed(2))]);
fs.writeFileSync(path.join(out,'tips.json'),JSON.stringify(report));
await browser.close();server.close();
console.log('rendered',jobs.length,'shots');
