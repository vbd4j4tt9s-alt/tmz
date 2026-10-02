--!nocheck
-- R125 biome title: logo in a CanvasGroup medallion (faded as one piece), the rest a plain Frame faded element by
-- element; fades in, holds, fades away; layout centred; second show back at full strength.
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.CharacterAdded=R.signal();me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
map:SetAttribute('BiomeStartZ_1',0);map:SetAttribute('BiomeEndZ_1',200);map:SetAttribute('BiomeStartZ_6',200);map:SetAttribute('BiomeEndZ_6',400)
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,190);root.Parent=char
local hum=R.new('Humanoid');hum.Health=100;hum.WalkSpeed=16;hum.MoveDirection=V3(0,0,1);hum.Parent=char
W.load('BiomeEntryNotifier',R.new('LocalScript')) -- real BiomeArtwork / ArtworkRuntime87 (prepared fallback pixels)
local gui=pg:FindFirstChild('BiomeEntryUI');local group=gui and gui:FindFirstChild('BiomeTitle')
check(group and group.ClassName=='Frame'and group:FindFirstChildOfClass('UIScale'),'title is a plain Frame with its UIScale (HudNotices)')
local medal=group:FindFirstChild('BiomeBadge',true);check(medal and medal.ClassName=='CanvasGroup','logo medallion is a CanvasGroup')
local title=group:FindFirstChild('BiomeName',true);local ribbon=group:FindFirstChild('SoftRibbon',true)
local z=190;local samples={};local t0
for i=1,60*5 do
 z+=16/60;root.CFrame=CF(0,3,z);W.frames(1)
 if group.Visible and not t0 then t0=R.clock end
 if t0 then samples[#samples+1]={T=R.clock-t0,Text=title.TextTransparency,Ribbon=ribbon.BackgroundTransparency,Medal=medal.GroupTransparency,Visible=group.Visible}end
end
check(t0~=nil and title.Text=='JUNGLE','title shows JUNGLE when walking into the Jungle')
local logo=medal:FindFirstChild('BiomeLogo',true);check(logo and logo.Visible,'Jungle logo inside the medallion')
local drawn=0;if logo then for _,d in ipairs(logo:GetDescendants())do if d:IsA('GuiObject')and d.BackgroundTransparency<1 then drawn+=1 end end end
check(drawn>50,'logo pixels drawn ('..drawn..')')
local function at(t)for _,s in ipairs(samples)do if s.T>=t then return s end end end
check(at(.05).Text>.3 and at(.05).Medal>.3,'starts faded (fading in)')
check(at(1).Text<.01 and math.abs(at(1).Ribbon-.38)<.01 and at(1).Medal==0,'fully shown at 1 s (pill at its own .38, medallion opaque)')
check(at(2.8).Text>.2 and at(2.8).Text<.95 and at(2.8).Medal>.2 and at(2.8).Visible,'fading away at 2.8 s')
check(not at(3.3).Visible,'gone after ~3.1 s')
-- layout: medallion + words centred in the 490 px title
local left=medal.Position.X.Offset;local right=490-(title.Position.X.Offset+title.Size.X.Offset)
check(math.abs(left-right)<=40,('composition roughly centred (left %d, right %d)'):format(left,right))
-- second crossing
z=150;root.CFrame=CF(0,3,z);W.frames(10);t0=nil
for i=1,60*4 do z+=16/60;root.CFrame=CF(0,3,z);W.frames(1);if group.Visible and not t0 then t0=R.clock end;if t0 and R.clock-t0>=1 then break end end
check(t0~=nil and title.TextTransparency<.01 and math.abs(ribbon.BackgroundTransparency-.38)<.01 and medal.GroupTransparency==0,'second show back at full strength')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
