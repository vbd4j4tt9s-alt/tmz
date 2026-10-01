--!nocheck
-- R122: the Veiled One notifier card (WorldStatusHud 'SpecialKeeper'), old vs new, on desktop and phone sizes.
local W=require('./world');local R=W.R;local metrics=require('./metrics')
local V2=R.Vector2.new;local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end;return c end
local TextS=W.service('TextService')
function TextS.GetTextSize(_,text,size,_,bounds)local w=0;for _,cp in utf8.codes(text)do w+=(metrics[cp]or .6)*size end;return V2(math.min(bounds.X,w),size*1.2)end
local Players=W.service('Players');local player=R.new('Player');player.Name='P';player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
W.workspace.GetServerTimeNow=function()return R.clock end
local Gui=W.service('GuiService');Gui.GetInsetArea=Gui.GetInsetArea or function()return R.Vector2.new(0,0),R.Vector2.new(0,0)end
local UIS=W.service('UserInputService')
local Fit=W.module('GardenTextFit')
local function pos(o)return o.Position.X.Offset,o.Position.Y.Offset,o.Size.X.Offset,o.Size.Y.Offset end
local screens={{'desktop 1920x1080',1920,1080,false},{'laptop 1280x720',1280,720,false},{'phone 844x390',844,390,true},{'phone 667x375',667,375,true},{'tablet 1024x768',1024,768,true}}
local dumps={}
for _,variant in ipairs({'WorldStatusHudOld','WorldStatusHud'})do
 local Hud=W.module(variant)
 for _,s in ipairs(screens)do
  UIS.TouchEnabled=s[4];W.workspace.CurrentCamera.ViewportSize=V2(s[2],s[3])
  map:SetAttribute('VeiledEventActive',true)
  local h=Hud.Create(pg,player);pg.WorldStatus.AbsoluteSize=V2(s[2],s[3]);h.Update(R.clock)
  local card=pg.WorldStatus.StatusStack.SpecialKeeper
  check(card.Visible,variant..' '..s[1]..': card visible during event')
  local x,y,w,hh=pos(card);dumps[variant..s[1]]=string.format('%d,%d,%d,%d',x,y,w,hh)
  if variant=='WorldStatusHud'then
   check(dumps['WorldStatusHudOld'..s[1]]==dumps[variant..s[1]],s[1]..': same position/size as before ('..dumps[variant..s[1]]..' vs '..tostring(dumps['WorldStatusHudOld'..s[1]])..')')
   local badge=card:FindFirstChild('IconBadge');check(badge~=nil,'icon badge')
   local emblem=badge and badge:FindFirstChild('Icon');local art=emblem and emblem:FindFirstChild('GeneratedWeatherThunderstorm')
   check(art~=nil,'HudArtwork WeatherThunderstorm attached')
   check(art and art:FindFirstChild('SmoothFallback')~=nil,'prepared artwork visible immediately (SmoothFallback)')
   local bx,by,bw,bh=pos(badge);check(bx>=0 and by>=0 and bx+bw<=w and by+bh<=hh,'icon inside card')
   for _,n in ipairs({'Title','Hint'})do local l=card[n];local lx,_,lw=l.Position.X.Offset,0,l.Size.X.Offset+l.Size.X.Scale*w
    check(lx>=bx+bw and lx+lw<=w,n..' right of the icon, inside the card')end
   local glow=card.Glow;check(glow.Size.X.Scale==1 and glow.Position.X.Offset==0,'glow stays inside the card')
   check(card:FindFirstChild('BrightOutline')and card:FindFirstChild('BrightFill'),'outline + gradient')
  end
  h.Destroy()
 end
end
-- Text fits at a readable size in the narrower text column (144 px).
for _,t in ipairs({{'THE VEILED ONE',18,13,144},{'AT STORM PEAKS',12,10,144},{'CHASING YOU',12,10,144}})do
 local shown,size,cut=Fit.Layout(t[1],t[4],t[2]==18 and 21 or 16,R.Enum.Font.FredokaOne,t[2],t[3])
 print(('%q -> size %d%s'):format(t[1],size,cut and' (shortened)'or''));check(not cut and size>=t[3],t[1]..' fits')
end
print(('hud checks %d, fails %d'):format(checks,fails))
