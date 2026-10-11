--!nocheck
-- R150 (owner: "polish the pack pedestal that players have in base"): the server side of the mystery pedestal's look on the Roblox mock with the real
-- MysteryPedestalArt / MysteryPackService / MysteryPackRules and the real treadmill (BiomeVisuals): the sculpted pedestal (parts, solids, space in the
-- corner on straight and turned bases, nothing but static parts), its biome colours (the treadmill's own theme), the lit parts and the light in each state
-- (calm violet Locked, bright gold Ready, a dim mint ember Taken, grey-violet with nobody home), and that a state / biome change repaints the same parts
-- (no new instances: streaming-safe, nothing replicates per frame). The rules and the drive of the service (Publish, claims, saves) are in
-- docs/proposals/R147/tests/test_mystery.luau, which this extends with the look of each state.
local H=require('./pedestal_harness');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-9)end
local function rgb(c,t,tol)return c and math.abs(c.R*255-t[1])<=(tol or .5)and math.abs(c.G*255-t[2])<=(tol or .5)and math.abs(c.B*255-t[3])<=(tol or .5)end
local M=W.module('MysteryPackRules');local Art=H.server('MysteryPedestalArt')
R.clock=20000*86400+3600

-- 1. The palette is the treadmill's: Body / Trim / Glow / Ink and the Body material, tier by tier ---------------------------------------------------------
do
 local src=W.B.BiomeVisuals
 local a=src:find('local treadmillThemes={',1,true);local b=src:find('\n}',a,true)
 local block=src:sub(a,b)
 local rows={};for line in block:gmatch('[^\n]+')do if line:find('Body=RGB',1,true)then rows[#rows+1]=line end end
 check(#rows==7,'the treadmill has 7 themes ('..#rows..')')
 local stageOfTier={1,6,2,3,4,5,7} -- Config.TreadmillTiers: Forest, Jungle, Desert, Snow, Lava, Crystal, Storm (the tests of R147 check this order)
 local same=true;local why=''
 for tier,line in ipairs(rows)do
  local pal=M.Palette[stageOfTier[tier]]
  for _,key in ipairs({'Body','Trim','Glow','Ink'})do
   local r,g,b2=line:match(key..'=RGB%((%d+),(%d+),(%d+)%)')
   if not(pal and tonumber(r)==pal[key][1]and tonumber(g)==pal[key][2]and tonumber(b2)==pal[key][3])then same=false;why=why..' '..tier..key end
  end
  local mat=line:match('Material=Enum%.Material%.(%w+)')
  if mat=='Glass'then mat='SmoothPlastic'end -- (the one deliberate difference: the treadmill's Crystal body is never drawn in Glass; a solid glass column would look see-through)
  if not(pal and pal.Material==mat)then same=false;why=why..' '..tier..'Material' end
 end
 check(same,'every biome\'s pedestal colours (and body material, Crystal\'s Glass kept as plastic) equal its treadmill\'s theme (BiomeVisuals.treadmillThemes)'..why)
 local seven=true;for s=1,7 do if not M.Palette[s]then seven=false end end
 check(seven and M.Palette[8]==nil and M.Theme(8)==M.DefaultPalette and M.Theme(nil)==M.DefaultPalette and M.Theme('x')==M.DefaultPalette and M.Theme(4)==M.Palette[4],'one palette per regular biome; anything else (no owner, odd stage) wears the violet default')
 check(M.AnchorHeight==9.3 and M.PadTop==6.41 and M.ColumnRadius==2.1 and near(M.Offset.X,34)and near(M.Offset.Z,75),'the pack hovers 9.3 over the pad; the glow pad is 6.41 up and the column is 2.1 across (what the client\'s fx are placed by)')
 local looks=true;for _,k in ipairs({'Empty','Locked','Ready','Claimed'})do if not M.StateLook[k]then looks=false end end
 check(looks and M.StateLook.Empty.Light==nil and M.StateLook.Locked.Light and M.StateLook.Ready.Light.Brightness>M.StateLook.Locked.Light.Brightness and M.StateLook.Claimed.Light.Brightness<M.StateLook.Locked.Light.Brightness,'a look per state: no light with nobody home; Ready brighter than Locked; Taken the dimmest')
end

-- 2. The sculpted pedestal ------------------------------------------------------------------------------------------------------------------------------
local rec=H.base(1,CF(0,4.5,0));local pad=rec.Pad
local treadmillOk,terr=pcall(function()return H.server('BiomeVisuals').BuildTreadmillV131(rec.Model,1)end)
check(treadmillOk,'the real treadmill builds on the base: '..tostring(terr))
local model=H.model(rec);local ped=H.pedestal(rec)
local function staticParts(m)local out={};for _,p in ipairs(H.parts(m))do if not p:FindFirstAncestor('MysteryPack')and p.Name~='PackAnchor'then out[#out+1]=p end end;return out end
local parts=staticParts(model) -- (the pedestal itself: not the pack that floats over it, not the invisible anchor)
check(#parts>=24 and #parts<=32,'about 30 static parts per base ('..#parts..')')
local byName={};for _,p in ipairs(parts)do byName[p.Name]=(byName[p.Name]or 0)+1 end
check(byName.Apron==1 and byName['Apron inlay']==1 and byName.Plinth==1 and byName.Step==1 and byName['Step trim']==1 and byName['Lower collar']==1 and byName.Column==1 and byName['Waist ring']==1 and byName['Upper collar']==1 and byName.Cup==1 and byName.Top==1 and byName['Top rim']==1 and byName['Glow ring']==1,'the layers: apron + inlay, plinth, step + trim, collar, column + waist ring, collar, cup, top + rim, glow pad')
check(byName.Post==4 and byName['Post cap']==4 and byName.Gem==4,'four corner posts, each with a gold cap and a gem')
local solid,static=0,true;local solids={}
for _,p in ipairs(parts)do
 if p.CanCollide then solid+=1;solids[p.Name]=true end
 if not p.Anchored or p.CanTouch or(not p.CanCollide and p.CanQuery)or p.Massless then static=false end
end
check(solid==4 and solids.Plinth and solids.Step and solids.Column and solids.Top,'four solid parts only (plinth, step, column, top); everything else is for show')
check(static,'every part is anchored, none can be touched, and only the solid ones can be queried')
local noCode=true;for _,d in ipairs(model:GetDescendants())do if d:IsA('Script')or d:IsA('LocalScript')or d:IsA('ParticleEmitter')or d:IsA('Beam')or d:IsA('Trail')or d:IsA('SurfaceGui')or d:IsA('BillboardGui')or d:IsA('Sound')then noCode=false end end
check(noCode,'the server\'s pedestal has no scripts, particles, beams, GUIs or sounds: it is only parts, one light and the prompt')
local lights=0;for _,d in ipairs(model:GetDescendants())do if d:IsA('PointLight')or d:IsA('SpotLight')or d:IsA('SurfaceLight')then lights+=1 end end
check(lights==1 and ped.Light.Parent==ped.Anchor and ped.Light.Shadows==false,'one point light (without shadows) and nothing else that lights')
local shadows=0;for _,p in ipairs(parts)do if p.CastShadow then shadows+=1 end end
check(shadows==4,'only the four solid parts cast a shadow')
check(ped.Anchor.Transparency==1 and near(pad.CFrame:PointToObjectSpace(ped.Anchor.Position).Y,pad.Size.Y/2+9.3,1e-6)and model.PrimaryPart==ped.Anchor,'the pack anchor (invisible) is 9.3 over the pad')
-- Exact geometry in the pedestal's own frame.
local origin=pad.CFrame*CF(M.Offset.X,pad.Size.Y/2,M.Offset.Z)
local function local_(p)return origin:PointToObjectSpace(p.Position)end
local function find(name,i)local n=0;for _,p in ipairs(parts)do if p.Name==name then n+=1;if n==(i or 1)then return p end end end end
local glow=find('Glow ring')
check(near(local_(glow).Y+glow.Size.X/2,M.PadTop,1e-9),'the glowing pad\'s top is M.PadTop ('..string.format('%.3f',local_(glow).Y+glow.Size.X/2)..')')
check(near(find('Column').Size.Y/2,M.ColumnRadius,1e-9),'the column is 2.1 in radius (the client hangs the padlock by it)')
local top=find('Top');check(near(local_(top).Y+top.Size.X/2,6.31,1e-9)and near(local_(glow).Y-glow.Size.X/2,6.31,1e-9),'the glow pad rests exactly on the top plate')
local layers={'Plinth','Step','Step trim','Lower collar','Column','Upper collar','Cup','Top'}
local rest=true
for i=2,#layers do
 local lower,upper=find(layers[i-1]),find(layers[i])
 local function topY(p)local h=(p.Shape==R.Enum.PartType.Cylinder)and p.Size.X or p.Size.Y;return local_(p).Y+h/2 end
 local function botY(p)local h=(p.Shape==R.Enum.PartType.Cylinder)and p.Size.X or p.Size.Y;return local_(p).Y-h/2 end
 if not near(botY(upper),topY(lower),1e-9)then rest=false;print('  '..layers[i]..' bottom '..botY(upper)..' vs '..layers[i-1]..' top '..topY(lower))end
end
check(rest,'every layer rests exactly on the one under it (face to face: nothing floats, nothing overlaps)')
local function pos(name,i)return local_(find(name,i))end
check(near(pos('Plinth').Y,.25,1e-9)and near(find('Plinth').Size.X,9.2)and near(find('Plinth').Size.Z,9.2),'the plinth is 9.2 x 9.2 and .5 thick on the pad')
local ok4=true;for i=1,4 do local p=pos('Post',i);if not(near(math.abs(p.X),3.7,1e-9)and near(math.abs(p.Z),3.7,1e-9)and near(p.Y-.95,.5,1e-9))then ok4=false end end
check(ok4,'the four posts stand on the plinth at (+-3.7, +-3.7)')
-- Space: clear of the aisle, the tool boxes and the real treadmill (padspace boxes), on a straight and a turned base.
local function extents(model_,pad_)
 local x0,x1,z0,z1,y1=1e9,-1e9,1e9,-1e9,-1e9
 for _,p in ipairs(staticParts(model_))do
  local cf=p.CFrame;local s=p.Size
  for sx=-1,1,2 do for sy=-1,1,2 do for sz=-1,1,2 do
   local c=pad_.CFrame:PointToObjectSpace(cf*V3(sx*s.X/2,sy*s.Y/2,sz*s.Z/2))
   x0=math.min(x0,c.X);x1=math.max(x1,c.X);z0=math.min(z0,c.Z);z1=math.max(z1,c.Z);y1=math.max(y1,c.Y)
  end end end
 end
 return {X0=x0,X1=x1,Z0=z0,Z1=z1,Y1=y1}
end
local function overlap(a,b)return a.X0<b.X1 and a.X1>b.X0 and a.Z0<b.Z1 and a.Z1>b.Z0 end
local function clear(fp,label)
 check(fp.X0>21+1 and fp.X1<45.25-1,label..': X '..string.format('%.1f..%.1f',fp.X0,fp.X1)..' - clear of the entrance aisle (|X| < 21) and of the tool boxes (X 45.25 ..)')
 check(fp.Z0>=65 and fp.Z1<=85,label..': Z '..string.format('%.1f..%.1f',fp.Z0,fp.Z1)..' - inside the treadmill\'s Z band (65 .. 85)')
 check(not overlap(fp,{X0=45.25,X1=52.75,Z0=71.25,Z1=76.75})and not overlap(fp,{X0=-52.75,X1=-45.25,Z0=71.25,Z1=76.75}),label..': not over a tool box')
end
local fp=extents(model,pad)
clear(fp,'base 1')
local tm=extents(rec.Model.TreadmillArtV131,pad)
check(not overlap(fp,tm)and not overlap(fp,{X0=-42.5,X1=-25.5,Z0=64,Z1=86}),'not over the real treadmill ('..string.format('%.1f..%.1f',tm.X0,tm.X1)..') or its apron')
check(near((fp.X0+fp.X1)/2,34,.01)and near((fp.Z0+fp.Z1)/2,75,.01),'centred on pad X 34, Z 75')
check(fp.Y1-pad.Size.Y/2<=8.1 and fp.Y1-pad.Size.Y/2>=6.3,'it stands under the floating pack ('..string.format('%.2f',fp.Y1-pad.Size.Y/2)..' studs tall: the pack hovers at 9.3)')
local turned=H.base(3,CF(-600,4.5,300)*R.CFrame.Angles(0,math.pi/2,0))
clear(extents(H.model(turned),turned.Pad),'base 3 (turned 90 degrees)')
local tilted=H.base(4,CF(900,4.5,-300)*R.CFrame.Angles(0,math.pi,0))
clear(extents(H.model(tilted),tilted.Pad),'base 4 (turned 180 degrees)')
-- the pack's own space: the biggest pack's bottom clears the glow pad at its lowest bob

-- 3. The look of each state ---------------------------------------------------------------------------------------------------------------------------
local function lit()local out={};for _,p in ipairs(parts)do if p.Name=='Glow ring'or p.Name=='Gem'then out[#out+1]=p end end;return out end
local function allLit(state)
 local look=M.StateLook[state];local ok=true
 for _,p in ipairs(lit())do
  local neon=p.Material==R.Enum.Material.Neon
  if not(rgb(p.Color,look.Color)and neon==look.Neon and near(p.Transparency,look.Transparency,1e-9))then ok=false end
 end
 return ok and #lit()==5
end
local function light(state)
 local look=M.StateLook[state].Light
 if not look then return ped.Light.Enabled==false end
 return ped.Light.Enabled and rgb(ped.Light.Color,look.Color)and near(ped.Light.Brightness,look.Brightness,1e-9)and near(ped.Light.Range,look.Range,1e-9)
end
check(allLit('Empty')and light('Empty'),'[empty] nobody home: five cold grey-violet parts, not glowing, and the light is off')
H.publish(rec,'Locked',{Owner=1,Stage=1,UnlockIn=900})
check(allLit('Locked')and light('Locked'),'[locked] the glow pad and the four gems are calm violet neon (a little see-through) and the light is a soft violet')
H.publish(rec,'Ready',{Owner=1,Stage=1,Variant='Pack03'})
check(allLit('Ready')and light('Ready'),'[ready] they light up bright gold (no see-through) and the light is gold, brighter and reaches further')
H.publish(rec,'Claimed',{Owner=1,Stage=1,Variant='Pack03'})
check(allLit('Claimed')and light('Claimed'),'[taken] they go to a dim mint, no longer neon, and the light is a faint mint ember')
check(M.StateLook.Ready.Light.Range>M.StateLook.Locked.Light.Range and M.StateLook.Locked.Light.Range>M.StateLook.Claimed.Light.Range,'(and the light reaches 20 / 12 / 9 studs: ready / locked / taken)')
H.publish(rec,'Empty')
check(allLit('Empty')and light('Empty'),'[empty] and when the owner leaves it goes back to the cold look')
-- Biome colours: the same parts change colour, no new instances.
local function themed(stage,why)
 local pal=M.Theme(stage);local ok=true
 for _,p in ipairs(parts)do
  if p.Name=='Step'or p.Name=='Column'or p.Name=='Post'then if not(rgb(p.Color,pal.Body)and p.Material==R.Enum.Material[pal.Material])then ok=false end end
  if p.Name=='Plinth'or p.Name=='Top'then if not rgb(p.Color,pal.Ink)then ok=false end end
  if p.Name=='Cup'then if not rgb(p.Color,pal.Trim)then ok=false end end
 end
 check(ok,why)
end
themed(nil,'[empty] violet default colours (marble body, slate ink) with nobody home')
local ids={};for _,p in ipairs(parts)do ids[p]=true end
local goldOk=true
for _,stage in ipairs({1,6,2,3,4,5,7})do
 H.publish(rec,'Locked',{Owner=1,Stage=stage,UnlockIn=900})
 themed(stage,'[biome '..stage..'] body, ink and cup wear that treadmill\'s colours and body material')
 for _,p in ipairs(parts)do if p.Name:find('collar',1,true)or p.Name:find('trim',1,true)or p.Name:find('rim',1,true)or p.Name:find('cap',1,true)or p.Name:find('ring',1,true)and p.Name~='Glow ring'then if not rgb(p.Color,M.Gold)then goldOk=false end end end
end
check(goldOk,'gold stays gold in every biome (collars, trims, rims, caps, waist ring)')
local sameModel=H.model(rec)==model and #staticParts(model)==#parts
local sameParts=true;for _,p in ipairs(staticParts(model))do if not ids[p]then sameParts=false end end
check(sameModel and sameParts,'a biome or state change repaints the same parts: no instance is created or destroyed (and so nothing re-streams)')
-- An upgrade while Locked (the treadmill's biome changes): the Look key changes, the pack is rebuilt, the colours follow.
local packA=H.pack(rec)
H.publish(rec,'Locked',{Owner=1,Stage=4,UnlockIn=900})
check(H.pack(rec)~=packA and H.pack(rec):GetAttribute('Stage')==4,'a treadmill upgrade rebuilds the silhouette in the new biome (as before)')
local packB=H.pack(rec)
ped.Look=ped.Look;H.svc:_look(ped,'Locked',4,nil)
check(H.pack(rec)==packB,'the same look again changes nothing (the pack is not rebuilt)')
-- Taken: no pack, no prompt.
H.publish(rec,'Claimed',{Owner=1,Stage=4,Variant='Pack03'})
check(H.pack(rec)==nil and ped.Prompt.Enabled==false,'[taken] no pack on the pedestal and the prompt is off')
-- The model stays Persistent and tagged; a rebuilt pedestal starts clean and dim.
check(model.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent and W.CS:HasTag(model,'MysteryPedestal'),'the model is Persistent and tagged (StreamingEnabled: never streamed out, so clients never hold stale copies)')
H.svc:_build(rec)
local again=H.model(rec)
check(again~=model and again.Parent==rec.Model and #staticParts(again)==#parts and H.svc.Pedestals[rec].Prompt.Enabled==false and H.svc.Pedestals[rec].Light.Enabled==false,'rebuilding replaces the pedestal (never two) and it starts dim, with the prompt off')
local twice=0;for _,c in ipairs(rec.Model:GetChildren())do if c.Name=='MysteryPedestal'then twice+=1 end end
check(twice==1,'(exactly one MysteryPedestal in the base)')

-- 4. Cost: one build, no connections, nothing per frame on the server ------------------------------------------------------------------------------------
do
 local before=#H.parts(H.model(rec))
 for i=1,60 do R.advance(.5)end
 check(#H.parts(H.model(rec))==before,'[cost] nothing is added or removed over time (the look changes only when the state or the biome does)')
 check(Art.Tint~=nil and Art.Build~=nil and not(function()for k,v in pairs(Art)do if type(v)~='function'then return true end end;return false end)(),'[cost] the art module is two pure functions (Build, Tint): no state, no connections')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
