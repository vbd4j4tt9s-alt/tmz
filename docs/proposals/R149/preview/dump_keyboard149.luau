--!nocheck
-- R149 keyboard preview dump (not a test): runs the REAL KeyboardTrack.client.lua (+ KeyboardTrack.lua) of whichever version rs_bundle.luau
-- holds (R148 = "before", R149 = "after") on the Roblox mock, with a map that has Obby/Biomes/<biome>/BiomeGround_n floors in the biomes'
-- ground colours, and prints one JSON line per scene ("SCENE <name> {json}") for render_keyboard149.mjs:
--  parts  every visible keyboard part (name, class, size, centre, colour) and the real floors (with their LocalTransparencyModifier: a
--         floor the keyboard hides for this client is not drawn);
--  guis   every SurfaceGui that is on a part (its face size, canvas size, labels: text, centre / size in canvas pixels, rotation, ink,
--         transparency, text size or TextScaled), so the renderer can paint the letters where Roblox would;
--  runner the local runner (on the ground: the key under him is down).
-- Scenes: the runner 60 studs before the Desert spacebar (Jungle), in Snow 150 studs before Lava (the long view), and in Crystal.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local workspace=W.workspace
local K=W.module('KeyboardTrack');local C=K.Config;local F=C.FloorTop
local ATTR={BiomeTrackEndZ=5980,BiomeStartZ_1=-100,BiomeEndZ_1=80,BiomeStartZ_6=80,BiomeEndZ_6=530,BiomeStartZ_2=530,BiomeEndZ_2=1180,
 BiomeStartZ_3=1180,BiomeEndZ_3=2030,BiomeStartZ_4=2030,BiomeEndZ_4=3080,BiomeStartZ_5=3080,BiomeEndZ_5=4380,BiomeStartZ_7=4380,BiomeEndZ_7=5980}
-- the biomes' real ground colours (BiomeVisuals overrides for Snow / Lava / Crystal, the R143 keyboard's samples of the map for the rest)
local GROUND={[1]={82,180,87},[6]={78,133,62},[2]={224,188,103},[3]={176,194,204},[4]={56,57,66},[5]={94,78,123},[7]={88,111,144}}
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return {player}end
function workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play()end;function R.Inst.Stop()end
W.service('ContentProvider').PreloadAsync=function()end
W.stub('ClientFxBudget',{Get=function()return 3 end,Low=function()return false end})
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace
for k,v in pairs(ATTR)do map:SetAttribute(k,v)end
local obby=R.new('Folder');obby.Name='Obby';obby.Parent=map
local biomes=R.new('Folder');biomes.Name='Biomes';biomes.Parent=obby
local floors={}
for id=1,7 do
 local a,b=ATTR['BiomeStartZ_'..id],ATTR['BiomeEndZ_'..id]
 local m=R.new('Model');m.Name='Biome'..id;m:SetAttribute('Stage',id);m.Parent=biomes
 local gp=R.new('Part');gp.Name='BiomeGround_'..id;gp.Size=V3(180,4,b-a);gp.CFrame=CF(0,F-2,(a+b)/2);gp.Anchored=true;gp.Archivable=true
 gp.Color=R.Color3.fromRGB(GROUND[id][1],GROUND[id][2],GROUND[id][3]);gp.Parent=m
 floors[#floors+1]=gp
end
local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55);template.Archivable=true
local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.CanvasSize=R.Vector2.new(256,256);tgui.Parent=template
local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=W.RS
local model=R.new('Model');model.Name='Tester'
local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.Parent=model;model.PrimaryPart=root;model.Parent=workspace;player.Character=model
local g=K.Geometry(ATTR,0)
-- the camera looks down the track (+Z), as in the renders (R149 turns its long side toward the camera's facing)
workspace.CurrentCamera.CFrame=R.CFrame.lookAt(V3(0,20,0),V3(0,20,100))
local sc=R.new('LocalScript');sc.Name='KeyboardTrack'
root.CFrame=CF(2,F+3,470);W.load('KeyboardTrackClient',sc)
local function n(v)return string.format('%.3f',v)end
local function rgb(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function dump(name,rx,rz)
 root.CFrame=CF(rx,F+3,rz);W.frames(240)
 local vis=workspace:FindFirstChild('KeyboardTrackVisuals')
 local parts,guis={}, {}
 local function addPart(p,kind)
  local pos=p.CFrame.Position
  parts[#parts+1]=string.format('{"k":"%s","cls":"%s","s":[%s,%s,%s],"p":[%s,%s,%s],"c":%s,"t":%s}',kind or p.Name,p._class,n(p.Size.X),n(p.Size.Y),n(p.Size.Z),n(pos.X),n(pos.Y),n(pos.Z),rgb(p.Color),n(p.Transparency or 0))
 end
 local function addGui(gui,p)
  local pos=p.CFrame.Position;local w,d=p.Size.X,p.Size.Z
  local cw,ch
  if gui.SizingMode==R.Enum.SurfaceGuiSizingMode.PixelsPerStud then cw,ch=w*gui.PixelsPerStud,d*gui.PixelsPerStud
  else local cs=gui.CanvasSize;cw,ch=cs and cs.X or 800,cs and cs.Y or 600 end
  local labels={}
  for _,l in ipairs(gui:GetDescendants())do
   if l._class=='TextLabel'and l.Visible~=false and(l.Text or '')~=''and(l.TextTransparency or 0)<1 then
    local ps,sz=l.Position,l.Size
    local x=(ps and ps.X.Scale or 0)*cw+(ps and ps.X.Offset or 0);local y=(ps and ps.Y.Scale or 0)*ch+(ps and ps.Y.Offset or 0)
    local lw=(sz and sz.X.Scale or 0)*cw+(sz and sz.X.Offset or 0);local lh=(sz and sz.Y.Scale or 0)*ch+(sz and sz.Y.Offset or 0)
    local ap=l.AnchorPoint;if ap then x+=lw*(.5-ap.X);y+=lh*(.5-ap.Y)end
    labels[#labels+1]=string.format('{"t":"%s","x":%s,"y":%s,"w":%s,"h":%s,"rot":%d,"ink":%s,"a":%s,"size":%d,"scaled":%s}',l.Text,n(x),n(y),n(lw),n(lh),l.Rotation or 0,
     rgb(l.TextColor3 or R.Color3.new()),n(l.TextTransparency or 0),l.TextSize or 14,l.TextScaled and'true'or'false')
   end
  end
  if #labels>0 then
   guis[#guis+1]=string.format('{"p":[%s,%s,%s],"w":%s,"d":%s,"cw":%s,"ch":%s,"labels":[%s]}',n(pos.X),n(pos.Y+p.Size.Y/2),n(pos.Z),n(w),n(d),n(cw),n(ch),table.concat(labels,','))
  end
 end
 for _,p in ipairs(vis:GetDescendants())do
  if p:IsA('BasePart')and p.CFrame.Position.Y>-50 then
   if (p.Transparency or 0)<1 then addPart(p)end
   for _,gui in ipairs(p:GetChildren())do if gui._class=='SurfaceGui'then addGui(gui,p)end end
  end
 end
 for _,fp in ipairs(floors)do if(fp.LocalTransparencyModifier or 0)<1 then addPart(fp,'Floor')end end
 local nk=0;for _,p in ipairs(vis:GetDescendants())do if p:IsA('BasePart')and(p.Transparency or 0)<1 then nk+=1 end end
 print(string.format('SCENE %s {"version":%d,"parts":[%s],"guis":[%s],"runner":[%s,%s,%s],"counts":{"parts":%d,"guis":%d}}',name,K.Version or 0,table.concat(parts,','),
  table.concat(guis,','),n(rx),n(F),n(rz),nk,#guis))
end
local mid=2 -- the same spot for both versions
dump('jungle',mid,470)
dump('snow',mid,1880)
dump('crystal',mid,3500)
