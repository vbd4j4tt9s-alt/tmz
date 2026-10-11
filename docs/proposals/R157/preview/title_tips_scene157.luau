--!nocheck
-- R157 preview data (not a test; a copy of R156's title_tips_scene156.luau): the REAL title screen (src/ReplicatedStorage/TitleScreen104.lua, with the real TitleTips156) started on the Roblox mock at a PC / landscape-phone /
-- portrait-phone size, stepped through its own frame function at 120 fps, and its GUI trees (the Shade backdrop + the title content) printed as SCENE lines for headless Chromium.
-- The 3D seed pack (a ViewportFrame in the game) cannot be built on the mock: an ImageLabel stand-in sits where the viewport is (Position .71,.04 / Size .29,.92 of the logo).
-- VIEW (set by render_title_tips157.sh): 'pc' (1920 x 1080), 'land' (844 x 390), 'port' (390 x 844).   REDUCED = true runs it with Reduced Motion (and asserts: no fade, no pulse). The line itself is never moved (R157b: no bob), in every frame.
-- Frames, all through the real rotation (TitleScreen104.TipOrder, the title's fixed-order hook, picks the tips): tip 1 settled, tip 2 settled (one Interval later), tip 3 settled, the fade-out of a 4th tip at 50%,
-- and on the PC also tip 1's pulse at its largest (+3%) and its smallest (-3%): a full breath is Tips.PulsePeriod = 1.8 s.
-- Prints: SCENE <name><TAB><backdrop json><TAB><title json>   and   TIP<TAB><frame><TAB><kind><TAB><label alpha><TAB><pulse scale><TAB><moved px (always 0)><TAB><layout json><TAB><label text (RichText)>
--         TIPLINE<TAB><kind><TAB><the line as RichText>  (every tip, in list order: the fit / overlap check reads them)
local W=require('./world');local R=W.R
local dump=require('./dump_tree153')
local V2=R.Vector2.new
local VIEWS={pc={1920,1080,false},land={844,390,true},port={390,844,true}}
local VIEW=VIEW or'pc'
local SW,SH,TOUCH=VIEWS[VIEW][1],VIEWS[VIEW][2],VIEWS[VIEW][3]
-- which tips each view shows: {settled 1, settled 2, settled 3, fading 4} as pieces of their plain text (TitleTips156 finds them)
local PICKS={
 pc={'mythic packs','beware the darkened','pyramid','dig holes'},
 land={'hit thieves','lights go out','pyramid','every 10th pack'},
 port={'friends in your server','something waits','pyramid','hold E'},
}
local REDUCED=REDUCED==true -- (set by the runner for the Reduced Motion check)
W.UIS.TouchEnabled=TOUCH;W.UIS.KeyboardEnabled=not TOUCH;W.UIS.GamepadEnabled=false
W.Gui.MenuIsOpen=false;W.Gui.ReducedMotionEnabled=REDUCED
W.Gui.GetInsetArea=function()return{Min=V2(0,0),Width=SW,Height=SH}end
W.workspace.CurrentCamera.ViewportSize=V2(SW,SH)
rawset(R.Enum.PlayerActions,'GetEnumItems',function()return {}end)
W.service('ReplicatedFirst').RemoveDefaultLoadingScreen=function()end
W.service('Lighting');W.service('ProximityPromptService').Enabled=true;W.service('ContentProvider')
do -- (the mock's buttons have no MouseButton1Down / Up)
 local inew=R.Instance.new
 R.Instance.new=function(class,parent)
  local o=inew(class,parent)
  if class:find('Button')then o._props.MouseButton1Down=R.signal();o._props.MouseButton1Up=R.signal()end
  return o
 end
 W.env.Instance=R.Instance
end
local binds={}
function W.Run.BindToRenderStep(_,name,_,fn)binds[name]=fn end
function W.Run.UnbindFromRenderStep(_,name)binds[name]=nil end
W.service('ContextActionService').BindActionAtPriority=function(_,name,fn)W.actions[name]=fn end
local Players=W.service('Players')
local player=R.new('Player');player.Name='Ann';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local T=W.module('TitleScreen104');local Tips=W.module('TitleTips156');local Today=W.module('TitleScreen104Today') -- (Today = the title before R157: only for the "was ... px" logo sizes)
local function find(piece)
 for i,tip in ipairs(Tips.Tips)do if Tips.Plain(tip.Text):find(piece,1,true)then return i end end
 error('no tip with: '..piece)
end
local picks=PICKS[VIEW]
local order={find(picks[1]),find(picks[2]),find(picks[3]),find(picks[4])}
for i=1,#Tips.Tips do local used=false;for _,o in ipairs(order)do if o==i then used=true end end;if not used then order[#order+1]=i end end
T.TipOrder=order
for i,tip in ipairs(Tips.Tips)do print('TIPLINE\t'..tip.Kind..'\t'..Tips.Line(i))end
local stop=T.Start(player,pg)
local backdrop=pg:FindFirstChild('StealAPackTitleBackdrop');local screen=pg:FindFirstChild('StealAPackTitle')
local group=screen:FindFirstChild('TitleContent')
group.AbsoluteSize=V2(SW,SH) -- (the mock's size is 100 x 40; the title lays out from it)
backdrop.AbsoluteSize=V2(SW,SH);screen.AbsoluteSize=V2(SW,SH)
-- the pack art stand-in, where the title's ViewportFrame would be
local native=group:FindFirstChild('Logo'):FindFirstChild('NativeTitle')
local art=R.new('ImageLabel');art.Name='ForestMythicPack (stand-in)';art.BackgroundTransparency=1;art.Position=R.UDim2.fromScale(.71,.04);art.Size=R.UDim2.fromScale(.29,.92)
art.ImageContent='stand-in';art.Parent=native
local label
local now=0
local DT=1/120
local function at(seconds) -- step the real frame function until `seconds` after the title started
 local frame=binds.StealAPackTitle104;assert(frame,'the title did not bind its frame step')
 local n=math.floor((seconds-now)/DT+.5)
 for _=1,n do R.advance(DT);frame(DT)end
 now+=n*DT
end
local function near(a,b,tol)return math.abs(a-b)<=tol end
local function snap(name,kind,expect)
 for _,root in ipairs({backdrop,screen})do -- (dump_tree153 reads Color3.new for a label that sets no stroke colour; its module has no Color3 global)
  for _,o in ipairs(root:GetDescendants())do
   if o.ClassName=='TextLabel'or o.ClassName=='TextButton'then
    if not o.TextStrokeColor3 then o.TextStrokeColor3=R.Color3.new(0,0,0)end
    if not o.TextColor3 then o.TextColor3=R.Color3.new(0,0,0)end
   end
  end
 end
 label=group:FindFirstChild('TipLine')
 assert(label,'the tip line was not built')
 local L=T.Layout(SW,SH)
 local alpha=1-(label.TextTransparency or 0)
 local scale=label:FindFirstChildOfClass('UIScale').Scale
 local moved=label.Position.Y.Offset-L.TipY
 assert(moved==0 and label.Position.X.Offset==SW/2,'the tip line must never be moved (no bob): '..moved)
 -- the line floats centred in the gap between the logo (with its pack) and the button; its pulse keeps it clear of both (the button grows 3.5% when hovered)
 local logoBottom=L.LogoY+L.LogoHeight/2;local buttonTop=L.ButtonY-L.ButtonHeight/2*1.035
 local gap=buttonTop-logoBottom
 local top=L.TipY-L.TipHeight/2*(1+Tips.PulseAmount);local bottom=L.TipY+L.TipHeight/2*(1+Tips.PulseAmount)
 assert(top>=logoBottom+4 and bottom<=buttonTop-4,('the tip line (%.1f..%.1f) is not clear of the logo (bottom %.1f) and the button (top %.1f)'):format(top,bottom,logoBottom,buttonTop))
 assert(math.abs((L.TipY-logoBottom)-(L.ButtonY-L.ButtonHeight/2-L.TipY))<.01,'the tip line is not vertically centred between the logo and the button')
 if REDUCED then assert(alpha==1 and scale==1,('Reduced Motion: alpha %.2f scale %.3f'):format(alpha,scale))end
 if expect and not REDUCED then
  if expect.scale then assert(near(scale,expect.scale,.004),('%s: pulse scale %.4f, expected %.3f'):format(name,scale,expect.scale))end
  if expect.alpha then assert(near(alpha,expect.alpha,.03),('%s: alpha %.3f, expected %.2f'):format(name,alpha,expect.alpha))end
 end
 local bd,sc=dump(backdrop,SW,SH),dump(screen,SW,SH)
 print('SCENE '..name..'\t'..bd..'\t'..sc)
 local T0=Today.Layout(SW,SH)
 print(('TIP\t%s\t%s\t%.2f\t%.3f\t%.2f\t{"logoW":%.0f,"logoH":%.0f,"logoY":%.0f,"logoBottom":%.0f,"buttonTop":%.0f,"gap":%.0f,"tipY":%.1f,"tipH":%.0f,"tipSize":%.0f,"buttonY":%.0f,"todayLogoW":%.0f,"todayLogoH":%.0f}\t%s'):format(
  name,kind,alpha,scale,moved,L.LogoWidth,L.LogoHeight,L.LogoY,logoBottom,L.ButtonY-L.ButtonHeight/2,L.ButtonY-L.ButtonHeight/2-logoBottom,L.TipY,L.TipHeight,L.TipSize,L.ButtonY,T0.LogoWidth,T0.LogoHeight,label.Text))
end
local kinds={}
for i,o in ipairs(order)do kinds[i]=Tips.Tips[o].Kind end
local I,F=Tips.Interval,Tips.Fade
-- tip 1 settled (the reveal takes .72 s, then the first fade-in); the pulse clock runs from the start, so at 1.5 breaths (2.7 s) it is back at scale 1
local P=Tips.PulsePeriod
at(1.5*P);snap(VIEW..'_1',kinds[1],{scale=1,alpha=1})
if VIEW=='pc'then
 at(1.5*P+P/4);snap('pc_small',kinds[1],{scale=1-Tips.PulseAmount}) -- (1.5 breaths in, the sine is going down:) a quarter of a breath later: the smallest
 at(1.5*P+3*P/4);snap('pc_big',kinds[1],{scale=1+Tips.PulseAmount}) -- three quarters: the largest
end
at(7*P);snap(VIEW..'_2',kinds[2],{scale=1,alpha=1}) -- (a whole number of half breaths after the start: scale 1; 12.6 s, tip 2 has been up 2.6 s)
at(12*P);snap(VIEW..'_3',kinds[3],{scale=1,alpha=1}) -- (21.6 s)
-- the 4th tip, F/2 s before its end: the fade-out is 50% through (with Reduced Motion there is no fade: it is fully visible)
at(4*I-F/2);snap(VIEW..'_fade',kinds[4],{alpha=.5})
if stop then stop()end
