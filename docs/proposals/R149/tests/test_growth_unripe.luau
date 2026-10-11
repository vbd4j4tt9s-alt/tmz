--!nocheck
-- R149 review part 2, finding 7: the baked Ember Pumpkin grows pale green like every other fruit (run_growth.sh). Its vertex colours are orange and a tint
-- can only darken them, so while it is unripe it is drawn as a TWIN cloned from the white `_Neutral` template (PlantGrowth.addTwins), in the ordinary
-- pale-green -> ripe colour path of the seed's tone; the baked body is hidden until the ripe moment (the moment the real material switches on). The real
-- modules of this checkout with the server bake on the mock (fruit_mesh_mock.luau):
--  1. the pumpkin: one twin per fruit, pale green early (the hue of every other unripe fruit), the colour path ends at the tone, the baked body hidden;
--  2. the twin is the fruit as it always was drawn (size and pose equal to the same plant without twins), one flip each at the ripe moment, no more writes;
--  3. the final ripe look is identical (spec for spec, to the plant grown without twins and to the BASE growth module), the twins are gone;
--  4. the melons, a coated plant and a part-built fruit have no twin (today's look); a template that is not there leaves the fruit as it was;
--  5. a regrowing fruit and the server's silhouette work the same way; a plant that is destroyed mid-growth leaves nothing behind.
local C=require('./growth_common');local W,R,V3,CF=C.W,C.R,C.V3,C.CF;local check,near=C.check,C.near
local Mock=require('./fruit_mesh_mock');Mock.install(W)
check(Mock.prepare(W)==true,'(the server bake of the fruit meshes ran on the mock)')
local G,Base,Catalog,Visuals=C.Growth,C.Base,C.Catalog,C.Visuals
local Meshes=W.module('FruitMeshes149')
local id='EmberBloomSeed';local def=Catalog[id];local tone=Meshes.Seeds[id].Tone
local toneColour=R.Color3.fromRGB(tone[1],tone[2],tone[3])
local function body(model)for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p:GetAttribute('ApprovedMesh')=='EmberPumpkin149'then return p end end end
local function bodies(model)local out={};for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p:GetAttribute('ApprovedMesh')=='EmberPumpkin149'then out[#out+1]=p end end;return out end
local function allParts(model)local n=0;for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then n+=1 end end;return n end
local function close(a,b,tol)return(a-b).Magnitude<=(tol or 1e-6)end
local function sameColour(a,b)return near(a.R,b.R,1e-6)and near(a.G,b.G,1e-6)and near(a.B,b.B,1e-6)end

-- 1. the pumpkin grows pale green ------------------------------------------------------------------------------------------------------------------
local crop=C.crop(id);local model,st=C.grow(G,id,crop)
local n=def.FruitCount
check(st.Twins~=nil and#st.Twins==n and#bodies(model)==n,('one twin for each of the %d baked pumpkins (%d twins)'):format(n,st.Twins and#st.Twins or 0))
local t1=st.Twins[1]
check(t1:GetAttribute('ApprovedMesh')=='EmberPumpkin149_Neutral'and t1.Parent==body(model).Parent,'a twin is the white neutral mesh, in the plant next to its pumpkin')
check(not t1.CanQuery and not t1.CanCollide and t1:GetAttribute('GrowthTemporary')==true,'... temporary, no collision, not queryable')
local uh,us,uv=G.ToHSV(G.Unripe(toneColour))
local function state(now)G.Apply(st,crop,now)end
local function realOf(i)return bodies(model)[i]end
state(def.Seconds*.70)
local ok=true
for i,t in ipairs(st.Twins)do
 local h,s,v=G.ToHSV(t.Color)
 if t.Transparency~=0 or realOf(i).Transparency~=1 or t.Material~=R.Enum.Material.SmoothPlastic then ok=false end
 if not(math.abs(h-88/360)<.01 and s>.2 and s<.6 and v>.4)then ok=false end
end
check(ok,('at 70 %% of the growth (the fruit has just swelled): the twins are visible, pale yellow-green (hue %.0f degrees, the unripe hue of every fruit) and the baked bodies are hidden'):format(G.ToHSV(t1.Color)*360))
check(sameColour(t1.Color,G.Unripe(toneColour)),'... exactly the colour G.Unripe gives the tone (the part-built pumpkin\'s unripe colour)')
-- the path to ripe: hue and brightness move towards the tone, never back
local hues={};local lastH=nil;local mono=true
for f=.55,.99,.04 do state(def.Seconds*f);local h=G.ToHSV(t1.Color);hues[#hues+1]=h;if lastH and h>lastH+1e-6 then mono=false end;lastH=h end
check(mono and hues[1]-hues[#hues]>.08,('the colour ripens from green towards the orange tone (hue %.0f -> %.0f degrees, never back)'):format(hues[1]*360,hues[#hues]*360))
check(near(select(1,G.ToHSV(t1.Color)),select(1,G.ToHSV(toneColour)),.06),'... and is near the tone just before the ripe moment')

-- 2. the twin is the fruit as it always was drawn ----------------------------------------------------------------------------------------------------
-- a control: the same plant with the flag off (no twins), i.e. the real pumpkin parts written as before
Meshes.Seeds[id].UnripeNeutral=nil
local ctlModel,ctl=C.grow(G,id,crop)
Meshes.Seeds[id].UnripeNeutral=true
check(ctl.Twins==nil,'(control: with the flag off a plant has no twins)')
local geo=true;local worst=0
for _,f in ipairs({.1,.2,.35,.5,.65,.8,.9,.95,.99})do
 state(def.Seconds*f);G.Apply(ctl,crop,def.Seconds*f)
 for i,t in ipairs(st.Twins)do
  local c=bodies(ctlModel)[i]
  if(c.Transparency==0)~=(t.Transparency==0)then geo=false end
  if c.Transparency==0 then
   if not close(t.Size,c.Size)or not close(t.Position,c.Position)then geo=false;worst=math.max(worst,(t.Size-c.Size).Magnitude+(t.Position-c.Position).Magnitude)end
   if(t.CFrame.RightVector-c.CFrame.RightVector).Magnitude>1e-6 then geo=false end
  end
 end
end
check(geo,'at 10 - 99 % the twin has the size and the pose the pumpkin has without twins (swell, plump and sway share one path; off by '..worst..')')
-- the ripe moment: one flip each
state(def.Seconds-1)
local before={};for i,t in ipairs(st.Twins)do before[i]={t.Transparency,realOf(i).Transparency}end
state(def.Seconds)
local flipped=true
for i,t in ipairs(st.Twins)do
 local real=realOf(i)
 if not(before[i][1]==0 and before[i][2]==1 and t.Transparency==1 and real.Transparency==0)then flipped=false end
end
check(flipped,'at the ripe moment the baked bodies show and the twins hide (the same moment the real material switches on)')
-- the flips over the whole growth, sampled at every 1 % step: the body hides once and shows once, a twin shows once and hides once
local m2,s2=C.grow(G,id,crop);local flips={body=0,twin=0};local lastB,lastT=nil,nil
for k=0,200 do
 G.Apply(s2,crop,def.Seconds*k/200)
 local b,t=bodies(m2)[1].Transparency,s2.Twins[1].Transparency
 if lastB~=nil and b~=lastB then flips.body+=1 end;if lastT~=nil and t~=lastT then flips.twin+=1 end;lastB,lastT=b,t
end
check(flips.body<=1 and flips.twin<=2,('over the whole growth the baked body flips once (%d) and a twin twice (%d): one swap per fruit at ripeness'):format(flips.body,flips.twin))
-- writes of one refresh that moves nothing: nothing (a skipped Apply writes and allocates nothing, twins included)
local m3,s3=C.grow(G,id,crop);G.Apply(s3,crop,def.Seconds*.6)
local idle=C.Count(function()G.Apply(s3,crop,def.Seconds*.6)end)
check((idle.Total or 0)==0,'a refresh at the same growth writes nothing, the twins included ('..tostring(idle.Total)..')')
local busy=C.Count(function()G.Apply(s3,crop,def.Seconds*.61)end)
check((busy.Total or 0)>0,'(a step that moves the growth writes the twins: '..tostring(busy.Total)..' property writes)')
do -- a swayed growing plant moves its twins with it (G.Place) and drops the pose with the last write
 local m5,s5=C.grow(G,id,crop);G.Apply(s5,crop,def.Seconds*.8)
 local batch={Set=function(_,p,cf)p.CFrame=cf end}
 local t=s5.Twins[1];local at=t.Position;G.Place(s5,CF(.4,0,.2),batch)
 check((t.Position-at-V3(.4,0,.2)).Magnitude<1e-6,'a swayed plant moves its twins with it (Place)')
 G.Apply(s5,crop,def.Seconds*.82);check((t.Position-at-V3(.4,0,.2)).Magnitude<.2 and t.Transparency==0,'... and a later refresh keeps writing at that pose')
 C.finish(G,s5,crop);check(s5.Pose==nil and bodies(m5)[1].Transparency==0,'... the last write is at rest, the baked body shows');m5:Destroy()
end
m2:Destroy();m3:Destroy();ctlModel:Destroy()

-- 3. the final ripe look is identical -----------------------------------------------------------------------------------------------------------------
local function finalOf(Growth,flag)
 Meshes.Seeds[id].UnripeNeutral=flag
 local m,s=C.grow(Growth,id,crop);C.finish(Growth,s,crop);local snap=C.snapshot(m);Meshes.Seeds[id].UnripeNeutral=true;return m,snap
end
local mA,snapA=finalOf(G,true);local mB,snapB=finalOf(G,nil);local mC,snapC=finalOf(Base,nil)
check(C.sameAs(snapA,snapB),'the grown plant ends exactly as the plant grown without twins: '..tostring((select(2,C.sameParts(snapA,snapB)))))
check(C.sameAs(snapA,snapC),'... and exactly as the BASE growth module leaves it: '..tostring((select(2,C.sameParts(snapA,snapC)))))
check(allParts(mA)==allParts(mB)and#bodies(mA)==n,'no twin is left in the finished plant ('..allParts(mA)..' parts, '..allParts(mB)..' without twins)')
-- a ripe pumpkin has its baked colours (vertex colours, the shaded white part colour): the body is written exactly as before at the ripe moment
local bd=bodies(mA)[1];local bb=bodies(mB)[1]
check(sameColour(bd.Color,bb.Color)and bd.Material==bb.Material and bd.Transparency==0 and bd.Size==bb.Size,'the baked body\'s colour, material, size and opacity are today\'s')
mA:Destroy();mB:Destroy();mC:Destroy()

-- 4. who gets no twin ---------------------------------------------------------------------------------------------------------------------------------
for _,other in ipairs({'SunflowerSeed','SnowdropSeed'})do
 local m,s=C.grow(G,other,C.crop(other));check(s.Twins==nil,other..': the melons keep today\'s look (green vertex colours): no twin');m:Destroy()
end
for _,coat in ipairs({'Gold','Diamond'})do
 local cm,cs=C.grow(G,id,C.crop(id,{Mutation=coat}));check(cs.Twins==nil,'a '..coat..' pumpkin plant has no twin (it grows from the neutral mesh already)'..tostring(cs.Twins and #cs.Twins));cm:Destroy()
end
do -- the neutral template is not there (still loading on a client): the pumpkin stays as it was, tinted, without a twin and without an error
 local f=W.RS:FindFirstChild('FruitMeshTemplates149');local neutral=f:FindFirstChild('EmberPumpkin149_Neutral');neutral.Parent=nil
 local ok2,m,s=pcall(C.grow,G,id,crop)
 check(ok2 and s.Twins==nil,'no neutral template: no twin, no error')
 if ok2 then G.Apply(s,crop,def.Seconds*.8);local b=bodies(m)[1];check(b and b.Transparency==0,'... and the baked body is drawn as before (tinted)');m:Destroy()end
 neutral.Parent=f
end

-- 5. a regrowing fruit, the server's silhouette, a plant that goes mid-growth ---------------------------------------------------------------------------
do
 local rc=C.crop(id,{HarvestCycle=1});rc.FruitStates={}
 for i=1,def.FruitCount do local dur=def.RegrowSeconds or def.Seconds;rc.FruitStates[tostring(i)]={ReadyAt=def.Seconds+dur+i*40,Cycle=1,Duration=dur}end
 local m,s=C.growFruit(G,id,rc,1);local real=body(m)
 local ready=rc.FruitStates['1'].ReadyAt;local dur=rc.FruitStates['1'].Duration
 check(s.Twins~=nil and#s.Twins==1 and real~=nil,'a regrowing fruit has its twin too')
 G.Apply(s,rc,ready-dur*.4);check(s.Twins[1].Transparency==0 and real.Transparency==1,'... visible while it regrows, the baked body hidden')
 G.Apply(s,rc,ready);check(s.Twins[1].Transparency==1 and real.Transparency==0,'... and the body is back at the ripe moment')
 Visuals.EndGrowth(m);m:Destroy()
end
do
 local silhouette=R.new('Model');Visuals.GrowingSupports(id,C.origin,crop,2,silhouette,def.Seconds*.5)
 local ss=G.StateOf(silhouette);local proxies={};for _,p in ipairs(silhouette:GetDescendants())do if p:IsA('BasePart')and p:GetAttribute('ApprovedMesh')=='EmberPumpkin149'then proxies[#proxies+1]=p end end
 check(ss~=nil and ss.Twins~=nil and#proxies>=1,'the server\'s silhouette: the pumpkin proxies grow pale green too ('..tostring(ss and ss.Twins and#ss.Twins)..' twins)')
 local allHidden=true;for _,p in ipairs(proxies)do if p.Transparency~=1 then allHidden=false end end
 check(allHidden,'... and their baked bodies are hidden until they ripen')
 local before=allParts(silhouette);Visuals.EndGrowth(silhouette,crop,def.Seconds*2)
 local twinsLeft=0;for _,p in ipairs(silhouette:GetDescendants())do if p.Name=='Growing fruit body'then twinsLeft+=1 end end
 local shown=true;for _,p in ipairs(proxies)do if p.Transparency~=0 then shown=false end end
 check(twinsLeft==0 and shown and allParts(silhouette)<before,'EndGrowth ends the silhouette: the twins are gone and the pumpkin proxies show')
 silhouette:Destroy()
end
do
 local m,s=C.grow(G,id,crop);local twins=table.clone(s.Twins);m:Destroy()
 local gone=true;for _,t in ipairs(twins)do if t.Parent~=nil then gone=false end end
 check(gone and G.StateOf(m)==nil,'a plant that is removed mid-growth takes its twins with it (they live inside the plant)')
end
C.done('growth unripe')
