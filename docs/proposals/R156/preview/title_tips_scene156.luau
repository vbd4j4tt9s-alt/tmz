--!nocheck
-- R156 preview data (not a test): the REAL title screen (TitleScreen104, the scratch copy with Style B from patch_title156.py) started on the Roblox mock at a PC / landscape-phone /
-- portrait-phone size, stepped through its own frame function, and its GUI trees (the Shade backdrop + the title content) printed as SCENE lines for headless Chromium.
-- The 3D seed pack (a ViewportFrame in the game) cannot be built on the mock: an ImageLabel stand-in sits where the viewport is (Position .71,.04 / Size .29,.92 of the logo).
-- VIEW (set by run_title_tips156.sh): 'pc' (1920 x 1080), 'land' (844 x 390), 'port' (390 x 844).
-- Frames (all through the real rotation; TitleScreen104.TipOrder picks the tips): tip 1 settled, tip 2 settled (5 s later), tip 3 settled, and the fade-out of a 4th tip at 50%.
-- Prints: SCENE <name><TAB><backdrop json><TAB><title json>      and      TIP <view> <frame> <kind> <alpha of the label> <text>
local W=require('./world');local R=W.R
local dump=require('./dump_tree153')
local V2=R.Vector2.new
local VIEWS={pc={1920,1080,false},land={844,390,true},port={390,844,true}}
local VIEW=VIEW or'pc'
local SW,SH,TOUCH=VIEWS[VIEW][1],VIEWS[VIEW][2],VIEWS[VIEW][3]
-- which tips each view shows: {settled 1, settled 2, settled 3, fading 4} as pieces of their text (TitleTips156 finds them)
local PICKS={
 pc={'mythic packs give','beware the darkened','pyramid','shovel holes'},
 land={'swing the bat','when the lights go out','pyramid','every 10th pack'},
 port={'each friend in ur server','something waits','pyramid','hold E'},
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
local T=W.module('TitleScreen104');local Tips=W.module('TitleTips156')
local function find(piece)
 for i,tip in ipairs(Tips.Tips)do if tip.Text:find(piece,1,true)then return i end end
 error('no tip with: '..piece)
end
local picks=PICKS[VIEW]
local order={find(picks[1]),find(picks[2]),find(picks[3]),find(picks[4])}
for i=1,#Tips.Tips do local used=false;for _,o in ipairs(order)do if o==i then used=true end end;if not used then order[#order+1]=i end end
T.TipOrder=order
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
local function tick(seconds)
 local frame=binds.StealAPackTitle104;assert(frame,'the title did not bind its frame step')
 local n=math.floor(seconds*60+.5)
 for _=1,n do R.advance(1/60);frame(1/60)end
end
local function snap(name,kind)
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
 local bd,sc=dump(backdrop,SW,SH),dump(screen,SW,SH)
 print('SCENE '..name..'\t'..bd..'\t'..sc)
 local alpha=1-(label.TextTransparency or 0)
 print(('TIP %s %s %s alpha=%.2f layout: logo %.0fx%.0f y=%.0f  tip y=%.0f h=%.0f size<=%.0f  button y=%.0f | %s'):format(VIEW,name,kind,alpha,T.Layout(SW,SH).LogoWidth,T.Layout(SW,SH).LogoHeight,T.Layout(SW,SH).LogoY,
  T.Layout(SW,SH).TipY,T.Layout(SW,SH).TipHeight,T.Layout(SW,SH).TipSize,T.Layout(SW,SH).ButtonY,label.Text))
end
local kinds={}
for i,o in ipairs(order)do kinds[i]=Tips.Tips[o].Kind end
-- settle: the reveal (.72 s) and the first tip's fade-in
tick(2.5);snap(VIEW..'_1',kinds[1])
tick(5);snap(VIEW..'_2',kinds[2])
tick(5);snap(VIEW..'_3',kinds[3])
-- the 4th tip, 4.825 s into its 5 s: its fade-out is 50% through (with Reduced Motion there is no fade: it is fully visible)
tick(2.5+5-.175);snap(VIEW..'_fade',kinds[4])
if stop then stop()end
