import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const HERE=path.dirname(new URL(import.meta.url).pathname);const OUT='/home/user/tmz/docs/proposals/keepers_R113';
const OUT2='/home/user/tmz/docs/proposals/strikes_R123';
const S=JSON.parse(fs.readFileSync(path.join(HERE,'scenes_strikes.json')));const jobs=[];
const names={1:'Timber Golem',2:'Sand Snake',3:'Ice Fang',4:'Lava Dragon',5:'Crystal Knight',6:'Jungle King',7:'Storm Colossus',8:'Veiled One'};
const R={1:19,2:20,3:17,4:23,5:26,6:16,7:32,8:15};const C={1:[0,9,-2],2:[0,1,4],3:[0,2,0],4:[0,4,0],5:[0,12,-4],6:[0,3,-1],7:[0,14,-4],8:[0,4,-2]};
for(let st=1;st<=8;st++){
 const cells=S.cells.filter(c=>c.kind==='k'+st).map(c=>({...c,dir:[0.95,0.30,-0.45],center:C[st],R:R[st],groundY:st===8?-5.4:-4,labelColor:c.label.startsWith('R123')?'#0b6b2e':'#8a1d1d',arrow:6}));
 jobs.push({file:`strike_${st}_${names[st].replace(' ','_').toLowerCase()}.png`,title:`${st<8?st+' ':''}${names[st]} - hit animation frame strip: R112 shared strike (top, = server contact frames) vs R123 signature move (bottom)`,
  subtitle:`Real module output (KeeperStrikeFrames / KeeperSignatureStrike${st===8?' / VeiledKeeper81':''}), side 3/4 view, keeper faces the blue arrow. Orange = contact frame at exactly the server hit time; red cube = the server's striking tip at contact. ${[2,3,4,6].includes(st)?'Mesh parts drawn as unrotated-size boxes (APPROXIMATION). ':''}Particles not drawn.`,cols:7,cellW:230,cellH:240,cells});
}
const server=http.createServer((req,res)=>{const u=decodeURIComponent(new URL(req.url,'http://x').pathname);const f=path.join(HERE,u);
 if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){res.writeHead(404);return res.end();}
 res.writeHead(200,{'content-type':f.endsWith('.html')?'text/html':f.endsWith('.js')?'text/javascript':'application/json'});fs.createReadStream(f).pipe(res);});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;
const browser=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1800,height:1200}});page.on('pageerror',e=>console.error('pageerror:',e.message));
for(const job of jobs){const jf=`job_${job.file.replace('.png','')}.json`;fs.writeFileSync(path.join(HERE,jf),JSON.stringify(job));
 await page.goto(`http://127.0.0.1:${port}/render.html?job=/${jf}`);await page.waitForFunction(()=>window.__done===true,null,{timeout:240000});
 await page.locator('#sheet').screenshot({path:path.join(OUT2,job.file)});fs.unlinkSync(path.join(HERE,jf));console.log('wrote',job.file);}
await browser.close();server.close();
