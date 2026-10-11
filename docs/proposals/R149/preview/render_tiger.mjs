// Usage: node render_tiger.mjs <dir with tiger.html, scene.json and node_modules/{three,playwright}> <out dir> [only]
// Serves the folder on localhost, renders the BEFORE/AFTER sheets with headless Chromium (software WebGL) and writes the PNGs.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';
import {chromium} from 'playwright';
const [dir,out,only]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json'};
const server=http.createServer((req,res)=>{const f=path.join(dir,decodeURIComponent(req.url.split('?')[0]));
 fs.readFile(f,(e,b)=>{if(e||fs.statSync(f).isDirectory()){res.writeHead(404);return res.end();}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream'});res.end(b);});});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;
const exe='/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const browser=await chromium.launch({...(fs.existsSync(exe)?{executablePath:exe}:{}),args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:2000,height:1200}});
page.on('pageerror',e=>console.error('pageerror:',e.message));page.on('console',m=>{if(m.type()==='error')console.error(m.text())});
// Views are rig-space directions from the tiger's centre to the camera; the tiger faces -Z.
const V={front:[.18,.28,-1],front34:[.85,.42,-1],rear34:[-.85,.45,1],side:[1,.14,0],head:[.55,.3,-1]};
const base={center:[0,.8,2.6],R:15.5,zoom:.76};
const cell=(row,which,pose,view,label,note,extra={})=>({row,which,pose,dir:V[view],label,note,...base,...extra});
const BEFORE='BEFORE (current)',AFTER='AFTER (R149 gear)';
const main=[];
for(const [row,which] of [[BEFORE,'before'],[AFTER,'after']])
 main.push(cell(row,which,'stand','front','front','rest pose'),cell(row,which,'stand','front34','front 3/4','rest pose'),
  cell(row,which,'stand','rear34','rear 3/4','rest pose'),cell(row,which,'run','front34','chase stride 3/4','real BeastPose frames'));
const poses=[];
for(const [row,which] of [[BEFORE,'before'],[AFTER,'after']])
 poses.push(cell(row,which,'stand','head','head close-up','rest pose',{center:[0,3.2,-6.8],R:5.2,zoom:.9}),
  cell(row,which,'sleep','front34','asleep (curled)','sleep pose'),
  cell(row,which,'cock','front34','pounce wind-up','real KeeperSignatureStrike'),
  cell(row,which,'strike','front34','pounce impact','real KeeperSignatureStrike'));
const sub='The mesh files cannot be downloaded here, so the tiger body is a reconstruction: each textured mesh is drawn as the convex hull of the rig\'s FloorSamples (points taken from that mesh), the tail (Bounds only) as an approximate tube, and the small untextured mesh details (eyes, muzzle, nose) as rounded boxes at their exact place. The gear is the real KeeperAccents output (offline Luau, exact CFrame math), posed by the live BeastPose / KeeperSignatureStrike frames. Same cameras and lighting in both rows; materials and the three ice spines (present in both rows) are approximate.';
const jobs=[{file:'tiger_gear.png',title:'Snow keeper (Ice Fang, the tiger): silver-and-sapphire gear, before vs after',subtitle:sub,cols:4,cellW:480,cellH:400,cells:main},
 {file:'tiger_gear_poses.png',title:'Snow tiger gear in motion: head, sleep, wind-up and strike (the gear follows each limb)',subtitle:sub,cols:4,cellW:480,cellH:400,cells:poses}];
for(const job of jobs){if(only&&!job.file.includes(only))continue;
 const jf=`job_${job.file.replace('.png','')}.json`;fs.writeFileSync(path.join(dir,jf),JSON.stringify(job));
 await page.goto(`http://127.0.0.1:${port}/tiger.html?job=/${jf}`);await page.waitForFunction(()=>window.__done===true,null,{timeout:300000});
 await page.locator('#sheet').screenshot({path:path.join(out,job.file)});fs.unlinkSync(path.join(dir,jf));console.log('wrote',job.file);}
await browser.close();server.close();
