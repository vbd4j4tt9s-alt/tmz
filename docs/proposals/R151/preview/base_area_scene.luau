--!nocheck
-- R151 base area preview (design only, not a test and not game code): the owner's hub as players see it, for base_area.html.
-- Loads the owner's Workspace.ChestChaseMap (place_tree.luau from docs/proposals/R149/tools/rbxl_geom.py --tree) into the Roblox mock
-- (docs/proposals/R149/tests/zfight_world.luau), runs the REAL start-up builders exactly like the R149 z-fighting scene does
-- (MapService.new with MarketLayout / GardenBaseLayout / TrackExpansion83 ..., the six treadmills, the garden fences, the mystery pedestals,
-- Verity's dais, the hub leaderboards) and the client keyboard around a runner at the track start, then - with REDESIGN = true - the
-- scratch R151 dressing (HubDressing151.luau, this folder: walls, track gate, paths, base entrances, life), and prints one line
-- "SCENE {...}": every visible BasePart (tools/zfight.py format, so the same file feeds the z-fighting check), every SurfaceGui's layout
-- (text drawn on faces), point lights and particle emitters.
-- Globals (set by the runner): REDESIGN (bool), PHASE (1 = the server half only, 2 = + the client "life" layer), WALL ('tall' = the dressed
-- 48-stud wall | 'low' = owner option: 30-stud visible wall + skyline), SLOTS (draw the reserved future slots as ghosts), OWNERS (base index ->
-- display name, for the name banners), RUNNER = {x, z}. BUILT = true: the real R151 src (HubDecor151 via MapService + HubLife151.client) instead
-- of the scratch builder; CLIENT_TIER (1..3) for the client.
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return{}end
function Players.GetPlayerByUserId()return nil end;function Players.GetUserThumbnailAsync()return'',true end
local Http=W.service('HttpService');local guid=0;function Http.GenerateGUID()guid+=1;return'guid-'..guid end;function Http.JSONEncode(_,t)return'{}'end;function Http.JSONDecode()return{}end
local DS=W.service('DataStoreService');function DS.GetDataStore()return{GetAsync=function()return nil end,SetAsync=function()end,UpdateAsync=function()return nil end}end;DS.GetOrderedDataStore=DS.GetDataStore
local MS=W.service('MarketplaceService');MS.PromptProductPurchaseFinished=R.signal();MS.PromptGamePassPurchaseFinished=R.signal()
W.env.bit32=bit32
do local Inst=R.Inst;local raw=Inst.IsA
 function Inst:IsA(c)if self._class=='SpawnLocation'and(c=='Part'or c=='BasePart'or c=='PVInstance'or c=='FormFactorPart')then return true end;return raw(self,c)end
end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='RemoteFunction'then o.OnServerInvoke=nil end
 if class=='BindableEvent'then o.Event=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local map=Z.loadPlace(require('./place_tree'),W.workspace)
local steps,failed={},0
local function step(name,fn,...)
 local ok,err=pcall(fn,...)
 if ok then steps[#steps+1]=name else failed+=1;print('STEP '..name..' FAILED '..tostring(err))end
 return ok
end
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local Config;step('Config',function()Config=server('Config')end)
local art;step('BiomeVisuals',function()art=server('BiomeVisuals')end)
step('MapService.new',function()server('MapService').new(Config);R.advance(.1)end)
-- Treadmills and fences: the starting tier (1, Forest) on every base, as most bases look; base 2 / 4 show tier 3 / 5 for variety.
local skins={1,3,1,5,2,1}
local records={}
for _,base in ipairs(map.Bases:GetChildren())do if base:GetAttribute('BaseIndex')then
 local i=base:GetAttribute('BaseIndex');records[#records+1]={Index=i,Model=base,Pad=base:FindFirstChild('Pad')}
 step('Treadmill '..base.Name,function()art.BuildTreadmillV131(base,skins[i]or 1)end)
end end
table.sort(records,function(a,b)return a.Index<b.Index end)
step('GardenTypography',function()W.module('GardenTypography').Apply(map)end)
step('GardenFenceArt',function()local A=server('GardenFenceArt');for _,r in ipairs(records)do A.Build(r.Model,skins[r.Index]or 1)end end)
step('MysteryPedestal',function()
 local S=server('MysteryPackService');local svc=S.new(Config,{},{Map=nil},{},{},{MapRoot=map})
 for _,r in ipairs(records)do svc:_build(r)end
end)
step('VerityDais',function()
 local S=server('VerityService');local svc=S.new(Config,{},{},{},{MapRoot=map,EconomyHub=map.EconomyHub})
 svc:_build(map.EconomyHub)
end)
step('Leaderboards',function()
 local L=W.module('LeaderboardLandscape')
 for _,m in ipairs(map.EconomyHub.GeneratedHubScenery:GetChildren())do if m:GetAttribute('SceneryOwner')=='ChestChase'then L.Apply(m)end end
end)
-- Owners (the name banners and the owner badges read these attributes, as BaseService sets them).
local owners=OWNERS or{}
for _,r in ipairs(records)do local name=owners[r.Index];if name then
 r.Model:SetAttribute('BaseOwnerDisplayName',name);r.Model:SetAttribute('BaseOwnerUserId',1000+r.Index)
end end
R.advance(1)
if not RS:FindFirstChild('R142Keycap')then -- the place's keycap mesh (ReplicatedStorage.R142Keycap): a stand-in of the same size
 local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55)
 local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
 local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=RS
end
-- R151 dressing, server half (static geometry everyone shares).
local Dress
if REDESIGN then
 step('HubDressing151 (server)',function()
  Dress=W.module('HubDressing151')
  Dress.BuildServer(map,{Wall=WALL or'tall'})
 end)
end
-- Client builders: the keyboard around a runner at the track start, then the R151 client half (life: trees, flowers, lamps, butterflies...).
Run.IsClient=function()return true end;Run.IsServer=function()return false end
local player=R.new('Player');player.Name='Tester';player.UserId=1001;player.Parent=Players;Players.LocalPlayer=player
player:SetAttribute('PhysicalWalkSpeed',60)
function Players.GetPlayers()return{player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play()end;function R.Inst.Stop()end
W.service('ContentProvider').PreloadAsync=function()end
W.stub('ClientFxBudget',{Get=function()return CLIENT_TIER or 3 end,Low=function()return(CLIENT_TIER or 3)==1 end})
local RUNNER=RUNNER or{0,-60}
local model=R.new('Model');model.Name='Tester'
local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Transparency=1;root.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.Parent=model;model.PrimaryPart=root;model.Parent=W.workspace;player.Character=model
root.CFrame=CF(RUNNER[1],7,RUNNER[2])
step('KeyboardTrack.client',function()local sc=R.new('LocalScript');sc.Name='KeyboardTrack';W.load('KeyboardTrackClient',sc);W.frames(90)end)
-- the test player is just faster than the Jungle keeper (so the gate shows Forest and Jungle ticked on his screen)
pcall(function()player:SetAttribute('PhysicalWalkSpeed',W.module('KeeperPursuit').EscapeSpeed(6)+.5)end)
if REDESIGN and Dress and(PHASE or 2)>=2 then step('HubDressing151 (client)',function()Dress.BuildClient(map,{Wall=WALL or'tall',Player=player,Slots=SLOTS});W.frames(5)end)end
-- BUILT: the real R151 code of this checkout (MapService already ran HubDecor151); the real client script builds the life layer, with every
-- detail level shown (renders look from many places).
if BUILT and(PHASE or 2)>=2 then step('HubLife151.client',function()
 local sc=R.new('LocalScript');sc.Name='HubLife151';sc:SetAttribute('R151TestHook',true);sc.Parent=player:FindFirstChild('PlayerGui')
 local api=W.load('HubLife151Client',sc);assert(api,'no test hook')
 assert(api.Build(),'HubLife151 build failed')
 api.Near.detail=1e6;api.Near.fine=1e6;api.ApplyLod();api.ApplyKeys();api.ApplySigns()
 if NIGHT then for _,l in ipairs(api.State.Ctx.Lights)do l.Enabled=true end end
 BUILT_API=api
end)end
model.Parent=nil -- (the test runner's invisible root is not drawn anyway)
-- Dump ---------------------------------------------------------------------------------------------------------------------------------
local playable={}
do local f=map.Lobby.LobbyFloor;local c,s=f.CFrame.Position,f.Size
 playable[#playable+1]=string.format('[%.3f,%.3f,%.3f,%.3f]',c.X-s.X/2,c.Z-s.Z/2,c.X+s.X/2,c.Z+s.Z/2)
 playable[#playable+1]=string.format('[%.3f,%.3f,%.3f,%.3f]',-94,-110,94,(map:GetAttribute('BiomeTrackEndZ')or 5980)+10)
end
local function areaOf(p)
 local path=Z.path(p)
 if path:find('R151HubDressing',1,true)then local g=path:match('R151HubDressing/([^/]+)');return'r151:'..(g or'?')end
 if path:find('KeyboardTrackVisuals',1,true)then return'keyboard'end
 if path:find('EconomyHub/MerchantStands',1,true)or path:find('EconomyHub/FruitOfTheHour',1,true)then return'shop'end
 if path:find('EconomyHub/VerityNPC',1,true)then return'verity'end
 if path:find('/EconomyHub/',1,true)then return'hub'end
 if path:find('/Bases/',1,true)then return'bases'end
 if path:find('/Lobby/',1,true)or path:find('ChestChaseWalls',1,true)or path:find('GardenHubDesign',1,true)then return'lobby'end
 return'track'
end
local parts=Z.dump(W.workspace,areaOf)
local function n4(v)return string.format('%.4f',v)end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function enumName(e)if e==nil then return nil end;if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local function rgb(c)if not c then return'[255,255,255]'end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function partOf(o)local x=o;while x do if x:IsA('BasePart')and x._props.CFrame then return x end;x=x._parent end;return nil end
local function frameJson(part)
 local cf=part._props.CFrame;local r=cf.R;local p=cf.Position;local s=part._props.Size
 return string.format('"p":[%s,%s,%s],"r":[[%s,%s,%s],[%s,%s,%s],[%s,%s,%s]],"s":[%s,%s,%s]',n4(p.X),n4(p.Y),n4(p.Z),n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),n4(s.X),n4(s.Y),n4(s.Z))
end
-- SurfaceGuis: canvas size and every visible Frame / TextLabel with its absolute rectangle on the canvas.
local guis={}
local faceDims={Front=function(s)return s.X,s.Y end,Back=function(s)return s.X,s.Y end,Left=function(s)return s.Z,s.Y end,Right=function(s)return s.Z,s.Y end,Top=function(s)return s.X,s.Z end,Bottom=function(s)return s.X,s.Z end}
local function hidden(o,stop)local x=o;while x and x~=stop do if x._props.Visible==false then return true end;x=x._parent end;return false end
for _,sg in ipairs(W.workspace:GetDescendants())do
 if sg._class=='SurfaceGui'and sg._props.Enabled~=false then
  local part=sg._props.Adornee or partOf(sg._parent)
  if part and part._props.Size and(part._props.Transparency or 0)<1.5 then
   local face=enumName(sg._props.Face)or'Front';local fw,fh=faceDims[face](part._props.Size)
   local cw,ch
   if enumName(sg._props.SizingMode)=='PixelsPerStud'then local k=sg._props.PixelsPerStud or 50;cw,ch=fw*k,fh*k
   else local c=sg._props.CanvasSize;cw,ch=c and c.X or 800,c and c.Y or 600 end
   local items={}
   local function walk(o,px,py,pw,ph)
    for _,g in ipairs(o._children)do
     if(g._class=='Frame'or g._class=='TextLabel'or g._class=='TextButton'or g._class=='ImageLabel')and g._props.Visible~=false then
      local pos=g._props.Position or R.UDim2.new(0,0,0,0);local size=g._props.Size or R.UDim2.new(0,100,0,100);local ap=g._props.AnchorPoint or{X=0,Y=0}
      local w=size.X.Scale*pw+size.X.Offset;local h=size.Y.Scale*ph+size.Y.Offset
      local x=px+pos.X.Scale*pw+pos.X.Offset-ap.X*w;local y=py+pos.Y.Scale*ph+pos.Y.Offset-ap.Y*h
      local corner,stroke
      for _,k in ipairs(g._children)do
       if k._class=='UICorner'then local cr=k._props.CornerRadius;corner=cr and(cr.Scale*math.min(w,h)+cr.Offset)or 8
       elseif k._class=='UIStroke'and k._props.Enabled~=false then stroke=string.format('{"c":%s,"w":%s,"t":%s}',rgb(k._props.Color),n4(k._props.Thickness or 1),n4(k._props.Transparency or 0))end
      end
      local text=(g._class=='TextLabel'or g._class=='TextButton')and g._props.Text or nil
      items[#items+1]=string.format('{"cls":%s,"x":%s,"y":%s,"w":%s,"h":%s,"bg":%s,"bgT":%s,"text":%s,"tc":%s,"tT":%s,"sc":%s,"sT":%s,"scaled":%s,"ts":%s,"rot":%s,"corner":%s,"stroke":%s,"xa":%s,"font":%s}',
       q(g._class),n4(x),n4(y),n4(w),n4(h),rgb(g._props.BackgroundColor3),n4(g._props.BackgroundTransparency or 0),text and q(text)or'null',rgb(g._props.TextColor3),n4(g._props.TextTransparency or 0),
       rgb(g._props.TextStrokeColor3),n4(g._props.TextStrokeTransparency or 1),g._props.TextScaled and'true'or'false',n4(g._props.TextSize or 14),n4(g._props.Rotation or 0),
       corner and n4(corner)or'null',stroke or'null',q(enumName(g._props.TextXAlignment)or'Center'),q(enumName(g._props.Font)or''))
      walk(g,x,y,w,h)
     end
    end
   end
   walk(sg,0,0,cw,ch)
   if #items>0 then guis[#guis+1]=string.format('{%s,"face":%s,"cw":%s,"ch":%s,"path":%s,"items":[%s]}',frameJson(part),q(face),n4(cw),n4(ch),q(Z.path(part)),table.concat(items,','))end
  end
 end
end
-- Point lights and particle emitters (glows and petals in the render).
local lights,emitters={},{}
for _,o in ipairs(W.workspace:GetDescendants())do
 if(o._class=='PointLight'or o._class=='SpotLight')and(o._props.Enabled~=false or o._props.Name=='R151LampLight')then -- (R151 lamps are off by day: "off")
  local p=partOf(o._parent);if p then local c=p._props.CFrame.Position
   lights[#lights+1]=string.format('{"p":[%s,%s,%s],"color":%s,"range":%s,"brightness":%s,"off":%s}',n4(c.X),n4(c.Y),n4(c.Z),rgb(o._props.Color),n4(o._props.Range or 8),n4(o._props.Brightness or 1),o._props.Enabled==false and'true'or'false')end
 elseif o._class=='ParticleEmitter'and o._props.Enabled~=false and(o._props.Rate or 0)>0 then
  local p=partOf(o._parent);if p then local c=p._props.CFrame.Position;local s=p._props.Size
   local col=o._props.Color;col=col and(col.R and col or col.A and col.A.R and col.A)or nil
   local life=o._props.Lifetime;life=type(life)=='table'and life.Min and(life.Min+life.Max)/2 or 2
   local sp=o._props.Speed;sp=type(sp)=='table'and sp.Min and(sp.Min+sp.Max)/2 or 1
   emitters[#emitters+1]=string.format('{"p":[%s,%s,%s],"size":[%s,%s,%s],"color":%s,"rate":%s,"life":%s,"speed":%s,"acc":%s}',n4(c.X),n4(c.Y),n4(c.Z),n4(s.X),n4(s.Y),n4(s.Z),rgb(col),n4(o._props.Rate or 1),n4(life),n4(sp),n4(o._props.Acceleration and o._props.Acceleration.Y or 0))end
 end
end
for _,s in ipairs(steps)do print('STEP '..s..' ok')end
print('SCENE {"playable":['..table.concat(playable,',')..'],"parts":['..table.concat(parts,',')..'],"guis":['..table.concat(guis,',')..'],"lights":['..table.concat(lights,',')..'],"emitters":['..table.concat(emitters,',')..']}')
print(string.format('ZSCENE %d parts, %d guis, %d lights, %d emitters, %d steps ok, %d failed',#parts,#guis,#lights,#emitters,#steps,failed))
