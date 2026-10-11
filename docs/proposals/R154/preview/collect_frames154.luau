-- R154 preview (not a test): appended to R152's preview_frames152.luau with SET='collect' (run_seed_collect_preview.sh), so it uses that file's
-- mock world, real scripts and FRAME writer. Plays the REAL reveal with the REAL Hotbar on the Roblox mock and prints the moments of the collect:
-- the result waiting (its hint), still waiting 30 s later, the click, the seed's flight, its landing on the hotbar slot (the pop and the slot's
-- flash), the seed in the hotbar. A Legendary card and a King story scene, desktop 1280 x 720.
if SET=='collect'then
 setDevice(false)
 local UT,KC=R.Enum.UserInputType,R.Enum.KeyCode
 local Collect=W.module('SeedCollect154');local Card=W.module('RarePullCard')
 do local Meshes=W.module('ApprovedPlantMeshes');local cache={}
  Meshes.Get=function(key)local p=cache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=V3(1,1,1);cache[key]=p end;return p end
  Meshes.Status=function()return'Ready'end end
 -- the hotbar, laid out as the engine lays it out (its slots' AbsolutePosition: where the seed lands)
 local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
 local function lay(o,px,py,pw,ph)
  for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
   local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
   local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
   local x=px+p.X.Scale*pw+p.X.Offset-a.X*w;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h
   set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y));lay(c,x,y,w,h)
  end end
 end
 W.Run.RenderStepped:Connect(function()local g=X.pg:FindFirstChild('ChestToolHotbar');if g then lay(g,0,0,1280,720)end end)
 -- what the player carries: the shovel (slot 1), a pack, a fruit
 local function live(t,manual)t.Activated=t.Activated or R.signal();if t.ManualActivationOnly==nil then t.ManualActivationOnly=manual==true end;return t end
 live(F.shovel(W,E.bag),true);live(F.pack(W,E.bag,3,'Pack06',1,'None'));live(F.fruit(W,E.bag,'AppleSeed',1,'None',240,1))
 do local hb=R.new('LocalScript');hb.Name='Hotbar';W.load('Hotbar',hb)end
 W.frames(10,1/30)
 -- one frame: R152's frame() with the hotbar under the card and the flying seed as the viewport
 local function shot(name,label,tag)
  local Wd,Ht=1280,720
  local cam=W.workspace.CurrentCamera
  local stage=W.workspace:FindFirstChild('_RarePullStage')
  local inStage=cam.CameraType==R.Enum.CameraType.Scriptable and stage~=nil
  local roots={}
  if inStage then roots={stage}else
   roots={X.char,oc}
   for _,nm in ipairs({'_LocalSeedPackEffects','_RarePullWorld'})do local f=W.workspace:FindFirstChild(nm);if f then roots[#roots+1]=f end end
  end
  local eye=cam.CFrame.Position;local target=eye+cam.CFrame.LookVector*10;local fov=cam.FieldOfView or 70
  local g=cam:FindFirstChild('RarePullGrade');local b=cam:FindFirstChild('RarePullBlur')
  local grade=g and string.format('{"b":%s,"c":%s,"s":%s,"tint":%s}',n(g.Brightness or 0),n(g.Contrast or 0),n(g.Saturation or 0),c3(g.TintColor))or'null'
  local under,over={},{}
  local hb=X.pg:FindFirstChild('ChestToolHotbar');if hb and hb.Enabled~=false then under[#under+1]=dump(hb,Wd,Ht)end
  local u2,o2=guiLayers(Wd,Ht);for _,x in ipairs(u2)do under[#under+1]=x end;for _,x in ipairs(o2)do over[#over+1]=x end
  local vp='null'
  local fly=X.pg:FindFirstChild('SeedCollectFly');local fv=fly and fly:FindFirstChild('Seed')
  if fv and fv.CurrentCamera and(fv.ImageTransparency or 1)<.98 then
   local s=fv.Size.X.Offset;local x,y=fv.Position.X.Offset-s/2,fv.Position.Y.Offset-s/2;local vc=fv.CurrentCamera
   vp=string.format('{"rect":[%s,%s,%s,%s],"alpha":%s,"scale":1,"eye":%s,"target":%s,"fov":%s,%s}',n(x),n(y),n(s),n(s),n(1-fv.ImageTransparency),v3(vc.CFrame.Position),v3(vc.CFrame.Position+vc.CFrame.LookVector*10),n(vc.FieldOfView or 30),world({fv}))
  else
   local gui=X.pg:FindFirstChild('RarePullReveal');local view=gui and gui:FindFirstChild('Seed',true)
   if view and view._class=='ViewportFrame'and view.Visible and(view.ImageTransparency or 1)<.98 and view.CurrentCamera then
    local x,y,w,h=X.rect(view,Wd,Ht);local s=math.min(w,h);x=x+(w-s)/2;y=y+(h-s)/2
    local scale=view:FindFirstChildOfClass('UIScale');local k=scale and scale.Scale or 1;local vc=view.CurrentCamera
    vp=string.format('{"rect":[%s,%s,%s,%s],"alpha":%s,"scale":%s,"eye":%s,"target":%s,"fov":%s,%s}',n(x),n(y),n(s),n(s),n(1-view.ImageTransparency),n(k),v3(vc.CFrame.Position),v3(vc.CFrame.Position+vc.CFrame.LookVector*10),n(vc.FieldOfView or 30),world({view}))
   end
  end
  local kind=inStage and('stage'..(M.Active()and M.Active().Rank or 8))or'world'
  print('FRAME '..name..' '..string.format('{"w":%d,"h":%d,"label":%s,"tag":%s,"tree":%s,"kind":%s,"eye":%s,"target":%s,"fov":%s,"grade":%s,"blur":%s,%s,"under":[%s],"guis":[%s],"viewport":%s}',
   Wd,Ht,q(label),q(tag),q(TREE),q(kind),v3(eye),v3(target),n(fov),grade,n(b and b.Size or 0),world(roots),table.concat(under,','),table.concat(over,','),vp))
 end
 -- one opening of the opener's own pack, the server's side included (at its end: the pack goes, the seed's tool arrives and is held)
 local opened=0
 local function collectStrip(rank,prefix,tag,waitLabel)
  clearAll();opened+=1;local id='pv-collect-'..opened
  local tool=live(F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId=id,Stage=2},nil));tool.Enabled=false;tool.Parent=X.char
  local seedId=X.byRank[rank];local spec=Rules.SeedDesignById[seedId];local rarity=Rules.GetRarity(seedId)
  local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None')
  local dur=Rules.GetRevealDuration(rarity)
  bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',rarity);bag:SetAttribute('Weather','None');bag:SetAttribute('RevealDuration',dur);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
  local t0=R.clock
  local function frames(n0)
   for _=1,n0 do
    W.frames(1,1/30)
    if bag.Parent and R.clock-t0>=dur then
     bag:Destroy();tool:Destroy()
     local t=live(F.tool(W,spec and spec.name or seedId,{GardenSeed=true,SeedInventoryId=id,SeedId=seedId,SeedScale=1,Mutation='None',Weather='None',Rarity=rarity,Stage=2},E.bag),true)
     X.hum:EquipTool(t)
    end
   end
  end
  frames(1)
  local run=M.Active();local i=0
  local function take(label)i+=1;shot(string.format('%s_%02d',prefix,i),label,tag)end
  local g=0;while not run.SawResult and g<900 do frames(1);g+=1 end
  frames(12);take('THE RESULT: '..Card.CollectText(false))
  local t1=R.clock;while R.clock-t1<30 do frames(15)end
  take(waitLabel)
  if run.Kind=='Scene'then local b=X.pg.RarePullReveal:FindFirstChild('Backdrop',true);b.Activated:Fire()
  else W.UIS.InputBegan:Fire({UserInputType=UT.MouseButton1,KeyCode=KC.Unknown,Position=V3(640,360,0)},false)end
  if run.Kind=='Scene'then frames(5);take('CLICK: BACK TO THE WORLD');frames(math.floor(M.SceneExit*30)-2)end
  frames(4);take('IT FLIES HOME')
  frames(6);take('')
  local landed=false;local conn=Collect.OnRelease(function()landed=true end)
  g=0;while not landed and g<120 do frames(1);g+=1 end;conn:Disconnect()
  frames(2);take('LANDS: POP, THE SLOT FLASHES')
  frames(24);take('IN THE HOTBAR (AND THE HAND)')
  frames(30)
 end
 collectStrip(4,'collect4','Legendary card (desktop)','STILL WAITING, 30 S LATER')
 collectStrip(8,'collect8','King story scene (desktop)','STILL ON THE HERO SHOT, 30 S LATER')
end
