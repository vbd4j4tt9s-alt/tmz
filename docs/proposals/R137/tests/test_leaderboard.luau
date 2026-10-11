--!nocheck
-- R137 (owner: "i cant seem to scroll down for the leaderboard"): the real LeaderboardClient on the mock. A board in
-- the world with 100 ranks; the camera looks straight at it (screen y = the board's pixel y, so the maths is easy to
-- check). The list scrolls by the ▲ / ▼ buttons, the mouse wheel while pointing at the board (the camera does not zoom
-- then), and click / finger drag; a wall in front of the board blocks it; the thumb follows.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=55;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
-- Mock gaps: RaycastParams, ScreenPointToRay, BindActionAtPriority, JSONDecode.
W.env.RaycastParams={new=function()return {}end}
local blocker=nil
function W.workspace.Raycast(_,origin,direction)return blocker end
local CAS=W.service('ContextActionService');local bound={}
function CAS.BindActionAtPriority(_,name,fn,_,priority,...)bound[name]={Fn=fn,Priority=priority,Inputs={...}}end
function CAS.UnbindAction(_,name)bound[name]=nil end
local rows={};for i=1,100 do rows[i]={u=i==57 and 55 or 1000+i,n='Player '..i,s='$'..(1000-i)..'M'}end
local Http=W.service('HttpService');function Http.JSONDecode(_,raw)return rows end
-- The board: 18 x 26 studs, centre (0,16,0), its Front face (-Z) towards the camera at z = -40.
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local hubF=R.new('Folder');hubF.Name='EconomyHub';hubF.Parent=map
local scenery=R.new('Folder');scenery.Name='GeneratedHubScenery';scenery.Parent=hubF
local model=R.new('Model');model.Name='SpeedBoard';model.Parent=scenery
local board=R.new('Part');board.Name='Board';board.Size=V3(18,26,.7);board.CFrame=CF(0,16,0);board.Parent=model
local display=R.new('SurfaceGui');display.Name='Display';display.Face=R.Enum.NormalId.Front;display.Enabled=true;display.Parent=board
local camera=W.workspace.CurrentCamera
local H=1040
-- Screen point (x, y) -> a ray from the camera through the board point at pixel y (x in studs from the centre).
function camera.ScreenPointToRay(_,x,y)
 local origin=V3(0,16,-40);local target=V3((x-640)/40,29-y/H*26,-.35)
 return {Origin=origin,Direction=(target-origin).Unit}
end
-- The client polls every 5 s in a task.spawn loop; the mock's task.wait does not yield, so give it one that does.
do local T=W.env.task
 W.env.task=setmetatable({
  wait=function(t)local co=coroutine.running();T.delay(t or 0,function()coroutine.resume(co)end);return coroutine.yield()end,
  spawn=function(f,...)local co=coroutine.create(f);local ok,err=coroutine.resume(co,...);if not ok then error(err)end;return co end},{__index=T})
end
local script=R.new('LocalScript');script.Name='LeaderboardClient'
model:SetAttribute('LeaderboardTitle','💨 TOP SPEED');model:SetAttribute('LeaderboardStatus','ok');model:SetAttribute('LeaderboardUpdated',os.time())
model:SetAttribute('LeaderboardRows','[...]')
W.load('LeaderboardClient',script)
R.advance(.1)
local gui=pg:FindFirstChild('Leaderboard_SpeedBoard')
if not check(gui,'the scrollable board is built')then error('no board')end
local list=gui:FindFirstChild('Ranks',true);local rail=gui:FindFirstChild('ScrollRail',true)
local up,down=rail and rail:FindFirstChild('PageUp'),rail and rail:FindFirstChild('PageDown');local thumb=rail and rail:FindFirstChild('Thumb',true)
check(list and up and down and thumb,'▲ / ▼ buttons and a thumb next to the list')
check(list.ScrollingEnabled==false and list.ScrollBarThickness==0,'the list scrolls itself (the thin bar that could not be grabbed is gone)')
local function y()return list.CanvasPosition.Y end
local most=100*100-(H-(150+96+24))
check(y()==0 and thumb.Position.Y.Offset==0,'starts at the top')
-- Buttons
down.Activated:Fire();R.advance(.5)
local afterPage=y()
check(afterPage>500 and afterPage<800,('▼ scrolls a page (%d px)'):format(afterPage))
check(thumb.Position.Y.Offset>0,'the thumb moves down')
up.Activated:Fire();R.advance(.5);check(y()==0,'▲ scrolls back up')
for _=1,30 do down.Activated:Fire();R.advance(.4)end
check(math.abs(y()-most)<1,'▼ stops at the bottom: rank 100 can be reached')
local found=false;for _,d in ipairs(list:GetChildren())do if d.Name=='Rank'and d.Visible then local n=d:FindFirstChild('DisplayName');if n and n.Text=='Player 100'then found=true end end end
check(found,'the 100th rank is on the board')
up.Activated:Fire();R.advance(.5);check(y()<most,'and back up from the bottom')
list.CanvasPosition=R.Vector2.new(0,0);R.advance(.1)
-- Mouse wheel
local wheel=bound.LeaderboardScroll
check(wheel and wheel.Priority==R.Enum.ContextActionPriority.High.Value and wheel.Inputs[1]==R.Enum.UserInputType.MouseWheel,'the mouse wheel is bound above the camera zoom')
local function spin(x,yy,z)return wheel.Fn('LeaderboardScroll',R.Enum.UserInputState.Change,{Position=V3(x,yy,z),UserInputType=R.Enum.UserInputType.MouseWheel})end
local res=spin(640,500,-1);R.advance(.3)
check(res==R.Enum.ContextActionResult.Sink and y()>100,'wheel down over the board scrolls it, and the camera does not zoom')
local at=y();res=spin(640,500,1);R.advance(.3)
check(res==R.Enum.ContextActionResult.Sink and y()<at,'wheel up scrolls back')
at=y();res=spin(1500,500,-1);R.advance(.3)
check(res==R.Enum.ContextActionResult.Pass and y()==at,'off the board the wheel still zooms the camera')
blocker={Instance=R.new('Part'),Position=V3(0,16,-10)};res=spin(640,500,-1);R.advance(.3)
check(res==R.Enum.ContextActionResult.Pass and y()==at,'a wall in front of the board blocks it')
blocker=nil
-- Drag (mouse and finger)
local UIS=W.service('UserInputService')
list.CanvasPosition=R.Vector2.new(0,2000);R.advance(.1)
local press={UserInputType=R.Enum.UserInputType.MouseButton1,Position=V3(640,700,0)}
UIS.InputBegan:Fire(press,true)
UIS.InputChanged:Fire({UserInputType=R.Enum.UserInputType.MouseMovement,Position=V3(640,696,0)},false)
check(y()==2000,'a tiny wobble is a click, not a scroll')
UIS.InputChanged:Fire({UserInputType=R.Enum.UserInputType.MouseMovement,Position=V3(640,400,0)},false)
check(math.abs(y()-2300)<1,('dragging up 300 px moves the list 300 px (%d)'):format(y()))
UIS.InputEnded:Fire(press,false)
UIS.InputChanged:Fire({UserInputType=R.Enum.UserInputType.MouseMovement,Position=V3(640,100,0)},false)
check(math.abs(y()-2300)<1,'letting go stops the drag')
local finger={UserInputType=R.Enum.UserInputType.Touch,Position=V3(640,300,0)}
UIS.InputBegan:Fire(finger,true);finger.Position=V3(640,800,0);UIS.InputChanged:Fire(finger,false)
check(math.abs(y()-1800)<1,('a finger drag down scrolls back up (%d)'):format(y()))
finger.Position=V3(640,3000,0);UIS.InputChanged:Fire(finger,false);check(y()==0,'never past the top')
UIS.InputEnded:Fire(finger,false)
-- FIND ME still works
local jump=gui:FindFirstChild('JumpToMe',true);jump.Activated:Fire();R.advance(.6)
check(math.abs(y()-(56*100-200))<1,'FIND ME jumps to your rank (#57)')
script.Destroying:Fire();check(bound.LeaderboardScroll==nil,'the wheel is released when the script goes')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
