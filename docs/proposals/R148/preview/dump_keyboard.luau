--!nocheck
-- R148 preview dump (not a test): runs the REAL KeyboardTrack.client.lua (+ KeyboardTrack.lua) on the Roblox mock with a runner standing
-- on the Jungle / Desert border and prints the parts it drew as one JSON scene ("SCENE keyboard {json}") for render_keyboard.mjs.
-- Scene: every visible keycap / block / spacebar / bed part (size, centre, colour), every lit legend (text, ink, GUI rotation) and the
-- spacebar labels, plus the runner. The renderer draws boxes with plain lighting: a design preview, not a Roblox screenshot.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local workspace=W.workspace
local K=W.module('KeyboardTrack');local C=K.Config;local F=C.FloorTop
local ATTR={BiomeTrackEndZ=5980,BiomeStartZ_1=-100,BiomeEndZ_1=80,BiomeStartZ_6=80,BiomeEndZ_6=530,BiomeStartZ_2=530,BiomeEndZ_2=1180,
 BiomeStartZ_3=1180,BiomeEndZ_3=2030,BiomeStartZ_4=2030,BiomeEndZ_4=3080,BiomeStartZ_5=3080,BiomeEndZ_5=4380,BiomeStartZ_7=4380,BiomeEndZ_7=5980}
local g=K.Geometry(ATTR,0)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return {player}end
function workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play()end;function R.Inst.Stop()end
W.service('ContentProvider').PreloadAsync=function()end
W.stub('ClientFxBudget',{Get=function()return 3 end,Low=function()return false end})
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace
for k,v in pairs(ATTR)do map:SetAttribute(k,v)end
local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55)
local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=W.RS
local model=R.new('Model');model.Name='Tester'
local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.Parent=model;model.PrimaryPart=root;model.Parent=workspace;player.Character=model
-- the runner: heading +Z, 22 studs before the Desert entrance (z 530)
local RX,RZ=g.ColCenter(31),508
root.CFrame=CF(RX,F+3,RZ)
local sc=R.new('LocalScript');sc.Name='KeyboardTrack';W.load('KeyboardTrackClient',sc)
W.frames(120)
local vis=workspace:FindFirstChild('KeyboardTrackVisuals')
local function n(v)return string.format('%.3f',v)end
local parts,legends={}, {}
local function add(p,kind)
 local pos=p.CFrame.Position;local c=p.Color
 parts[#parts+1]=string.format('{"k":"%s","s":[%s,%s,%s],"p":[%s,%s,%s],"c":[%d,%d,%d]}',kind,n(p.Size.X),n(p.Size.Y),n(p.Size.Z),n(pos.X),n(pos.Y),n(pos.Z),
  math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))
end
for _,folder in ipairs(vis:GetChildren())do
 if folder.Name=='Bed'then for _,p in ipairs(folder:GetChildren())do add(p,'Bed')end
 elseif folder.Name=='Keys'or folder.Name:find('^Blocks')then
  for _,p in ipairs(folder:GetChildren())do
   if p.Transparency==0 then
    add(p,p.Name)
    local gui=p:FindFirstChildWhichIsA('SurfaceGui');local label=gui and gui:FindFirstChildWhichIsA('TextLabel',true)
    if gui and label then
     local pos=p.CFrame.Position;local ink=label.TextColor3
     legends[#legends+1]=string.format('{"t":"%s","p":[%s,%s,%s],"ink":[%d,%d,%d],"rot":%d,"face":"%s","w":%s,"d":%s,"bar":%s}',label.Text,n(pos.X),n(pos.Y+p.Size.Y/2),n(pos.Z),
      math.floor(ink.R*255+.5),math.floor(ink.G*255+.5),math.floor(ink.B*255+.5),label.Rotation,gui.Face.Name,n(p.Size.X),n(p.Size.Z),p.Name=='Spacebar'and'true'or'false')
    end
   end
  end
 end
end
print(string.format('SCENE keyboard {"parts":[%s],"legends":[%s],"runner":[%s,%s,%s],"counts":{"parts":%d,"legends":%d}}',table.concat(parts,','),table.concat(legends,','),n(RX),n(F),n(RZ),#parts,#legends))
