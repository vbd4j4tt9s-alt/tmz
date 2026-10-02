--!nocheck
-- R123 signature hit animations: server frames untouched, client contact lands at the server hit time,
-- the contact pose holds through HitHold, striking limbs land near the server's contact geometry,
-- the moves are distinct per keeper, late replication starts from idle, no pop at the window end, accents emit.
local Mx=require('./cfmath');local CF,V=Mx.CFrame,Mx.Vector3.new
local Base=require('./loader').new(require('./bundle_base'));local New=require('./loader').new(require('./bundle_new'))
local Sb,Sn=Base.require('KeeperStrikeFrames'),New.require('KeeperStrikeFrames')
local Sig=New.require('KeeperSignatureStrike');local C=New.require('KeeperCombat');local Cfg=New.require('KeeperRigConfig')
local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local function maxdiff(a,b)local d=0
 for g,f in pairs(a)do local h=b[g];if not h then return math.huge end
  d=math.max(d,(f.Position-h.Position).Magnitude)
  for i=1,3 do for j=1,3 do d=math.max(d,math.abs(f.R[i][j]-h.R[i][j]))end end end
 for g in pairs(b)do if not a[g]then return math.huge end end
 return d end
local function tipPoint(stage,group)
 local b=Cfg[stage].Bounds[group]
 if group=='Head'then return V((b[1][1]+b[2][1])/2,(b[1][2]+b[2][2])/2,math.min(b[1][3],b[2][3]))end
 return V((b[1][1]+b[2][1])/2,math.min(b[1][2],b[2][2]),(b[1][3]+b[2][3])/2)
end
local function tip(stage,frames)
 local s,n=V(0,0,0),0
 for _,g in ipairs(Sig.Moves[stage].Tip)do s+=frames[g]*tipPoint(stage,g);n+=1 end
 return s/n
end
local paths={};local names={}
print('stage move              W    contact  | tip at contact client vs server (fwd,up)  d     | cocked vs R112 cocked')
for stage=1,7 do
 local Wd=C.Get(stage).Windup;local move=Sig.Moves[stage];local T=Wd+C.Recovery
 check(not names[move.Name],stage..' move name unique');names[move.Name]=true
 -- 1. server frames (KeeperStrikeFrames, used by KeeperContact) identical to the R112/R113 snapshot, whole window
 local worst=0
 for i=-5,200 do local t=T*i/200;worst=math.max(worst,maxdiff(Sb.Frames(stage,t,0),Sn.Frames(stage,t,0)))end
 check(worst==0,stage..' server strike frames identical over the whole window ('..worst..')')
 -- 2. contact lands exactly at the server impact time and holds through HitHold
 local k,c=Sig.Weights(move,Wd,Wd-1e-4,nil);check(c<1,stage..' not in contact before W')
 for i=0,10 do local _,cc,ff,_,_,_=Sig.Weights(move,Wd,Wd+C.HitHold*i/10-(i>0 and 1e-9 or 0),nil);check(cc==1 and ff==0,stage..' contact weight 1 through HitHold')end
 check(Sig.ContactAt(stage,5)==5+Wd,stage..' ContactAt = server impact')
 local contact=Sig.Frames(stage,Wd,0)
 local ct=tip(stage,contact)
 -- tip arrives at the contact point at W: distance to the contact tip shrinks monotonically through the strike
 local rel=Wd*move.Release;local prev=math.huge;local mono=true;local peakSpeed,peakAt=0,0;local last
 for i=0,40 do local t=rel+(Wd-rel)*i/40;local p=tip(stage,Sig.Frames(stage,t,0));local d=(p-ct).Magnitude
  if i>=24 and d>prev+1e-6 then mono=false end;prev=d
  if last then local sp=(p-last).Magnitude;if sp>=peakSpeed then peakSpeed,peakAt=sp,t end end;last=p end
 check(mono,stage..' striking tip closes on the contact point through the last 40% of the strike')
 check(prev<1e-6,stage..' striking tip reaches the contact point exactly at W')
 check(peakAt>=rel+(Wd-rel)*.6,stage..' strike accelerates into the impact (peak tip speed at '..string.format('%.0f%%',(peakAt-rel)/(Wd-rel)*100)..' of the strike)')
 local hold=0;for i=0,10 do hold=math.max(hold,(tip(stage,Sig.Frames(stage,Wd+C.HitHold*i/10,0))-ct).Magnitude)end
 check(hold<.15,stage..' contact pose held through HitHold (tip drift '..string.format('%.3f',hold)..')')
 -- 3. lands near the server's contact geometry
 local st=tip(stage,Sn.Frames(stage,Wd,0));local d=(ct-st).Magnitude;local scale=Cfg[stage].Scale or 1
 local tol=4*math.max(1,scale^.5)
 check(d<=tol,stage..' client contact tip within '..tol..' studs of the server tip ('..string.format('%.2f',d)..')')
 -- 4. distinct from the shared R112 wind-up
 local ck=Wd*(move.Cock+move.Release)/2;local dc=maxdiff(Sig.Frames(stage,ck,0),Sn.Frames(stage,ck,0))
 check(dc>1,stage..' cocked pose differs from the R112 wind-up ('..string.format('%.2f',dc)..')')
 -- tip path signature (cocked -> contact -> follow peak), scale-normalised, for the pairwise distinct check
 local fp=Wd+C.HitHold+(C.Recovery-C.HitHold)*move.Peak
 local a,b,f=tip(stage,Sig.Frames(stage,ck,0)),ct,tip(stage,Sig.Frames(stage,fp,0))
 local u1,u2=(b-a)/scale,(f-b)/scale
 paths[stage]={u1.X,u1.Y,u1.Z,u2.X,u2.Y,u2.Z}
 -- 5. late replication: first-seen frame is the idle pose; no pop at the window end
 local idle=Sig.Frames(stage,.05,nil)
 check(maxdiff(Sig.Frames(stage,.05,0,.05),idle)<1e-9,stage..' late-seen wind-up starts from idle')
 check(maxdiff(Sig.Frames(stage,T-1e-4,0),Sig.Frames(stage,T-1e-4,nil))<.02,stage..' no pop at the window end')
 local nan=false;for i=0,300 do for _,f in pairs(Sig.Frames(stage,T*i/300,0,(i%7)*.01))do local p=f.Position;if p.X~=p.X or p.Y~=p.Y or p.Z~=p.Z then nan=true end end end
 check(not nan,stage..' no NaN across the window with leads')
 print(string.format('%d %-17s %.2f  %.2fs   | (%6.2f,%6.2f) vs (%6.2f,%6.2f)  %5.2f | %5.2f',stage,move.Name,Wd,Wd,-ct.Z,ct.Y,-st.Z,st.Y,d,dc))
end
-- pairwise distinct tip paths
local function dist(p,q)local s=0;for i=1,6 do s+=(p[i]-q[i])^2 end;return math.sqrt(s)end
local minD=math.huge
for i=1,7 do for j=i+1,7 do local d=dist(paths[i],paths[j]);minD=math.min(minD,d);check(d>1,('moves %d and %d distinct (%.2f)'):format(i,j,d))end end
print(string.format('min pairwise tip-path distance %.2f (scale-normalised studs)',minD))
-- Veiled One: server K.Frames unchanged; client lunge lands at W, holds, and stays near the server's swat
do
 local VB,VN=Base.require('VeiledKeeper81'),New.require('VeiledKeeper81')
 local attrs={GuardianBehavior='ATTACKING',VeiledAwakeAt=0,KeeperAttackAt=10,KeeperTravelSpeed=0}
 local model={PrimaryPart={CFrame=CF.new(0,5,0)},GetAttribute=function(_,k)return attrs[k]end}
 local Wd=C.Get(7).Windup;local worst=0
 for i=-5,200 do local t=10+(Wd+C.Recovery)*i/200;worst=math.max(worst,maxdiff(VB.Frames(model,t),VN.Frames(model,t)))end
 check(worst==0,'veiled server frames identical ('..worst..')')
 local hand=function(fr)return (fr.RHand.Position+fr.LHand.Position)/2 end
 local ct=VN.ClientFrames(model,10+Wd).RHand.Position;local st=VB.Frames(model,10+Wd).RHand.Position
 local drift=0;for i=0,10 do drift=math.max(drift,(VN.ClientFrames(model,10+Wd+C.HitHold*i/10).RHand.Position-ct).Magnitude)end
 check(drift<.2,'veiled contact held ('..drift..')')
 check((ct-st).Magnitude<4,'veiled right claw near the server swat ('..string.format('%.2f',(ct-st).Magnitude)..')')
 local _,c=Sig.Weights(Sig.Moves.Veiled,Wd,Wd-1e-4);check(c<1,'veiled not in contact before W')
 check(maxdiff(VN.ClientFrames(model,10+Wd+C.Recovery+.01),VN.Frames(model,10+Wd+C.Recovery+.01))==0,'veiled client = server outside the window')
 attrs.KeeperAttackAt=nil;local before=VN.Frames(model,10.05);attrs.KeeperAttackAt=10
 check(maxdiff(VN.ClientFrames(model,10.05,.05),before)<.05,'veiled late-seen lunge starts from the pre-attack pose')
 local ck=10+Wd*.64;check(maxdiff(VN.ClientFrames(model,ck),VN.Frames(model,ck))>1,'veiled wind-up distinct from the server swat')
 print(string.format('V %-17s %.2f  %.2fs   | right claw client vs server %.2f studs',Sig.Moves.Veiled.Name,Wd,Wd,(ct-st).Magnitude))
end
print(('signature checks %d, fails %d'):format(checks,fails))
