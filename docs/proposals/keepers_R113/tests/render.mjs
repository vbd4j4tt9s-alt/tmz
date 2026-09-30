import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {chromium} from 'playwright';
const HERE=path.dirname(new URL(import.meta.url).pathname);const OUT='/home/user/tmz/docs/proposals/keepers_R113';
const S=JSON.parse(fs.readFileSync(path.join(HERE,'scenes.json')));const jobs=[];
const names={1:'Timber Golem',2:'Sand Snake',3:'Ice Fang',4:'Lava Dragon',5:'Crystal Knight',6:'Jungle King',7:'Storm Colossus'};
const R={1:17,2:20,3:16,4:24,5:22,6:15,7:26};const C={1:[0,10,0],2:[0,1,9],3:[0,2,4],4:[0,5,3],5:[0,13,0],6:[0,4,0],7:[0,15,0]};
for(let st=1;st<=7;st++){
 const cells=S.cells.filter(c=>c.kind==='k'+st).map(c=>({...c,dir:[0.85,0.32,-0.75],center:C[st],R:R[st],groundY:-4,labelColor:c.label.startsWith('R113')?'#0b6b2e':'#8a1d1d',arrow:6}));
 jobs.push({file:`keeper_${st}_${names[st].replace(' ','_').toLowerCase()}.png`,title:`${st} ${names[st]} - key poses, R112 (top) vs R113 (bottom)`,
  subtitle:`Real BeastPose / KeeperStrikeFrames output${st===1||st===5||st===7?' (native parts, R113 finish colours)':'; mesh parts drawn as unrotated boxes at each part centre (APPROXIMATION)'}; R113 adds KeeperPolish${[1,2,3,5,7].includes(st)?' and the client accent parts':''}. Front 3/4 view, keeper faces the blue arrow. Orange = server contact frame (identical in both rows). Materials/particles not drawn.`,cols:8,cellW:210,cellH:230,cells});
}
function plot(series,opts){const w=opts.w||420,h=opts.h||200,ml=40,mr=8,mt=22,mb=30;const X=t=>ml+(t/opts.tmax)*(w-ml-mr);const Y=v=>mt+(opts.ymax-v)/(opts.ymax-opts.ymin)*(h-mt-mb);
 let s=`<svg width="${w}" height="${h}" style="background:#fff;border:1px solid #dde"><text x="${ml}" y="14" font-size="12" font-weight="bold">${opts.title}</text>`;
 for(let v=opts.ymin;v<=opts.ymax+1e-9;v+=opts.ystep)s+=`<line x1="${ml}" x2="${w-mr}" y1="${Y(v)}" y2="${Y(v)}" stroke="${Math.abs(v)<1e-9?'#999':'#eee'}"/><text x="${ml-4}" y="${Y(v)+4}" font-size="9" text-anchor="end">${v.toFixed(1)}</text>`;
 for(let t=0;t<=opts.tmax;t+=1)s+=`<text x="${X(t)}" y="${h-mb+12}" font-size="9" text-anchor="middle">${t}</text>`;
 for(const m of opts.marks)s+=`<rect x="${X(m[0])}" width="${X(m[1])-X(m[0])}" y="${mt}" height="${h-mt-mb}" fill="${m[2]}" opacity=".18"/><text x="${X(m[0])+2}" y="${h-mb-3}" font-size="9">${m[3]}</text>`;
 series.forEach(([pts,col,dash,lab],i)=>{s+=`<polyline fill="none" stroke="${col}" stroke-width="1.8" ${dash?'stroke-dasharray="4 3"':''} points="${pts.map(p=>X(p[0])+','+Y(p[1])).join(' ')}"/><text x="${w-mr-150}" y="${mt+12+i*12}" font-size="9.5" fill="${col}">${lab}</text>`;});
 return s+`<text x="${w/2}" y="${h-3}" font-size="9.5" text-anchor="middle">seconds (sleep, wake 2.0, chase 3.1, turn 4.0, strike 5.0, taunt, return 7.6)</text></svg>`;}
let svg='<div style="display:grid;grid-template-columns:repeat(4,420px);gap:8px">';
for(let st=1;st<=7;st++){const a=S.curves['R112_'+st],b=S.curves['R113_'+st];
 svg+=plot([[a.map(p=>[p[0],p[1]]),'#c0392b',true,'head pitch R112'],[b.map(p=>[p[0],p[1]]),'#1e8449',false,'head pitch R113'],[b.map(p=>[p[0],p[2]]),'#2471a3',false,'head yaw R113 (look-at)'],[b.map(p=>[p[0],p[3]-a[b.indexOf(p)][3]]),'#8e44ad',false,'body pitch added (lean/rear)'],[b.map(p=>[p[0],p[4]-a[b.indexOf(p)][4]]),'#e67e22',false,'tail/body-end yaw added']],
  {title:`${st} ${names[st]} (radians)`,tmax:8.4,ymin:-1.2,ymax:1.2,ystep:.4,marks:[[2,3.1,'#f1c40f','wake'],[5,5.6,'#e67e22','strike'],[4,4.35,'#3498db','turn']]});}
svg+='</div>';
jobs.push({file:'motion_curves.png',title:'Keeper polish over one scripted timeline (all stages)',subtitle:'Real modules. Head pitch includes the sleep pose (R112 and R113 share it); R113 adds the wake anticipation dip, roar lift, look-at, lean and tail follow-through. Nothing is added in the strike window (orange band) beyond a 0.08 s fade-in that ends before impact.',svg});
const server=http.createServer((req,res)=>{const u=decodeURIComponent(new URL(req.url,'http://x').pathname);const f=path.join(HERE,u);
 if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){res.writeHead(404);return res.end();}
 res.writeHead(200,{'content-type':f.endsWith('.html')?'text/html':f.endsWith('.js')?'text/javascript':'application/json'});fs.createReadStream(f).pipe(res);});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;
const browser=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const page=await browser.newPage({viewport:{width:1800,height:1200}});page.on('pageerror',e=>console.error('pageerror:',e.message));
for(const job of jobs){const jf=`job_${job.file.replace('.png','')}.json`;fs.writeFileSync(path.join(HERE,jf),JSON.stringify(job));
 await page.goto(`http://127.0.0.1:${port}/render.html?job=/${jf}`);await page.waitForFunction(()=>window.__done===true,null,{timeout:240000});
 await page.locator('#sheet').screenshot({path:path.join(OUT,job.file)});fs.unlinkSync(path.join(HERE,jf));console.log('wrote',job.file);}
await browser.close();server.close();
