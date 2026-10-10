// Usage: node render_verity_portrait.mjs <dir with verity_portrait.html and node_modules/three> <FRAME lines file> <out png> <label>
// Reads the "FRAME <name> json" lines of dump_verity_portrait (rest / mid / peak) and writes one picture with the three portrait frames side by side.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const [dir,framesFile,out,label]=process.argv.slice(2);
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));fs.readFile(f,(e,b)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b)})});
await new Promise(r=>server.listen(0,r));
const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1400,height:700}});page.on('console',m=>{if(m.type()==='error')console.log('page:',m.text())});
await page.goto(`http://localhost:${server.address().port}/verity_portrait.html`);await page.waitForFunction(()=>window.ready===true);
const frames=[];
for(const line of fs.readFileSync(framesFile,'utf8').split('\n')){const m=line.match(/^FRAME (\w+) (.*)$/);if(m){const f=JSON.parse(m[2]);f.name=m[1];frames.push(f)}}
const order=['rest','mid','peak'];frames.sort((a,b)=>order.indexOf(a.name)-order.indexOf(b.name));
const url=await page.evaluate(([f,w,l])=>window.shoot(f,w,l),[frames,380,label]);
fs.writeFileSync(out,Buffer.from(url.split(',')[1],'base64'));console.log('wrote',out,frames.length,'frames');
await browser.close();server.close();
