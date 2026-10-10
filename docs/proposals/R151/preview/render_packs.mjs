// Usage: node render_packs.mjs <dir with packs.html and node_modules/three> <scenes.txt> <out dir> <prefix> <jobs.json>
// Reads the "SCENE <json>" lines of dump_packs.luau and renders the jobs of jobs.json: [{scene:'Forest_01', name:'front', w:240, h:280, opts:{...}}].
// Writes <out dir>/<prefix>_<scene>_<name>.png and <out dir>/<prefix>_marks.json ({"<scene>_<name>": {part: [x0,y0,x1,y1]}}).
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,scenesFile,out,prefix,jobsFile]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:900,height:900}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/packs.html`);await page.waitForFunction(()=>window.ready===true);
const scenes={};
for(const line of fs.readFileSync(scenesFile,'utf8').split('\n')){if(!line.startsWith('SCENE '))continue;const s=JSON.parse(line.slice(6));scenes[s.label]=s}
const jobs=JSON.parse(fs.readFileSync(jobsFile,'utf8'));const marks={};let n=0;
for(const j of jobs){
  const sc=scenes[j.scene];if(!sc){console.log('no scene',j.scene);continue}
  const r=await page.evaluate(([s,w,h,o])=>window.shoot(s,w,h,o),[sc,j.w,j.h,j.opts||{}]);
  fs.writeFileSync(path.join(out,`${prefix}_${j.scene}_${j.name}.png`),Buffer.from(r.url.split(',')[1],'base64'));
  marks[`${j.scene}_${j.name}`]=r.marks;n++;
}
fs.writeFileSync(path.join(out,`${prefix}_marks.json`),JSON.stringify(marks));
console.log('rendered',n,'images for',prefix);
await browser.close();server.close();
