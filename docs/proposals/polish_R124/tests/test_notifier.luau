--!nocheck
-- R124: the biome title fades in, holds, then fades away (element by element; no CanvasGroup).
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.CharacterAdded=R.signal();me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
map:SetAttribute('BiomeStartZ_1',0);map:SetAttribute('BiomeEndZ_1',200);map:SetAttribute('BiomeStartZ_6',200);map:SetAttribute('BiomeEndZ_6',400)
W.stub('BiomeArtwork',{Attach=function(parent)local i=R.Instance.new('ImageLabel');i.BackgroundTransparency=1;i.ImageTransparency=0;i.Parent=parent;return i end})
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,190);root.Parent=char
local hum=R.new('Humanoid');hum.Health=100;hum.WalkSpeed=16;hum.MoveDirection=V3(0,0,1);hum.Parent=char
W.load('BiomeEntryNotifier',R.new('LocalScript'))
local gui=pg:FindFirstChild('BiomeEntryUI');local group=gui and gui:FindFirstChild('BiomeTitle')
check(group and group.ClassName=='Frame','title is a plain Frame (no CanvasGroup)')
local title=group and group:FindFirstChild('BiomeName',true);local ribbon=group and group:FindFirstChild('SoftRibbon',true)
-- walk forward across the Forest -> Jungle line
local z=190;local samples={}
local t0
for i=1,60*5 do
 z+=16/60;root.CFrame=CF(0,3,z);W.frames(1)
 if group.Visible and not t0 then t0=R.clock end
 if t0 then samples[#samples+1]={T=R.clock-t0,Text=title.TextTransparency,Ribbon=ribbon.BackgroundTransparency,Visible=group.Visible}end
end
check(t0~=nil and title.Text~='','title shows when walking into the Jungle: '..tostring(title and title.Text))
local function at(t)for _,s in ipairs(samples)do if s.T>=t then return s end end end
check(at(.05).Text>.3,'starts faded (fading in): '..at(.05).Text)
check(at(1).Text<.01 and math.abs(at(1).Ribbon-.46)<.01,'fully shown at 1 s (ribbon at its own .46)')
check(at(2.6).Text>.2 and at(2.6).Text<.9 and at(2.6).Visible,'fading away at 2.6 s: '..at(2.6).Text)
check(at(2.6).Ribbon>.46 and at(2.6).Ribbon<1,'ribbon fades too')
check(not at(3.2).Visible,'gone after 3 s')
-- a second crossing restores the resting look
z=150;root.CFrame=CF(0,3,z);W.frames(10);t0=nil
for i=1,60*4 do z+=16/60;root.CFrame=CF(0,3,z);W.frames(1);if group.Visible and not t0 then t0=R.clock end;if t0 and R.clock-t0>=1 then break end end
check(t0~=nil and title.TextTransparency<.01 and math.abs(ribbon.BackgroundTransparency-.46)<.01,'second show back at full strength')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
