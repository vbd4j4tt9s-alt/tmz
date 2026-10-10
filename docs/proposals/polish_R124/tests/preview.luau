--!nocheck
-- R124 previews (not a test): builds the REAL roll window, refresh wall sign and King card border under the mock and
-- prints JSON dumps (render_gui.py draws them). Preview-only overrides: the strip around the marker is fixed so the
-- Legendary / Mythic / Secret designs sit next to each other; pack pictures are simple stand-ins; tweens settle
-- colours only (pulses are shown at their brightest).
local W=require('./world');local R=W.R;local dump=require('./dump_gui')
local mode=MODE or 'roll'
local V3,CF,RGB=R.Vector3.new,R.CFrame.new,R.Color3.fromRGB
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=1;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local Tween=W.service('TweenService');function Tween.Create(_,obj,_,props)return {Play=function()if props.Color then obj.Color=props.Color end end,Cancel=function()end,Completed=R.signal()}end
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end
local function frame(parent,name,x,y,w,h,color,radius,scaleX,scaleY)
 local f=R.Instance.new('Frame');f.Name=name;f.BackgroundColor3=color;f.BorderSizePixel=0
 f.Position=scaleX and R.UDim2.fromScale(x,y)or R.UDim2.fromOffset(x,y);f.Size=scaleY and R.UDim2.fromScale(w,h)or R.UDim2.fromOffset(w,h);f.Parent=parent
 if radius then local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(0,radius);c.Parent=f end;return f
end
if mode=='roll' or mode=='phone' then
 local biomeColor={[1]=RGB(92,170,70),[6]=RGB(40,120,60),[2]=RGB(214,170,96),[3]=RGB(170,214,236),[4]=RGB(200,70,40),[5]=RGB(170,130,230),[7]=RGB(90,100,150)}
 W.stub('ItemPictures',{Show=function(holder,tool)
  local void=tool:GetAttribute('BagVariant')=='EclipseReliquary'
  local body=frame(holder,'Bag',.18,.06,.64,.88,void and RGB(40,20,80)or biomeColor[tool:GetAttribute('Stage')]or RGB(120,120,120),6,true,true)
  frame(body,'Crimp',0,0,1,.16,RGB(30,30,30),nil,true,true).BackgroundTransparency=.55
  local badge=frame(body,'Emblem',.32,.42,.36,.3,void and RGB(190,144,255)or RGB(255,240,200),20,true,true)
 end,Clear=function()end})
 W.stub('InteractionAudio',{Asset=function()return nil end,Play=function()return true end})
 W.stub('RarityRevealAudio',{Preload=function()end,Play=function()return true end});W.stub('AudioMixer',{Route=function()end})
 W.stub('SoundTiming',{Play=function()end})
 local Rules=W.module('TreadmillBonusRules')
 local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 local remote=R.new('RemoteFunction');remote.Name=Rules.RemoteName;remote.Parent=remotes
 local reply={Ok=true,Stage=1,Variant='Pack06',Rarity='Mythic',Label='Forest Seed Pack',Pool='1,6,2,3,4,5',Ready=1}
 function remote.InvokeServer()me:SetAttribute(Rules.Attr.Ready,reply.Ready);return reply end
 local real=Rules.BuildStrip
 Rules.BuildStrip=function(stages,winner,draw,count,win)
  local cards=real(stages,winner,draw,count,win);win=win or Rules.Strip.Win
  cards[win-2]={Stage=6,Variant='Pack03'};cards[win-1]={Stage=4,Variant='Pack05'};cards[win+1]={Stage=7,Variant='EclipseReliquary'};cards[win+2]={Stage=3,Variant='Pack01'}
  return cards
 end
 W.load('TreadmillBonusClient',R.new('LocalScript'))
 local overlay=pg.TreadmillBonusRoll
 local w,h=1280,720;if mode=='phone'then w,h=844,390 end
 overlay.AbsoluteSize=R.Vector2.new(w,h)
 me:SetAttribute(Rules.Attr.Ready,2);W.frames(2)
 pg.TreadmillBonusHud.BonusRollButton.Activated:Fire();W.frames(2)
 local window=overlay.Panel.StripWindow;window.AbsoluteSize=R.Vector2.new(overlay.Panel.Size.X.Offset-28,window.Size.Y.Offset)
 local n=0;while overlay.Panel.Actions.Skip.Visible and n<2000 do W.frames(1,1/60);n+=1 end
 W.frames(20,1/60)
 print('JSON '..dump(overlay,w,h))
elseif mode=='wall' then
 local B=W.module('RefreshBarrier')
 local folder=R.new('Folder');folder.Parent=W.workspace
 local line=R.new('Part');line.Size=V3(180,.24,1);line.CFrame=CF(0,4.12,-99.275)
 W.stub('HudArtwork',{Attach=function(parent)
  local moon=frame(parent,'GeneratedMoon',.08,.08,.84,.84,RGB(196,214,240),1000,true,true)
  frame(moon,'Bite',.32,-.08,.84,.84,RGB(242,242,242),1000,true,true)
  frame(parent,'Star1',.74,.1,.12,.12,RGB(255,206,72),2,true,true).Rotation=45
  frame(parent,'Star2',.86,.3,.07,.07,RGB(255,206,72),2,true,true).Rotation=45
  return moon end})
 local wall,labels=B.Build(line,-100,folder)
 for _,l in ipairs(labels)do l.Text=tostring(SECONDS or 3)end
 local paint=B.Decorate(wall);paint(DOTS_AT or 1.3,SECONDS or 3)
 local gui;for _,g in ipairs(wall:GetChildren())do if g.ClassName=='SurfaceGui'then gui=g;break end end
 print('JSON '..dump(gui,gui.CanvasSize.X,gui.CanvasSize.Y))
elseif mode=='notifier' then
 local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
 local order={1,6,2,3,4,5,7};local z=0
 for _,st in ipairs(order)do map:SetAttribute('BiomeStartZ_'..st,z);map:SetAttribute('BiomeEndZ_'..st,z+200);z+=200 end
 me.CharacterAdded=R.signal()
 local char=R.new('Model');char.Parent=W.workspace;me.Character=char
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Parent=char
 local hum=R.new('Humanoid');hum.Health=100;hum.WalkSpeed=16;hum.MoveDirection=V3(0,0,1);hum.Parent=char
 W.load('BiomeEntryNotifier',R.new('LocalScript'))
 local idx=table.find(order,STAGE or 5);local start=(idx-1)*200-10
 root.CFrame=CF(0,3,start);W.frames(5)
 local zz=start;for i=1,60 do zz+=16/60;root.CFrame=CF(0,3,zz);W.frames(1)end
 W.frames(30,1/60)
 print('JSON '..dump(pg.BiomeEntryUI,1280,720))
elseif mode=='featured' then
 local sg=R.Instance.new('ScreenGui');sg.Parent=pg
 for i,kind in ipairs({'Featured','Crown'})do
  local b=frame(sg,'Jump'..kind,20+(i-1)*130,20,110,96,RGB(18,20,30),10);b.BackgroundTransparency=.1
  local st=R.Instance.new('UIStroke');st.Color=i==1 and RGB(255,170,40)or RGB(255,226,40);st.Thickness=3;st.Parent=b
  local icon=frame(b,'Icon',.25,.08,.5,.56,RGB(0,0,0),nil,true,true);icon.BackgroundTransparency=1
  W.module('PremiumEmblems').Draw(icon,kind)
  local t=R.Instance.new('TextLabel');t.Text=i==1 and'Featured'or'Passes';t.TextSize=16;t.Font=R.Enum.Font.GothamBlack;t.TextColor3=i==1 and RGB(255,170,40)or RGB(255,226,40)
  t.BackgroundTransparency=1;t.Position=R.UDim2.fromScale(0,.66);t.Size=R.UDim2.fromScale(1,.3);t.TextStrokeTransparency=1;t.Parent=b
 end
 print('JSON '..dump(sg,280,136))
elseif mode=='offline' then
 W.Gui.MenuOpened=R.signal();W.Gui.MenuClosed=R.signal();W.Gui.MenuIsOpen=false
 local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
 local p=R.new('Part');p:SetAttribute('GardenOwnerId',1);p:SetAttribute('GardenPlantCount',6);p.Parent=map
 W.load('OfflineGrowthNotice',R.new('LocalScript'));W.Gui.MenuOpened:Fire()
 print('JSON '..dump(pg.OfflineGrowthNotice,1280,720))
elseif mode=='gems' then
 local M=W.module(GEMS_MODULE or 'GardenCardMotion')
 local sg=R.Instance.new('ScreenGui');sg.Parent=pg
 for i,rarity in ipairs({'Legendary','Mythic','Secret','King'})do
  local card=frame(sg,'Card'..rarity,20+(i-1)*130,20,104,104,RGB(36,44,40),8)
  M.Rarity(card,rarity)
 end
 W.frames(5,1/12)
 print('JSON '..dump(sg,540,144))
end
