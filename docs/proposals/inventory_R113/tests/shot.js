const { chromium } = require('/tmp/claude-0/-home-user-tmz/3b81e797-bc5f-5803-9d1a-e4f30034f130/scratchpad/preview/node_modules/playwright');
const http=require('http'),fs=require('fs'),path=require('path');
const [,,out,v,W,H]=process.argv;
const srv=http.createServer((q,r)=>{const f=path.join(__dirname,q.url.split('?')[0]);if(!fs.existsSync(f)){r.writeHead(404);return r.end()}
 r.writeHead(200,{'Content-Type':f.endsWith('.js')?'text/javascript':f.endsWith('.json')?'application/json':'text/html'});r.end(fs.readFileSync(f))}).listen(8766,async()=>{
 const b=await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});const p=await b.newPage({viewport:{width:+W,height:+H}});
 p.on('console',m=>console.log('console',m.text()));p.on('pageerror',e=>console.log('err',e.message));
 await p.goto('http://localhost:8766/'+(v==='flat'?'flat.html':'mock2.html?v='+v));await p.waitForFunction('window.done===true',null,{timeout:90000});await p.waitForTimeout(300);
 await p.screenshot({path:out});await b.close();srv.close()});
