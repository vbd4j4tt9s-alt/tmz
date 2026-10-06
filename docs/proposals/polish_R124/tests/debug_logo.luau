--!nocheck
-- (R153: obsolete. The biome title has no medallion or logo any more; test_notifier.luau covers the new text-only notifier.)
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.CharacterAdded=R.signal();me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
map:SetAttribute('BiomeStartZ_1',0);map:SetAttribute('BiomeEndZ_1',200);map:SetAttribute('BiomeStartZ_6',200);map:SetAttribute('BiomeEndZ_6',400)
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,190);root.Parent=char
local hum=R.new('Humanoid');hum.Health=100;hum.WalkSpeed=16;hum.MoveDirection=V3(0,0,1);hum.Parent=char
local ok,err=pcall(W.load,'BiomeEntryNotifier',R.new('LocalScript'));print('load',ok,err)
local group=pg.BiomeEntryUI.BiomeTitle
local z=190
for i=1,60*3 do z+=16/60;root.CFrame=CF(0,3,z);W.frames(1)
 if i%30==0 then
  local badge=group:FindFirstChild('BiomeBadge',true)
  local logo=badge and badge:FindFirstChild('BiomeLogo')
  local n,vis,sum=0,0,0
  if logo then for _,d in ipairs(logo:GetDescendants())do if d:IsA('GuiObject')then n+=1;sum+=d.BackgroundTransparency;if d.Visible then vis+=1 end end end end
  print(('t=%.1f visible=%s logo=%s descendants=%d visibleDesc=%d avgBgT=%.2f logoVisible=%s'):format(i/60,tostring(group.Visible),tostring(logo~=nil),n,vis,n>0 and sum/n or -1,tostring(logo and logo.Visible)))
 end
end
