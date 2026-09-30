const { chromium } = require('/tmp/claude-0/-home-user-tmz/3b81e797-bc5f-5803-9d1a-e4f30034f130/scratchpad/preview/node_modules/playwright');
const http=require('http'),fs=require('fs'),path=require('path');
const srv=http.createServer((q,r)=>{const f=path.join(__dirname,q.url.split('?')[0]);if(!fs.existsSync(f)){r.writeHead(404);return r.end()}
 r.writeHead(200,{'Content-Type':f.endsWith('.js')?'text/javascript':f.endsWith('.json')?'application/json':'text/html'});r.end(fs.readFileSync(f))}).listen(8765,async()=>{
 const b=await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});const p=await b.newPage({viewport:{width:1280,height:720}});
 p.on('console',m=>console.log('console',m.text()));p.on('pageerror',e=>console.log('err',e.message));
 await p.goto('http://localhost:8765/mock.html');await p.waitForFunction('window.done===true',null,{timeout:60000});await p.waitForTimeout(300);
 await p.screenshot({path:process.argv[2]});await b.close();srv.close()});
