--!nocheck
-- R151 hub displays: HubDisplayArt on the Roblox mock with the REAL game builders (SeedPackVisuals for seeds, HarvestPresentation / PlantVisuals for fruit, the R150
-- pedestal art for the podium). The place's own layout against the map is test_hub_scene (the whole hub after the real start-up builders); this is the display alone:
--  1. the frame: parts and what is solid, everything inside the apron and under the walls' height, the stage, podium, plinth, sign board and posts where they should be, a
--     sign (SurfaceGui) with five labels laid out by HubDisplayRules.Sign, one light, nothing animated or scripted;
--  2. the giant item for EVERY seed of the game (54) and EVERY fruit of the rotation, plain and with Gold / Diamond coats: at most 150 parts, static anchored inert parts, no
--     scripts / lights / emitters / foreign tags, scaled to about 10 studs, standing on the podium, clear of the sign, in the right place whatever the display's turn;
--     an item over the cap is trimmed (the biggest parts stay) or built with the plant builder's simplified fruit; a builder that fails gives a gem, never an empty display;
--  3. the looks: the empty state is calm and unlit, a champion lights the podium, the halo, the gems and the light in its colour, the sign shows its words and a ribbon in its colour;
--  4. cost: the numbers of parts, lights, guis and emitters of a finished display.
local HH=require('./hub_harness');local H=HH.H;local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
-- the place's baked fruit meshes live in ServerStorage: stand-ins (one part each), as the other previews do
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('MeshPart');p.Name=key;p.Size=V3(1,1,1);p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local rawWarn=W.env.warn;W.env.warn=function(msg,...)if tostring(msg):find('fruit meshes',1,true)then return end;rawWarn(msg,...)end -- (the mock cannot bake the R149 fruit meshes: the part-built fruit is the fallback, as on a server that cannot bake)
local Rules=W.module('HubDisplayRules');local P=W.module('SeedPackRules');local Catalog=W.module('PlantCatalog')
local Art=H.server('HubDisplayArt')
local list=Rules.EligibleFruits()
local CS=W.CS
local function all(root,class)local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA(class)then out[#out+1]=d end end;return out end
local function parts(root)return all(root,'BasePart')end

-- 1. The frame -----------------------------------------------------------------------------------------------------------------------------------------------------------
local holder=R.new('Folder');holder.Name='ChestChaseMap';holder.Parent=W.workspace
local pullD=Art.BuildFrame(holder,'Pull',Rules.Layout,4)
local fruitD=Art.BuildFrame(holder,'Fruit',Rules.Layout,4)
local function worldBox(model)
 local lo,hi
 for _,p in ipairs(parts(model))do
  local c=p.CFrame;local s=p.Size;local r=c.R
  local ex=V3((math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2)
  local a,b=c.Position-ex,c.Position+ex
  lo=lo and V3(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))or a
  hi=hi and V3(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))or b
 end
 return lo,hi
end
local function toLocal(d,v)return d.F:PointToObjectSpace(v)end
do
 check(pullD.Model.Name=='BestPullDisplay'and fruitD.Model.Name=='BiggestFruitDisplay','two displays: BestPullDisplay and BiggestFruitDisplay')
 check(pullD.Model.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent and fruitD.Model.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent,'both models are Persistent (a landmark seen from afar: never streamed out and back as new instances)')
 check(CS:HasTag(pullD.Model,Rules.Tag)and CS:HasTag(fruitD.Model,Rules.Tag),'both carry the tag the client finds them by')
 check(pullD.Model:GetAttribute('Kind')=='Pull'and fruitD.Model:GetAttribute('Kind')=='Fruit'and pullD.Model:GetAttribute('HubDisplay')==Rules.Version and pullD.Model:GetAttribute('State')=='Empty','attributes: Kind, HubDisplay, State')
 local n=Art.Counts(pullD)
 check(n.Frame>=40 and n.Frame<=140 and n.Item==0 and n.Avatar==0,'the frame is '..n.Frame..' static parts (the item and the avatar come later)')
 local nonParts=0;for _,d in ipairs(pullD.Model:GetDescendants())do
  if not(d:IsA('BasePart')or d:IsA('Model')or d:IsA('Folder')or d:IsA('SurfaceGui')or d:IsA('GuiObject')or d:IsA('UIGradient')or d:IsA('UICorner')or d:IsA('UIStroke')or d:IsA('UITextSizeConstraint')or d:IsA('PointLight'))then nonParts+=1;print('   unexpected '..d._class)end
 end
 check(nonParts==0,'the frame is parts, one SurfaceGui (with its labels) and one PointLight: no scripts, no emitters, no joints, no sounds')
 check(#all(pullD.Model,'PointLight')==1 and #all(pullD.Model,'SurfaceGui')==1 and #all(pullD.Model,'ParticleEmitter')==0 and #all(pullD.Model,'Script')==0,'one light, one sign, no emitters, no scripts')
 local bad=0;for _,p in ipairs(parts(pullD.Model))do if not p.Anchored or p.CanTouch then bad+=1 end end
 check(bad==0,'every part is anchored and untouchable')
 local solid={};for _,p in ipairs(parts(pullD.Model))do if p.CanCollide then solid[p.Name]=(solid[p.Name]or 0)+1;if not p.CanQuery then bad+=1 end end end
 check(solid.Apron==1 and solid.Stage==1 and solid['Front step']==1 and solid.Plinth>=2 and solid.Post==2 and solid.Step==1 and solid.Column==1 and solid.Top==1,'solid: the apron, stage, step, the podium\'s four pieces (plinth, step, column, top), the avatar plinth and the two posts')
 check(not solid['Sign board']and not solid['Sign frame']and not solid.Halo and not solid['Post gem']and not solid['Crown band'],'the sign, the halo and the trims are for show')
 local solids=0;for _,v in pairs(solid)do solids+=v end
 check(solids<=14,'only '..solids..' solid parts')
 -- the stage and its space
 local lo,hi=worldBox(pullD.Model)
 local llo,lhi=toLocal(pullD,lo),toLocal(pullD,hi)
 local pts={}
 for _,x in ipairs({lo.X,hi.X})do for _,y in ipairs({lo.Y,hi.Y})do for _,z in ipairs({lo.Z,hi.Z})do pts[#pts+1]=V3(x,y,z)end end end
 local minY,maxY=lo.Y,hi.Y
 check(near(minY,4,.001),'the stage stands on the floor (its lowest point is the hub floor, y 4)')
 check(maxY-4<=47,'the tallest point is '..string.format('%.1f',maxY-4)..' studs over the floor: under the hub walls (48)')
 -- everything within the apron's half size (local X / Z), also for the gems, posts, sign
 local inside=true;local worst=0
 for _,p in ipairs(parts(pullD.Model))do
  local q=toLocal(pullD,p.CFrame.Position);local ex=math.max(p.Size.X,p.Size.Y,p.Size.Z)/2
  if math.abs(q.X)+ex>Rules.Layout.Footprint.HalfX+.001 or math.abs(q.Z)+ex>Rules.Layout.Footprint.HalfZ+.001 then
   -- a long thin part: use its real extent
   local r=(p.CFrame.Rotation);local s=p.Size
   local exx=(math.abs((pullD.F.Rotation:Inverse()*r).R[1][1])*s.X+math.abs((pullD.F.Rotation:Inverse()*r).R[1][2])*s.Y+math.abs((pullD.F.Rotation:Inverse()*r).R[1][3])*s.Z)/2
   local exz=(math.abs((pullD.F.Rotation:Inverse()*r).R[3][1])*s.X+math.abs((pullD.F.Rotation:Inverse()*r).R[3][2])*s.Y+math.abs((pullD.F.Rotation:Inverse()*r).R[3][3])*s.Z)/2
   if math.abs(q.X)+exx>Rules.Layout.Footprint.HalfX+.001 or math.abs(q.Z)+exz>Rules.Layout.Footprint.HalfZ+.001 then inside=false;worst=math.max(worst,math.abs(q.X)+exx,math.abs(q.Z)+exz);print('   outside: '..p.Name)end
  end
 end
 check(inside,'every part is inside the apron\'s '..(Rules.Layout.Footprint.HalfX*2)..' x '..(Rules.Layout.Footprint.HalfZ*2)..' footprint')
 -- where things stand (display-local: X toward the viewer's left, Z away from the viewers)
 local function find(d,name)for _,p in ipairs(parts(d.Model))do if p.Name==name then return p end end end
 local board=pullD.Board;local bq=toLocal(pullD,board.CFrame.Position)
 check(near(bq.Z,Art.Dim.Board.Z,.01)and near(bq.X,0,.01)and near(bq.Y,Art.Dim.Board.Bottom+Art.Dim.Board.H/2+0,.01),'the sign board is centred behind the stage, '..Art.Dim.Board.Bottom..' studs up')
 check(board.Size.X==Rules.Sign.BoardW and board.Size.Y==Rules.Sign.BoardH,'48 x 20 studs')
 local front=toLocal(pullD,board.CFrame.Position+board.CFrame.LookVector*1)
 check(front.Z<bq.Z,'its front face (the sign) looks toward the viewers (local -Z)')
 local look=pullD.F.LookVector
 local toTarget=(Rules.Layout.Target-pullD.F.Position);toTarget=V3(toTarget.X,0,toTarget.Z).Unit
 check(near(look.X,toTarget.X,1e-6)and near(look.Z,toTarget.Z,1e-6),'the display\'s front faces the market (the layout\'s target)')
 local fl=fruitD.F.LookVector;local ft=(Rules.Layout.Target-fruitD.F.Position);ft=V3(ft.X,0,ft.Z).Unit
 check(near(fl.X,ft.X,1e-6)and near(fl.Z,ft.Z,1e-6),'and so does the other')
 check(pullD.F.Position.X>0 and fruitD.F.Position.X<0 and near(pullD.F.Position.X,-fruitD.F.Position.X)and near(pullD.F.Position.Z,fruitD.F.Position.Z),'BEST PULL in the +X corner, BIGGEST FRUIT in the -X corner, mirror images')
 local podiumPivot=find(pullD,'PodiumPivot');local pq=toLocal(pullD,podiumPivot.CFrame.Position)
 check(near(pq.X,Art.Dim.Podium.X,.01)and near(pq.Y,Art.Dim.StageTop,.01),'the podium stands on the stage on the viewers\' left')
 local topY=-1e9;for _,p in ipairs(parts(pullD.Podium))do if p.Name=='Glow ring'then topY=toLocal(pullD,p.CFrame.Position).Y+p.Size.X/2 end end
 check(near(topY,Art.PodiumTop()+.0,.06),'its glowing top ring is at '..string.format('%.2f',Art.PodiumTop())..' (the R150 pedestal x '..Art.Dim.Podium.Scale..')')
 local plinth=pullD.Model.AvatarPlinth.Plinth;local plq=toLocal(pullD,plinth.CFrame.Position)
 check(near(plq.X,Art.Dim.Plinth.X,.01)and plq.X<0,'the avatar\'s plinth is on the viewers\' right')
 check(near(toLocal(pullD,pullD.FeetAt.Position).Y,Art.AvatarFeet(),1e-6)and near(toLocal(pullD,pullD.ItemAt.Position).Y,Art.ItemBase(),1e-6),'the spots for the soles and the item\'s bottom are on the plinth glow and over the podium')
 -- the sign
 local gui=pullD.Gui
 check(gui.Face==R.Enum.NormalId.Front and gui.SizingMode==R.Enum.SurfaceGuiSizingMode.PixelsPerStud and gui.PixelsPerStud==24 and gui.LightInfluence==0 and gui.Parent==board and gui.MaxDistance==Rules.Sign.MaxDistance,'the sign is a SurfaceGui on the board\'s front, 24 px per stud, LightInfluence 0, readable up to '..Rules.Sign.MaxDistance..' studs')
 local labels={Title=true,Name=true,Line=true,Odds=true,Footer=true};local count=0
 for key in pairs(labels)do
  local l=pullD.Labels[key];if l then count+=1;local row=Rules.Sign.Rows[key]
   local c=Rules.Sign.Canvas
   check(near(l.Position.X.Scale,row.X/c.W,1e-9)and near(l.Position.Y.Scale,row.Y/c.H,1e-9)and near(l.Size.X.Scale,row.W/c.W,1e-9)and near(l.Size.Y.Scale,row.H/c.H,1e-9),'the "'..key..'" label sits in its row')
   local fit=l:FindFirstChildOfClass('UITextSizeConstraint')
   check(l.TextScaled and fit and fit.MaxTextSize==row.Max and l.Font==R.Enum.Font.FredokaOne,'"'..key..'": scaled text, at most '..row.Max..' px, Fredoka One')
  end
 end
 check(count==5,'five labels')
end

-- 2. The giant item ------------------------------------------------------------------------------------------------------------------------------------------------------
local function auditItem(d,model,info,label)
 local list=parts(model)
 local ok=true;local why=''
 if #list==0 or #list>Rules.ItemParts then ok=false;why=why..' parts='..#list end
 local anchored,inert,foreign=true,true,0
 for _,p in ipairs(list)do
  if not p.Anchored then anchored=false end
  if p.CanCollide or p.CanTouch or p.CanQuery then inert=false end
 end
 for _,x in ipairs(model:GetDescendants())do
  if x:IsA('LuaSourceContainer')or x:IsA('ParticleEmitter')or x:IsA('Light')or x:IsA('Sound')or x:IsA('Attachment')or x:IsA('WeldConstraint')or x:IsA('BillboardGui')or x:IsA('SurfaceGui')then foreign+=1;why=why..' '..x._class end
 end
 local tags=true
 for _,x in ipairs(model:GetDescendants())do for _,t in ipairs(CS:GetTags(x))do if t~='GiantVisualPart'then tags=false;why=why..' tag '..t end end end
 for _,t in ipairs(CS:GetTags(model))do tags=false;why=why..' modeltag '..t end
 if not anchored then ok=false;why=why..' unanchored' end
 if not inert then ok=false;why=why..' not inert' end
 if foreign>0 then ok=false end
 if not tags then ok=false end
 -- the box in display-local space
 local function localBox()
  local lo2=V3(1e9,1e9,1e9);local hi2=V3(-1e9,-1e9,-1e9)
  for _,p in ipairs(list)do
   local c=d.F:ToObjectSpace(p.CFrame);local s=p:GetAttribute('ArtSize')or p.Size;local r=c.R
   local ex=V3((math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2)
   local a,b=c.Position-ex,c.Position+ex
   lo2=V3(math.min(lo2.X,a.X),math.min(lo2.Y,a.Y),math.min(lo2.Z,a.Z));hi2=V3(math.max(hi2.X,b.X),math.max(hi2.Y,b.Y),math.max(hi2.Z,b.Z))
  end
  return lo2,hi2
 end
 local a,b=localBox()
 local height=b.Y-a.Y;local width=math.max(b.X-a.X,b.Z-a.Z)
 if height>Rules.ItemHeight+.6 or width>14.6 then ok=false;why=why..string.format(' size %.1f x %.1f',height,width)end
 if a.Y<Art.ItemBase()-.2 or a.Y>Art.ItemBase()+.6 then ok=false;why=why..string.format(' bottom %.2f (want %.2f)',a.Y,Art.ItemBase())end
 local cx=(a.X+b.X)/2;local cz=(a.Z+b.Z)/2
 if math.abs(cx-Art.Dim.Podium.X)>3.5 or math.abs(cz-Art.Dim.Podium.Z)>3.5 then ok=false;why=why..string.format(' off the podium (%.1f,%.1f)',cx-Art.Dim.Podium.X,cz-Art.Dim.Podium.Z)end
 if b.Y>Art.Dim.Board.Bottom-1.2 then ok=false;why=why..string.format(' top %.1f touches the sign (bottom %.1f)',b.Y,Art.Dim.Board.Bottom)end
 return ok,why,height,width,#list
end
do
 local seedOk,seedBad,minH,maxH,maxParts=0,{},1e9,0,0
 local lastModel
 for _,spec in ipairs(P.SeedDesigns)do
  local model,info=Art.BuildItem(pullD,{Kind='Seed',Id=spec.id,Coat='None'})
  local ok,why,height,_,n=auditItem(pullD,model,info,spec.id)
  if ok and info.Source=='art'then seedOk+=1 else seedBad[#seedBad+1]=spec.id..':'..tostring(info.Source)..why end
  minH=math.min(minH,height);maxH=math.max(maxH,height);maxParts=math.max(maxParts,n)
  model:Destroy()
 end
 check(seedOk==#P.SeedDesigns,'all '..#P.SeedDesigns..' seeds of the game build a clean giant item ('..table.concat(seedBad,'; ')..')')
 check(maxParts<=Rules.ItemParts,'the biggest seed model is '..maxParts..' parts (cap '..Rules.ItemParts..')')
 print(string.format('  (seed items are %.1f to %.1f studs tall, at most %d parts)',minH,maxH,maxParts))
 local fruitOk,fruitBad,fminH,fmaxH,fmaxParts=0,{},1e9,0,0
 for _,id in ipairs(list)do
  local model,info=Art.BuildItem(fruitD,{Kind='Fruit',Id=id,Coat='None'})
  local ok,why,height,width,n=auditItem(fruitD,model,info,id)
  if ok and info.Source=='art'then fruitOk+=1 else fruitBad[#fruitBad+1]=id..':'..tostring(info.Source)..why end
  fminH=math.min(fminH,height);fmaxH=math.max(fmaxH,height);fmaxParts=math.max(fmaxParts,n)
  model:Destroy()
 end
 check(fruitOk==#list,'all '..#list..' fruit of the rotation build a clean giant item ('..table.concat(fruitBad,'; ')..')')
 print(string.format('  (fruit items are %.1f to %.1f studs tall, at most %d parts)',fminH,fmaxH,fmaxParts))
 check(fminH>=2.5,'even the flattest fruit stands at least 2.5 studs tall ('..string.format('%.1f',fminH)..')')
 -- coats
 for _,coat in ipairs({'Gold','Diamond'})do
  local model=Art.BuildItem(fruitD,{Kind='Fruit',Id='SunflowerSeed',Coat=coat})
  local material=coat=='Gold'and R.Enum.Material.Metal or R.Enum.Material.Glass
  local coated,total=0,0
  for _,p in ipairs(parts(model))do total+=1;if p.Material==material then coated+=1 end end
  check(coated>=total*.5,'a '..coat..' fruit is coated ('..coated..' of '..total..' parts)')
  model:Destroy()
  local seed=Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat=coat})
  local c2=0;for _,p in ipairs(parts(seed))do if p.Material==material then c2+=1 end end
  check(c2>=1,'a '..coat..' seed is coated')
  seed:Destroy()
 end
 -- over the cap
 local model,info=Art.BuildItem(fruitD,{Kind='Fruit',Id='AmethystSeed',Coat='None'})
 check(info.Parts<=Rules.ItemParts,'the Amethyst Grape (718 parts as a plant, 163 as a harvested fruit) is cut to '..info.Parts..' parts (cap '..Rules.ItemParts..'; the detail it loses is the smallest parts)')
 model:Destroy()
 local geode,ginfo=Art.BuildItem(fruitD,{Kind='Fruit',Id='HollowGeodeSeed',Coat='None'})
 check(ginfo.Parts<=Rules.ItemParts,'so is the Hollow Geode ('..ginfo.Parts..' parts)')
 geode:Destroy()
 -- a mystery seed
 local mystery=Art.BuildItem(pullD,{Kind='Seed',Id='SunflowerSeed',Mystery=true})
 local dark=true;for _,p in ipairs(parts(mystery))do if p.Color.R>.1 or p.Color.G>.1 or p.Color.B>.15 then dark=false end end
 check(dark and #all(mystery,'Decal')==0,'the empty BEST PULL shows a black mystery seed')
 mystery:Destroy()
 -- scale stays about ItemHeight whatever the display's turn
 local turned=Art.BuildFrame(holder,'Pull',{Target=V3(100,4,-300),Pull={Center=V3(-50,4,20)},Fruit={Center=V3(0,4,0)}},4)
 local m=Art.BuildItem(turned,{Kind='Seed',Id='FirePepperSeed',Coat='None'})
 local ok,why=auditItem(turned,m,{},'turned')
 check(ok,'on a display turned another way the item still stands on its podium and clear of the sign'..why)
 m:Destroy();turned.Model:Destroy()
 -- a builder that fails gives a gem
 local Visuals=W.module('SeedPackVisuals');local rawSeed=Visuals.Seed
 Visuals.Seed=function()error('mesh library missing')end
 local gem,ginfo2=Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat='None',Accent={255,100,50}})
 check(ginfo2.Source=='gem'and #parts(gem)>=2,'when the seed builder fails the display gets a gem on a ring (never nothing)')
 gem:Destroy();Visuals.Seed=rawSeed
 local H2=W.module('HarvestPresentation');local rawBuild=H2.Build
 H2.Build=function()error('no meshes yet')end
 local gem2,ginfo3=Art.BuildItem(fruitD,{Kind='Fruit',Id='SunflowerSeed',Coat='None'})
 check(ginfo3.Source=='gem'and #parts(gem2)>=2,'and when the fruit builder fails')
 gem2:Destroy();H2.Build=rawBuild
 local none,ninfo=Art.BuildItem(fruitD,{Kind='Fruit',Id='NoSuchPlantSeed',Coat='None'})
 check(ninfo.Source=='gem','an unknown plant is a gem too (no error)')
 none:Destroy()
 -- placing
 local item=Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat='None'})
 Art.SetItem(pullD,item);check(item.Parent==pullD.ItemFolder and item.Name=='GiantItem'and item:GetAttribute('Spin')==true and item.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent,'the item goes in the display\'s Item slot')
 local item2=Art.BuildItem(pullD,{Kind='Seed',Id='AppleSeed',Coat='None'})
 Art.SetItem(pullD,item2);check(item.Parent==nil and #pullD.ItemFolder:GetChildren()==1,'a new item replaces the old one (no leftovers)')
 Art.SetItem(pullD,nil);check(#pullD.ItemFolder:GetChildren()==0,'nil empties the slot')
 local c=pullD.Model:GetAttribute('ItemCenter')
 check(R.typeof(c)=='Vector3'and near(toLocal(pullD,c).Y,Art.ItemBase()+Rules.ItemHeight/2,.01),'the display tells the client where the item\'s centre is (ItemCenter)')
end

-- 3. The looks -----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local text=Rules.SignText('Pull',nil,nil,3600)
 Art.SetSign(pullD,text);Art.Tint(pullD,text.Accent,'Empty',nil)
 check(pullD.Halo.Transparency==1 and pullD.Light.Enabled==false,'the empty BEST PULL: no halo, the light off')
 check(pullD.Labels.Name.Text=='Nobody yet'and pullD.Model:GetAttribute('State')=='Empty','and says nobody yet')
 local rec=Rules.CleanPull({Uid=1,Name='Jess',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='Mythic',Odds=.125,Scale=1,At=5})
 local t2=Rules.SignText('Pull',rec,nil,18720)
 Art.SetSign(pullD,t2);Art.Tint(pullD,t2.Accent,'Ready',4)
 local want=R.Color3.fromRGB(t2.Accent[1],t2.Accent[2],t2.Accent[3])
 check(pullD.Labels.Title.Text=='🏆 BEST PULL TODAY'and pullD.Labels.Name.Text=='Jess'and pullD.Labels.Line.Text=='Mythic Fire Pepper'and pullD.Labels.Odds.Text=='1/800'and pullD.Labels.Footer.Text=='New board in 5h 12m','the sign says it all: title, name, seed, chance, countdown')
 check(near(pullD.Labels.Line.TextColor3.R,want.R,.01)and near(pullD.Labels.Line.TextColor3.G,want.G,.01),'the seed line is in the rarity\'s colour')
 check(pullD.Halo.Transparency>0 and pullD.Halo.Transparency<1 and near(pullD.Halo.Color.R,want.R,.01)and pullD.Light.Enabled and near(pullD.Light.Color.R,want.R,.01),'a champion: the halo and the light wear the rarity\'s colour')
 local lit=0;for _,p in ipairs(pullD.Lit)do if near(p.Color.R,want.R,.01)and p.Material==R.Enum.Material.Neon then lit+=1 end end
 check(lit==#pullD.Lit and #pullD.Lit>=10,'all '..#pullD.Lit..' lit parts (podium ring and gems, post gems, plinth glow, crown jewels) glow in it')
 check(pullD.Model:GetAttribute('State')=='Champion','the model says Champion')
 local ribbon=pullD.Ribbon.BackgroundColor3
 check(ribbon.R<want.R+.001 and ribbon.R>0,'the ribbon behind the title is a deep shade of it')
 -- the podium wears the seed's biome (Lava)
 local theme=W.module('MysteryPackRules').Theme(4)
 local body=0;for _,p in ipairs(pullD.PodiumArt.Body)do if near(p.Color.R*255,theme.Body[1],.6)then body+=1 end end
 check(body==#pullD.PodiumArt.Body and body>=3,'the podium\'s body is in Lava\'s treadmill colours (the pulled seed\'s biome)')
 Art.Tint(pullD,t2.Accent,'Empty',nil)
 check(pullD.Light.Enabled==false and pullD.Halo.Transparency==1,'back to calm')
 -- the fruit board
 local f=Rules.CleanFruit({Uid=2,Name='Sam',Id='SunflowerSeed',Scale=2.5,Coat='Gold',At=5})
 local ft=Rules.SignText('Fruit',f,'SunflowerSeed',100,'Watermelon')
 Art.SetSign(fruitD,ft);Art.Tint(fruitD,ft.Accent,'Ready',1)
 check(fruitD.Labels.Title.Text=='🍉 BIGGEST WATERMELON TODAY'and fruitD.Labels.Line.Text=='Sam'and fruitD.Labels.Odds.Text=='Gold','the fruit sign: title, weight, name, the coat')
end

-- 4. Cost ---------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local item=Art.BuildItem(pullD,{Kind='Seed',Id='HoloAppleTreeSeed',Coat='None'}) -- (the biggest seed model: 116 parts)
 Art.SetItem(pullD,item)
 local avatar=HH.rig(10);avatar.Parent=pullD.AvatarFolder
 local n=Art.Counts(pullD)
 check(n.Frame+n.Item+n.Avatar<=400,'a finished display with the biggest seed and an avatar with 10 hats is '..(n.Frame+n.Item+n.Avatar)..' parts (frame '..n.Frame..', item '..n.Item..', avatar '..n.Avatar..')')
 check(#all(pullD.Model,'PointLight')==1,'one light')
 check(#all(pullD.Model,'ParticleEmitter')==0,'no emitters on the server (the client adds sparkles near the display)')
 local m=getmetatable(pullD)
 local fns=0;for k,v in pairs(Art)do if type(v)=='function'then fns+=1 end end
 check(next(Art.Dim)~=nil and fns>=8,'the art module is functions and constants (no connections, no state)')
 -- nothing happens over time
 local before=#parts(pullD.Model);for _=1,40 do R.advance(.5)end
 check(#parts(pullD.Model)==before,'nothing is added or removed over time')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
