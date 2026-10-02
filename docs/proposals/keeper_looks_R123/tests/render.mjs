// Renders BEFORE/AFTER keeper sheets from scenes.json (written by dump_refined.luau) with headless Chromium + three.js.
// Run from a folder holding render.html, scenes.json and node_modules/{three,playwright}.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const HERE=process.cwd();const OUT=process.argv[2]||'/home/user/tmz/docs/proposals/keeper_looks_R123/renders';
const K={2:{name:'Sand Snake',file:'sand_snake',center:[0,0,8],R:17.5,zoom:.8,groundY:-4.0,bg:'#efe6d6',ground:'#d8c49c'},
 3:{name:'Ice Fang (snow tiger)',file:'ice_fang',center:[0,1,4.2],R:16.5,zoom:.74,groundY:-4.6,bg:'#e3ecf6',ground:'#dfe9f4'},
 4:{name:'Lava Dragon',file:'lava_dragon',center:[0,4.3,2.5],R:24,zoom:.74,groundY:-4.9,bg:'#f0e4e0',ground:'#5a4a46'},
 6:{name:'Jungle King (gorilla)',file:'jungle_king',center:[0,3.9,-.7],R:11.5,zoom:.9,groundY:-4.0,bg:'#e4eee0',ground:'#93a77c'}};
const FRONT=[.8,.42,-1.0],SIDE=[1,.12,0];
const before='BEFORE (current mesh keeper)',after='AFTER (R123 refined)';
const jobs=[];
const cell=(st,which,pose,dir,label,note)=>({stage:+st,which,pose,dir,label,note,row:which==='after'?after:before,...K[st]});
for(const st of Object.keys(K)){
 const cells=[];
 for(const which of ['before','after'])
  cells.push(cell(st,which,'rest',FRONT,'front 3/4','rest pose'),cell(st,which,'rest',SIDE,'side','rest pose'),
   cell(st,which,'chase',FRONT,'chase stride','real BeastPose frames'),cell(st,which,'impact',FRONT,'strike impact','real KeeperStrikeFrames'));
 jobs.push({file:`keeper_${st}_${K[st].file}_before_after.png`,title:`${st} ${K[st].name}: before vs after`,
  subtitle:`Same cameras and lighting in both rows. AFTER is the real BeastModelsRefined.lua output (offline Luau, exact CFrame math), posed by the live BeastPose / KeeperStrikeFrames. BEFORE is a reconstruction: the mesh files cannot be downloaded here, so each textured mesh is drawn as the convex hull of the rig's FloorSamples (points taken from that mesh) in an assumed texture tone, and the untextured mesh details are drawn as rounded boxes at their exact size and position. Materials are approximated; particles, KeeperFx and client accents are not drawn.`,
  cols:4,cellW:470,cellH:380,cells});
}
const ov=[];
for(const which of ['before','after'])for(const st of Object.keys(K))ov.push({...cell(st,which,'rest',FRONT,`${st} ${K[st].name}`,'front 3/4, rest pose')});
jobs.unshift({file:'overview_before_after.png',title:'Keeper looks R123: dragon, snow tiger, snake, gorilla (before vs after)',
 subtitle:'Top row: the current imported mesh keepers (a reconstruction; see the per-keeper sheets). Bottom row: the proposed native-part refinements, with the same rig groups, pivots and bounds, under the same camera and lighting. Preview only: nothing in src/ has changed.',
 cols:4,cellW:470,cellH:380,cells:ov});
const server=http.createServer((req,res)=>{const u=decodeURIComponent(new URL(req.url,'http://x').pathname);const f=path.join(HERE,u);
 if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){res.writeHead(404);return res.end();}
 res.writeHead(200,{'content-type':f.endsWith('.html')?'text/html':f.endsWith('.js')?'text/javascript':'application/json'});fs.createReadStream(f).pipe(res);});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;
const browser=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:2000,height:1200}});page.on('pageerror',e=>console.error('pageerror:',e.message));page.on('console',m=>{if(m.type()==='error')console.error(m.text())});
const only=process.argv[3];
for(const job of jobs){if(only&&!job.file.includes(only))continue;
 const jf=`job_${job.file.replace('.png','')}.json`;fs.writeFileSync(path.join(HERE,jf),JSON.stringify(job));
 await page.goto(`http://127.0.0.1:${port}/render.html?job=/${jf}`);await page.waitForFunction(()=>window.__done===true,null,{timeout:300000});
 await page.locator('#sheet').screenshot({path:path.join(OUT,job.file)});fs.unlinkSync(path.join(HERE,jf));console.log('wrote',job.file);}
await browser.close();server.close();
