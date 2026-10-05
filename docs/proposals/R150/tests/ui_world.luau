--!nocheck
-- R150 test world for the treadmill bonus UI: the R123 mock world (real modules from rs_bundle) plus
--  * a stepping TweenService (numbers, Color3, UDim2, Vector2 interpolate over the mock clock; Completed fires),
--  * live-listener counting on RunService signals (idle checks) and a wrapper that counts task.delay calls,
--  * UW.rects: absolute rectangles of a GUI tree the way Roblox lays them out (UDim2 against the parent, AnchorPoint, UIScale,
--    rotation about the object's centre as an axis-aligned box), with ClipsDescendants rectangles,
--  * UW.fit: whether a label's text fits its box (Montserrat Black character widths, which are a little wider than GothamBlack, so a
--    pass here is conservative); TextScaled labels are simulated between MinTextSize and MaxTextSize.
local W=require('./world');local R=W.R
local UW={W=W,R=R}
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end
-- Tweens -------------------------------------------------------------------------------------------------------
local active={}
local Tween=W.service('TweenService')
local function lerp(a,b,t)return a+(b-a)*t end
local function mix(kind,a,b,t)
 if kind=='number'then return lerp(a,b,t)end
 if kind=='Color3'then return R.Color3.new(lerp(a.R,b.R,t),lerp(a.G,b.G,t),lerp(a.B,b.B,t))end
 if kind=='UDim2'then return {X={Scale=lerp(a.X.Scale,b.X.Scale,t),Offset=lerp(a.X.Offset,b.X.Offset,t),__type='UDim'},Y={Scale=lerp(a.Y.Scale,b.Y.Scale,t),Offset=lerp(a.Y.Offset,b.Y.Offset,t),__type='UDim'},__type='UDim2'}end
 if kind=='Vector2'then return R.Vector2.new(lerp(a.X,b.X,t),lerp(a.Y,b.Y,t))end
 return t>=1 and b or a
end
UW.tweensCreated=0
function Tween.Create(_,obj,info,props)
 UW.tweensCreated+=1
 local t={Obj=obj,Info=info,Props=props,T=0,Completed=R.signal(),Playing=false}
 function t:Play()
  self.Start={};for k in pairs(self.Props)do self.Start[k]=obj[k]end
  self.T=0;self.Playing=true;table.insert(active,self)
  if (info.Time or 0)<=0 then UW.finish(self)end
 end
 function t:Cancel()
  self.Playing=false;local i=table.find(active,self);if i then table.remove(active,i)end
 end
 return t
end
function UW.finish(t)
 for k,v in pairs(t.Props)do t.Obj[k]=v end
 t.Playing=false;local i=table.find(active,t);if i then table.remove(active,i)end
 t.Completed:Fire()
end
function UW.stepTweens(dt)
 for _,t in ipairs(table.clone(active))do
  if t.Playing then
   t.T+=dt;local a=math.min(1,t.T/math.max(1e-6,t.Info.Time or 0))
   for k,v in pairs(t.Props)do t.Obj[k]=mix(R.typeof(v),t.Start[k],v,a)end
   if a>=1 then UW.finish(t)end
  end
 end
end
function UW.activeTweens()return #active end
function UW.frames(n,dt)
 dt=dt or 1/60
 for _=1,n do UW.stepTweens(dt);W.frames(1,dt)end
end
-- Runs the clock forward (also runs scheduled task.delay callbacks) in steps of dt.
function UW.seconds(s,dt)UW.frames(math.floor(s/(dt or 1/60)+.5),dt)end
-- Listener counting ----------------------------------------------------------------------------------------------------
function UW.live(signal)local n=0;for _,c in ipairs(signal._c)do if c.Connected then n+=1 end end;return n end
function UW.frameListeners()
 local Run=W.Run;return UW.live(Run.RenderStepped)+UW.live(Run.Heartbeat)+UW.live(Run.Stepped)+UW.live(Run.PreSimulation)+UW.live(Run.PostSimulation)
end
-- Counts task.delay / task.defer / task.spawn calls (scheduled work).
UW.delays=0
do
 local delay,defer,spawn=R.task.delay,R.task.defer,R.task.spawn
 R.task.delay=function(...)UW.delays+=1;return delay(...)end
 R.task.defer=function(...)UW.delays+=1;return defer(...)end
 R.task.spawn=function(...)UW.delays+=1;return spawn(...)end
end
-- Live instances below an object (not destroyed).
function UW.count(root)local n=0;for _,d in ipairs(root:GetDescendants())do if not d._destroyed then n+=1 end end;return n end
-- Rectangles --------------------------------------------------------------------------------------------------------------
local GUI={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,CanvasGroup=true,ViewportFrame=true}
local function child(o,class)for _,c in ipairs(o._children)do if c._class==class then return c end end end
UW.child=child
-- Returns a list of {Obj, Path, X, Y, W, H (axis-aligned box incl. rotation), RX, RY, RW, RH (unrotated), Visible (this and every ancestor), Clip}
-- and a by-path map. root = a ScreenGui / BillboardGui of size (W,H).
function UW.rects(root,rootW,rootH)
 local list,byPath={},{}
 local function walk(o,px,py,pw,ph,k,path,visible,clip)
  for _,c in ipairs(o._children)do
   if GUI[c._class]then
    local s,p=c.Size,c.Position;local ap=c.AnchorPoint or{X=0,Y=0}
    local sc=child(c,'UIScale');local own=sc and sc.Scale or 1
    local w=s.X.Scale*pw+s.X.Offset*k;local h=s.Y.Scale*ph+s.Y.Offset*k
    local ax=px+p.X.Scale*pw+p.X.Offset*k;local ay=py+p.Y.Scale*ph+p.Y.Offset*k
    w*=own;h*=own;local x,y=ax-ap.X*w,ay-ap.Y*h
    local rot=math.rad(c.Rotation or 0)
    local bx,by,bw,bh=x,y,w,h
    if rot~=0 then
     -- R150 review: Roblox rotates a GuiObject about its CENTRE, whatever its AnchorPoint (the model used to pivot about the anchor point, which only
     -- agrees for AnchorPoint (.5,.5)): the box is the axis-aligned bounds of the rectangle turned about its own centre
     local cs,sn=math.abs(math.cos(rot)),math.abs(math.sin(rot))
     local ew,eh=w*cs+h*sn,w*sn+h*cs
     bx,by,bw,bh=x+w/2-ew/2,y+h/2-eh/2,ew,eh
    end
    local vis=visible and c.Visible~=false
    local entry={Obj=c,Path=path..'.'..c.Name,X=bx,Y=by,W=bw,H=bh,RX=x,RY=y,RW=w,RH=h,Visible=vis,Clip=clip,Scale=k*own,Name=c.Name}
    list[#list+1]=entry;byPath[entry.Path]=entry
    local nclip=clip
    if c.ClipsDescendants then nclip={X=x,Y=y,W=w,H=h}end
    walk(c,x,y,w,h,k*own,entry.Path,vis,nclip)
   end
  end
 end
 walk(root,0,0,rootW,rootH,1,root.Name,true,nil)
 return list,byPath
end
-- Text width model (Montserrat Black, in em). Unknown ASCII ~.62, non-ASCII (emoji) 1.15.
local EM={A=.81,B=.77,C=.74,D=.83,E=.67,F=.64,G=.77,H=.8,I=.35,J=.57,K=.77,L=.62,M=.95,N=.8,O=.85,P=.74,Q=.85,R=.74,S=.66,T=.65,U=.78,V=.79,W=1.21,X=.76,Y=.71,Z=.69,
 a=.64,b=.7,c=.61,d=.7,e=.65,f=.43,g=.71,h=.7,i=.33,j=.33,k=.7,l=.33,m=1.04,n=.7,o=.68,p=.7,q=.7,r=.46,s=.56,t=.46,u=.7,v=.64,w=.98,x=.65,y=.64,z=.57,
 ['0']=.69,['1']=.42,['2']=.61,['3']=.61,['4']=.71,['5']=.62,['6']=.66,['7']=.65,['8']=.68,['9']=.66,[' ']=.3,['!']=.31,['?']=.61,['.']=.3,[',']=.3,[':']=.3,['%']=.92,
 ["'"]=.25,['-']=.39,['+']=.62,['(']=.38,[')']=.38,['/']=.44,['&']=.78}
function UW.width(text,size)
 local total=0
 for _,cp in utf8.codes(text)do
  local ch=utf8.char(cp)
  if cp>127 then total+=(cp==0xB7 and .34 or 1.15)else total+=EM[ch]or .62 end
 end
 return total*size
end
local function strip(text)return(text:gsub('<[^>]+>',''))end
local LINE=1.12
function UW.lines(text,size,maxW)
 local lines,line=1,''
 for word in text:gmatch('%S+')do
  local candidate=line==''and word or line..' '..word
  if UW.width(candidate,size)<=maxW then line=candidate
  else
   if line~=''then lines+=1 end
   line=word
   while UW.width(line,size)>maxW and #line>1 do -- a word wider than the box breaks
    lines+=1;local cut=math.max(1,math.floor(#line*maxW/UW.width(line,size)));line=line:sub(cut+1)
   end
  end
 end
 return lines
end
-- ok, size, lines. rect = {W,H} of the label.
function UW.fit(label,rect)
 local text=label.Text or''
 if label.RichText then text=strip(text)end
 if text==''then return true,0,0 end
 local constraint=child(label,'UITextSizeConstraint')
 local wrapped=label.TextWrapped==true or label.TextScaled==true
 if label.TextScaled then
  local maxS=constraint and constraint.MaxTextSize or 100;local minS=constraint and constraint.MinTextSize or 1
  for size=maxS,minS,-1 do
   local lines=wrapped and UW.lines(text,size,rect.W)or 1
   if lines*size*LINE<=rect.H+.5 and(wrapped or UW.width(text,size)<=rect.W+.5)and UW.width(text:match('%S+')or'',size)<=rect.W+.5 then return true,size,lines end
  end
  return false,minS,wrapped and UW.lines(text,minS,rect.W)or 1
 end
 local size=label.TextSize
 local lines=wrapped and UW.lines(text,size,rect.W)or 1
 local ok=lines*size*LINE<=rect.H+.5 and(wrapped or UW.width(text,size)<=rect.W+.5)
 return ok,size,lines
end
-- Draw order under ZIndexBehavior.Sibling: does a draw above b? The two branches below their lowest common ancestor are compared: the higher ZIndex wins and
-- a tie goes to the later sibling; a descendant draws above its own ancestor. (This is how a layer inside a panel ends up under or over the panel's other children.)
function UW.drawsAbove(a,b)
 local function chain(o)local list={};while o do table.insert(list,1,o);o=o.Parent end;return list end
 local ca,cb=chain(a),chain(b)
 local i=1;while ca[i]and cb[i]and ca[i]==cb[i]do i+=1 end
 if not ca[i]then return false end
 if not cb[i]then return true end
 local za,zb=ca[i].ZIndex or 1,cb[i].ZIndex or 1
 if za~=zb then return za>zb end
 local siblings=ca[i-1]._children;return table.find(siblings,ca[i])>table.find(siblings,cb[i])
end
-- Does the rectangle of a UW.rects entry (its unrotated RX / RY / RW / RH turned about its centre by its Rotation) touch the box r = {X,Y,W,H}? (separating axes)
function UW.turnedHits(e,r)
 local rot=math.rad(e.Obj.Rotation or 0);local cs,sn=math.cos(rot),math.sin(rot)
 local cx,cy=e.RX+e.RW/2,e.RY+e.RH/2;local pts={}
 for _,d in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}})do local dx,dy=d[1]*e.RW/2,d[2]*e.RH/2;pts[#pts+1]={cx+dx*cs-dy*sn,cy+dx*sn+dy*cs}end
 local corners={{r.X,r.Y},{r.X+r.W,r.Y},{r.X+r.W,r.Y+r.H},{r.X,r.Y+r.H}}
 for _,axis in ipairs({{1,0},{0,1},{cs,sn},{-sn,cs}})do
  local a0,a1,b0,b1=math.huge,-math.huge,math.huge,-math.huge
  for _,p in ipairs(pts)do local v=p[1]*axis[1]+p[2]*axis[2];a0=math.min(a0,v);a1=math.max(a1,v)end
  for _,p in ipairs(corners)do local v=p[1]*axis[1]+p[2]*axis[2];b0=math.min(b0,v);b1=math.max(b1,v)end
  if a1<=b0 or b1<=a0 then return false end
 end
 return true
end
function UW.overlap(a,b,pad)pad=pad or 0;return a.X<b.X+b.W-pad and a.X+a.W>b.X+pad and a.Y<b.Y+b.H-pad and a.Y+a.H>b.Y+pad end
function UW.inside(a,outer,tol)tol=tol or 0;return a.X>=outer.X-tol and a.Y>=outer.Y-tol and a.X+a.W<=outer.X+outer.W+tol and a.Y+a.H<=outer.Y+outer.H+tol end
-- Common client set-up -------------------------------------------------------------------------------------------------
-- Builds a Player / PlayerGui / character, stubs the audio and picture modules and loads the real TreadmillBonusClient.
-- opts.view = {w,h}, opts.touch; opts.realAudio = use the REAL InteractionAudio / RarityRevealAudio / SoundTiming / AudioMixer (Sounds are
-- cold until opts.loadDelay seconds (default .1) after creation or until ContentProvider:PreloadAsync (.05 s); every :Play() is recorded in
-- ctx.Audio.Plays with whether the sound was loaded at that moment).
function UW.boot(opts)
 opts=opts or{}
 local Players=W.service('Players')
 local me=R.new('Player');me.Name='Me';me.UserId=1;me.Parent=Players;Players.LocalPlayer=me
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
 local char=R.new('Model');char.Parent=W.workspace;me.Character=char
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=R.Vector3.new(0,3,0);root.Parent=char
 local head=R.new('Part');head.Name='Head';head.Position=R.Vector3.new(0,4.5,0);head.Parent=char
 W.service('SoundService')
 local view=opts.view or{1280,720}
 if opts.touch then W.UIS.TouchEnabled=true;W.UIS.MouseEnabled=false end
 do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
  if class=='Sound'then
   if opts.realAudio then
    local sound=o;sound.IsLoaded=false;sound.Loaded=R.signal();sound.IsPlaying=false;sound.TimeLength=1;sound.TimePosition=0
    function sound.Play()sound.IsPlaying=true;UW.audio.Plays[#UW.audio.Plays+1]={Name=sound.Name,At=R.clock,Loaded=sound.IsLoaded,Pitch=sound.PlaybackSpeed,Group=sound.SoundGroup,Sound=sound,Volume=sound.Volume}end
    function sound.Stop()sound.IsPlaying=false end
    R.task.delay(opts.loadDelay or .1,function()if not sound._destroyed and not sound.IsLoaded then sound.IsLoaded=true;sound.Loaded:Fire()end end)
   else o.IsLoaded=true;function o.Stop()end;function o.Play()end end
  end
  if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(view[1],view[2])end
  return o end;W.env.Instance=R.Instance end
 UW.audio={Plays={},Preloads={}}
 if opts.realAudio then
  local Content=W.service('ContentProvider')
  function Content.PreloadAsync(_,list)
   UW.audio.Preloads[#UW.audio.Preloads+1]=table.clone(list)
   local items=table.clone(list)
   R.task.delay(.05,function()for _,sound in ipairs(items)do if not sound._destroyed and not sound.IsLoaded then sound.IsLoaded=true;sound.Loaded:Fire()end end end)
  end
 end
 local Rules=W.module('TreadmillBonusRules')
 local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 local remote=R.new('RemoteFunction');remote.Name=Rules.RemoteName;remote.Parent=remotes
 local ctx={Me=me,PG=pg,Root=root,Head=head,Rules=Rules,Remote=remote,Played={},Reveals={},Ticks={},Shown={},Invoked=0,Reply=nil}
 function remote.InvokeServer(_,...)ctx.Invoked+=1
  if ctx.Reply and ctx.Reply.Ok then me:SetAttribute(Rules.Attr.Ready,ctx.Reply.Ready)end
  return ctx.Reply end
 W.stub('ItemPictures',{Show=function(holder,tool)ctx.Shown[#ctx.Shown+1]={Holder=holder,Stage=tool:GetAttribute('Stage'),Variant=tool:GetAttribute('BagVariant')}end,Clear=function()end,Warm=function()end})
 ctx.Audio=UW.audio
 if not opts.realAudio then
  W.stub('InteractionAudio',{Asset=function(k)return k=='MenuClick'and'rbxassetid://116737765668953'or nil end,Play=function(k)ctx.Played[#ctx.Played+1]=k;return true end})
  W.stub('RarityRevealAudio',{Preload=function()ctx.RevealPreloads=(ctx.RevealPreloads or 0)+1 end,Play=function(k,pitch)ctx.Reveals[#ctx.Reveals+1]=k;ctx.RevealPitches=ctx.RevealPitches or{};ctx.RevealPitches[#ctx.Reveals]=pitch;return true end})
  W.stub('AudioMixer',{Route=function()end})
  W.stub('SoundTiming',{Play=function(s)ctx.Ticks[#ctx.Ticks+1]={At=R.clock,Pitch=s.PlaybackSpeed}end})
 end
 W.stub('ClientFxBudget',{Get=function()return ctx.Tier or 3 end})
 local script=R.new('LocalScript');script.Name='TreadmillBonusClient';ctx.Script=script
 W.load('TreadmillBonusClient',script)
 ctx.Hud=pg:FindFirstChild('TreadmillBonusHud');ctx.Overlay=pg:FindFirstChild('TreadmillBonusRoll');ctx.Bar=pg:FindFirstChild('TreadmillBonusProgress')
 ctx.Button=ctx.Hud.BonusRollButton
 function ctx.set(k,v)me:SetAttribute(Rules.Attr[k],v)end
 function ctx.size(w,h)
  ctx.Hud.AbsoluteSize=R.Vector2.new(w,h);ctx.Overlay.AbsoluteSize=R.Vector2.new(w,h)
 end
 return ctx
end
return UW
