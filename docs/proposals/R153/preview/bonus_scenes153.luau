--!nocheck
-- R153 previews (not a test): runs the REAL TreadmillBonusClient of this checkout (with the REAL EmbeddedImage153 decoding the REAL BonusPackImage153) under the Roblox mock,
-- drives it into each state and prints one line per scene: SCENE <name> <crop x y w h> <scale> <json of the GUI tree>. VIEW = 'desktop' (1280x720) | 'phone' (844x390),
-- set by run_preview153.sh. Preview-only stand-ins: the pack pictures on the reel cards are drawn with frames (the game shows 3D models), sounds are silent, the strip around
-- the winner is fixed so the rarities sit next to each other, and the engine's EditableImage is a marker (render_gui153.mjs draws the decoded picture where an ImageLabel has one).
local W=require('./world');local R=W.R;local dump=require('./dump_tree153')
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
-- The picture: the real decoder runs; the "EditableImage" is a marker the renderer swaps for the decoded pixels.
local EI=W.module('EmbeddedImage153');local decoded
EI.Hooks.Create=function(w,h,rgba)decoded={W=w,H=h,Len=buffer.len(rgba)};return decoded end
EI.Hooks.Content=function(o)return {Picture=o} end
EI.Hooks.None={};EI.Hooks.Wait=function()end
-- Stand-in pack pictures on the reel cards (the game draws 3D models there).
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
-- Fixed neighbours around the winner so the rarities sit side by side (the Secret tease, 3 or 4 cards before the winner, is left as the client built it).
local real=Rules.BuildStrip
Rules.BuildStrip=function(stages,winner,draw,count,win)
 local cards=real(stages,winner,draw,count,win);win=win or Rules.Strip.Win
 cards[win-2]={Stage=6,Variant='Pack03'};cards[win-1]={Stage=2,Variant='Pack02'};cards[win+1]={Stage=3,Variant='Pack04'};cards[win+2]={Stage=4,Variant='Pack01'}
 return cards
end
local script=R.new('LocalScript');script.Name='TreadmillBonusClient'
W.load('TreadmillBonusClient',script)
local hud=pg:FindFirstChild('TreadmillBonusHud');local overlay=pg:FindFirstChild('TreadmillBonusRoll')
overlay.AbsoluteSize=R.Vector2.new(VW,VH);hud.AbsoluteSize=R.Vector2.new(VW,VH)
local button=hud.BonusRollButton
W.frames(3,1/60)
local function set(k,v)me:SetAttribute(Rules.Attr[k],v)end
local function emit(name,tree,crop,scale,cw,ch)
 print(string.format('SCENE %s %d %d %d %d %s %s',name,crop[1],crop[2],crop[3],crop[4],tostring(scale),dump(tree,cw or VW,ch or VH)))
end
local function settle()W.frames(150,1/60)end
-- Button states --------------------------------------------------------------------------------------------
local function snap(name)
 if not button.Visible then return false end
 local ap=button.AnchorPoint or{X=0,Y=0}
 local w,h=button.Size.X.Offset,button.Size.Y.Offset;local x,y=button.Position.X.Offset-ap.X*w,button.Position.Y.Offset-ap.Y*h
 emit(name,hud,{x-26,y-24,w+52,h+46},3.2,VW,VH);return true
end
local function buttonScene(name,ready,training,left,frames)
 set('Interval',360);set('Ready',ready);me:SetAttribute('TreadmillTraining',training or nil)
 set('DueAt',training and ready<2 and R.clock+(left or 200)or nil);set('Left',left or 200)
 if frames then W.frames(frames,1/60)else settle()end
 return snap(name)
end
buttonScene('button_charging',0,true,341)            -- NEXT 5:41, the fill just started
buttonScene('button_half',0,true,180)                -- half way
buttonScene('button_almost',0,true,25,200)           -- ALMOST THERE! (caught in a pulse: ~0.4 s after the burst starts is not guaranteed, so a few frames in)
buttonScene('button_almost2',0,true,2)               -- the last seconds
-- a roll completes: BONUS READY! / OPEN IT! (caught a moment into the sparkles)
set('Ready',0);set('DueAt',R.clock+3);me:SetAttribute('TreadmillTraining',true);W.frames(10,1/60)
set('Ready',1);set('DueAt',R.clock+360);W.frames(7,1/60);snap('button_readypop')
R.advance(4);W.frames(10,1/60);snap('button_ready')
set('Ready',2);set('DueAt',nil);W.frames(5,1/60);R.advance(4);W.frames(10,1/60);snap('button_ready2')
me:SetAttribute('TreadmillTraining',nil);set('DueAt',nil);set('Ready',0);settle()
-- Roll screen ------------------------------------------------------------------------------------------------------
local function startFlow(res)
 reply=res;set('Ready',1);W.frames(2,1/60);button.Activated:Fire();W.frames(2,1/60)
 local window=overlay.Panel.StripWindow;window.AbsoluteSize=R.Vector2.new(overlay.Panel.Size.X.Offset-28,window.Size.Y.Offset)
end
local function finishFlow()
 local n=0;while overlay.Panel.Actions.Skip.Visible and n<2000 do W.frames(1,1/60);n+=1 end
end
-- Where is the nearest Secret card (a card whose rarity plaque says SECRET and is not the winner) relative to the pointer?
local function secretOffset()
 local strip=overlay.Panel.StripWindow.Strip;local window=overlay.Panel.StripWindow
 local mid=window.AbsoluteSize.X/2;local best
 for _,c in ipairs(strip:GetChildren())do
  local n=tonumber(c.Name:match('^Card(%d+)$'))
  if n and n~=Rules.Strip.Win and c:FindFirstChild('Rarity')and c.Rarity.Text=='SECRET'then
   local x=strip.Position.X.Offset+c.Position.X.Offset+Rules.Strip.CardWidth/2
   if not best or math.abs(x-mid)<math.abs(best)then best=x-mid end
  end
 end
 return best
end
local function rollScene(name,res,mode)
 startFlow(res)
 if mode=='early'then
  local t0=R.clock;while R.clock-t0<.9 and overlay.Panel.Actions.Skip.Visible do W.frames(1,1/60)end
 elseif mode=='secret'then
  -- the frame where the Secret card is right next to the pointer (a little before it passes under it)
  local n=0;while overlay.Panel.Actions.Skip.Visible and n<2000 do
   local off=secretOffset();if off and off<=70 then break end
   W.frames(1,1/60);n+=1
  end
 else finishFlow();W.frames(mode or 24,1/60)end
 local ps=overlay.Panel.Size;local pw,ph=ps.X.Offset,ps.Y.Offset
 emit(name,overlay,{VW/2-pw/2-14,VH/2-ph/2-14,pw+28,ph+28},VIEW=='desktop'and 1.6 or 1.8)
 finishFlow();overlay.Panel.Actions.Close.Activated:Fire();W.frames(5,1/60)
end
local pool='1,6,2,3,4,5'
local function res(stage,variant,rarity,label)return {Ok=true,Stage=stage,Variant=variant,Rarity=rarity,Label=label,Pool=pool,Ready=0}end
rollScene('roll_early',res(1,'Pack01','Common','Forest Seed Pack'),'early')
rollScene('roll_secret_passing',res(1,'Pack01','Common','Forest Seed Pack'),'secret')
rollScene('roll_common',res(1,'Pack01','Common','Forest Seed Pack'),18)
rollScene('roll_secret_won',res(7,'EclipseReliquary','Secret','Void Pack'),20)
