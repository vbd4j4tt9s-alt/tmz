--!nocheck
-- R151 treadmill look PROPOSAL (preview only, not a test and not game code): Base 1 of the owner's place (place_tree.luau from
-- docs/proposals/R149/tools/rbxl_geom.py --tree) on the Roblox mock (docs/proposals/R149/tests/zfight_world.luau), after the REAL start-up
-- builders (MapService.new, so the base's beds, apron and fence are there), the REAL treadmill (BiomeVisuals.BuildTreadmillV131) at each
-- level and the REAL upgrade buttons (GardenUpgradeService.Refresh with a stand-in player). DRESS = true adds the proposal prototype
-- (TreadmillDress151.luau, this folder) on top. The REAL client effects controller (TreadmillFx) then turns lights / particles / ribbons
-- on as a nearby player's screen would (desktop quality, someone training). Prints per level:
--   "SCENE <before|after>_L<n> {json}"  parts (with textures), SurfaceGuis, BillboardGuis, beams, lights, emitters and the views (world)
--   "ZSCENE <before|after>_L<n> {json}" the base's parts in the tools/zfight.py format (for the z-fighting check)
--   "BUDGET <before|after> L<n> parts=.. lights=.. emitters=.. beams=.. textures=.. new=.. retired=.. collide=.. query=.. label=.."
-- Globals: DRESS (bool), LEVELS (list, default 1..7).
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
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local Config=server('Config');local Art=server('BiomeVisuals')
pcall(function()server('MapService').new(Config);R.advance(.1)end)
local base
for _,b in ipairs(map.Bases:GetChildren())do if b:GetAttribute('BaseIndex')==1 then base=b end end
assert(base,'no Base 1')
local Dress=DRESS and W.module('TreadmillDress151')or nil
-- A stand-in owner for the real upgrade buttons (GardenUpgradeService.Refresh): rich, fence tier 1, treadmill tier = the level shown.
local player=R.new('Player');player.Name='Ben';player.UserId=1001;player.Parent=Players
local cash=R.new('NumberValue');cash.Value=9e15
local tread={Tier=1,Skin=1,Cleared={}}
local record={Index=1,Model=base}
local svc={GardenUpgradeRecords={},BaseOwners={[1]=player},BusyChecker=function()return false end,Config=Config,
 GetPlayerBase=function()return record end,RefreshTreadmill=function()end,
 PlayerData={GetFenceTier=function()return 1 end,GetCash=function()return cash.Value end,GetTreadmillData=function()return tread end,
  GetOrCreateCashValue=function()return cash end,IsLoaded=function()return true end}}
local Upgrade=server('GardenUpgradeService')
local Fx=W.module('TreadmillFx')
local camera=W.workspace.CurrentCamera
function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end

-- dump helpers ------------------------------------------------------------------------------------------------------------------------
local function n4(v)return string.format('%.4f',v)end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function enumName(e)if e==nil then return nil end;if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local function rgb(c)if not c then return'[255,255,255]'end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function v3(v)return string.format('[%s,%s,%s]',n4(v.X),n4(v.Y),n4(v.Z))end
-- a colour from a Color3 or a (mock) ColorSequence: {A=Color3,B=Color3} or {A={keypoints}}
local function seqColor(s)
 if type(s)~='table'then return nil end
 if s.R then return s end
 if type(s.A)=='table'then if s.A.R then return s.A end;local k=s.A[1];if type(k)=='table'then return k.V or k.Value end end
 return nil
end
local function partOf(o)local x=o;while x do if x:IsA('BasePart')and x._props.CFrame then return x end;x=x._parent end;return nil end
local function attWorld(a) -- (the mock keeps an attachment's Position as set, or the position of the CFrame it was given)
 local p=partOf(a._parent);if not p then return nil end
 local pos=a._props.Position;if type(pos)~='table'or type(pos.X)~='number'then pos=(a._props.CFrame or CF(0,0,0)).Position end
 return p._props.CFrame*pos
end
local faceDims={Front=function(s)return s.X,s.Y end,Back=function(s)return s.X,s.Y end,Left=function(s)return s.Z,s.Y end,Right=function(s)return s.Z,s.Y end,Top=function(s)return s.X,s.Z end,Bottom=function(s)return s.X,s.Z end}
local function guiItems(root,cw,ch)
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
    items[#items+1]=string.format('{"cls":%s,"x":%s,"y":%s,"w":%s,"h":%s,"bg":%s,"bgT":%s,"text":%s,"tc":%s,"tT":%s,"sc":%s,"sT":%s,"scaled":%s,"ts":%s,"rot":%s,"corner":%s,"stroke":%s,"xa":%s}',
     q(g._class),n4(x),n4(y),n4(w),n4(h),rgb(g._props.BackgroundColor3),n4(g._props.BackgroundTransparency or 0),text and q(text)or'null',rgb(g._props.TextColor3),n4(g._props.TextTransparency or 0),
     rgb(g._props.TextStrokeColor3),n4(g._props.TextStrokeTransparency or 1),g._props.TextScaled and'true'or'false',n4(g._props.TextSize or 14),n4(g._props.Rotation or 0),
     corner and n4(corner)or'null',stroke or'null',q(enumName(g._props.TextXAlignment)or'Center'))
    walk(g,x,y,w,h)
   end
  end
 end
 walk(root,0,0,cw,ch)
 return items
end
local function inArea(p,origin)local l=origin:PointToObjectSpace(p);return math.abs(l.X)<38 and math.abs(l.Z)<30 end
local function dumpScene(name,origin,views)
 local parts,guis,bills,beams,lights,emitters={},{},{},{},{},{}
 for _,c in ipairs(base:GetDescendants())do
  if c:IsA('BasePart')and c._props.CFrame and c._props.Size and((c._props.Transparency or 0)<.995)and(c==base.Pad or inArea(c._props.CFrame.Position,origin))then
   local cf=c._props.CFrame;local r=cf.R;local s=c._props.Size
   local cls=c._class;local shape='Block'
   if cls=='WedgePart'then shape='Wedge'elseif cls=='CornerWedgePart'then shape='CornerWedge'elseif cls=='MeshPart'then shape='Mesh'elseif c._props.Shape then shape=enumName(c._props.Shape)end
   local tex={}
   for _,d in ipairs(c._children)do if d._class=='Texture'then
    tex[#tex+1]=string.format('{"img":%s,"face":%s,"c":%s,"t":%s,"u":%s,"v":%s,"ou":%s,"ov":%s,"rate":%s,"z":%d}',q(d:GetAttribute('BeltImage')or'grid'),q(enumName(d._props.Face)or'Top'),rgb(d._props.Color3),n4(d._props.Transparency or 0),
     n4(d._props.StudsPerTileU or 2),n4(d._props.StudsPerTileV or 2),n4(d._props.OffsetStudsU or 0),n4(d._props.OffsetStudsV or 0),n4(d:GetAttribute('TreadmillScroll')or 0),d._props.ZIndex or 1)
   end end
   parts[#parts+1]=string.format('{"name":%s,"path":%s,"shape":%s,"size":%s,"p":%s,"r":[[%s,%s,%s],[%s,%s,%s],[%s,%s,%s]],"color":%s,"material":%s,"t":%s%s}',
    q(c.Name),q(Z.path(c,base)),q(shape),v3(s),v3(cf.Position),n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),
    rgb(c._props.Color),q(enumName(c._props.Material)or'Plastic'),n4(c._props.Transparency or 0),#tex>0 and(',"tex":['..table.concat(tex,',')..']')or'')
  elseif c._class=='SurfaceGui'and c._props.Enabled~=false then
   local part=c._props.Adornee or partOf(c._parent)
   if part and part._props.Size and inArea(part._props.CFrame.Position,origin)then
    local face=enumName(c._props.Face)or'Front';local cw,ch
    if enumName(c._props.SizingMode)=='PixelsPerStud'then local k=c._props.PixelsPerStud or 50;local fw,fh=faceDims[face](part._props.Size);cw,ch=fw*k,fh*k
    else local cs=c._props.CanvasSize;cw,ch=cs and cs.X or 800,cs and cs.Y or 600 end
    local items=guiItems(c,cw,ch)
    local cf=part._props.CFrame;local r=cf.R;local s=part._props.Size
    if #items>0 then guis[#guis+1]=string.format('{"p":%s,"r":[[%s,%s,%s],[%s,%s,%s],[%s,%s,%s]],"s":%s,"face":%s,"cw":%s,"ch":%s,"path":%s,"items":[%s]}',v3(cf.Position),
     n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),v3(s),q(face),n4(cw),n4(ch),q(Z.path(part,base)),table.concat(items,','))end
   end
  elseif c._class=='BillboardGui'and c._props.Enabled~=false then
   local at=c._parent and c._parent._class=='Attachment'and attWorld(c._parent)or(partOf(c._parent)and partOf(c._parent)._props.CFrame.Position)
   local sz=c._props.Size
   if at and sz then
    local items=guiItems(c,sz.X.Scale*100,sz.Y.Scale*100)
    bills[#bills+1]=string.format('{"p":%s,"w":%s,"h":%s,"hideOwner":%s,"items":[%s]}',v3(at),n4(sz.X.Scale),n4(sz.Y.Scale),c:GetAttribute('HideWhileOwnerTrains')and'true'or'false',table.concat(items,','))
   end
  elseif c._class=='Beam'and c._props.Enabled then
   local a,b=c._props.Attachment0,c._props.Attachment1
   local pa,pb=a and attWorld(a),b and attWorld(b)
   if pa and pb then
    local col=seqColor(c._props.Color)
    local tx=tostring(c._props.Texture or''):match('particles/(%a+)_')or'sparkles'
    local tr=c._props.Transparency;local t=.3
    if type(tr)=='number'then t=tr elseif type(tr)=='table'then local list=type(tr.A)=='table'and tr.A or nil;if list and list[2]then t=list[2].V or list[2].Value or .3 elseif type(tr.A)=='number'then t=tr.A end end
    beams[#beams+1]=string.format('{"a":%s,"b":%s,"w0":%s,"w1":%s,"c":%s,"tex":%s,"face":%s,"t":%s,"c0":%s,"c1":%s}',v3(pa),v3(pb),n4(c._props.Width0 or 1),n4(c._props.Width1 or 1),rgb(col),q(tx),
     c._props.FaceCamera and'true'or'false',n4(t),n4(c._props.CurveSize0 or 0),n4(c._props.CurveSize1 or 0))
   end
  elseif(c._class=='PointLight'or c._class=='SpotLight')and c._props.Enabled then
   local p=c._parent._class=='Attachment'and attWorld(c._parent)or(partOf(c._parent)and partOf(c._parent)._props.CFrame.Position)
   if p then lights[#lights+1]=string.format('{"p":%s,"color":%s,"range":%s,"brightness":%s}',v3(p),rgb(c._props.Color),n4(c._props.Range or 8),n4(c._props.Brightness or 1))end
  elseif c._class=='ParticleEmitter'and c._props.Enabled and(c._props.Rate or 0)>0 then
   local p=c._parent._class=='Attachment'and attWorld(c._parent)or(partOf(c._parent)and partOf(c._parent)._props.CFrame.Position)
   if p then
    local col=seqColor(c._props.Color)
    local life=c._props.Lifetime;life=type(life)=='table'and life.Min and(life.Min+life.Max)/2 or 2
    local sp=c._props.Speed;sp=type(sp)=='table'and sp.Min and(sp.Min+sp.Max)/2 or 1
    local acc=c._props.Acceleration or V3(0,0,0)
    emitters[#emitters+1]=string.format('{"p":%s,"color":%s,"rate":%s,"life":%s,"speed":%s,"acc":%s,"tex":%s}',v3(p),rgb(col),n4(c._props.Rate or 1),n4(life),n4(sp),n4(acc.Y),q(tostring(c._props.Texture or''):match('particles/(%a+)_')or'sparkles'))
   end
  end
 end
 print('SCENE '..name..' {"parts":['..table.concat(parts,',')..'],"guis":['..table.concat(guis,',')..'],"bills":['..table.concat(bills,',')..'],"beams":['..table.concat(beams,',')..'],"lights":['..table.concat(lights,',')..'],"emitters":['..table.concat(emitters,',')..'],"views":{'..views..'}}')
end
-- Views, in the treadmill's own space (x across, y up from the belt centre, z: the runner faces -z; the entry end is +z), made world here.
local VIEWS={
 hero={{12,9,22.5},{0,3.6,-1.5},46},
 side={{-25,7,3},{0,3.8,-.5},46},
 front={{-7,7.5,-25},{0,4.5,-5},46},
 runner={{0,8.6,15.5},{0,3.4,-6},56,owner=true},
 belt={{2.6,5.6,13.2},{0,0,1.6},44},
 corner={{11.5,3.4,15},{6.2,.7,7.4},40},
 label={{-3.5,9.5,-21},{0,8.6,-7.5},46},
 sign={{5,5.2,10.5},{21,2.6,6.5},46},
 wide={{-17,21,35},{5,0,1},50},
}
local function viewsJson(origin)
 local out={}
 for name,v in pairs(VIEWS)do
  local cam=origin*V3(v[1][1],v[1][2],v[1][3]);local look=origin*V3(v[2][1],v[2][2],v[2][3])
  local avatar=origin*V3(0,.2,0)
  out[#out+1]=string.format('%s:{"pos":%s,"look":%s,"fov":%s,"owner":%s,"runner":%s,"belt":%s}',q(name),v3(cam),v3(look),n4(v[3]),v.owner and'true'or'false',v3(avatar),v3(origin*V3(0,0,-1)-origin.Position))
 end
 return table.concat(out,',')
end

local levels=LEVELS or{1,2,3,4,5,6,7}
local which=DRESS and'after'or'before'
for _,level in ipairs(levels)do
 Art.BuildTreadmillV131(base,level)
 tread.Tier=level;tread.Skin=level
 Upgrade.Refresh(svc,player)
 local summary,sign
 if Dress then
  summary=Dress.Apply(base,level,Config)
  sign=Dress.Sign(base,level,Config,function(n)return'$'..Dress.Format(n)end)
 end
 local belt=base.Treadmill;local origin=belt._props.CFrame
 belt:SetAttribute('TrainingActive',true)
 -- the real client fx controller, desktop quality, camera 14 studs behind the runner
 camera.CFrame=CF((origin*V3(0,8,16)).X,(origin*V3(0,8,16)).Y,(origin*V3(0,8,16)).Z)
 local fx=Fx.new({Map=function()return map end,Camera=function()return camera end,Quality=function()return 3 end,Fast=function()return false end,
  Reduced=function()return false end,Random=W.env.Random.new(3),Move=function(ps,cfs)for i,p in ipairs(ps)do p.CFrame=cfs[i]end end})
 fx:Step(1.05);fx:Step(.05);fx:Step(.05)
 -- budgets: every BasePart of the treadmill art (+ the dressing), lights, emitters, beams, textures; collision / query of new parts
 local art=base.TreadmillArtV131
 local counts={Parts=0,Lights=0,Emitters=0,Beams=0,Textures=0,Collide=0,Query=0}
 for _,v in ipairs(art:GetDescendants())do
  if v:IsA('BasePart')then counts.Parts+=1;if v.CanCollide then counts.Collide+=1 end;if v.CanQuery then counts.Query+=1 end
  elseif v:IsA('Light')then counts.Lights+=1 elseif v._class=='ParticleEmitter'then counts.Emitters+=1 elseif v._class=='Beam'then counts.Beams+=1 elseif v._class=='Texture'then counts.Textures+=1 end
 end
 local signParts=0;local sm=base:FindFirstChild('TreadmillUpgradeSign');if sm then for _,v in ipairs(sm:GetDescendants())do if v:IsA('BasePart')then signParts+=1;if v.CanCollide then counts.Collide+=1 end;if v.CanQuery then counts.Query+=1 end end end end
 print(string.format('BUDGET %s L%d parts=%d lights=%d emitters=%d beams=%d textures=%d new=%d retired=%d sign=%d collide=%d query=%d label=%s belt=%s',which,level,counts.Parts,counts.Lights,counts.Emitters,counts.Beams,counts.Textures,
  summary and summary.Parts or 0,summary and summary.Retired or 0,signParts,counts.Collide,counts.Query,summary and summary.Label or'-',tostring(belt.Size)..'@'..tostring(belt.Position)..' solid='..tostring(belt.CanCollide)))
 dumpScene(which..'_L'..level,origin,viewsJson(origin))
 -- z-fighting scene: the whole base (treadmill, dressing, sign, buttons, fence, beds, apron, pad)
 local zparts=Z.dump(base,function(p)local path=Z.path(p);if path:find('TreadmillDress',1,true)or path:find('TreadmillUpgradeSign',1,true)then return'r151treadmill'end;if path:find('TreadmillArtV131',1,true)then return'treadmill'end;return'base'end)
 local pad=base.Pad;local pc,ps=pad._props.CFrame.Position,pad._props.Size
 print('ZSCENE '..which..'_L'..level..' {"playable":[['..n4(pc.X-120)..','..n4(pc.Z-120)..','..n4(pc.X+120)..','..n4(pc.Z+120)..']],"parts":['..table.concat(zparts,',')..']}')
 belt:SetAttribute('TrainingActive',false)
 fx:Destroy()
end
