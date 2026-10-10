--!nocheck
-- R150 previews (not a test): runs the REAL TreadmillBonusClient (R149's for SIDE='old', this checkout's for SIDE='new') under the Roblox
-- mock, drives it into each state and prints one line per scene: SCENE <name> <crop x y w h> <scale> <json of the GUI tree>.
-- Globals set by run_bonus_preview.sh: SIDE ('old'|'new'), VIEW ('desktop' 1280x720 | 'phone' 844x390).
-- Preview-only stand-ins: pack pictures are drawn with frames (the game shows 3D models), sounds are silent, and the strip around the
-- winner is fixed so the rarities sit next to each other. Tweens settle at once in the mock; the animator is stepped by W.frames, so the
-- sparkles, confetti, rays and pointers are caught at the moment named in each scene.
local W=require('./world');local R=W.R;local dump=require('./dump_tree')
local V3,RGB=R.Vector3.new,R.Color3.fromRGB
local VW,VH=1280,720
if VIEW=='phone'then VW,VH=844,390 end
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=1;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=V3(0,3,0);root.Parent=char
local head=R.new('Part');head.Name='Head';head.Position=V3(0,4.5,0);head.Parent=char
W.service('SoundService')
if VIEW=='phone'then W.UIS.TouchEnabled=true;W.UIS.MouseEnabled=false end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(VW,VH)end;return o end;W.env.Instance=R.Instance end
local Rules=W.module('TreadmillBonusRules')
-- Stand-in pack pictures (the game draws 3D models here).
local biomeColor={[1]=RGB(96,176,72),[6]=RGB(36,128,70),[2]=RGB(222,176,98),[3]=RGB(168,216,240),[4]=RGB(210,74,42),[5]=RGB(176,136,236),[7]=RGB(92,104,160)}
local function frame(parent,name,x,y,w,h,color,radius)
 local f=R.Instance.new('Frame');f.Name=name;f.BackgroundColor3=color;f.BorderSizePixel=0
 f.Position=R.UDim2.fromScale(x,y);f.Size=R.UDim2.fromScale(w,h);f.Parent=parent
 if radius then local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(0,radius);c.Parent=f end;return f
end
W.stub('ItemPictures',{Show=function(holder,tool)
 local void=tool:GetAttribute('BagVariant')=='EclipseReliquary'
 local base=void and RGB(46,24,92)or biomeColor[tool:GetAttribute('Stage')]or RGB(120,120,120)
 local body=frame(holder,'Bag',.2,.04,.6,.92,base,7)
 local g=R.Instance.new('UIGradient');g.Color=R.ColorSequence.new(R.Color3.new(1,1,1),RGB(150,150,160));g.Rotation=90;g.Parent=body
 local crimp=frame(body,'Crimp',0,0,1,.14,RGB(20,20,28),5);crimp.BackgroundTransparency=.55
 local badge=frame(body,'Emblem',.28,.36,.44,.34,void and RGB(196,150,255)or RGB(255,244,206),30)
 frame(body,'Shine',.1,.2,.14,.55,RGB(255,255,255),4).BackgroundTransparency=.82
end,Clear=function()end,Warm=function()end})
W.stub('InteractionAudio',{Asset=function()return nil end,Play=function()return true end})
W.stub('RarityRevealAudio',{Preload=function()end,Play=function()return true end});W.stub('AudioMixer',{Route=function()end})
W.stub('SoundTiming',{Play=function()end});W.stub('ClientFxBudget',{Get=function()return 3 end})
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteFunction');remote.Name=Rules.RemoteName;remote.Parent=remotes
local reply
function remote.InvokeServer()if reply and reply.Ok then me:SetAttribute(Rules.Attr.Ready,reply.Ready)end;return reply end
-- Fixed neighbours around the winner so the rarities sit side by side.
local real=Rules.BuildStrip
Rules.BuildStrip=function(stages,winner,draw,count,win)
 local cards=real(stages,winner,draw,count,win);win=win or Rules.Strip.Win
 cards[win-2]={Stage=6,Variant='Pack03'};cards[win-1]={Stage=2,Variant='Pack02'};cards[win+1]={Stage=3,Variant='Pack04'};cards[win+2]={Stage=4,Variant='Pack01'}
 return cards
end
local script=R.new('LocalScript');script.Name='TreadmillBonusClient'
W.load('TreadmillBonusClient',script)
local hud=pg:FindFirstChild('TreadmillBonusHud');local overlay=pg:FindFirstChild('TreadmillBonusRoll');local bar=pg:FindFirstChild('TreadmillBonusProgress')
overlay.AbsoluteSize=R.Vector2.new(VW,VH);hud.AbsoluteSize=R.Vector2.new(VW,VH)
local button=hud.BonusRollButton
W.frames(3,1/60)
local function set(k,v)me:SetAttribute(Rules.Attr[k],v)end
local function emit(name,tree,crop,scale,cw,ch)
 print(string.format('SCENE %s %d %d %d %d %s %s',name,crop[1],crop[2],crop[3],crop[4],tostring(scale),dump(tree,cw or VW,ch or VH)))
end
local function settle()W.frames(150,1/60)end
-- Button states --------------------------------------------------------------------------------------------
local function buttonScene(name,ready,training,left)
 set('Interval',360);set('Ready',ready);me:SetAttribute('TreadmillTraining',training or nil)
 set('DueAt',training and ready<2 and R.clock+(left or 200)or nil);set('Left',left or 200)
 settle()
 if not button.Visible then return false end
 local ap=button.AnchorPoint or{X=0,Y=0} -- (R150 review: this checkout's button is anchored at its centre, R149's at its top-left corner)
 local w,h=button.Size.X.Offset,button.Size.Y.Offset;local x,y=button.Position.X.Offset-ap.X*w,button.Position.Y.Offset-ap.Y*h
 emit(name,hud,{x-26,y-24,w+52,h+46},3.2,VW,VH);return true
end
buttonScene('button_charging',0,true,360*.54)
buttonScene('button_almost',0,true,24)
buttonScene('button_ready',1,true,250)
buttonScene('button_ready2',2,true,250)
me:SetAttribute('TreadmillTraining',nil);set('DueAt',nil);set('Ready',0);settle()
if VIEW=='desktop'then
 -- Gift timer ---------------------------------------------------------------------------------------------
 local function barScene(name,ready,left)
  set('Ready',ready);set('Interval',360);set('Left',left);set('DueAt',ready<2 and R.clock+left or nil);me:SetAttribute('TreadmillTraining',true)
  W.frames(20,1/60);R.advance(4);W.frames(20,1/60)
  local s=bar.Size;emit(name,bar,{0,0,s.X.Offset,s.Y.Offset,s.X.Offset,s.Y.Offset},3.4,s.X.Offset,s.Y.Offset)
 end
 set('Ready',0);R.advance(5);barScene('bar_mid',0,222);barScene('bar_almost',0,22)
 -- The "ready" moment: a roll completes while the timer is showing (caught a moment into the sparkles).
 set('Ready',0);set('DueAt',R.clock+3);me:SetAttribute('TreadmillTraining',true);W.frames(10,1/60)
 set('Ready',1);set('DueAt',R.clock+360);W.frames(7,1/60)
 do local s=bar.Size;emit('bar_ready',bar,{0,0,s.X.Offset,s.Y.Offset,s.X.Offset,s.Y.Offset},3.4,s.X.Offset,s.Y.Offset)end
 R.advance(4);W.frames(10,1/60)
 barScene('bar_full',2,0)
 me:SetAttribute('TreadmillTraining',nil);set('Ready',0);W.frames(10,1/60)
end
-- Roll screen ------------------------------------------------------------------------------------------------------
local function startFlow(res)
 reply=res;set('Ready',1);W.frames(2,1/60);button.Activated:Fire();W.frames(2,1/60)
 local window=overlay.Panel.StripWindow;window.AbsoluteSize=R.Vector2.new(overlay.Panel.Size.X.Offset-28,window.Size.Y.Offset)
end
local function finishFlow()
 local n=0;while overlay.Panel.Actions.Skip.Visible and n<2000 do W.frames(1,1/60);n+=1 end
end
local function rollScene(name,res,after)
 startFlow(res)
 if after=='spin'then
  local t0=R.clock;while R.clock-t0<2.1 and overlay.Panel.Actions.Skip.Visible do W.frames(1,1/60)end
 else finishFlow();W.frames(after or 24,1/60)end
 emit(name,overlay,{0,0,VW,VH},VIEW=='desktop'and 1 or 1.5)
 finishFlow();overlay.Panel.Actions.Close.Activated:Fire();W.frames(5,1/60)
end
local pool='1,6,2,3,4,5'
local function res(stage,variant,rarity,label)return {Ok=true,Stage=stage,Variant=variant,Rarity=rarity,Label=label,Pool=pool,Ready=0}end
rollScene('roll_spin',res(1,'Pack01','Common','Forest Seed Pack'),'spin')
rollScene('roll_common',res(1,'Pack01','Common','Forest Seed Pack'),18)
rollScene('roll_rare',res(6,'Pack03','Rare','Jungle Seed Pack'),18)
rollScene('roll_legendary',res(4,'Pack05','Legendary','Lava Seed Pack'),20)
rollScene('roll_mythic',res(1,'Pack06','Mythic','Forest Seed Pack'),20)
rollScene('roll_secret',res(7,'EclipseReliquary','Secret','Void Pack'),20)
