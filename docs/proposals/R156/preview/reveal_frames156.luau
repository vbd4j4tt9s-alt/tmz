-- R156 preview (not a test, not game code): appended to R155's preview_cinematic155.luau with SET='fixes156' and VIEW (run_reveal_fixes_preview.sh), so it uses that file's
-- mock world, the real RarePull* modules (this checkout, or the same tree with reveal_fixes.patch applied), PackOpeningFeedback, SeedPackClient, SeedCollect154 and the real
-- Hotbar, and its FRAME writer. Plays REAL openings on the Roblox mock at one screen size and prints, for each moment, everything the screen shows (FRAME lines for
-- render_cinematic155.mjs: the world or the story stage, the HUD, the reveal card, the card's seed viewport), plus GUIDE / PILL / FIT lines (numbers for the sheet).
--  * the HUD: the real hotbar, the real pity bars (PityBars155), the real BASE / TRACK (TravelButtons.client.lua), and STAND-INS from HudLayout's own metrics for the rest (balances,
--    status / timers stack, MENU, the owner tools, a phone's thumb controls). The sky is a plain gradient and the avatar a blocky stand-in. APPROXIMATE: not a Studio screenshot.
--  * a Cosmic / King / Secret story scene (the HUD is hidden by the director, as in the game): the SKIP pill, then the result waiting ("click to collect!");
--  * a Common and a Mythic card (Ladder): the suspense (the pill, if there is one) and the result waiting;
--  * a Secret opening in place ("Skip pack animations" on: the HUD stays up): the pill and the result;
--  * a story scene on a phone with a thumb control that stays visible (the controls are not hidden: the pill steps clear of the real control).
-- VIEW: pc (1920 x 1080) | land (844 x 390 phone) | port (390 x 844 phone) | own1 (1891 x 733: the owner's first screenshot) | own2 (530 x 593: the second).
if SET=='fixes156'then
 local VIEWNAME=VIEW or'pc'
 local SIZES={pc={1920,1080,'desktop'},land={844,390,'phone'},port={390,844,'phone'},own1={1891,733,'desktop'},own2={530,593,'desktop'}}
 local SW,SH,KIND=SIZES[VIEWNAME][1],SIZES[VIEWNAME][2],SIZES[VIEWNAME][3]
 local V2=R.Vector2.new;local RGB=R.Color3.fromRGB
 local pg=X.pg
 setDevice(KIND,V2(SW,SH))
 W.Gui.GetInsetArea=function()return{Min=V2(0,0),Width=SW,Height=SH}end -- (the mock's safe area is always 1280 x 720)
 local function sizeGui(g)if g.ClassName=='ScreenGui'then g.AbsoluteSize=V2(SW,SH)end end
 for _,g in ipairs(pg:GetChildren())do sizeGui(g)end
 pg.ChildAdded:Connect(sizeGui)
 local Hud=W.module('HudLayout');local PB=W.module('PityBars155');local Cfg=W.module('SettingsConfig')
 -- the seed names the owner sees ("Watermelon Seed")
 do local cat=W.RS:FindFirstChild('ChestChaseRemotes'):FindFirstChild('SeedCatalog')
  for _,id in pairs(X.byRank)do local e=cat:FindFirstChild(id);if e then e:SetAttribute('DisplayName',Rules.SeedDesignById[id].name..' Seed')end end end
 local TOUCH=W.UIS.TouchEnabled
 local m=Hud.Read(V2(SW,SH),TOUCH,nil)
 -- the HUD ------------------------------------------------------------------------------------------------------------------------------------
 local standin=R.Instance.new('ScreenGui');standin.Name='HudStandIn';standin.DisplayOrder=20;standin.Parent=pg
 local function box(name,x,y,w,h,color,alpha,radius,text,textSize,textColor)
  local f=R.Instance.new('Frame');f.Name=name;f.Position=R.UDim2.fromOffset(x,y);f.Size=R.UDim2.fromOffset(w,h);f.BackgroundColor3=color or RGB(24,30,52);f.BackgroundTransparency=alpha or .35;f.ZIndex=1;f.Parent=standin
  local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(0,radius or 8);c.Parent=f
  local s=R.Instance.new('UIStroke');s.Color=RGB(12,17,38);s.Thickness=2;s.Transparency=.3;s.ApplyStrokeMode=R.Enum.ApplyStrokeMode.Border;s.Parent=f
  if text then
   local t=R.Instance.new('TextLabel');t.Name='Text';t.Size=R.UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=text;t.TextSize=textSize or 12;t.Font=R.Enum.Font.FredokaOne
   t.TextColor3=textColor or RGB(214,226,255);t.TextStrokeTransparency=.3;t.TextStrokeColor3=RGB(8,13,24);t.TextWrapped=true;t.ZIndex=2;t.Parent=f
  end
  return f
 end
 for _,k in ipairs({'Speed','Cash','Gem'})do box('Wallet'..k,m[k..'X']or m.WalletX,m[k..'Y'],m.WalletWidth,m.WalletHeight,RGB(20,26,48),.3,6,k=='Gem'and'Gems'or k,math.max(10,math.floor(m.WalletHeight*.42)))end
 for _,b in ipairs(Hud.HudBoxes(m,SW,SH,false))do
  if b.N=='Hub'then box('Menu',b.X,b.Y,b.W,b.H,RGB(74,125,184),.1,10,'MENU',12)
  elseif b.N=='Status'then box('Status',b.X,b.Y,b.W,b.H,RGB(20,26,48),.45,8,'weather / track / boosts',11)
  elseif b.N=='OwnerTools'then box('Tools',b.X,b.Y,b.W,b.H,RGB(40,46,80),.3,8,'TOOLS',10)
  elseif b.N=='Jump'or b.N=='ThumbR'then box('Jump',b.X+b.W/2-35,b.Y+b.H/2-35,70,70,RGB(255,255,255),.75,35,'jump',12)
  elseif b.N=='ThumbL'then box('Stick',b.X+b.W/2-45,b.Y+b.H/2-45,90,90,RGB(255,255,255),.82,45,'',12)end
 end
 -- the real BASE / TRACK and the real pity bars
 do local remotes=W.RS:FindFirstChild('ChestChaseRemotes')
  for _,nm in ipairs({'RequestBaseTeleport','RequestTrackTeleport'})do if not remotes:FindFirstChild(nm)then local e=R.new('RemoteEvent');e.Name=nm;e.Parent=remotes end end
  W.load('TravelButtons',R.new('LocalScript')) end
 local barsState=PB.Start(X.player,{})
 X.player:SetAttribute('PackPityNormal',3);X.player:SetAttribute('PackPityEvent',1)
 W.frames(90,1/60)
 for _,g in ipairs(pg:GetChildren())do sizeGui(g)end
 W.frames(10,1/60)
 -- numbers for the sheet: where BASE / TRACK end, where the hotbar and the pity bars begin
 do
  local travel=pg:FindFirstChild('TravelButtons');local pair=travel and travel:FindFirstChild('TravelPair')
  local tb=0
  if pair then local _,py,_,ph=X.rect(pair,SW,SH);tb=py+ph end
  local hb,pity=SH,SH
  for _,b in ipairs(Hud.HudBoxes(m,SW,SH,false))do if b.N=='Hotbar'then hb=b.Y end end
  local okR,box2=pcall(PB.Reserved,SW,SH,m,nil);if okR then pity=box2.Y end
  print(('GUIDE %s {"travel":%.1f,"hotbar":%.1f,"pity":%.1f,"w":%d,"h":%d}'):format(VIEWNAME,tb,hb,pity,SW,SH))
 end
 -- the frame ------------------------------------------------------------------------------------------------------------------------------------
 -- (dump_tree falls back to a global Color3 for a colour never set: fill Roblox's defaults first. UIAspectRatioConstraint is drawn as Roblox's default AspectType,
 -- FitWithinMaxSize: the largest box of that ratio within the size the element is given; render_gui.mjs does not apply it, so its size is fixed for the dump)
 local function dump156(root,Wd,Ht)
  for _,o in ipairs(root:GetDescendants())do
   if o:IsA('GuiObject')then
    if o._props.BackgroundColor3==nil then o._props.BackgroundColor3=R.Color3.fromRGB(255,255,255)end
    if o._props.TextColor3==nil then o._props.TextColor3=R.Color3.fromRGB(27,42,53)end
    if o._props.TextStrokeColor3==nil then o._props.TextStrokeColor3=R.Color3.fromRGB(0,0,0)end
    if o._props.ImageColor3==nil then o._props.ImageColor3=R.Color3.fromRGB(255,255,255)end
   end
  end
  local undo={}
  for _,o in ipairs(root:GetDescendants())do
   local a=o:IsA('GuiObject')and o:FindFirstChildOfClass('UIAspectRatioConstraint')
   if a and o.Size and o.Size.X.Offset==0 and o.Size.Y.Offset==0 then
    local _,_,pw,ph=X.rect(o,Wd,Ht);local ratio=a.AspectRatio or 1
    local w=math.min(pw,ph*ratio);local h=w/ratio
    local parentW,parentH=Wd,Ht
    if o.Parent and o.Parent:IsA('GuiObject')then local _,_,qw,qh=X.rect(o.Parent,Wd,Ht);parentW,parentH=qw,qh end
    undo[o]=o.Size;o._props.Size=R.UDim2.fromScale(w/math.max(1,parentW),h/math.max(1,parentH))
   end
  end
  local out=dumpTree(root,Wd,Ht)
  for o,size in pairs(undo)do o._props.Size=size end
  return out
 end
 local function layers156(Wd,Ht)
  local under,over={},{}
  for _,nm in ipairs({'HudStandIn','ChestToolHotbar','PackPityBars155','TravelButtons','TouchGui'})do
   local g=pg:FindFirstChild(nm);if g and g.Enabled~=false then under[#under+1]=dump156(g,Wd,Ht)end
  end
  local fx=pg:FindFirstChild('PackOpeningEffects');if fx and fx.Enabled~=false then over[#over+1]=dump156(fx,Wd,Ht)end
  local gui=pg:FindFirstChild('RarePullReveal')
  if gui and gui.Enabled~=false then
   local view=gui:FindFirstChild('Seed',true)
   if view and view._class=='ViewportFrame'then
    local root=view.Parent;local z=view.ZIndex or 6
    local saved={}
    for _,c in ipairs(root:GetChildren())do if c:IsA('GuiObject')then saved[c]=c._props.Visible end end
    for c in pairs(saved)do if(c.ZIndex or 1)>=z then c._props.Visible=false end end;under[#under+1]=dump156(gui,Wd,Ht)
    for c,v in pairs(saved)do c._props.Visible=v end
    for c in pairs(saved)do if(c.ZIndex or 1)<=z then c._props.Visible=false end end;over[#over+1]=dump156(gui,Wd,Ht)
    for c,v in pairs(saved)do c._props.Visible=v end
   else over[#over+1]=dump156(gui,Wd,Ht)end
  end
  return under,over
 end
 local function frame156(name,label,opts)
  opts=opts or{}
  local Wd,Ht=SW,SH
  local cam=W.workspace.CurrentCamera
  local stage=W.workspace:FindFirstChild('_RarePullStage')
  local inStage=cam.CameraType==R.Enum.CameraType.Scriptable and stage~=nil
  local roots={}
  if inStage then roots={stage}else
   roots={X.char,oc}
   for _,nm in ipairs({'_LocalSeedPackEffects','_RarePullWorld'})do local f=W.workspace:FindFirstChild(nm);if f then roots[#roots+1]=f end end
  end
  local eye=cam.CFrame.Position;local target=eye+cam.CFrame.LookVector*10;local fov=cam.FieldOfView or 70;local up=cam.CFrame.UpVector
  local g=cam:FindFirstChild('RarePullGrade');local b=cam:FindFirstChild('RarePullBlur');local d=cam:FindFirstChild('RarePullDof')
  local grade=g and string.format('{"b":%s,"c":%s,"s":%s,"tint":%s}',n(g.Brightness or 0),n(g.Contrast or 0),n(g.Saturation or 0),c3(g.TintColor))or'null'
  local dof=d and(d.FarIntensity or 0)+(d.NearIntensity or 0)>0 and string.format('{"focus":%s,"radius":%s,"far":%s,"near":%s}',n(d.FocusDistance),n(d.InFocusRadius),n(d.FarIntensity),n(d.NearIntensity))or'null'
  local under,over=layers156(Wd,Ht)
  local vp='null'
  local gui=pg:FindFirstChild('RarePullReveal');local view=gui and gui:FindFirstChild('Seed',true)
  if view and view._class=='ViewportFrame'and view.Visible and(view.ImageTransparency or 1)<.98 and view.CurrentCamera then
   local x,y,w,h=X.rect(view,Wd,Ht);local s=math.min(w,h);x=x+(w-s)/2;y=y+(h-s)/2
   local scale=view:FindFirstChildOfClass('UIScale');local k=scale and scale.Scale or 1;local vc=view.CurrentCamera
   vp=string.format('{"rect":[%s,%s,%s,%s],"alpha":%s,"scale":%s,"eye":%s,"target":%s,"fov":%s,%s}',n(x),n(y),n(s),n(s),n(1-view.ImageTransparency),n(k),v3(vc.CFrame.Position),v3(vc.CFrame.Position+vc.CFrame.LookVector*10),n(vc.FieldOfView or 30),world({view}))
  end
  local kind=inStage and('stage'..(M.Active()and M.Active().Rank or 8))or'world'
  print('FRAME '..name..' '..string.format('{"w":%d,"h":%d,"label":%s,"tag":"","tree":"R156","kind":%s,"eye":%s,"target":%s,"up":%s,"fov":%s,"dof":%s,"shot":"","move":"","t":0,"grade":%s,"blur":%s,%s,"under":[%s],"guis":[%s],"viewport":%s}',
   Wd,Ht,q(label),q(kind),v3(eye),v3(target),v3(up),n(fov),dof,grade,n(b and b.Size or 0),world(roots),table.concat(under,','),table.concat(over,','),vp))
 end
 -- driving an opening ----------------------------------------------------------------------------------------------------------------------
 local opened=0
 -- shots(run, tl, press) -> {{seconds on the opening's clock, frame name, label}}; press: when a story scene is clicked (collected)
 local function drive(rank,shots,opts)
  opts=opts or{}
  clearAll();opened+=1;local id='pv156-'..opened
  local skipAttr=Cfg.ToggleAttributes.SkipCutscenes
  X.player:SetAttribute(skipAttr,opts.InPlace==true or nil)
  local tool=live(F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId=id,Stage=2},nil));tool.Enabled=false;tool.Parent=X.char
  local seedId=X.byRank[rank];local spec=Rules.SeedDesignById[seedId];local rarity=Rules.GetRarity(seedId)
  tool.ToolTip='Desert Seed Pack\n'..(spec and spec.name or seedId)..': 1/'..({'2','4','16','60','400','5K','83.3K','1.67B'})[rank]
  local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None')
  local dur=Rules.GetRevealDuration(rarity)
  bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',rarity);bag:SetAttribute('Weather','None');bag:SetAttribute('RevealDuration',dur);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
  local t0=R.clock
  local function step(dt)
   W.frames(1,dt)
   if bag.Parent and R.clock-t0>=dur then -- the server ends the opening: the pack goes, the seed's tool arrives (held back until it has flown in)
    bag:Destroy();tool:Destroy()
    local t=live(F.tool(W,spec and spec.name or seedId,{GardenSeed=true,SeedInventoryId=id,SeedId=seedId,SeedScale=1,Mutation='None',Weather='None',Rarity=rarity,Stage=2},E.bag),true)
    X.hum:EquipTool(t)
   end
  end
  step(1/60)
  local run=M.Active();if not run then error('no opening started')end
  local tl=run.TL
  local press=tl.FloatEnd and tl.Climax and(tl.FloatEnd+Cam155.SettleSeconds+(opts.Wait or 1))or math.huge
  print(('RUN %s %s rank=%d kind=%s why=%s'):format(VIEWNAME,opts.Name or'',rank,tostring(run.Kind),tostring(run.Why)))
  if run.Card and run.Card.SkipButton then print(('PILLBUTTON %s %s yes'):format(VIEWNAME,opts.Name or''))else print(('PILLBUTTON %s %s none'):format(VIEWNAME,opts.Name or''))end
  for _,s in ipairs(shots(run,tl,press))do
   local want=s[1]
   while run.Clock()<want-1e-6 do
    if run.Kind=='Scene'and not run.Collected and run.Clock()>=press-1e-6 then local b=pg:FindFirstChild('Backdrop',true);if b then b.Activated:Fire()end;if not run.Collected then M.Collect()end end
    local left=math.min(1/60,want-run.Clock());if run.Kind=='Scene'and not run.Collected then left=math.min(left,press-run.Clock())end
    step(math.max(1e-4,left))
   end
   frame156(s[2],s[3] or'')
   local card=run.Card
   if card and card.SkipBox and s[4]then local bx=card.SkipBox;print(('PILL %s %s {"x":%d,"y":%d,"w":%d,"h":%d,"right":%d,"bottom":%d}'):format(VIEWNAME,s[2],bx.X,bx.Y,bx.W,bx.H,SW-(bx.X+bx.W),SH-(bx.Y+bx.H)))end
   if card and card.Layout and card.Layout.Fit then
    local L2=card.Layout
    print(('FIT %s %s {"top":%.1f,"bottom":%.1f,"k":%.3f,"title":[%.1f,%.1f],"seed":[%.1f,%.1f],"odds":[%.1f,%.1f],"name":[%.1f,%.1f],"hint":[%.1f,%.1f]}'):format(VIEWNAME,s[2],L2.Fit.Top*SH,L2.Fit.Bottom*SH,L2.Fit.K,
     L2.Title.Y*SH,L2.Title.H*SH,L2.Seed.Y*SH,L2.Seed.H*SH,L2.Odds.Y*SH,L2.Odds.H*SH,L2.Name.Y*SH,L2.Name.H*SH,L2.Hint.Y*SH,L2.Hint.H*SH))
   end
  end
  if not run.Collected then M.Collect()end
  local g=0;while(M.Active()or Collect.Flying()>0)and g<600 do step(1/30);g+=1 end
  if bag.Parent then bag:Destroy()end;if tool.Parent then tool:Destroy()end
  X.player:SetAttribute(skipAttr,nil)
  return run
 end
 -- the shots ---------------------------------------------------------------------------------------------------------------------------------
 local only=ONLY156 -- (a quick look: a list of the drives to run)
 local function want(name)return only==nil or only[name]end
 -- a card: the suspense (a pill, if there is one) and the result waiting
 local function ladder(rank,key)
  if not want(key)then return end
  drive(rank,function(run,tl)
   local susp=math.min(tl.Burst-.05,math.max(.55,tl.Burst*.62))
   return {{susp,key..'_susp','',true},{tl.FloatEnd+.9,key..'_res','',true}}
  end,{Name=key})
 end
 ladder(1,'common');ladder(5,'mythic')
 -- a story scene: the pill, the result waiting under its hint
 local SCENE={pc=7,land=8,port=6,own1=7,own2=7}
 local rank=SCENE[VIEWNAME]
 if want('scene')then
  drive(rank,function(run,tl,press)
   return {{tl.SkipFrom+.4,'scene_skip','',true},{press-.1,'scene_res','',true}}
  end,{Name='scene',Wait=1})
 end
 -- the same scene on a phone whose jump button stays visible (the mock's controls are not hidden by the director): the pill steps clear of the real control
 if want('jump')and(VIEWNAME=='land')then
  local touch=R.Instance.new('ScreenGui');touch.Name='TouchGui';touch.Parent=pg;touch.AbsoluteSize=V2(SW,SH)
  local function ctl(name,x,y,w,h)
   local f=R.Instance.new('Frame');f.Name=name;f.AbsolutePosition=V2(x,y);f.AbsoluteSize=V2(w,h);f.Size=R.UDim2.fromOffset(w,h);f.Position=R.UDim2.fromOffset(x,y)
   f.BackgroundColor3=RGB(255,255,255);f.BackgroundTransparency=name=='JumpButton'and .75 or .82;f.Parent=touch
   local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(.5,0);c.Parent=f
   if name=='JumpButton'then
    local t=R.Instance.new('TextLabel');t.Size=R.UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text='jump';t.TextSize=12;t.Font=R.Enum.Font.FredokaOne;t.TextColor3=RGB(214,226,255);t.TextStrokeTransparency=.3;t.TextStrokeColor3=RGB(8,13,24);t.Parent=f
   end
  end
  ctl('ThumbstickFrame',20,SH-110,90,90);ctl('JumpButton',SW-95,SH-90,70,70)
  local old=X.hud.Touch;if old then old.Parent=nil end
  drive(rank,function(run,tl,press)return {{tl.SkipFrom+.4,'jump_skip','',true}}end,{Name='jump',Wait=0})
  touch:Destroy();if old then old.Parent=pg end
 end
 -- a Secret opening in place ("Skip pack animations" on): the HUD stays up, the pill keeps clear of it; then the result
 if want('inplace')and(VIEWNAME=='pc'or VIEWNAME=='land')then
  drive(6,function(run,tl)
   return {{math.min(tl.Climax-.4,tl.SkipFrom+.8),'inplace_skip','',true},{tl.FloatEnd+1.2,'inplace_res','',true}}
  end,{Name='inplace',InPlace=true})
 end
end
