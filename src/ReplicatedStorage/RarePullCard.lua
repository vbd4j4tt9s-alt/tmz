-- R151: the screen side of every pull reveal, one visual language from Common to King (the opener only).
--  Ladder (Common..Mythic, on the reveal's server clock): while the pack builds, the screen edges pulse in the flickering rarity hint
--   (RarePullRules.Hint), motes gather (Legendary+), Mythic brings a brief letterbox; on the burst a flash (and rays / a coloured shockwave
--   for Legendary / Mythic), then the SEED CARD: the seed itself (its real model in a ViewportFrame) big and centred, floating down and
--   turning, the rarity word above it, "1 in N" counting up and slamming in, the seed's name. Short and smaller lower down.
--  Scene (Secret / Cosmic / King story scenes, on the cinematic's clock): letterbox bars, the dim, the fade to the hidden stage and back,
--   the flash on the hit, the per-tier title (SECRET void-purple glitch, COSMIC nebula with stars and orbiting planets, KING gold with a crown
--   and turning rays), "1 in N", the name and the skip hint. The seed is the real 3D seed in the scene, framed in the free middle band.
--  InPlace (Secret+ when the full scene is not safe): a compact card in the upper third; the middle of the screen stays clear.
-- R154: the result WAITS on screen (the director's tl.Wait: nothing fades out) until the player collects it; the hint then says so
-- ("click to collect!" / "tap to collect!") and the seed's view leaves the card to fly home (TakeSeed, SeedCollect154).
-- Nothing here blocks input (Active=false everywhere) but the SKIP button (R155); the director owns the buttons. All sizes are shares of the
-- screen, so desktop and phone keep the same framing (RarePullRules.Layout); ReducedMotion: no float, spin, jitter or moving motes; lite: fewer pieces.
-- R155 (owner: "for some cutscenes u can skip it by spam clicking disable this feature and u can only skip at the bottom right of the screen"):
-- a click / tap anywhere no longer skips. The skip is a small SKIP button at the bottom right (Card.SkipRect: inside the device's safe area,
-- clear of every HUD box - the hotbar, the status / timers stack, the balances, a phone's thumb controls); it shows from SkipFrom until the hit
-- (gamepad B / R2 and Enter press it: the director), then the corner says how to collect the result.
-- R155 review: a player in Shift Lock or first person has no mouse to click it with (the cursor is locked to the middle): the button is MODAL while it shows
-- (Roblox frees the mouse for as long as a modal button is visible, and gives the lock back when it goes), and a keyboard's pill carries a small "Enter" key
-- (the gamepad's has its "B"). Its place also keeps clear of the pity bars above the hotbar (PityBars155.Reserved), which a phone's thumb controls would put it on.
-- R157 (owner: "this skip is not placed at the correct spot it should be at the bottom right side of the screen and additionally the click to collect should be
-- below the fruit name and also reduce the size of the seed display so it fits perfectly between the base buttons and the hotbar while also making it so that the
-- skip button only appears for secret and above"):
--  * SKIP: a story scene (kind 'Scene') hides the whole HUD, so nothing of it can be in the pill's way: it goes to the corner of the safe area (14 px in), and keeps
--    clear only of a thumb control that is really on screen (Card.ControlBoxes). A card that leaves the HUD up (the compact in-place card) keeps today's rule (SkipBoxes).
--    Only Secret / Cosmic / King can be skipped: Common..Mythic have no SkipFrom (RarePullRules.CardTimeline), so no pill.
--  * The collect hint ("click to collect!" / "tap to collect!") sits directly under the seed's name, centred, in every card (Layout.Hint).
--  * The Common..Mythic card, and the compact card of an opening in place, are fitted to the band between BASE / TRACK and the pity bars / hotbar (Card.FitBand,
--    RarePullRules.FitLayout); the story scenes keep their layout (their HUD is hidden).
local RS=game:GetService('ReplicatedStorage')
local Rules=require(script.Parent.RarePullRules)
local Cache=require(script.Parent.PropCache152)
-- R152 (owner: "improve look on ... the card, the seed display"): a soft glow and, from Legendary up, a turning halo ring behind the seed,
-- and the Cosmic title's planets, drawn on the client (RarePullArt: the same images the story scenes use); the R151 shapes otherwise.
local Art do local ok,m=pcall(require,script.Parent.RarePullArt);Art=ok and m or nil end
local function artImage(parent,name,props)
 if not Art then return nil end
 local state,content=Art.Get(name);if state~='ready'then return nil end
 local img=Instance.new('ImageLabel');img.BackgroundTransparency=1;img.BorderSizePixel=0;img.Active=false
 for k,v in pairs(props)do img[k]=v end
 local ok=pcall(function()img.ImageContent=content end)
 if not ok then img:Destroy();return nil end
 img:SetAttribute('RarePullArt',name);img.Parent=parent;return img
end
local Card={};Card.__index=Card
local C=Color3.fromRGB;local WHITE=C(255,255,255);local BLACK=C(0,0,0)
local function new(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props)do o[k]=v end
 if o:IsA('GuiObject')then o.BorderSizePixel=0;o.Active=false end
 o.Parent=parent;return o
end
local function frame(parent,name,color,z,props)
 local f=new('Frame',{Name=name,BackgroundColor3=color,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),ZIndex=z or 1,BackgroundTransparency=1},parent)
 if props then for k,v in pairs(props)do f[k]=v end end
 return f
end
local function round(f)new('UICorner',{CornerRadius=UDim.new(1,0)},f);return f end
local function label(parent,name,font,color,stroke,z)
 local l=new('TextLabel',{Name=name,BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Font=font,TextColor3=color,TextStrokeColor3=stroke or BLACK,
  TextStrokeTransparency=1,TextScaled=true,Text='',ZIndex=z or 10,TextTransparency=1,Size=UDim2.fromScale(.9,.1),Position=UDim2.fromScale(.5,.5)},parent)
 new('UITextSizeConstraint',{MaxTextSize=200,MinTextSize=8},l)
 return l
end
local function gradient(parent,a,b,c)
 local seq=c and ColorSequence.new({ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(.5,b),ColorSequenceKeypoint.new(1,c)})or ColorSequence.new(a,b)
 return new('UIGradient',{Color=seq,Rotation=90},parent)
end
local function clamp01(x)return math.clamp(x,0,1)end
-- R152: the right and bottom insets of the device's safe area, as shares of the full screen (0, 0 on a plain screen or if unknown)
function Card.SafeInsets()
 local ok,r,b=pcall(function()
  local G=game:GetService('GuiService')
  local full,safe=G:GetInsetArea(Enum.ScreenInsets.None),G:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
  local function corner(a)return a.Max or Vector2.new(a.Min.X+a.Width,a.Min.Y+a.Height)end
  local fw,fh=full.Width,full.Height;if not(fw and fh and fw>0 and fh>0)then return 0,0 end
  local fm,sm=corner(full),corner(safe)
  return math.clamp((fm.X-sm.X)/fw,0,.12),math.clamp((fm.Y-sm.Y)/fh,0,.12)
 end)
 if ok and type(r)=='number'and type(b)=='number'then return r,b end
 return 0,0
end
-- kind: 'Ladder' | 'Scene' | 'InPlace'; opts: {Rank, Phone, Reduced, Lite, Quick, SeedName, Odds (final "N" text or nil), Seed (Model or nil),
-- Skip (R153: the card is skippable: it shows the skip hint too; R154: every card has the hint, it says how to collect the result)}
function Card.Create(gui,kind,opts)
 local rank=math.clamp(opts.Rank or 1,1,8);local tier=Rules.Tier(rank)
 local self=setmetatable({Gui=gui,Kind=kind,Rank=rank,Tier=tier,Phone=opts.Phone==true,Reduced=opts.Reduced==true,Lite=opts.Lite==true,Quick=opts.Quick==true,
  Odds=opts.Odds,SeedName=opts.SeedName or'',Layout=Rules.Layout(opts.Phone==true,kind=='InPlace',rank),
  HudHidden=kind=='Scene'}, -- (R157: a story scene hides the whole HUD: nothing of it is in the SKIP button's way)
  Card)
 if kind~='Scene'then self.Layout=self:_fit()or self.Layout end -- (R157: Common..Mythic and the compact card: fitted to the band between BASE / TRACK and the pity bars / hotbar)
 local root=frame(gui,'RarePull',BLACK,1);root.Size=UDim2.fromScale(1,1);self.Root=root
 local cache=Cache.new();self.Set,self.Scale=cache.Set,cache.Scale -- (R152 perf: per-frame writes only when a value changes)
 local accent=tier.Theme or tier.Hint
 -- edges: four soft gradients in the hint colour (the dim / suspense pulse)
 self.Edges={}
 local edgeSpecs={{'Top',UDim2.fromScale(.5,0),UDim2.fromScale(1,.32),Vector2.new(.5,0),90},{'Bottom',UDim2.fromScale(.5,1),UDim2.fromScale(1,.32),Vector2.new(.5,1),-90},
  {'Left',UDim2.fromScale(0,.5),UDim2.fromScale(.22,1),Vector2.new(0,.5),0},{'Right',UDim2.fromScale(1,.5),UDim2.fromScale(.22,1),Vector2.new(1,.5),180}}
 for _,e in ipairs(edgeSpecs)do
  local f=frame(root,'Edge '..e[1],accent,2,{Position=e[2],Size=e[3],AnchorPoint=e[4],BackgroundTransparency=0,Visible=false})
  new('UIGradient',{Rotation=e[5],Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(1,1)})},f)
  self.Edges[#self.Edges+1]=f
 end
 -- motes that gather toward the middle
 self.Motes={}
 local motes=(rank>=4 or kind~='Ladder')and(self.Lite and 8 or 16)or 0
 for i=1,motes do
  local m=frame(root,'Mote '..i,accent,3,{Size=UDim2.fromScale(.012,.012),Rotation=45,Visible=false})
  new('UIAspectRatioConstraint',{AspectRatio=1},m)
  self.Motes[i]=m
 end
 -- rays behind the seed / title
 self.Rays={}
 if tier.Rays or rank==8 then
  local holder=frame(root,'Rays',accent,4,{Size=UDim2.fromScale(.9,.9),Visible=false});new('UIAspectRatioConstraint',{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},holder);self.RayHolder=holder
  for i=1,(self.Lite and 8 or 12)do
   local r=frame(holder,'Ray '..i,accent,4,{Size=UDim2.fromScale(.018,.5),AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,.5),Rotation=(i-1)*360/(self.Lite and 8 or 12),BackgroundTransparency=0})
   new('UIGradient',{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.6,.55),NumberSequenceKeypoint.new(1,1)})},r)
   self.Rays[i]=r
  end
 end
 -- the shockwave ring (2D)
 if tier.Shock or rank>=6 then
  local ring=frame(root,'Shockwave',accent,5,{Size=UDim2.fromScale(.1,.1),Visible=false});round(ring);new('UIAspectRatioConstraint',{AspectRatio=1},ring)
  self.RingStroke=new('UIStroke',{Color=accent,Thickness=4,Transparency=1},ring);self.Ring=ring
 end
 -- the seed card (Ladder / InPlace): the seed's real model in a viewport
 if kind~='Scene'then
  local L=self.Layout
  local view=new('ViewportFrame',{Name='Seed',BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,L.Seed.Y),Size=UDim2.fromScale(L.Seed.H,L.Seed.H),
   ImageTransparency=1,ZIndex=6,Ambient=C(170,170,182),LightColor=C(255,250,240),LightDirection=Vector3.new(-.6,-1,-.8),Visible=false},root)
  new('UIAspectRatioConstraint',{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},view)
  local glow=artImage(root,'glow',{Name='Seed glow',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,L.Seed.Y),Size=UDim2.fromScale(L.Seed.H*1.5,L.Seed.H*1.5),
   ImageColor3=tier.Glow,ImageTransparency=1,ZIndex=5,Visible=false})
  if glow then self.GlowIsImage=true
  else
   glow=frame(root,'Seed glow',tier.Glow,5,{Position=UDim2.fromScale(.5,L.Seed.Y),Size=UDim2.fromScale(L.Seed.H*1.05,L.Seed.H*1.05),BackgroundTransparency=1,Visible=false})
   round(glow)
   new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,1)})},glow)
  end
  new('UIAspectRatioConstraint',{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},glow) -- (sized by the screen height, like the seed)
  if rank>=4 then
   self.SeedHalo=artImage(root,'halo',{Name='Seed halo',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,L.Seed.Y),Size=UDim2.fromScale(L.Seed.H*1.25,L.Seed.H*1.25),
    ImageColor3=(tier.Theme or tier.Hint):Lerp(WHITE,.25),ImageTransparency=1,ZIndex=5,Visible=false})
   if self.SeedHalo then new('UIAspectRatioConstraint',{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},self.SeedHalo)end
  end
  self.View=view;self.SeedGlow=glow
  local cam=Instance.new('Camera');cam.Name='Seed camera';cam.FieldOfView=30;cam.Parent=view;view.CurrentCamera=cam;self.ViewCamera=cam
  self.ViewScale=new('UIScale',{Scale=1},view)
 end
 -- texts
 local L=self.Layout
 local title=label(root,'Title',tier.Font,WHITE,tier.Deep,12);title.Position=UDim2.fromScale(.5,L.Title.Y);title.Size=UDim2.fromScale(.92,L.Title.H);title.Text=tier.Title
 self.TitleScale=new('UIScale',{Scale=1},title);self.Title=title
 if rank<=5 then gradient(title,tier.Glow:Lerp(WHITE,.4),tier.Hint)
 elseif rank==6 then
  title.TextColor3=C(236,220,255);title.TextStrokeColor3=C(26,6,44)
  self.Split={}
  for i,c in ipairs({C(80,255,240),C(255,60,170)})do
   local s=label(root,'Title split '..i,tier.Font,c,BLACK,11);s.Position=title.Position;s.Size=title.Size;s.Text=tier.Title;self.Split[i]=s
  end
  self.Scan={}
  for i=1,(self.Lite and 2 or 4)do self.Scan[i]=frame(root,'Scanline '..i,C(10,0,20),13,{Size=UDim2.fromScale(.6,.006),Visible=false,BackgroundTransparency=.3})end
 elseif rank==7 then
  gradient(title,C(255,170,236),C(186,150,255),C(120,220,255));title.TextStrokeColor3=C(8,10,40)
  self.Stars={}
  for i=1,(self.Lite and 4 or 7)do
   local s=frame(root,'Title star '..i,WHITE,13,{Size=UDim2.fromScale(.012,.012),Rotation=45,Visible=false,BackgroundTransparency=0});new('UIAspectRatioConstraint',{AspectRatio=1},s);self.Stars[i]=s
  end
  self.Planets={};self.PlanetImages={}
  for i,c in ipairs({C(255,170,120),C(140,200,255)})do
   local size=.022+.008*i
   local p=artImage(root,i==1 and'planet_gas'or'planet_ring',{Name='Title planet '..i,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromScale(size*(i==1 and 1.35 or 2.4),size*(i==1 and 1.35 or 2.4)),ZIndex=13,Visible=false})
   if p then new('UIAspectRatioConstraint',{AspectRatio=1},p);self.PlanetImages[i]=true
   else
    p=round(frame(root,'Title planet '..i,c,13,{Size=UDim2.fromScale(size,size),Visible=false,BackgroundTransparency=0}));new('UIAspectRatioConstraint',{AspectRatio=1},p)
    local ringF=frame(p,'Ring',WHITE,13,{Size=UDim2.fromScale(1.9,.35),BackgroundTransparency=1,Rotation=-18});round(ringF);new('UIStroke',{Color=WHITE,Thickness=1.5,Transparency=.35},ringF)
   end
   self.Planets[i]=p
  end
 else
  gradient(title,C(255,248,200),C(255,206,84),C(196,120,24));title.TextStrokeColor3=C(70,34,4)
  local ok,Emblems=pcall(require,RS:FindFirstChild('PremiumEmblems'))
  if ok and Emblems then
   local holder=frame(root,'Title crown',WHITE,13,{Size=UDim2.fromScale(L.Title.H*.7,L.Title.H*.7),Position=UDim2.fromScale(.5,L.Title.Y-L.Title.H*.62),Visible=false})
   new('UIAspectRatioConstraint',{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},holder)
   local crown=Emblems.Draw(holder,'Crown');for _,d in ipairs(crown:GetDescendants())do if d:IsA('GuiObject')then d.ZIndex=13 end end
   self.Crown=holder;self.CrownParts={};for _,d in ipairs(holder:GetDescendants())do if d:IsA('GuiObject')then self.CrownParts[#self.CrownParts+1]=d end end
  end
 end
 local odds=label(root,'Odds',Enum.Font.GothamBlack,WHITE,tier.Deep,12);odds.Position=UDim2.fromScale(.5,L.Odds.Y);odds.Size=UDim2.fromScale(.8,L.Odds.H)
 self.OddsScale=new('UIScale',{Scale=1},odds);self.OddsLabel=odds
 local name=label(root,'Seed name',Enum.Font.GothamBold,tier.Glow:Lerp(WHITE,.5),tier.Deep,12);name.Position=UDim2.fromScale(.5,L.Name.Y);name.Size=UDim2.fromScale(.7,L.Name.H);name.Text=self.SeedName
 self.NameLabel=name
 -- letterbox, glitch, fade, flash, skip hint
 self.Bars={frame(root,'Letterbox top',BLACK,20,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromScale(1,0),BackgroundTransparency=0}),
  frame(root,'Letterbox bottom',BLACK,20,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,1),Size=UDim2.fromScale(1,0),BackgroundTransparency=0})}
 if rank==6 then
  self.Glitch={}
  for i=1,(self.Lite and 3 or 5)do self.Glitch[i]=frame(root,'Glitch '..i,i%2==0 and C(80,255,240)or C(255,60,170),21,{Visible=false,BackgroundTransparency=.35})end
 end
 self.Fade=frame(root,'Fade',BLACK,30,{BackgroundTransparency=1})
 self.Flash=frame(root,'Flash',tier.Glow,31,{BackgroundTransparency=1})
 do -- (R154: every card: the collect hint, and the skip hint before it)
  local hint=label(root,'Skip hint',Enum.Font.GothamBold,C(230,230,240),BLACK,32)
  -- (R157: it was in the bottom-right corner, inside the device's safe area; now it is directly under the seed's name, centred: Layout.Hint)
  hint.AnchorPoint=Vector2.new(.5,.5);hint.Position=UDim2.fromScale(.5,L.Hint.Y);hint.Size=UDim2.fromScale(.6,L.Hint.H);hint.TextXAlignment=Enum.TextXAlignment.Center
  self.CollectText=Card.CollectText(self.Phone)
  hint.Text='';self.SkipHint=hint
 end
 self:_place()
 if opts.Skip then self:_buildSkip(gui)end -- (R155: on the screen layer itself, above a story scene's full-screen button)
 if opts.Seed then self:SetSeed(opts.Seed)end
 return self
end
-- R157: the static sizes of the pieces from self.Layout: once the pieces exist, and again when a fitted card's screen changes size (_refit)
function Card:_place()
 local L=self.Layout;local S=self.Scale
 S(self.Title,'Size',.92,L.Title.H);S(self.OddsLabel,'Size',.8,L.Odds.H);S(self.NameLabel,'Size',.7,L.Name.H)
 if self.SkipHint then S(self.SkipHint,'Size',.6,L.Hint.H)end
 if self.View then
  local w=L.Seed.W or L.Seed.H;local glow=self.GlowIsImage and 1.5 or 1.05
  S(self.View,'Size',w,L.Seed.H);S(self.SeedGlow,'Size',w*glow,L.Seed.H*glow)
  if self.SeedHalo then S(self.SeedHalo,'Size',w*1.25,L.Seed.H*1.25)end
 end
 if self.Crown then S(self.Crown,'Size',L.Title.H*.7,L.Title.H*.7)end
 -- R157: the card tells where its rows are (Card.Rows), so the lucky pack's tag (PityBars155.TagPlace) follows the fitted card: as the attributes of a Folder under its root
 -- frame (Card.RowsName; a folder is never drawn, the frame's own look stays as it was)
 if self.View then
  local box=self.RowsBox
  if not box then box=Instance.new('Folder');box.Name=Card.RowsName;box.Parent=self.Root;self.RowsBox=box end
  for key,value in pairs(Card.Rows(L))do box:SetAttribute(Card.RowKeys[key],value)end
 end
end
-- R157: the rows of a seed card's layout L as shares of the screen's height: the seed's square where it comes to rest (Seed.Y + Rules.Fit.Float), the top of
-- "1 in N", the bottom of the name, the collect hint's row. Published as the attributes Card.RowKeys of the root frame's Folder Card.RowsName (PityBars155.CardRows reads them).
Card.RowsName='FitRows'
Card.RowKeys={SeedTop='FitSeedTop',SeedBottom='FitSeedBottom',OddsTop='FitOddsTop',NameBottom='FitNameBottom',HintTop='FitHintTop',HintBottom='FitHintBottom'}
function Card.Rows(L)
 local rest=L.Seed.Y+Rules.Fit.Float
 return {SeedTop=rest-L.Seed.H/2,SeedBottom=rest+L.Seed.H/2,OddsTop=L.Odds.Y-L.Odds.H/2,NameBottom=L.Name.Y+L.Name.H/2,HintTop=L.Hint.Y-L.Hint.H/2,HintBottom=L.Hint.Y+L.Hint.H/2}
end
-- (R157: the screen changed size - a window resized, a phone turned: the card is fitted to the new band)
function Card:_refit()
 local cam=workspace.CurrentCamera
 if self.FitFor and cam and cam.ViewportSize~=self.FitFor then local layout=self:_fit();if layout then self.Layout=layout;self:_place()end end
end
-- R157: the card's layout for the screen it is on (Common..Mythic, and the compact card of an opening in place): RarePullRules.FitLayout in the band FitBand gives. nil when that
-- cannot be told (no camera / no HudLayout): the card keeps RarePullRules.Layout, as before.
function Card:_fit()
 local cam=workspace.CurrentCamera;local vp=cam and cam.ViewportSize
 if not vp or vp.X<=0 or vp.Y<=0 then return nil end
 local ok,layout=pcall(function()
  local compact=self.Kind=='InPlace'
  local top,bottom=Card.FitBand(self.Gui,vp,self.Rank,self.Phone,compact)
  return Rules.FitLayout(self.Phone,self.Rank,top,bottom,vp.X,vp.Y,compact)
 end)
 if not(ok and type(layout)=='table')then return nil end
 self.FitFor=vp;return layout
end
-- The seed card's model: centred in its viewport, framed by its bounding sphere.
function Card:SetSeed(model)
 if not self.View or not model then return end
 self.SeedModel=model;model.Parent=self.View
 -- framed by what is visible (RarePullRules.VisibleBounds) and its biggest side (it turns about Y, so its width and depth both pass the
 -- camera): the seed fills most of the card
 local ok,centre,size=pcall(Rules.VisibleBounds,model)
 if not ok or not centre then
  local ok2,cf,s=pcall(function()return model:GetBoundingBox()end)
  if ok2 and cf then centre,size=cf.Position,s else centre,size=Vector3.zero,Vector3.one end
 end
 self.SeedCentre=centre;self.SeedRadius=math.max(.2,math.max(size.X,size.Y,size.Z)*.53)
 local base=model:GetPivot();self.SeedBase=CFrame.new(self.SeedCentre):ToObjectSpace(base)
 local dist=self.SeedRadius/math.tan(math.rad(15))*1.08
 self.ViewCamera.CFrame=CFrame.lookAt(self.SeedCentre+Vector3.new(0,self.SeedRadius*.12,dist),self.SeedCentre)
end
-- Shared pieces --------------------------------------------------------------------------------------------------------------------------
-- R152 perf: every frame used to set every property of every piece (most to the value already there); the card's own cache (PropCache152)
-- writes only what changes. Every value is the same as before: only the writes of unchanged values are gone.
function Card:_edges(color,a)local S=self.Set;for _,e in ipairs(self.Edges)do S(e,'Visible',a>.005);S(e,'BackgroundColor3',color);S(e,'BackgroundTransparency',1-a)end end
function Card:_bars(k)local S=self.Set;local h=self.Layout.Bar*clamp01(k);for _,b in ipairs(self.Bars)do self.Scale(b,'Size',1,h);S(b,'Visible',h>0)end end
function Card:_motes(k,t,color,alpha)
 local S=self.Set
 for i,m in ipairs(self.Motes)do
  local a=i*2.399+.3;local r=.62*(1-k)+.06
  if self.Reduced then r=.5 end
  S(m,'Visible',alpha>.01);S(m,'BackgroundColor3',color);S(m,'BackgroundTransparency',1-alpha*(.4+.6*math.sin(i+t*3)^2))
  self.Scale(m,'Position',.5+math.cos(a+t*(self.Reduced and 0 or .9))*r*.62,.5+math.sin(a+t*(self.Reduced and 0 or .9))*r)
 end
end
function Card:_rays(t,alpha)
 if not self.RayHolder then return end
 local S=self.Set
 S(self.RayHolder,'Visible',alpha>.01);S(self.RayHolder,'Rotation',self.Reduced and 0 or t*14)
 for _,r in ipairs(self.Rays)do S(r,'BackgroundTransparency',1-alpha)end
end
function Card:_ring(k,alpha)
 if not self.Ring then return end
 local S=self.Set
 S(self.Ring,'Visible',alpha>.01 and k<1);local d=.1+(self.Reduced and .35 or 1.3)*(1-(1-k)^2)
 self.Scale(self.Ring,'Size',d,d);S(self.RingStroke,'Transparency',1-alpha*(1-k));S(self.RingStroke,'Thickness',2+6*(1-k))
end
function Card:_flash(a)self.Set(self.Flash,'BackgroundTransparency',1-clamp01(a)*(self.Reduced and .35 or 1))end
function Card:_fade(a)self.Set(self.Fade,'BackgroundTransparency',1-clamp01(a))end
-- R154 the collect hint: once the result is shown and waits (tl.Wait) "click to collect!" / "tap to collect!" (owner's voice), in after
-- CollectHint s, breathing softly (held still with Reduced Motion); it goes with the collect (tl.WaitEnd: a story scene's way out). (R153's
-- "CLICK TO SKIP" before it is gone: R155 skips with the SKIP button only, Card:_skip.)
Card.CollectHint=.25
function Card.CollectText(phone)return phone and'tap to collect!'or'click to collect!'end
function Card:_hint(t,tl)
 local h=self.SkipHint;if not h then return end
 local S=self.Set;local hit=tl.Climax or tl.Burst or 0;local shown=Rules.ShownAt(tl)
 if t>=shown and(tl.Wait or tl.WaitEnd)then
  local a=clamp01((t-shown-Card.CollectHint)/.3)*(tl.WaitEnd and 1-clamp01((t-tl.WaitEnd)/.15)or 1)*(self.Reduced and 1 or .82+.18*math.sin((t-shown)*3.2))
  S(h,'Text',self.CollectText);S(h,'TextTransparency',1-.9*a);S(h,'TextStrokeTransparency',1-.5*a);S(h,'Visible',a>.01)
  self.Scale(h,'Position',.5,self.Layout.Hint.Y-(self.Lift or 0)) -- (R157: under the name, lifting with it as the card goes)
  return
 end
 S(h,'Visible',false)
end
-- R155: the SKIP button ----------------------------------------------------------------------------------------------------------------------
-- Where it goes, in pixels of the safe area (w x h; boxes: HudLayout.HudBoxes in the same space): the bottom row first, from the right edge
-- leftwards (never left of the middle), then the rows above it (never above .45 of the height; R157: .2 when nothing lower is clear); the first spot clear of the screen's edge by
-- 14 px (R157: was 12) and of every box by 8 px. Its height: 6.5 % of the screen's (34 - 48 px; at least 40 on a touch screen: a thumb's target).
-- R157: a story scene passes no boxes (its HUD is hidden): the first spot is the corner, 14 px from the right and bottom edges of the safe area.
Card.SkipLabel='SKIP  ▸▸'
Card.EnterLabel='Enter'
-- (the word's place and size on the pill: alone, beside the gamepad's B, beside the keyboard's Enter key; built once, not per frame)
local WORD_AT,WORD_PAD_AT,WORD_KEY_AT=UDim2.fromScale(.5,.5),UDim2.fromScale(.58,.5),UDim2.fromScale(.675,.5)
local WORD_SIZE,WORD_KEY_SIZE=UDim2.fromScale(.74,.5),UDim2.fromScale(.5,.5)
function Card.SkipRect(w,h,touch,boxes)
 local bh=math.floor(math.clamp(h*.065,touch and 40 or 34,48)+.5);local bw=math.floor(bh*2.75+.5)
 local margin,pad=14,8
 local function clear(x,y)
  if x<margin or y<margin or x+bw>w-margin or y+bh>h-margin then return false end
  for _,b in ipairs(boxes or{})do if x<b.X+b.W+pad and x+bw>b.X-pad and y<b.Y+b.H+pad and y+bh>b.Y-pad then return false end end
  return true
 end
 local x0,y0=w-margin-bw,h-margin-bh
 for y=y0,math.floor(h*.45),-4 do for x=x0,math.floor(w*.5),-4 do if clear(x,y)then return x,y,bw,bh end end end
 -- (R157 build: a tiny window - 640 x 360, 420 x 420 - whose hotbar, bars and status stack fill the whole lower right: higher up the right half, to .2 of the height,
 -- before it would lie on the slots)
 for y=math.floor(h*.45)-4,math.floor(h*.2),-4 do for x=x0,math.floor(w*.5),-4 do if clear(x,y)then return x,y,bw,bh end end end
 return x0,y0,bw,bh -- (nothing is clear: the corner itself)
end
-- What the button keeps clear of in a safe area w x h: HudLayout's boxes (controls: a touch screen's real thumb controls, HudLayout.Controls, or nil) and, R155 review,
-- the pity bars' extent: they are above the hotbar all the time, and on a phone the thumb controls push the button up to where they are.
function Card.SkipBoxes(w,h,touch,controls)
 local okL,Layout=pcall(require,RS:FindFirstChild('HudLayout'))
 if not(okL and Layout)then return{} end
 local ok,list=pcall(function()
  local m=Layout.Read(Vector2.new(w,h),touch,controls)
  local list=Layout.HudBoxes(m,w,h,false)
  local okB,Bars=pcall(require,RS:FindFirstChild('PityBars155'))
  if okB and Bars then local okR,box=pcall(Bars.Reserved,w,h,m,nil);if okR and type(box)=='table'then list[#list+1]=box end end
  return list
 end)
 return ok and type(list)=='table'and list or{}
end
-- R157 (owner: the seed display "fits perfectly between the base buttons and the hotbar"): the band of the full screen, top and bottom in px, the Common..Mythic seed card
-- may fill. Its top: the bottom edge of BASE / TRACK (HudLayout.TravelBottom, from GuiService.TopbarInset: where TravelButtons draws them) and a small margin; for
-- Mythic also under its letterbox bar. Its bottom: the top of whatever is highest above the bottom of the screen of the hotbar (HudLayout's box: the slots and the held
-- item's name line), the pity bars (PityBars155.Reserved: their glow and the held bar's scale included) and, in a narrow window, the balances / status stack where they reach
-- into the column the card's words fill (centred, .4 of the height wide: HudLayout lifts them up beside the hotbar there), less the same margin. The HUD is measured in the safe area
-- (as SkipBoxes does) and moved to the full screen's coordinates. gui: the card's ScreenGui (the real thumb controls); vp: the screen's size; rank: 1-5; phone: the card's.
function Card.FitBand(gui,vp,rank,phone,compact)
 local Layout=require(RS:FindFirstChild('HudLayout'))
 local ox,oy,w,h=Card.SafeArea(vp)
 local touch=game:GetService('UserInputService').TouchEnabled
 local okC,controls=pcall(function()return Layout.Controls(gui)end)
 local m=Layout.Read(Vector2.new(w,h),touch,okC and controls or nil)
 local margin=math.max(8,math.floor(vp.Y*.012+.5))
 local top=Layout.TravelBottom(game:GetService('GuiService').TopbarInset)+margin
 if Rules.Tier(rank).Letterbox then top=math.max(top,Rules.Layout(phone,false,rank).Bar*vp.Y+margin)end -- (Mythic's bar, while it is up)
 local lowest=h
 for _,b in ipairs(Layout.HudBoxes(m,w,h,false))do
  if b.N=='Hotbar'then lowest=math.min(lowest,b.Y)
  -- (a narrow window lifts the balances and the status stack up beside the hotbar: where they reach into the column the card's words fill, .4 of the height wide and
  -- centred, they are the card's floor too)
  elseif b.Y>h*.35 and(b.N:sub(1,6)=='Wallet'or b.N=='Status')and b.X<w/2+h*.2 and b.X+b.W>w/2-h*.2 then lowest=math.min(lowest,b.Y)end
 end
 local okB,Bars=pcall(require,RS:FindFirstChild('PityBars155'))
 if okB and Bars then local okR,box=pcall(Bars.Reserved,w,h,m,nil);if okR and type(box)=='table'then lowest=math.min(lowest,box.Y)end end
 local bottom=oy+lowest-margin
 if compact then bottom=math.min(bottom,math.max(vp.Y*.45,top+140))end -- (the compact card keeps to the upper part of the screen: the middle stays clear)
 return top,bottom
end
function Card:_buildSkip(parent)
 local b=new('TextButton',{Name='Skip button',Text='',AutoButtonColor=false,BackgroundColor3=C(18,16,30),BackgroundTransparency=1,ZIndex=45,Visible=false,
  Selectable=false,Size=UDim2.fromOffset(110,40),Position=UDim2.fromScale(.88,.9)},parent)
 b.Active=true;b:SetAttribute('ButtonSound',false);b:SetAttribute('ButtonHighlight',false) -- (the hit is the sound of a skip)
 -- (R155 review: MODAL while it shows - Shift Lock and first person lock the mouse to the middle, and then nothing on the screen can be clicked; a modal button
 -- that is visible frees it. _skip turns it on with the button's fade-in and off with its fade-out; a button that is hidden any other way - the card's fade-out
 -- hides every button - turns it off here, and Destroy does)
 b.Modal=false
 b:GetPropertyChangedSignal('Visible'):Connect(function()if not b.Visible and b.Modal then b.Modal=false end end)
 new('UICorner',{CornerRadius=UDim.new(.5,0)},b)
 self.SkipStroke=new('UIStroke',{Color=WHITE,Thickness=1.5,Transparency=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
 local text=label(b,'Label',Enum.Font.GothamBlack,WHITE,BLACK,46);text.Size=UDim2.fromScale(.74,.5);text.Position=UDim2.fromScale(.5,.5);text.Text=Card.SkipLabel
 -- (a gamepad: its B on the left of the pill, the button it answers to)
 local pad=frame(b,'Gamepad B',C(226,72,72),46,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.16,.5),Size=UDim2.fromScale(.24,.62),Visible=false})
 new('UIAspectRatioConstraint',{AspectRatio=1},pad);new('UICorner',{CornerRadius=UDim.new(.5,0)},pad)
 local pl=label(pad,'B',Enum.Font.GothamBlack,WHITE,BLACK,47);pl.Size=UDim2.fromScale(.8,.8);pl.Text='B'
 -- (a keyboard: its Enter key on the left of the pill - R155 review: nothing said that Enter skips)
 local key=frame(b,'Enter key',C(236,236,244),46,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.2,.5),Size=UDim2.fromScale(.32,.6),Visible=false})
 new('UICorner',{CornerRadius=UDim.new(.24,0)},key)
 local kl=label(key,'Enter',Enum.Font.GothamBlack,C(34,28,56),BLACK,47);kl.Size=UDim2.fromScale(.92,.66);kl.Text=Card.EnterLabel
 self.SkipButton,self.SkipWord,self.SkipPad,self.SkipPadText,self.SkipKey,self.SkipKeyText=b,text,pad,pl,key,kl
 self.Input=game:GetService('UserInputService') -- (once: _skip asks it every frame)
end
-- R157: the device's safe area in px (CoreUISafeInsets, kept within the screen itself): its corner ox, oy and its size w, h. vp: the screen's size.
function Card.SafeArea(vp)
 local ox,oy,w,h=0,0,vp.X,vp.Y
 local okA,area=pcall(function()return game:GetService('GuiService'):GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)end)
 if okA and area and area.Width and area.Width>0 and area.Height>0 then -- (never outside the screen itself: a stale or odd safe area)
  ox,oy=math.clamp(area.Min.X,0,vp.X*.25),math.clamp(area.Min.Y,0,vp.Y*.25)
  w,h=math.clamp(area.Width,vp.X*.5,vp.X-ox),math.clamp(area.Height,vp.Y*.5,vp.Y-oy)
 end
 return ox,oy,w,h
end
-- R157: what a story scene's SKIP button keeps clear of: the thumb controls (HudLayout.Controls: {Joystick, Jump} in the safe area) that are really on screen, if any. The
-- scene hides the rest of the HUD, and ControlModule:Disable() (RarePullCinematic.holdControls) hides the controls too, so this is normally nothing: the corner.
function Card.ControlBoxes(controls)
 local list={}
 for _,key in ipairs({'Joystick','Jump'})do
  local c=type(controls)=='table'and controls[key]
  if c and c.W>0 and c.H>0 then list[#list+1]={N=key,X=c.X,Y=c.Y,W=c.W,H=c.H}end
 end
 return list
end
-- (placed again whenever the screen changes size; R157: and for a story scene when it first shows, once the director has hidden the HUD and held the controls)
function Card:_placeSkip(shown)
 local b=self.SkipButton;local cam=workspace.CurrentCamera;local vp=cam and cam.ViewportSize
 if not b or not vp then return end
 local key=shown and 1 or 0
 if vp==self.SkipFor and(key==self.SkipShown or not self.HudHidden)then return end
 self.SkipFor,self.SkipShown=vp,key
 local ox,oy,w,h=Card.SafeArea(vp)
 local touch=game:GetService('UserInputService').TouchEnabled
 local okC,controls=pcall(function()return require(RS:FindFirstChild('HudLayout')).Controls(self.Gui)end) -- (a touch screen's real thumb controls)
 controls=okC and controls or nil
 -- (R157: a story scene has no HUD on screen: the corner, unless a thumb control really is there; a card that leaves the HUD up keeps clear of all of it)
 local boxes=self.HudHidden and Card.ControlBoxes(controls)or Card.SkipBoxes(w,h,touch,controls)
 local x,y,bw,bh=Card.SkipRect(w,h,touch,boxes)
 b.Position=UDim2.fromOffset(ox+x,oy+y);b.Size=UDim2.fromOffset(bw,bh);self.SkipBox={X=ox+x,Y=oy+y,W=bw,H=bh}
end
function Card:_skip(t,tl)
 local b=self.SkipButton;if not b then return end
 local S=self.Set;local hit=tl.Climax or tl.Burst or 0
 local a=clamp01((t-(tl.SkipFrom or math.huge))/.25)*(1-clamp01((t-(hit-.02))/.12))
 local shown=a>.01
 self:_placeSkip(shown)
 S(b,'Visible',shown);if b.Modal~=shown then b.Modal=shown end -- (modal exactly while it shows: the mouse is free for it, and locked again when it goes)
 S(b,'BackgroundTransparency',1-.78*a);S(self.SkipStroke,'Transparency',1-.6*a);S(self.SkipWord,'TextTransparency',1-a)
 -- (a gamepad: its B; else a keyboard: its Enter key - the keys the director answers on the button's behalf)
 local input=self.Input
 local pad=shown and input.GamepadEnabled==true
 local key=shown and not pad and input.KeyboardEnabled==true
 S(self.SkipPad,'Visible',pad);S(self.SkipPad,'BackgroundTransparency',1-a);S(self.SkipPadText,'TextTransparency',1-a)
 S(self.SkipKey,'Visible',key);S(self.SkipKey,'BackgroundTransparency',1-.92*a);S(self.SkipKeyText,'TextTransparency',1-a)
 S(self.SkipWord,'Position',pad and WORD_PAD_AT or key and WORD_KEY_AT or WORD_AT);S(self.SkipWord,'Size',key and WORD_KEY_SIZE or WORD_SIZE)
end
-- R154: the seed flies home (SeedCollect154.Fly): its view leaves the card, which goes on (and fades) without it. Where it is now: its centre and
-- height in shares of the screen, its spin.
function Card:TakeSeed()
 local v=self.View;if not v then return nil end
 self.View=nil
 local scale=self.ViewScale and self.ViewScale.Scale or 1
 return {View=v,Centre=self.SeedCentre,Base=self.SeedBase,Yaw=self.SeedYawShown,X=v.Position.X.Scale,Y=v.Position.Y.Scale,S=v.Size.Y.Scale*scale}
end
-- Texts: title pops in at `inAt`, odds count from `countAt` and slam at `slamAt`, everything fades out between `outAt` and `goneAt`.
function Card:_texts(t,inAt,countAt,slamAt,outAt,goneAt)
 local S,Sc=self.Set,self.Scale
 local out=1-clamp01((t-outAt)/math.max(.01,goneAt-outAt))
 local shown=t>=inAt and out>0
 -- (R152) on the way out the texts and the seed lift a little as they fade (eased in), instead of fading where they stand
 local lift=self.Reduced and 0 or .03*Rules.EaseIn(1-out);self.Lift=lift
 local L=self.Layout
 Sc(self.Title,'Position',.5,L.Title.Y-lift);Sc(self.OddsLabel,'Position',.5,L.Odds.Y-lift);Sc(self.NameLabel,'Position',.5,L.Name.Y-lift)
 local tin=clamp01((t-inAt)/.12)
 S(self.Title,'TextTransparency',shown and 1-tin*out or 1);S(self.Title,'TextStrokeTransparency',shown and 1-(.6*tin*out)or 1)
 local pop=clamp01((t-inAt)/.2)
 S(self.TitleScale,'Scale',self.Reduced and 1 or 1+.7*(1-pop)^3)
 local odds=self.Odds
 if odds and t>=countAt and out>0 then
  local k=clamp01((t-countAt)/math.max(.01,slamAt-countAt))
  S(self.OddsLabel,'Text',Rules.CountText(odds,k))
  S(self.OddsLabel,'TextTransparency',1-clamp01((t-countAt)/.1)*out);S(self.OddsLabel,'TextStrokeTransparency',1-.55*clamp01((t-countAt)/.1)*out)
  -- the slam: up to 1.45x over 25 ms (R152: it jumped there in one frame), then settles
  local up=Rules.Smooth((t-slamAt)/.025);local s=clamp01((t-slamAt-.025)/.18)
  S(self.OddsScale,'Scale',(self.Reduced or t<slamAt)and 1 or 1+.45*up*(1-s)^2)
  S(self.OddsLabel,'TextColor3',t>=slamAt and WHITE:Lerp(self.Tier.Glow,.25+.75*s)or WHITE)
 else S(self.OddsLabel,'TextTransparency',1);S(self.OddsLabel,'TextStrokeTransparency',1)end
 local nk=clamp01((t-slamAt)/.2)*out
 S(self.NameLabel,'TextTransparency',t>=slamAt and 1-nk or 1);S(self.NameLabel,'TextStrokeTransparency',t>=slamAt and 1-.5*nk or 1)
 return shown,out
end
-- Tier dressing of the title (Secret glitch, Cosmic stars / planets, King crown) while it is shown.
function Card:_dress(t,since,alpha)
 local S,Sc=self.Set,self.Scale
 local L=self.Layout;local y=L.Title.Y-(self.Lift or 0)
 if self.Split then
  local jitter=since<.6 and not self.Reduced
  for i,s in ipairs(self.Split)do
   local off=jitter and(math.sin(t*97+i*2)*.006+(i==1 and -.004 or .004))or(i==1 and -.0025 or .0025)
   Sc(s,'Position',.5+off,y+(jitter and math.sin(t*71+i)*.003 or 0));S(s,'TextTransparency',1-alpha*.55);S(s,'Visible',alpha>.01)
  end
  for i,s in ipairs(self.Scan)do
   local on=alpha>.01 and((math.floor(t*12+i*3)%5)==0 or since<.5)and not self.Reduced
   S(s,'Visible',on);Sc(s,'Position',.5+math.sin(t*13+i)*.05,y-L.Title.H*.4+((t*.7+i*.27)%1)*L.Title.H*.8)
  end
 end
 if self.Stars then
  for i,s in ipairs(self.Stars)do
   local a=i*2.1;S(s,'Visible',alpha>.01)
   Sc(s,'Position',.5+math.cos(a)*(.16+.04*(i%3)),y+math.sin(a)*L.Title.H*.75)
   S(s,'BackgroundTransparency',1-alpha*(self.Reduced and .8 or .3+.7*math.abs(math.sin(t*3+i))))
  end
  for i,p in ipairs(self.Planets)do
   local a=(self.Reduced and 0 or t*(.9+.3*i))+i*math.pi;S(p,'Visible',alpha>.01)
   Sc(p,'Position',.5+math.cos(a)*.21,y+math.sin(a)*L.Title.H*.55)
   if self.PlanetImages[i]then S(p,'ImageTransparency',1-alpha)else S(p,'BackgroundTransparency',1-alpha)end
   S(p,'ZIndex',math.sin(a)>0 and 13 or 9)
  end
 end
 if self.Crown then
  local drop=self.Reduced and 1 or 1-(1-clamp01(since/.3))^3
  S(self.Crown,'Visible',alpha>.01);Sc(self.Crown,'Position',.5,y-L.Title.H*(.62+.5*(1-drop)))
  if self.CrownAlpha~=alpha then self.CrownAlpha=alpha;for _,d in ipairs(self.CrownParts)do d.BackgroundTransparency=1-alpha end end
 end
end
function Card:_seed(t,appear,floatEnd,outAt,goneAt)
 if not self.View then return end
 local S,Sc=self.Set,self.Scale
 local out=1-clamp01((t-outAt)/math.max(.01,goneAt-outAt))
 local shown=t>=appear and out>0
 S(self.View,'Visible',shown);S(self.SeedGlow,'Visible',shown);if self.SeedHalo then S(self.SeedHalo,'Visible',shown)end
 if not shown then return end
 local k=clamp01((t-appear)/.2);local f=clamp01((t-appear)/math.max(.05,floatEnd-appear))
 -- (R157: Reduced Motion's seed sits where the floating one comes to rest, Seed.Y + .03, so the fitted card's rows are the same with and without motion)
 local y=self.Layout.Seed.Y+(self.Reduced and .03 or(-.03+.06*Rules.Smooth(f))-.03*Rules.EaseIn(1-out))
 Sc(self.View,'Position',.5,y);Sc(self.SeedGlow,'Position',.5,y)
 S(self.View,'ImageTransparency',1-k*out)
 if self.GlowIsImage then S(self.SeedGlow,'ImageTransparency',1-.6*k*out)else S(self.SeedGlow,'BackgroundTransparency',1-.55*k*out)end
 if self.SeedHalo then Sc(self.SeedHalo,'Position',.5,y);S(self.SeedHalo,'ImageTransparency',1-.65*k*out);S(self.SeedHalo,'Rotation',self.Reduced and 0 or t*30)end
 S(self.ViewScale,'Scale',self.Reduced and 1 or .6+.4*(1-(1-k)^3))
 if self.SeedModel and self.SeedBase then
  local yaw=Rules.SeedYaw(t,self.Reduced)
  if yaw~=self.SeedYawShown then -- (R152 perf: a seed that stands still is not moved again)
   self.SeedYawShown=yaw
   pcall(function()self.SeedModel:PivotTo(CFrame.new(self.SeedCentre)*CFrame.Angles(0,yaw,0)*self.SeedBase)end)
  end
 end
end
-- Ladder: t on the reveal's server clock -------------------------------------------------------------------------------------------------
function Card:UpdateLadder(t,tl)
 local rank=self.Rank;local burst=tl.Burst
 self:_refit()
 local q=clamp01(t/burst)
 if t<burst then
  local color,strength=Rules.Hint(rank,q)
  -- R152: the edges throb on the heartbeats and wobbles you hear (Rules.Beat), not on a free-running pulse
  local beat=self.Reduced and .5 or Rules.Beat(rank,t,self.Quick)
  self:_edges(color,(.06+.05*rank)*strength*(.45+.55*beat)*(self.Lite and .8 or 1))
  self:_motes(q,t,color,#self.Motes>0 and q or 0)
 else
  local a=1-clamp01((t-burst)/.45)
  self:_edges(self.Tier.Hint,(.1+.06*rank)*a);self:_motes(1,t,self.Tier.Hint,0)
 end
 -- (R152: the letterbox eases out over the card's own fade, gone on Length; it used to be cut off at a fifth of its height. R154: a waiting
 -- result lets it go once the seed has floated down, so it never covers the hotbar while it waits)
 local outAt=tl.Wait and tl.FloatEnd or tl.Out;local goneAt=tl.Wait and tl.FloatEnd+.4 or tl.Length
 self:_bars(tl.Letterbox and(t<burst and Rules.Smooth((q-.45)/.3)or 1-Rules.Smooth((t-outAt)/math.max(.05,goneAt-outAt)))*.6 or 0)
 self:_flash(t>=burst and(.18+.08*rank)*(1-clamp01((t-burst)/.28))or 0)
 self:_ring(clamp01((t-burst)/.55),t>=burst and 1 or 0)
 local _,out=self:_texts(t,tl.TitleIn,tl.Count,tl.Odds,tl.Out,tl.Length)
 self:_rays(t,t>=burst and .55*clamp01((t-burst)/.15)*out or 0)
 self:_seed(t,burst,tl.FloatEnd,tl.Out,tl.Length)
 self:_dress(t,t-burst,0)
 self:_fade(0)
 self:_hint(t,tl);self:_skip(t,tl)
end
-- Scene: t on the cinematic's clock ----------------------------------------------------------------------------------------------------
function Card:UpdateScene(t,tl,skipShown)
 local rank=self.Rank;local accent=self.Tier.Theme or self.Tier.Hint
 local barsIn=clamp01(t/.35);local barsOut=clamp01((t-tl.Back)/.4)
 self:_bars(barsIn*(1-barsOut))
 local dim=t<tl.SceneIn and clamp01(t/math.max(.01,tl.Cut))or 0
 self:_edges(accent,.35*dim)
 self:_motes(clamp01(t/math.max(.01,tl.Cut)),t,accent,t<tl.SceneIn and .9*dim or 0)
 -- the fade: to black at the cut, open on the scene; a dip on the silence; to black before the world, open on the world
 local fade=0
 if t>=tl.Cut and t<tl.SceneIn then fade=clamp01((t-tl.Cut)/math.max(.01,tl.SceneIn-tl.Cut-.05))
 elseif t>=tl.SceneIn and t<tl.SceneIn+.3 then fade=1-clamp01((t-tl.SceneIn)/.3)
 elseif tl.Silence and t>=tl.Silence and t<tl.Climax then fade=.35
 elseif t>=tl.FloatEnd and t<tl.Back then fade=clamp01((t-tl.FloatEnd)/math.max(.01,tl.Back-tl.FloatEnd-.05))
 elseif t>=tl.Back then fade=1-clamp01((t-tl.Back)/.35)end
 self:_fade(fade)
 self:_flash(t>=tl.Climax and(1-clamp01((t-tl.Climax-.04)/.36))or 0)
 self:_ring(clamp01((t-tl.Climax)/.7),t>=tl.Climax and .8 or 0)
 local shown,out=self:_texts(t,tl.Climax,tl.Climax+Rules.SceneCountDelay,tl.Odds,tl.FloatEnd,tl.Back-.1)
 self:_rays(t,t>=tl.Climax and .45*out or 0)
 self:_dress(t,t-tl.Climax,shown and(1-clamp01((t-tl.FloatEnd)/math.max(.01,tl.Back-.1-tl.FloatEnd)))*clamp01((t-tl.Climax)/.12)or 0)
 if self.Glitch then
  local S=self.Set
  local on=false
  for _,g in ipairs({.25,tl.Cut,tl.Glitch1,tl.Glitch2,tl.Climax})do if g and t>=g and t<g+.2 then on=true end end
  for i,g in ipairs(self.Glitch)do
   local v=on and not self.Reduced
   S(g,'Visible',v)
   if v then self.Scale(g,'Size',.3+.5*math.abs(math.sin(t*37+i)),.012+.02*math.abs(math.sin(t*53+i*2)));self.Scale(g,'Position',.5+math.sin(t*41+i)*.25,(i*.19+t*3.1)%1)end
  end
 end
 if skipShown~=false then self:_hint(t,tl)elseif self.SkipHint then self.Set(self.SkipHint,'Visible',false)end
 self:_skip(t,tl)
end
-- InPlace: t on the reveal's server clock (or from 0 for a result card) --------------------------------------------------------------------
function Card:UpdateInPlace(t,tl)
 self:_refit()
 local accent=self.Tier.Theme or self.Tier.Hint
 local pre=tl.ResultOnly and 0 or clamp01(t/math.max(.01,tl.Climax))
 -- (R152: before the hit the edges and motes walk the same rarity hint as the pack in the world, as on the ladder; the tier colour
 -- from the first frame told the rarity before the suspense)
 local color=(t<tl.Climax and not tl.ResultOnly)and Rules.Hint(self.Rank,pre)or accent
 self:_edges(color,t<tl.Climax and .22*pre or .22*(1-clamp01((t-tl.Climax)/.6)))
 self:_motes(pre,t,color,t<tl.Climax and .7*pre or 0)
 self:_bars(0);self:_fade(0)
 self:_flash(t>=tl.Climax and .35*(1-clamp01((t-tl.Climax)/.35))or 0)
 self:_ring(clamp01((t-tl.Climax)/.6),t>=tl.Climax and .6 or 0)
 local outAt=tl.Out or tl.FloatEnd -- (R154: a waiting result: Out and Length are far away, the seed still floats down by FloatEnd)
 local shown,out=self:_texts(t,tl.Climax,tl.Climax+.08,tl.Odds,outAt,tl.Length)
 self:_rays(t,0)
 self:_dress(t,t-tl.Climax,shown and out or 0)
 self:_seed(t,tl.Climax,tl.FloatEnd,outAt,tl.Length)
 self:_hint(t,tl);self:_skip(t,tl)
end
function Card:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true;self.Root:Destroy()
 if self.SkipButton then self.SkipButton.Modal=false;self.SkipButton:Destroy()end -- (the mouse lock comes back with it)
end
return Card
