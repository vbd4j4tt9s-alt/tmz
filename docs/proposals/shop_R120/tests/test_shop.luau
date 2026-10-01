--!nocheck
-- R120 shop: runs the real GamePassClient + Premium* modules under the Roblox mock at many screen sizes.
-- A small layout resolver turns UDim2/AnchorPoint/aspect constraints into AbsolutePosition/AbsoluteSize
-- (the mock has no layout engine), so GardenTextFit and the checks see real pixel rects.
-- Run from a folder holding roblox.luau, world.luau, rs_bundle.luau and metrics.luau (see run.sh).
-- Lines starting with DUMP are JSON frame dumps for render_shop.py.
local W=require('./world');local R=W.R;local metrics=require('./metrics')
local V2=R.Vector2.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- Fredoka One advance widths for the mock TextService.
local TextS=W.service('TextService')
function TextS.GetTextSize(_,text,size,_,bounds)
 local w=0;for _,cp in utf8.codes(text)do w+=(metrics[cp]or .6)*size end
 return V2(math.min(bounds.X,w),size*1.2)
end
local tweens=0;local Tween=W.service('TweenService')
function Tween.Create(_,obj,_,props)tweens+=1;return {Play=function()for k,v in pairs(props)do obj[k]=v end end,Cancel=function()end,Completed=R.signal()}end
-- Players ------------------------------------------------------------------------------------
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local player=R.new('Player');player.Name='Buyer';player.DisplayName='Buyer';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
local friend=R.new('Player');friend.Name='Friend';friend.DisplayName='Friendly';friend.UserId=2;friend.Parent=Players
function Players.GetPlayers()return {player,friend}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
for _,k in ipairs({'Growth','Speed'})do player:SetAttribute(k..'OwnershipReady',true)end
-- Products ------------------------------------------------------------------------------------
local RS=W.RS
local Passes=W.module('GamePassCatalog');local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog')
local robux={}
RS.GamePassCatalog:SetAttribute('GrowthPassId',101);RS.GamePassCatalog:SetAttribute('SpeedPassId',102);robux[101]=467;robux[102]=399
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Mech.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
RS.PassGiftCatalog:SetAttribute('GrowthGiftProductId',401);RS.PassGiftCatalog:SetAttribute('SpeedGiftProductId',402);robux[401]=499;robux[402]=449
local Market=W.service('MarketplaceService');local prompts={}
Market.GetProductInfoAsync=function(_,id)return robux[id]and{PriceInRobux=robux[id],IsForSale=true}or nil end
Market.PromptGamePassPurchase=function(_,p,id)prompts[#prompts+1]={p,id}end
-- Server state + remote --------------------------------------------------------------------------
local function serverState()
 local offers={};for _,o in ipairs(Mech.Offers)do offers[tostring(o.Count)]={Count=o.Count,GemPrice=o.GemPrice,GemAvailable=true,RobuxAvailable=true,RobuxPrice=o.TargetRobuxPrice}end
 local bundles={};for _,row in ipairs(Pricing.Bundles)do bundles[row.Key]={Available=true,Amount=row.Amount,GemPrice=row.GemPrice,RobuxAmount=row.Amount}end
 return {PackOffers=offers,Bundles=bundles,GiftProducts={Growth={Available=true},Speed={Available=true}},GiftCredits={},Gems=500,OnSale=true,Success=true,Message=''}
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local remote=R.new('RemoteFunction');remote.Name='PremiumRequest';remote.Parent=remotes;local calls={}
remote.InvokeServer=function(_,action,value)calls[#calls+1]={action,value};return serverState()end
-- Heavy 3D / audio modules are stubbed (no meshes offline). ViewportFrames stay in the tree.
W.stub('InteractionAudio',{Transaction=function()end,Play=function()end,Preload=function()end})
W.stub('ShopViewport',{Visible=function()return true end})
local reveals=0
W.stub('ShopSeedReveal',{Attach=function()reveals+=1;return {Refresh=function()end,Destroy=function()end}end})
W.stub('PackViewport89',{DecorateCard=function()end,Create=function(parent)
 local halo=R.Instance.new('Frame');halo.Name='MechDockingBay';halo.Parent=parent
 local v=R.Instance.new('ViewportFrame');v.Name='MechPackPreview';v.Parent=parent;return v end})
-- Screens --------------------------------------------------------------------------------------
-- inset = the area CoreUISafeInsets removes (Roblox top bar 58 px + device notch / home bar).
local screens={
 {'PC 1920x1080',1920,1080,false,{0,58,0,0}},{'PC 1366x768',1366,768,false,{0,58,0,0}},{'PC 1280x720',1280,720,false,{0,58,0,0}},{'PC 1024x768',1024,768,false,{0,58,0,0}},
 {'Tablet 1180x820',1180,820,true,{0,58,0,20}},{'Tablet 1024x768',1024,768,true,{0,58,0,0}},
 {'Phone 667x375',667,375,true,{0,58,0,0}},{'Phone 740x360',740,360,true,{0,58,0,0}},{'Phone 844x390',844,390,true,{47,58,47,21}},{'Phone 932x430',932,430,true,{59,58,59,21}},
 {'Portrait 375x667',375,667,true,{0,78,0,0}},{'Portrait 390x844',390,844,true,{0,105,0,34}},{'Portrait 430x932',430,932,true,{0,117,0,34}},
}
-- Native thumb controls, as Roblox places them (small screen <=500 px short side), in safe-area coordinates.
local function controlsFor(w,h)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-110,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-180,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local touchGui=R.Instance.new('ScreenGui');touchGui.Name='TouchGui';touchGui.Enabled=false
local thumb=R.Instance.new('Frame');thumb.Name='ThumbstickFrame';thumb.Parent=touchGui
local jumpBtn=R.Instance.new('ImageButton');jumpBtn.Name='JumpButton';jumpBtn.Parent=touchGui
touchGui.Parent=pg
-- Start the client ---------------------------------------------------------------------------------
W.UIS.TouchEnabled=false
W.load('GamePassClient',R.new('LocalScript'))
local L=W.module('PremiumLayout')
local gui=pg.GardenPasses;local panel=gui.PremiumShop;local page=panel.Body.Page;local jumpRoot=gui.JumpButtons
local function act(b)b.Activated:Fire()end
-- Layout resolver -------------------------------------------------------------------------------
local function setAbs(o,x,y,w,h)
 local p,s=o.AbsolutePosition,o.AbsoluteSize
 if not p or p.X~=x or p.Y~=y then o.AbsolutePosition=V2(x,y)end
 if not s or s.X~=w or s.Y~=h then o.AbsoluteSize=V2(w,h)end
end
local function resolve(o,px,py,pw,ph)
 local scroll=o._class=='ScrollingFrame'
 local ox,oy=0,0
 if scroll then local c=o.CanvasPosition or V2(0,0);ox,oy=c.X,c.Y end
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local size,pos=c.Size,c.Position
  local w=size.X.Scale*pw+size.X.Offset;local h=size.Y.Scale*ph+size.Y.Offset
  local ar=c:FindFirstChildOfClass('UIAspectRatioConstraint')
  if ar and w>0 and h>0 then local a=ar.AspectRatio or 1;if w/h>a then w=h*a else h=w/a end end
  local ap=c.AnchorPoint or V2(0,0)
  local x=px+pos.X.Scale*pw+pos.X.Offset-ap.X*w-ox;local y=py+pos.Y.Scale*ph+pos.Y.Offset-ap.Y*h-oy
  setAbs(c,x,y,w,h);resolve(c,x,y,w,h)
 end end
end
local current={w=0,h=0,inset={0,0,0,0}}
local function layout()for _=1,2 do resolve(gui,0,0,gui.AbsoluteSize.X,gui.AbsoluteSize.Y)end end
local function rect(o)return {X=o.AbsolutePosition.X,Y=o.AbsolutePosition.Y,W=o.AbsoluteSize.X,H=o.AbsoluteSize.Y}end
local function inside(a,b,pad)pad=pad or 0;return a.X>=b.X-pad and a.Y>=b.Y-pad and a.X+a.W<=b.X+b.W+pad and a.Y+a.H<=b.Y+b.H+pad end
local function setScreen(s)
 local w,h=s[2]-s[5][1]-s[5][3],s[3]-s[5][2]-s[5][4]
 current={name=s[1],w=w,h=h,touch=s[4],inset=s[5],sw=s[2],sh=s[3]}
 W.UIS.TouchEnabled=s[4]
 if s[4]then local c=controlsFor(w,h);current.controls=c
  thumb.AbsolutePosition=V2(c.Joystick.X,c.Joystick.Y);thumb.AbsoluteSize=V2(c.Joystick.W,c.Joystick.H)
  jumpBtn.AbsolutePosition=V2(c.Jump.X,c.Jump.Y);jumpBtn.AbsoluteSize=V2(c.Jump.W,c.Jump.H)
  touchGui.Enabled=true
 else current.controls=nil;touchGui.Enabled=false end
 W.camera=W.workspace.CurrentCamera;W.camera.ViewportSize=V2(s[2],s[3])
 gui.AbsoluteSize=V2(w,h);layout()
end
-- JSON dump for the renderer ------------------------------------------------------------------------
local function num(v)return string.format('%.1f',v)end
local function col(c)return c and string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))or'null'end
local function esc(s)return (tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'))end
local function seqColor(seq)
 if not seq then return nil end
 local keys={}
 if type(seq.A)=='table'and seq.A.__type=='Color3'then keys={{0,seq.A},{1,seq.B or seq.A}}
 elseif type(seq.A)=='table'then for _,k in ipairs(seq.A)do keys[#keys+1]={k.T,k.V}end end
 local out={};for _,k in ipairs(keys)do out[#out+1]=string.format('[%s,%s]',num(k[1]),col(k[2]))end
 return '['..table.concat(out,',')..']'
end
local function seqNum(seq)
 if type(seq)~='table'then return'null'end
 local keys={}
 if type(seq.A)=='number'then keys={{0,seq.A},{1,seq.B or seq.A}}
 elseif type(seq.A)=='table'then for _,k in ipairs(seq.A)do keys[#keys+1]={k.T,k.V}end end
 local out={};for _,k in ipairs(keys)do out[#out+1]=string.format('[%.4f,%.3f]',k[1],k[2])end
 return '['..table.concat(out,',')..']'
end
local function dump(root,out,clip)
 local kids={}
 for i,c in ipairs(root._children)do if c:IsA('GuiObject')and c.Visible~=false then kids[#kids+1]={c,i}end end
 table.sort(kids,function(a,b)local za,zb=a[1].ZIndex or 1,b[1].ZIndex or 1;if za~=zb then return za<zb end;return a[2]<b[2]end)
 for _,e in ipairs(kids)do local o=e[1]
  local r=rect(o);local parts={}
  parts[#parts+1]=string.format('"c":"%s","n":"%s","x":%s,"y":%s,"w":%s,"h":%s,"rot":%s',o._class,esc(o.Name),num(r.X),num(r.Y),num(r.W),num(r.H),num(o.Rotation or 0))
  parts[#parts+1]=string.format('"bg":%s,"bt":%s',col(o.BackgroundColor3),num(o.BackgroundTransparency or 0))
  if clip then parts[#parts+1]=string.format('"clip":[%s,%s,%s,%s]',num(clip.X),num(clip.Y),num(clip.W),num(clip.H))end
  local corner=o:FindFirstChildOfClass('UICorner')
  if corner then local cr=corner.CornerRadius;parts[#parts+1]='"cr":'..num((cr.Scale or 0)*math.min(r.W,r.H)+(cr.Offset or 0))end
  for _,ch in ipairs(o._children)do
   if ch._class=='UIStroke'and ch.Enabled~=false then
    local contextual=ch.ApplyStrokeMode and ch.ApplyStrokeMode.Name=='Contextual'
    parts[#parts+1]=string.format('"%s":{"c":%s,"t":%s,"tr":%s}',contextual and'ts'or'st',col(ch.Color),num(ch.Thickness or 1),num(ch.Transparency or 0))
   elseif ch._class=='UIGradient'and ch.Enabled~=false and not parts.grad then
    parts.grad=true;parts[#parts+1]=string.format('"g":{"c":%s,"t":%s,"r":%s}',seqColor(ch.Color)or'null',seqNum(ch.Transparency),num(ch.Rotation or 0))
   end
  end
  if(o._class=='TextLabel'or o._class=='TextButton'or o._class=='TextBox')and o.Text~=''and(o.TextTransparency or 0)<1 then
   parts[#parts+1]=string.format('"tx":"%s","fs":%s,"tc":%s,"xa":"%s","ya":"%s","tst":%s',esc(o.Text),num(o.TextSize or 14),col(o.TextColor3),o.TextXAlignment and o.TextXAlignment.Name or'Center',o.TextYAlignment and o.TextYAlignment.Name or'Center',num(o.TextStrokeTransparency or 1))
  end
  if o._class=='ViewportFrame'then parts[#parts+1]='"vp":true'end
  out[#out+1]='{'..table.concat(parts,',')..'}'
  local nextClip=clip
  if o.ClipsDescendants or o._class=='ScrollingFrame'then
   if clip then local x1,y1=math.max(clip.X,r.X),math.max(clip.Y,r.Y);local x2,y2=math.min(clip.X+clip.W,r.X+r.W),math.min(clip.Y+clip.H,r.Y+r.H);nextClip={X=x1,Y=y1,W=math.max(0,x2-x1),H=math.max(0,y2-y1)}
   else nextClip=r end
  end
  dump(o,out,nextClip)
 end
end
local function emit(tag)
 local out={};dump(gui,out,nil)
 local c=current.controls
 local ctl=c and string.format('{"j":[%s,%s,%s,%s],"b":[%s,%s,%s,%s]}',num(c.Joystick.X),num(c.Joystick.Y),num(c.Joystick.W),num(c.Joystick.H),num(c.Jump.X),num(c.Jump.Y),num(c.Jump.W),num(c.Jump.H))or'null'
 print(string.format('DUMP {"tag":"%s","screen":"%s","sw":%d,"sh":%d,"inset":[%d,%d,%d,%d],"w":%s,"h":%s,"controls":%s,"nodes":[%s]}',tag,esc(current.name),current.sw,current.sh,current.inset[1],current.inset[2],current.inset[3],current.inset[4],num(current.w),num(current.h),ctl,table.concat(out,',')))
end
-- Expectations ---------------------------------------------------------------------------------------
local order={'Featured','Passes','Speed','Money','Gems'}
local function caption(b)return b:GetAttribute('Caption')end
local function captionFits(b,what)
 local label=b.Content.Price
 check(label:GetAttribute('TextShortened')~=true,current.name..': '..what..' caption shortened ("'..tostring(label.Text)..'")')
end
local function textFits(l,what)check(l:GetAttribute('TextShortened')~=true,current.name..': '..what..' text shortened ("'..tostring(l.Text)..'" / '..tostring(l:GetAttribute('FullText'))..')')end
local function openShop()act(pg:FindFirstChild('PassesButton',true));layout()end
local function closeShop()act(panel.Header.Close);layout()end
local function bundleFrame(key)return page:FindFirstChild(key..'Bundle')end
local function viewRect()return rect(page)end
local function sectionTop(key)
 if key=='Featured'then return rect(page.LimitedMechPack).Y end
 return rect(page[key..'Header']).Y
end
for si,s in ipairs(screens)do
 setScreen(s)
 calls={};openShop()
 local name=s[1];local view={X=0,Y=0,W=current.w,H=current.h}
 check(panel.Visible and jumpRoot.Visible,name..': shop opens')
 check(pg:GetAttribute('SeedMenu')=='Passes',name..': SeedMenu set')
 check(calls[1]and calls[1][1]=='State',name..': State requested on open')
 local P=rect(panel);local H=rect(panel.Header)
 check(inside(P,view),name..': panel inside the safe area '..string.format('%d,%d %dx%d in %dx%d',P.X,P.Y,P.W,P.H,view.W,view.H))
 check(P.Y>=0,name..': panel below the Roblox top bar')
 if not current.touch and not current.name:find('Portrait')then
  check(P.W>=math.min(1100,current.w*.6),name..': panel uses the screen width ('..math.floor(P.W)..')')
 end
 -- Header: title left, square close right.
 local close=rect(panel.Header.Close)
 check(inside(close,H),name..': close inside header');check(math.abs(close.W-close.H)<1 and close.W>=28,name..': close is a square >=28px')
 textFits(panel.Header.Title,'title')
 -- Jump buttons: on screen, clear of the panel, >=40 px.
 local prevY,prevX
 for i,key in ipairs(order)do
  local b=jumpRoot['Jump'..key];local r=rect(b)
  check(inside(r,view),name..': jump '..key..' on screen')
  check(not L.Overlaps(r,P,0),name..': jump '..key..' outside the panel')
  check(r.W>=40 and r.H>=40,name..': jump '..key..' >=40px')
  if b.Label.Visible then textFits(b.Label,'jump '..key)end
  if prevY then check(r.Y>prevY or r.X>prevX,name..': jump order')end;prevY,prevX=r.Y,r.X
 end
 -- Thumb controls stay clear.
 if current.controls then
  for cname,c in pairs(current.controls)do
   check(not L.Overlaps(P,c,0),name..': panel clear of '..cname)
   for _,key in ipairs(order)do check(not L.Overlaps(rect(jumpRoot['Jump'..key]),c,0),name..': jump '..key..' clear of '..cname)end
  end
 end
 -- Every product with price and buttons.
 local pack=page.LimitedMechPack
 for _,offer in ipairs(Mech.Offers)do check(pack:FindFirstChild('Quantity'..offer.Count)~=nil,name..': pack quantity '..offer.Count)end
 check(caption(pack.BuyWithGems)=='80',name..': pack gem price '..tostring(caption(pack.BuyWithGems)))
 check(caption(pack.BuyWithRobux)=='80',name..': pack robux price '..tostring(caption(pack.BuyWithRobux)))
 captionFits(pack.BuyWithGems,'pack gems');captionFits(pack.BuyWithRobux,'pack robux')
 textFits(pack.PackTitle,'pack title');textFits(pack.Contents,'LIMITED TIME')
 check(#pack.Outcomes:GetChildren()>=6,name..': six pack outcomes')
 for _,seed in ipairs(Mech.Seeds)do local t=pack.Outcomes[seed.Id];check(inside(rect(t),rect(pack),1),name..': outcome tile '..seed.Id..' inside banner');textFits(t.Chance,'chance')end
 for _,b in ipairs({pack.BuyWithGems,pack.BuyWithRobux,pack.Quantity1,pack.Quantity5,pack.Quantity10,pack.PreviewStage})do check(inside(rect(b),rect(pack),1),name..': '..b.Name..' inside banner')end
 for _,pass in ipairs(Passes)do
  local cards={page[pass.Key]};if pass.Key=='Speed'then cards[2]=page.SpeedPassBanner end
  for _,c in ipairs(cards)do
   check(c.GiftPass~=nil and c.GemPerk~=nil and c.RobuxPass~=nil,name..': '..c.Name..' has gift/gems/robux')
   check(caption(c.RobuxPass)==tostring(robux[pass.Key=='Growth'and 101 or 102]),name..': '..c.Name..' robux price '..tostring(caption(c.RobuxPass)))
   check(caption(c.GemPerk)==tostring(Mech.PassGemPrices[pass.Key]),name..': '..c.Name..' gem price')
   for _,b in ipairs({c.GiftPass,c.GemPerk,c.RobuxPass})do check(inside(rect(b),rect(c),1),name..': '..c.Name..'.'..b.Name..' inside card')end
   captionFits(c.RobuxPass,c.Name..' robux');captionFits(c.GemPerk,c.Name..' gems');textFits(c.Title,c.Name..' title')
  end
 end
 for _,row in ipairs(Pricing.Bundles)do
  local c=bundleFrame(row.Key);check(c~=nil,name..': bundle '..row.Key)
  if c then
   check(caption(c.RobuxBundle)==tostring(row.RobuxPrice),name..': '..row.Key..' robux price')
   check(caption(c.GemBundle)==tostring(row.GemPrice),name..': '..row.Key..' gem price')
   check(inside(rect(c.RobuxBundle),rect(c),1)and inside(rect(c.GemBundle),rect(c),1),name..': '..row.Key..' buttons inside card')
   captionFits(c.RobuxBundle,row.Key..' robux');captionFits(c.GemBundle,row.Key..' gems');textFits(c.Amount,row.Key..' amount')
  end
 end
 for _,n in ipairs({'GemQuantity','Maximum','Convert','Heading','Rate','Cost'})do check(inside(rect(page.ConvertCash[n]),rect(page.ConvertCash),1),name..': gems '..n..' inside card')end
 -- Section order and card grid.
 local tops={};for _,key in ipairs(order)do tops[#tops+1]=sectionTop(key)end
 for i=2,#tops do check(tops[i]>tops[i-1],name..': section order '..order[i-1]..' < '..order[i])end
 check(rect(page.SpeedPassBanner).Y>sectionTop('Speed')and rect(page.SpeedPassBanner).Y<rect(bundleFrame('SpeedSmall')).Y,name..': DOUBLE SPEED banner opens SPEED')
 local cards={}
 for _,c in ipairs(page:GetChildren())do if c:IsA('GuiObject')then cards[#cards+1]=c end end
 local pw=page.AbsoluteSize.X-page.ScrollBarThickness
 for i,a in ipairs(cards)do
  local ra=rect(a);ra.Y+=page.CanvasPosition.Y
  check(ra.X>=page.AbsolutePosition.X and ra.X+ra.W<=page.AbsolutePosition.X+pw+.5,name..': '..a.Name..' within page width')
  for j=i+1,#cards do local rb=rect(cards[j]);rb.Y+=page.CanvasPosition.Y;check(not L.Overlaps(ra,rb,-.5),name..': '..a.Name..' overlaps '..cards[j].Name)end
 end
 local function perRow(keys)
  local y=rect(bundleFrame(keys[1])).Y;local n=0
  for _,k in ipairs(keys)do if math.abs(rect(bundleFrame(k)).Y-y)<1 then n+=1 end end;return n
 end
 local speedKeys={'SpeedSmall','SpeedMedium','Speed','SpeedValue','SpeedMega'}
 local wideBody=pw-2*12>=520
 local first=perRow(speedKeys)
 check(first==3 or first==2,name..': speed first row has 3 or 2 cards ('..first..')')
 if current.w<=480 then check(first==2,name..': narrow screens show 2 per row')end
 if first==3 then check(math.abs(rect(bundleFrame('SpeedValue')).Y-rect(bundleFrame('SpeedMega')).Y)<1 and rect(bundleFrame('SpeedValue')).W>rect(bundleFrame('SpeedSmall')).W,name..': last row of 2 wide cards')end
 check(math.abs(rect(page.Growth).Y-rect(page.Speed).Y)<1 or current.w<480,name..': passes 2 per row')
 local _=wideBody
 emit('open')
 -- Jump buttons scroll to their section and highlight it.
 W.Gui.ReducedMotionEnabled=false
 for _,key in ipairs(order)do
  local before=tweens
  act(jumpRoot['Jump'..key]);layout()
  local top=sectionTop(key);local vr=viewRect()
  local maxY=page.CanvasSize.Y.Offset-page.AbsoluteSize.Y
  check(tweens>before,name..': jump '..key..' scrolls smoothly')
  check(top>=vr.Y-1 and top<=vr.Y+vr.H-40,name..': jump '..key..' brings the section into view (top '..math.floor(top-vr.Y)..')')
  if page.CanvasPosition.Y<maxY-1 then check(math.abs(top-vr.Y)<=14,name..': jump '..key..' puts the section at the top ('..math.floor(top-vr.Y)..')')end
  check(jumpRoot['Jump'..key]:GetAttribute('Current')==true,name..': jump '..key..' highlighted')
  local others=0;for _,k in ipairs(order)do if k~=key and jumpRoot['Jump'..k]:GetAttribute('Current')then others+=1 end end
  check(others==0,name..': only one highlighted')
  if si==9 and key=='Speed'then emit('speed')end
  if si==9 and key=='Money'then emit('money')end
  if si==9 and key=='Passes'then emit('passes')end
 end
 if si==9 then
  local y=rect(bundleFrame('SpeedSmall')).Y-page.AbsolutePosition.Y+page.CanvasPosition.Y-8
  page.CanvasPosition=V2(0,y);layout();emit('speedbundles')
 end
 -- Reduced motion: instant.
 W.Gui.ReducedMotionEnabled=true
 local before=tweens;act(jumpRoot.JumpFeatured);check(tweens==before and page.CanvasPosition.Y==0,name..': reduced motion jumps instantly')
 W.Gui.ReducedMotionEnabled=false
 -- Manual scroll updates the highlight.
 page.CanvasPosition=V2(0,page:GetAttribute('TargetY')or 0);layout()
 local moneyTop=rect(page.MoneyHeader).Y-page.AbsolutePosition.Y+page.CanvasPosition.Y
 local maxScroll=page.CanvasSize.Y.Offset-page.AbsoluteSize.Y
 page.CanvasPosition=V2(0,math.min(moneyTop+20,maxScroll-5));layout()
 check(jumpRoot.JumpMoney:GetAttribute('Current')==true,name..': manual scroll highlights Money')
 closeShop()
 check(not panel.Visible and not jumpRoot.Visible and pg:GetAttribute('SeedMenu')==nil,name..': close works')
 -- Legacy entry points (GardenWallet): PremiumPage then SeedMenu.
 for pageName,key in pairs({Packs='Featured',Passes='Passes',Perks='Passes',Speed='Speed',Cash='Money',Gems='Gems'})do
  pg:SetAttribute('PremiumPage',pageName);pg:SetAttribute('SeedMenu','Passes');layout()
  check(panel.Visible,name..': PremiumPage '..pageName..' opens')
  local top=sectionTop(key);local vr=viewRect()
  check(top>=vr.Y-1 and top<=vr.Y+vr.H-40,name..': PremiumPage '..pageName..' shows '..key)
  check(jumpRoot['Jump'..key]:GetAttribute('Current')==true,name..': PremiumPage '..pageName..' highlights '..key)
  pg:SetAttribute('SeedMenu',nil);layout()
  check(not panel.Visible,name..': SeedMenu nil closes')
 end
 -- PremiumFocus (wallet "+" buttons) scrolls to the Large bundle card.
 for _,kind in ipairs({'Cash','Speed'})do
  pg:SetAttribute('PremiumPage',kind);pg:SetAttribute('PremiumFocus',kind);pg:SetAttribute('SeedMenu','Passes');R.advance(0);layout()
  local c=rect(bundleFrame(kind));local vr=viewRect()
  check(inside(c,vr,1),name..': PremiumFocus '..kind..' shows the bundle card')
  check(pg:GetAttribute('PremiumFocus')==nil,name..': PremiumFocus cleared')
  pg:SetAttribute('SeedMenu',nil);layout()
 end
 -- Open from the SHOP button again starts at the top.
 openShop();check(page.CanvasPosition.Y==0,name..': SHOP button opens at the top')
 -- While open, PremiumPage still scrolls.
 pg:SetAttribute('PremiumPage','Gems');layout();check(jumpRoot.JumpGems:GetAttribute('Current')==true,name..': PremiumPage while open')
 closeShop()
 -- Shade closes too.
 openShop();act(gui.Shade);check(not panel.Visible,name..': shade closes');layout()
end
-- Purchases call the same remote actions / prompts as before ----------------------------------------
setScreen(screens[9]);openShop()
local function last()return calls[#calls]end
local pack=page.LimitedMechPack
calls={};act(pack.BuyWithRobux);check(last()and last()[1]=='RobuxPack'and last()[2]==1,'RobuxPack 1')
act(pack.Quantity5);act(pack.BuyWithRobux);check(last()[1]=='RobuxPack'and last()[2]==5,'RobuxPack 5')
check(caption(pack.BuyWithRobux)=='375'and caption(pack.BuyWithGems)=='375','quantity 5 prices')
check(pack.Quantity5:GetAttribute('Selected')==true and pack.Quantity1:GetAttribute('Selected')==false,'quantity selection shown')
act(pack.BuyWithGems);check(last()[1]=='BuyPack'and last()[2]==5,'BuyPack 5')
act(pack.Quantity10);act(pack.BuyWithGems);check(last()[2]==10,'BuyPack 10')
for _,row in ipairs(Pricing.Bundles)do
 local c=bundleFrame(row.Key)
 act(c.RobuxBundle);check(last()[1]=='RobuxBundle'and last()[2]==row.Key,'RobuxBundle '..row.Key)
 act(c.GemBundle);check(last()[1]=='BuyBundle'and type(last()[2])=='table'and last()[2].Key==row.Key and last()[2].GemPrice==row.GemPrice,'BuyBundle '..row.Key)
end
for _,pass in ipairs(Passes)do
 local cards={page[pass.Key]};if pass.Key=='Speed'then cards[2]=page.SpeedPassBanner end
 for _,c in ipairs(cards)do
  local n=#prompts;act(c.RobuxPass);check(#prompts==n+1 and prompts[#prompts][1]==player and prompts[#prompts][2]==Passes.Id(pass),'PromptGamePassPurchase '..c.Name)
  act(c.GemPerk);check(last()[1]=='BuyPerk'and last()[2]==pass.Key,'BuyPerk '..c.Name)
  act(c.GiftPass);local picker=panel.PassGiftPicker;check(picker.Visible,'gift dialog opens from '..c.Name)
  local rec=picker.Recipients:FindFirstChild('Recipient');check(rec~=nil,'gift recipient listed')
  act(rec);act(picker.GiftWithRobux);check(last()[1]=='RobuxGift'and last()[2]==pass.Key,'RobuxGift '..pass.Key)
  act(picker.GiftWithGems);check(last()[1]=='GiftPass'and last()[2].Key==pass.Key and last()[2].RecipientId==2 and last()[2].Payment=='Gems','GiftPass gems '..pass.Key)
  act(picker.CloseGift);check(not picker.Visible,'gift dialog closes')
 end
end
local gems=page.ConvertCash;gems.GemQuantity.Text='12';act(gems.Convert);check(last()[1]=='Convert'and last()[2]==12,'Convert 12')
-- Owned passes show OWNED (both Speed views); Growth untouched.
player:SetAttribute('DoubleSpeedOwned',true);layout()
for _,c in ipairs({page.Speed,page.SpeedPassBanner})do
 check(caption(c.RobuxPass)=='OWNED','OWNED on '..c.Name);check(c.GemPerk.Visible==false,'gem hidden when owned on '..c.Name)
 check(c.RobuxPass.Active==false,'owned robux inactive on '..c.Name);check(c.GiftPass.Visible~=false,'gift still available when owned on '..c.Name)
 check(inside(rect(c.RobuxPass),rect(c),1),'owned button inside '..c.Name)
end
local n=#prompts;act(page.Speed.RobuxPass);check(#prompts==n,'no prompt for an owned pass')
check(caption(page.Growth.RobuxPass)=='467','Growth still for sale')
act(jumpRoot.JumpPasses);layout();emit('owned')
player:SetAttribute('DoubleSpeedOwned',false);layout()
check(caption(page.Speed.RobuxPass)=='399'and page.Speed.GemPerk.Visible,'ownership loss restores buttons')
-- Status toast shows a server message and hides.
remote.InvokeServer=function(_,action,value)calls[#calls+1]={action,value};local s=serverState();s.Message='Complete the Roblox purchase prompt.';return s end
act(page.Growth.GemPerk);check(panel.Status.Visible and panel.Status.Text~='','status message shown')
R.advance(3.1);check(not panel.Status.Visible,'status hides after 3 s')
check(reveals==6,'six outcome previews built once ('..reveals..')')
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
