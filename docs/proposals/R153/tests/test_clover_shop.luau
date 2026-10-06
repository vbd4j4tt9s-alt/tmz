--!nocheck
-- R153, the 4 Leaf Clover CARD and the places the clover shows, CLIENT half: the real GamePassClient, PremiumBoostCard, PremiumLayout, PremiumShopArt, CloverIcon153, WorldStatusHud and
-- PurchaseCelebration under the Roblox mock, with the layout resolver and Fredoka One metrics of the R120 shop test (run from a folder with roblox.luau, world.luau, rs_bundle.luau, metrics.luau).
--  A. the pass id from the catalog (the code default; the test reads it, never copies it): the card is the third PASSES card (second row), "x2 Luck", Gem 999 | Robux (live price), the clover
--     picture (pass icon > drawn > shapes), Gem click = BuyPerk Clover (the same flow as the other perks), Robux click = the Roblox pass prompt, OWNED states, "Checking..."
--  B. the id switched off (CloverPassId = 0): no Robux button, the Gem button takes the whole row, the card says "ROBUX SOON", the Gem buy still asks the server, OWNED by Gems still reads OWNED
--  C. the HUD luck row shows the clover picture and the luck including the pass (and the cap); D. the purchase pop (PurchaseDone with the Icon)
-- Lines starting with DUMP are frame dumps for render_clover.py (the preview docs/proposals/R153/clover.png); CLOVERRGBA is the decoded picture (hex).
local W=require('./world');local R=W.R;local metrics=require('./metrics')
local V2=R.Vector2.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local TextS=W.service('TextService')
function TextS.GetTextSize(_,text,size,_,bounds)local w=0;for _,cp in utf8.codes(text)do w+=(metrics[cp]or .6)*size end;return V2(math.min(bounds.X,w),size*1.2)end
local tweens=0;local Tween=W.service('TweenService')
function Tween.Create(_,obj,_,props)tweens+=1;return {Play=function()for k,v in pairs(props)do obj[k]=v end end,Cancel=function()end,Completed=R.signal()}end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local player=R.new('Player');player.Name='Buyer';player.DisplayName='Buyer';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return {player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
for _,k in ipairs({'Growth','Speed','Clover'})do player:SetAttribute(k..'OwnershipReady',true)end
local RS=W.RS
local Passes=W.module('GamePassCatalog');local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog');local Art=W.module('PremiumShopArt')
local clover;for _,p in ipairs(Passes)do if p.Key=='Clover'then clover=p end end
local DEFAULT_ID=Passes.Id(clover) -- (no attribute is set yet: the code default, whatever the owner put there)
local robux={};local infos={}
local function rbx(n)return tostring(n)..' Robux'end
RS.GamePassCatalog:SetAttribute('GrowthPassId',101);RS.GamePassCatalog:SetAttribute('SpeedPassId',102);robux[101]=467;robux[102]=399
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Mech.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
local Market=W.service('MarketplaceService');local prompts={};local infoAsked={}
Market.GetProductInfoAsync=function(_,id,kind)infoAsked[#infoAsked+1]=id;if infos[id]then return infos[id]end;return robux[id]and{PriceInRobux=robux[id],IsForSale=true}or nil end
Market.PromptGamePassPurchase=function(_,p,id)prompts[#prompts+1]={p,id}end
local function serverState()
 local offers={};for _,o in ipairs(Mech.Offers)do offers[tostring(o.Count)]={Count=o.Count,GemPrice=o.GemPrice,GemAvailable=true,RobuxAvailable=true,RobuxPrice=o.TargetRobuxPrice}end
 local bundles={};for _,row in ipairs(Pricing.Bundles)do bundles[row.Key]={Available=true,Amount=row.Amount,GemPrice=row.GemPrice,RobuxAmount=row.Amount}end
 return {PackOffers=offers,Bundles=bundles,GiftProducts={Growth={Available=true},Speed={Available=true},Clover={Available=true}},GiftCredits={},Gems=5000,OnSale=true,Success=true,Message=''}
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local remote=R.new('RemoteFunction');remote.Name='PremiumRequest';remote.Parent=remotes;local calls={}
remote.InvokeServer=function(_,action,value)calls[#calls+1]={action,value};return serverState()end
local doneRemote=R.new('RemoteEvent');doneRemote.Name='PurchaseDone';doneRemote.OnClientEvent=R.signal();doneRemote.Parent=remotes
W.stub('InteractionAudio',{Transaction=function()end,Play=function()end,Preload=function()end})
W.stub('ShopViewport',{Visible=function()return true end,CachedVisible=function()return true end})
W.stub('ShopSeedReveal',{Attach=function()return {Refresh=function()end,Destroy=function()end}end})
W.stub('PackViewport89',{DecorateCard=function()end,Create=function(parent)
 local halo=R.Instance.new('Frame');halo.Name='MechDockingBay';halo.Parent=parent
 local v=R.Instance.new('ViewportFrame');v.Name='MechPackPreview';v.Parent=parent;return v end})
-- the clover picture: hooks stand in for the engine (an EditableImage is a table here)
local Icon=W.module('CloverIcon153');local created={}
Icon.Hooks.Create=function(w,h,rgba)local o={W=w,H=h,Data=rgba,Destroyed=false};function o.Destroy(self)self.Destroyed=true end;created[#created+1]=o;return o end
Icon.Hooks.Content=function(image)return {Image=image} end
Icon.Hooks.Spawn=function(f)f()end;Icon.Hooks.Wait=function()end;Icon.Hooks.Preload=function()end;Icon.Hooks.Delay=function()end
-- screens ----------------------------------------------------------------------------------------------------------------------------------------
local screens={{'PC 1280x720',1280,720,false,{0,58,0,0}},{'Phone 844x390',844,390,true,{47,58,47,21}},{'Phone 667x375',667,375,true,{0,58,0,0}},{'Portrait 390x844',390,844,true,{0,105,0,34}}}
local function controlsFor(w,h)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-110,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-180,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local touchGui=R.Instance.new('ScreenGui');touchGui.Name='TouchGui';touchGui.Enabled=false
local thumb=R.Instance.new('Frame');thumb.Name='ThumbstickFrame';thumb.Parent=touchGui
local jumpBtn=R.Instance.new('ImageButton');jumpBtn.Name='JumpButton';jumpBtn.Parent=touchGui
touchGui.Parent=pg
local L=W.module('PremiumLayout')
local gui,panel,page,jumpRoot
local function act(b)b.Activated:Fire()end
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
-- JSON dump for the renderer (R120's, plus "im":"clover" on the clover picture's label) --------------------------------------------------------------
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
  if o._class=='ImageLabel'and o.Name=='Embedded'and o.ImageContent~=nil then parts[#parts+1]='"im":"clover"'end
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
-- helpers ---------------------------------------------------------------------------------------------------------------------------------------
local function caption(b)return b:GetAttribute('Caption')end
local function textFits(l,what)check(l:GetAttribute('TextShortened')~=true,current.name..': '..what..' text shortened ("'..tostring(l.Text)..'" / '..tostring(l:GetAttribute('FullText'))..')')end
local function boot()
 W.UIS.TouchEnabled=false;table.clear(calls);table.clear(prompts);table.clear(infoAsked)
 W.load('GamePassClient',R.new('LocalScript'))
 gui=pg.GardenPasses;panel=gui.PremiumShop;page=panel.Body.Page;jumpRoot=gui.JumpButtons
end
local function openShop()act(pg:FindFirstChild('PassesButton',true));layout()end
local function closeShop()act(panel.Header.Close);layout()end
local function toPasses()act(jumpRoot.JumpPasses);layout()end
local function iconOf(card)return card.IconStage:FindFirstChild('CloverIcon153')end
local function hex(buf)local t={};for i=0,buffer.len(buf)-1 do t[#t+1]=string.format('%02x',buffer.readu8(buf,i))end;return table.concat(t)end
-- A. the pass with an id (the code default) ---------------------------------------------------------------------------------------------------------
local PASS_ID=DEFAULT_ID
if PASS_ID==0 then PASS_ID=103;RS.GamePassCatalog:SetAttribute('CloverPassId',PASS_ID)end -- (the owner has not put an id in the code: the attribute stands in for it)
robux[PASS_ID]=999;infos[PASS_ID]={PriceInRobux=999,IsForSale=true,IconImageAssetId=424242}
boot()
check(Passes.Id(clover)==PASS_ID,'the shop reads the pass id from the catalog ('..tostring(Passes.Id(clover))..')')
local rbxShown=true
for si,s in ipairs(screens)do
 Icon.Reset();table.clear(created);boot();setScreen(s)
 openShop();local name=s[1]
 local card=page:FindFirstChild('Clover')
 check(card~=nil and card:GetAttribute('PassKey')=='Clover','Clover card exists in the page')
 if card then
  check(page.Growth.LayoutOrder==1 and page.Speed.LayoutOrder==2 and card.LayoutOrder==3,name..': pass cards in order Growth, Speed, Clover')
  local rg,rs_,rc=rect(page.Growth),rect(page.Speed),rect(card)
  if current.w>=480 then check(math.abs(rg.Y-rs_.Y)<1 and rc.Y>rg.Y+rg.H-1 and math.abs(rc.X-rg.X)<1,name..': Clover is the third card: second row, under Growth')
  else check(rc.Y>rs_.Y,name..': Clover is under Speed (one card per row)')end
  check(rc.W==rg.W and rc.H==rg.H,name..': same size as the other pass cards')
  check(not L.Overlaps(rc,rg,-.5)and not L.Overlaps(rc,rs_,-.5),name..': no overlap with the other cards')
  check(card.Title.Text=='x2 Luck','title "x2 Luck" ('..tostring(card.Title.Text)..')');textFits(card.Title,'Clover title')
  check((card.Detail.Text:gsub('\n',' '))=='2x luck on every pack u open!','detail in the owner\'s voice: '..tostring(card.Detail.Text));textFits(card.Detail,'Clover detail')
  check(card.Permanent.Text=='PERMANENT','tag PERMANENT');textFits(card.Permanent,'Clover tag')
  check(caption(card.GemPerk)=='999','Gem button: 999 ('..tostring(caption(card.GemPerk))..')')
  check(caption(card.RobuxPass)==rbx(999),'Robux button: the live price ('..tostring(caption(card.RobuxPass))..')')
  check(card.RobuxPass.Visible==true and card.RobuxPass.Active==true and card.GemPerk.Visible==true and card.GemPerk.Active==true,name..': both buttons shown and active')
  check(rect(card.GemPerk).X+rect(card.GemPerk).W<=rect(card.RobuxPass).X and math.abs(rect(card.GemPerk).Y-rect(card.RobuxPass).Y)<1,name..': [Gems | Robux] row like the other cards')
  for _,b in ipairs({card.GemPerk,card.RobuxPass})do check(inside(rect(b),rc,1),name..': '..b.Name..' inside the card');textFits(b.Content.Price,b.Name..' caption')end
  check(rect(card.GemPerk).W==rect(page.Growth.GemPerk).W,name..': the Gem button is as wide as Growth\'s')
  check(card:FindFirstChild('GiftPass')==nil,name..': no gift button (R122)')
  -- the picture
  local icon=iconOf(card)
  check(icon~=nil and icon.Parent==card.IconStage,name..': the card holds the clover picture (CloverIcon153)')
  check(inside(rect(card.IconStage),rc,1)and rect(card.IconStage).W>=60,name..': the picture stage is inside the card and at least 60 px ('..math.floor(rect(card.IconStage).W)..')')
  check(Icon.Stats().Status=='ready'and#created==1,name..': opening the shop drew the picture (once)')
  local _,emb,pass=icon.Fallback,icon.Embedded,icon:FindFirstChild('PassIcon')
  check(pass~=nil and pass.Image=='rbxassetid://424242','the pass\'s own icon (IconImageAssetId) is set from the info the shop fetched: '..tostring(pass and pass.Image))
  check(Icon.Source(icon)=='embedded','until the pass icon has loaded the drawn clover shows')
  layout()
  if si==1 then
   toPasses();emit('clover_passes');print('CLOVERRGBA '..hex(created[1].Data))
   pass.IsLoaded=true;check(Icon.Source(icon)=='pass','once the pass icon has loaded it shows instead')
   check(Icon.Stats().Live==0 and created[1].Destroyed==true,'... and the drawn picture is released (no EditableImage left)')
   pass.IsLoaded=false
  end
  -- buying
  table.clear(calls);act(card.GemPerk);check(calls[#calls]and calls[#calls][1]=='BuyPerk'and calls[#calls][2]=='Clover','Gem click: BuyPerk "Clover" (the same flow as the other perks)')
  local n=#prompts;act(card.RobuxPass);check(#prompts==n+1 and prompts[#prompts][1]==player and prompts[#prompts][2]==PASS_ID,'Robux click: the Roblox pass prompt for the catalog id')
  -- owned by gems / Robux
  player:SetAttribute('CloverOwned',true);layout()
  check(card.GemPerk.Visible==false and caption(card.RobuxPass)=='OWNED' and card.RobuxPass.Active==false,name..': owned: Gem button gone, the Robux button reads OWNED and is inactive')
  check(inside(rect(card.RobuxPass),rect(card),1)and rect(card.RobuxPass).W>rect(page.Growth.RobuxPass).W,name..': ... and takes the whole row')
  local m=#prompts;act(card.RobuxPass);check(#prompts==m,'no prompt for an owned pass')
  check(caption(page.Growth.RobuxPass)==rbx(467),'Growth is untouched')
  if si==2 then toPasses();emit('clover_owned')end
  player:SetAttribute('CloverOwned',nil);layout()
  check(card.GemPerk.Visible and caption(card.GemPerk)=='999' and caption(card.RobuxPass)==rbx(999),'ownership loss restores both buttons')
  player:SetAttribute('CloverOwnershipReady',false);layout()
  check(caption(card.GemPerk)=='Checking…' and card.GemPerk.Active==false,'while the ownership check runs: "Checking…", no Gem buying')
  player:SetAttribute('CloverOwnershipReady',true);layout()
  if si==2 then
   toPasses() -- (the phone's panel is short: scroll on until the whole third card shows)
   local pr,cr=rect(page),rect(card);page.CanvasPosition=V2(0,page.CanvasPosition.Y+math.max(0,cr.Y+cr.H-(pr.Y+pr.H)+10));layout()
   check(inside(rect(card),rect(page),1),name..': scrolled down, the whole Clover card is in view')
   emit('clover_phone')
  end
 end
 closeShop()
end
-- the pass icon never arrives (no icon id / failing info): the drawn picture stays
do
 infos[PASS_ID]={PriceInRobux=999,IsForSale=true,IconImageAssetId=0}
 Icon.Reset();table.clear(created);boot();setScreen(screens[1]);openShop()
 local card=page.Clover;local icon=iconOf(card)
 check(icon:FindFirstChild('PassIcon')==nil and Icon.Source(icon)=='embedded','a pass without an icon id: no PassIcon, the drawn clover shows')
 closeShop()
 infos[PASS_ID]=nil;robux[PASS_ID]=nil
 Icon.Reset();table.clear(created);boot();setScreen(screens[1]);openShop()
 check(caption(page.Clover.RobuxPass)=='Unavailable'and page.Clover.RobuxPass.Active==false and page.Clover.RobuxPass.Visible==true,'Roblox info that never arrives: the Robux button says Unavailable (inactive), the Gem button works')
 check(page.Clover.GemPerk.Active==true and Icon.Source(iconOf(page.Clover))=='embedded','... and the card still shows the drawn clover')
 closeShop()
 robux[PASS_ID]=999;infos[PASS_ID]={PriceInRobux=999,IsForSale=true,IconImageAssetId=424242}
end
-- B. the id switched off ------------------------------------------------------------------------------------------------------------------------------
RS.GamePassCatalog:SetAttribute('CloverPassId',0)
Icon.Reset();table.clear(created);boot()
check(Passes.Id(clover)==0,'CloverPassId = 0: the pass has no id')
check(Passes.RobuxSoon(clover)==true and Passes.RobuxSoon(Passes[1])==false and Passes.RobuxSoon(Passes[2])==false,'RobuxSoon: true for the Clover with no id, false for passes that have no DefaultId')
for si,s in ipairs(screens)do
 setScreen(s);openShop();local name=s[1];local card=page.Clover;local rc=rect(card)
 check(card.RobuxPass.Visible==false,name..': id 0: the Robux button is hidden')
 check(card.GemPerk.Visible==true and card.GemPerk.Active==true and caption(card.GemPerk)=='999','... the Gem button works: 999 ('..tostring(caption(card.GemPerk))..')')
 local g=rect(card.GemPerk)
 check(inside(g,rc,1)and g.W>=rc.W-24,name..': ... and takes the whole row ('..math.floor(g.W)..' of '..math.floor(rc.W)..')')
 check(g.W>rect(page.Growth.GemPerk).W*1.8,name..': ... much wider than the Gem button of a two-button card')
 check(card.Permanent.Text=='ROBUX SOON',name..': the card says the Robux price is coming ('..tostring(card.Permanent.Text)..')');textFits(card.Permanent,'ROBUX SOON tag')
 check(page.Growth.RobuxPass.Visible==true and caption(page.Growth.RobuxPass)==rbx(467),name..': the other cards keep their Robux buttons')
 table.clear(calls);act(card.GemPerk);check(calls[#calls]and calls[#calls][1]=='BuyPerk'and calls[#calls][2]=='Clover',name..': Gem click still asks the server: BuyPerk "Clover"')
 local n=#prompts;act(card.RobuxPass);check(#prompts==n,name..': (a hidden Robux button opens no prompt)')
 local zeroAsked=0;for _,id in ipairs(infoAsked)do if id==0 then zeroAsked+=1 end end
 check(zeroAsked==0,name..': Roblox is never asked about pass 0')
 check(Icon.Source(iconOf(card))=='embedded'and iconOf(card):FindFirstChild('PassIcon')==nil,name..': the drawn clover shows (no pass icon without an id)')
 player:SetAttribute('CloverOwned',true);layout()
 check(card.GemPerk.Visible==false and card.RobuxPass.Visible==true and caption(card.RobuxPass)=='OWNED' and card.RobuxPass.Active==false,name..': id 0 and owned (by Gems): the pass reads OWNED')
 check(inside(rect(card.RobuxPass),rc,1),name..': ... inside the card')
 check(card.Permanent.Text=='PERMANENT',name..': ... and the tag is PERMANENT again ('..tostring(card.Permanent.Text)..')')
 if si==1 then toPasses();emit('clover_owned_gems')end
 player:SetAttribute('CloverOwned',nil);layout()
 check(card.RobuxPass.Visible==false and card.GemPerk.Visible==true,name..': ownership loss: back to the Gem button only')
 check(card.Permanent.Text=='ROBUX SOON',name..': ... and ROBUX SOON')
 if si==1 then toPasses();emit('clover_soon')end
 closeShop()
end
-- the attribute brings it back with a price, with no code change
RS.GamePassCatalog:SetAttribute('CloverPassId',555);robux[555]=999
Icon.Reset();table.clear(created);boot();setScreen(screens[1]);openShop()
check(page.Clover.RobuxPass.Visible==true and caption(page.Clover.RobuxPass)==rbx(999)and page.Clover.Permanent.Text=='PERMANENT','CloverPassId = 555 (a test id): the Robux button is back with its live price, the tag is PERMANENT again')
local n=#prompts;act(page.Clover.RobuxPass);check(prompts[#prompts][2]==555 and#prompts==n+1,'... and the prompt is for that id')
closeShop()
RS.GamePassCatalog:SetAttribute('CloverPassId',nil)
check(Passes.Id(clover)==DEFAULT_ID,'(attribute removed: the code default again)')
-- C. the HUD luck row --------------------------------------------------------------------------------------------------------------------------------
do
 Icon.Reset();table.clear(created)
 local Hud=W.module('WorldStatusHud');local h=Hud.Create(pg,player)
 local root=pg.WorldStatus.StatusStack;local row=root.LuckBoost
 check(row.Visible==false and Icon.Stats().Created==0,'HUD: no luck row at x1, and no picture drawn for it')
 local icon=row.Icon:FindFirstChild('CloverIcon153')
 check(icon~=nil,'HUD: the luck row\'s icon is the clover picture (CloverIcon153), the same one as the shop card')
 check(Icon.Source(icon)=='fallback','HUD: until it is drawn the plain clover shows')
 player:SetAttribute('ChestLuckMultiplier',2);R.advance(0)
 check(row.Visible==true and row.Value.Text=='×2','HUD: luck 2 (the pass alone) shows ×2 ('..tostring(row.Value.Text)..')')
 check(Icon.Stats().Status=='ready'and#created==1 and Icon.Source(icon)=='embedded','HUD: the picture is drawn when the row first shows')
 player:SetAttribute('ChestLuckMultiplier',100);R.advance(0);check(row.Value.Text=='×100','HUD: Sand Boots x50 + the pass = ×100 ('..tostring(row.Value.Text)..')')
 player:SetAttribute('ChestLuckMultiplier',50000000);R.advance(0);check(row.Value.Text=='×50M','HUD: the cap shows ×50M ('..tostring(row.Value.Text)..')')
 player:SetAttribute('ChestLuckMultiplier',1e12);R.advance(0);check(row.Value.Text=='×50M','HUD: more than the cap is shown as the cap')
 local speed,luck=Hud.Boosts(player);check(luck==50000000,'Hud.Boosts clamps the luck to MaxLuck')
 player:SetAttribute('ChestLuckMultiplier',1);R.advance(0);check(row.Visible==false,'HUD: back to x1: the row is hidden')
 check(#created==1,'HUD: the picture was drawn once')
 h.Destroy()
 local h2=Hud.Create(pg,player);player:SetAttribute('ChestLuckMultiplier',2);R.advance(0);h2.Destroy()
 check(#created==1 and Icon.Stats().Live==1,'a rebuilt HUD (respawn) shares the one picture: still 1 EditableImage made, 1 alive')
 player:SetAttribute('ChestLuckMultiplier',nil)
end
-- D. the purchase pop ----------------------------------------------------------------------------------------------------------------------------------
do
 Icon.Reset();table.clear(created)
 local audio=W.module('InteractionAudio');local played=0;audio.Play=function(key)if key=='GemClaim'then played+=1 end end
 W.load('PurchaseCelebration',R.new('LocalScript'))
 local function bursts()local s=pg:FindFirstChild('PurchaseCelebration');return s and s.Layer or nil end
 doneRemote.OnClientEvent:Fire({Kind='Pass',Name='Double Speed Pass'})
 local layer=bursts();check(layer~=nil and layer:FindFirstChild('PurchaseIcon')==nil and played==1,'a purchase without an Icon: the burst and the chime, no picture (as before)')
 for _=1,200 do W.frames(1,1/30)end;check(bursts()==nil,'... and everything is cleaned up')
 R.advance(1)
 doneRemote.OnClientEvent:Fire({Kind='Pass',Name='4 Leaf Clover Pass',Icon='Clover'})
 layer=bursts();local pop=layer and layer:FindFirstChild('PurchaseIcon')
 check(pop~=nil and pop:FindFirstChild('CloverIcon153')~=nil,'a purchase with Icon "Clover": the clover picture pops up in the middle of the burst')
 check(played==2,'... with the chime too')
 W.frames(6,1/60);check(pop.Size.X.Offset>0,'... it grows in ('..string.format('%.0f',pop.Size.X.Offset)..' px)')
 check(Icon.Stats().Status=='ready','... and it is drawn for it (Ensure)')
 for _=1,200 do W.frames(1,1/30)end;check(bursts()==nil and pop.Parent==nil,'... and removed with the burst (nothing left in the PlayerGui)')
 R.advance(1)
 for i,junk in ipairs({'clover','Clover ',5,true,{},{'Clover'},false})do
  doneRemote.OnClientEvent:Fire({Kind='Pass',Name='X',Icon=junk});local l=bursts();check(l==nil or l:FindFirstChild('PurchaseIcon')==nil,'a hostile Icon ('..tostring(junk)..') pops nothing, breaks nothing')
  for _=1,100 do W.frames(1,1/30)end;R.advance(1)
 end
 check(Icon.Stats().Live<=1,'(still at most one EditableImage alive)')
end
print(string.format('R153 clover shop: %d checks, %d failures',checks,fails))
if fails>0 then error('failed')end
