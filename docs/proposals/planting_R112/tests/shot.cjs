const {chromium}=require('/tmp/claude-0/-home-user-tmz/3b81e797-bc5f-5803-9d1a-e4f30034f130/scratchpad/art/node_modules/playwright');
const http=require('http'),fs=require('fs'),path=require('path');
const dir=__dirname;const out='/home/user/tmz/docs/proposals/planting_R112';fs.mkdirSync(out,{recursive:true});
const srv=http.createServer((q,s)=>{const p=path.join(dir,decodeURIComponent(q.url.split('?')[0]));const t=p.endsWith('.js')?'text/javascript':p.endsWith('.json')?'application/json':'text/html';let b;try{b=fs.readFileSync(p)}catch(e){s.writeHead(404);return s.end()}s.writeHead(200,{'Content-Type':t});s.end(b)}).listen(8765,async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});const pg=await b.newPage({viewport:{width:900,height:620}});
 pg.on('console',m=>console.log('console',m.text()));pg.on('pageerror',e=>console.log('err',e.message));
 const shots=[['small',0,0,'small_rise','Small plant (Watermelon-size, base 1.9): pile popping up, t=0.14 s'],['small',2,0,'small_pile','Small plant: settled pile, 23 cubes, radius 1.1'],['small',0,1,'small_mark','Small plant: mark left after the pile sinks'],
  ['medium',2,0,'medium_pile','Medium plant (Apple tree, base 10.5): settled pile, 36 cubes'],['big',1,0,'big_rise','Huge plant (Winter Crownwood x2, base 74): t=0.30 s, chunks flying'],['big',2,0,'big_pile','Huge plant: settled pile, 82 cubes, radius 4.2'],['big',3,0,'big_sink','Huge plant: sinking back into the soil'],['big',0,1,'big_mark','Huge plant: mark left at the growth point']];
 for(const [k,f,m,name,label] of shots){await pg.goto(`http://localhost:8765/index.html?k=${k}&f=${f}&m=${m}&label=${encodeURIComponent(label)}`);await pg.waitForFunction('window.done===true',null,{timeout:20000});await pg.screenshot({path:`${out}/${name}.png`});console.log('ok',name)}
 await b.close();srv.close();});
