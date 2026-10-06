--!nocheck
-- R153: a closer model of what Roblox does between a finger / the mouse and an item in the hand, on top of the R113 / R150 mock (world.luau + sfx_env.luau).
-- The R152 hotbar tests fired a slot's InputBegan, Activated and UserInputService.InputEnded by hand, in the orders the code expected, and the server was not
-- there at all; this engine derives every event from a pointer at a screen point instead:
--  * layout of EVERY ScreenGui in the PlayerGui (DisplayOrder, render order: children above their parent, siblings by ZIndex then creation), ScreenGui.Enabled,
--    Visible, a ScrollingFrame's canvas and its clipping;
--  * the hit test of the engine: the top GuiObject under the point takes the press when it is Active (a GuiButton is Active unless told otherwise); a non-Active
--    one lets it through; an Active non-button (a backdrop) eats it. Only the button that took the press gets MouseButton1Down; MouseButton1Up goes to the button
--    under the release; Activated only when that is the button pressed (V.anywhere: always, an old engine bug) and the press was no scroll;
--  * Variant: 'began' (InputBegan reaches the button: what R152 assumed), 'nobegan' (a GuiButton keeps its primary press: no InputBegan on it for the mouse
--    button / a touch, its children and frames still get one), 'stale' (the mouse button's InputObject keeps the PRESS position: the release reports it again),
--    'anywhere' (Activated fires on the pressed button wherever it is let go). Order: 'activated first' or 'release first' (Activated against UIS.InputEnded);
--  * screen points: InputObject.Position is in GUI space; MouseButton1Down / Up report SCREEN points (the 58 px top bar included); GuiService:GetGuiInset.
--    Two more variants turn that round: 'objscreen' (InputBegan reaches the button, but InputObject positions include the top bar) and 'nobegan_gui' (no
--    InputBegan on the button and MouseButton1Down / Up report GUI points): the hotbar must learn which it is from the button pressed;
--  * a touch is ONE InputObject for its whole life (Position / UserInputState change); each mouse move is a new MouseMovement InputObject; IsMouseButtonPressed;
--  * a touch that moves vertically inside a ScrollingFrame scrolls it (CanvasPosition) and is no click any more;
--  * the SERVER, a round trip away (S.RTT): a tool the client put in the hand is seen RTT/2 later; a pack is held only after its chip-bag shape is baked
--    (S.Bake s for each pack's first hold: R151 / R152 _holdPack) and only when nothing is being revealed and the player is not carrying / in a chase
--    (else it is sent back to the Backpack with HoldRefused, RTT/2 later); seeds, the shovel and fruit get their model in the hand RTT after the equip; a
--    (fruit: the REAL HeldHarvests builds it on the client when the test could load it: X.RealFruit); a reveal ends with the reward seed handed over by the server (S.Handoff 'empty': only into an empty hand, R153; 'always': R152); a respawn swaps the
--    Backpack and the server hands every tool back, in its own order, 0.25 s later.
return function(W,E,F,opts)
 opts=opts or{}
 local R=W.R;local UIS=W.UIS;local Gui=W.Gui;local V2,V3=R.Vector2.new,R.Vector3.new;local Enum=R.Enum
 local X={Variant=opts.Variant or'began',Order=opts.Order or'activated first',Log={}}
 local INSET=V2(0,58);local SCREEN=V2(1280,720)
 local OBJ=X.Variant=='objscreen'and INSET or V2(0,0) -- what InputObject positions add to a GUI point
 local BTN=X.Variant=='nobegan_gui'and V2(0,0)or INSET -- what MouseButton1Down / Up add
 local NOBEGAN=X.Variant=='nobegan'or X.Variant=='nobegan_gui'
 local function pos(p)return V3(p.X+OBJ.X,p.Y+OBJ.Y,0)end
 Gui.GetGuiInset=function()return INSET,V2(0,0)end
 local Players=W.service('Players');Players.GetPlayerFromCharacter=function(_,c)for _,p in ipairs(Players:GetChildren())do if p:IsA('Player')and p.Character==c then return p end end;return nil end
 local mouseDown,lastType=false,Enum.UserInputType.MouseMovement
 UIS.IsMouseButtonPressed=function(_,t)return t==Enum.UserInputType.MouseButton1 and mouseDown end
 UIS.GetLastInputType=function()return lastType end
 -- layout -------------------------------------------------------------------------------------------------------------------------------------------------
 local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
 local function lay(o,px,py,pw,ph,cx,cy)
  for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
   local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or V2(0,0)
   local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
   local x=px+p.X.Scale*pw+p.X.Offset-a.X*w-cx;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h-cy
   set(c,'AbsoluteSize',V2(w,h));set(c,'AbsolutePosition',V2(x,y))
   local ox,oy=0,0;if c._class=='ScrollingFrame'then local cp=c._props.CanvasPosition or V2(0,0);ox,oy=cp.X,cp.Y end
   lay(c,x,y,w,h,ox,oy)
  end end
 end
 function X.layout()for _,g in ipairs(E.pg:GetChildren())do if g:IsA('ScreenGui')then set(g,'AbsoluteSize',SCREEN);set(g,'AbsolutePosition',V2(0,0));lay(g,0,0,SCREEN.X,SCREEN.Y,0,0)end end end
 function X.frames(n,dt)for _=1,n or 1 do X.layout();W.frames(1,dt)end;X.layout()end
 function X.wait(seconds)X.frames(math.max(1,math.floor(seconds*60+.5)))end
 -- hit test -----------------------------------------------------------------------------------------------------------------------------------------------
 local function inside(o,p)local a,z=o.AbsolutePosition,o.AbsoluteSize;return p.X>=a.X and p.Y>=a.Y and p.X<a.X+z.X and p.Y<a.Y+z.Y end
 local function isButton(o)return o:IsA('GuiButton')end
 local function active(o)local a=o._props.Active;if a==nil then return isButton(o)or o._class=='TextBox'end;return a==true end
 local function drawn(o,list,clip)
  local kids={};for i,c in ipairs(o._children)do if c:IsA('GuiObject')and c._props.Visible~=false then kids[#kids+1]={c,i}end end
  table.sort(kids,function(a,b)local za,zb=a[1]._props.ZIndex or 1,b[1]._props.ZIndex or 1;if za~=zb then return za<zb end;return a[2]<b[2]end)
  for _,k in ipairs(kids)do local c=k[1];list[#list+1]={Obj=c,Clip=clip};drawn(c,list,c._class=='ScrollingFrame'and c or clip)end
 end
 function X.at(p) -- every GuiObject under p, the top one first
  local guis={};for i,g in ipairs(E.pg:GetChildren())do if g:IsA('ScreenGui')and g._props.Enabled~=false then guis[#guis+1]={g,i}end end
  table.sort(guis,function(a,b)local da,db=a[1]._props.DisplayOrder or 0,b[1]._props.DisplayOrder or 0;if da~=db then return da<db end;return a[2]<b[2]end)
  local list={};for _,g in ipairs(guis)do drawn(g[1],list,nil)end
  local hits={};for i=#list,1,-1 do local r=list[i];if inside(r.Obj,p)and(not r.Clip or inside(r.Clip,p))then hits[#hits+1]=r.Obj end end
  return hits
 end
 function X.target(p) -- the button the engine gives a press at p to (nil: nothing, or an Active non-button ate it), and whether anything Active was hit
  for _,o in ipairs(X.at(p))do if active(o)then if isButton(o)then return o,true end;return nil,true end end
  return nil,false
 end
 local function screen(p)return p.X+BTN.X,p.Y+BTN.Y end
 local function scrollerOf(o)local q=o;while q do if q._class=='ScrollingFrame'then return q end;q=q._parent end end
 -- pointer ------------------------------------------------------------------------------------------------------------------------------------------------
 function X.down(kind,p)
  local MB,TOUCH=Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch
  lastType=kind=='touch'and TOUCH or Enum.UserInputType.MouseMovement
  local input={UserInputType=kind=='touch'and TOUCH or MB,Position=pos(p),UserInputState=Enum.UserInputState.Begin,KeyCode=Enum.KeyCode.Unknown}
  local target,sunk=X.target(p)
  X.cur={Kind=kind,Input=input,Target=target,Start=p,Pos=p,Scroll=target and scrollerOf(target),Scrolling=false}
  if kind=='mouse'then mouseDown=true end
  for _,o in ipairs(X.at(p))do
   if not(NOBEGAN and isButton(o))then o.InputBegan:Fire(input)end
   if active(o)then break end
  end
  if target and target.MouseButton1Down then target.MouseButton1Down:Fire(screen(p))end
  UIS.InputBegan:Fire(input,sunk)
 end
 function X.move(p)
  local c=X.cur;if not c then return end
  local dy=p.Y-c.Pos.Y;c.Pos=p
  if c.Kind=='touch'then c.Input.Position=pos(p);c.Input.UserInputState=Enum.UserInputState.Change;UIS.InputChanged:Fire(c.Input,true)
  else
   if X.Variant~='stale'then c.Input.Position=pos(p)end
   UIS.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=pos(p),UserInputState=Enum.UserInputState.Change},true)
  end
  local s=c.Scroll
  if c.Kind=='touch'and s and s._props.ScrollingEnabled~=false and inside(s,c.Start)then
   if not c.Scrolling and math.abs(p.Y-c.Start.Y)>10 then c.Scrolling=true end
   if c.Scrolling then local cp=s._props.CanvasPosition or V2(0,0);local maxY=math.max(0,((s._props.CanvasSize and s._props.CanvasSize.Y.Offset)or 0)-s.AbsoluteSize.Y)
    local y=math.clamp(cp.Y-dy,0,maxY);if y~=cp.Y then s.CanvasPosition=V2(cp.X,y)end end
  end
 end
 function X.up(p)
  local c=X.cur;if not c then return end;X.cur=nil
  p=p or c.Pos
  if c.Kind=='mouse'then mouseDown=false;if X.Variant~='stale'then c.Input.Position=pos(p)end else c.Input.Position=pos(p)end
  c.Input.UserInputState=Enum.UserInputState.End
  local over=X.target(p)
  local fireActivated=c.Target and c.Target.Parent and not c.Scrolling and(over==c.Target or X.Variant=='anywhere')
  if over and over.MouseButton1Up then over.MouseButton1Up:Fire(screen(p))end
  local function act()if fireActivated then c.Target.Activated:Fire(c.Input,1)end end
  if X.Order=='activated first'then act();UIS.InputEnded:Fire(c.Input,true)else UIS.InputEnded:Fire(c.Input,true);act()end
 end
 function X.center(b,dx,dy)if not b then return V2(-500,-500)end;return V2(b.AbsolutePosition.X+b.AbsoluteSize.X/2+(dx or 0),b.AbsolutePosition.Y+b.AbsoluteSize.Y/2+(dy or 0))end
 -- a gesture: press at the first point, move through the others, let go at the last (frames between the steps when `paced`)
 function X.gesture(kind,points,paced)
  X.down(kind,points[1]);if paced then X.frames(1)end
  for i=2,#points do X.move(points[i]);if paced then X.frames(1)end end
  X.up(points[#points]);X.frames(2)
 end
 function X.tap(kind,b,dx,dy)X.gesture(kind,{X.center(b,dx,dy)})end
 function X.drag(kind,from,to,hold)
  local a,b=X.center(from),X.center(to);X.down(kind,a)
  if hold then X.wait(hold)end
  local n=6;for i=1,n do X.move(V2(a.X+(b.X-a.X)*i/n,a.Y+(b.Y-a.Y)*i/n));X.frames(1)end
  X.up(b);X.frames(2)
 end
 -- the server ---------------------------------------------------------------------------------------------------------------------------------------------
 local S={RTT=opts.RTT or .15,Bake=opts.Bake or 1.5,Handoff=opts.Handoff or'empty',Baked={},Held=nil,Revealing=false,Refused=0,Moves={}};X.S=S
 local player=E.Player
 local function char()return player.Character end
 local function bag()return player:FindFirstChildOfClass('Backpack')end
 local function later(t,f)R.task.delay(t,f)end
 local function bagModel()local c=char();local m=c and c:FindFirstChild('CarriedSeed');return m end
 local function dropBag()local m=bagModel();if m then m:Destroy()end end
 local function makeBag(tool)
  dropBag();local m=R.new('Model');m.Name='CarriedSeed';m:SetAttribute('SeedPackCarry',true);m:SetAttribute('ForTool',tool.Name);m.Parent=char()
 end
 local function refuse(tool,why)
  S.Refused+=1
  later(S.RTT/2,function()local b=bag();if b and tool.Parent==char()then tool:SetAttribute('HoldRefused',why..'@'..R.clock);S.Moves[#S.Moves+1]=tool.Name..' refused '..why;tool.Parent=b end end)
 end
 local function holdPack(tool)
  if tool.Parent~=char()then return end
  if S.Revealing then return refuse(tool,'opening')end
  if player:GetAttribute('ChestChaseSeedCarrying')or player:GetAttribute('ChestChaseRunActive')then return refuse(tool,'busy')end
  local wait=S.Baked[tool:GetAttribute('SeedInventoryId')]and 0 or S.Bake
  later(wait,function()
   S.Baked[tool:GetAttribute('SeedInventoryId')]=true
   if tool.Parent~=char()or S.Revealing then return end
   S.Held=tool;later(S.RTT/2,function()if tool.Parent==char()and S.Held==tool then makeBag(tool)end end)
  end)
 end
 local function visual(tool)
  later(S.RTT,function()if tool.Parent==char()and not tool:FindFirstChild('HandModel')then local m=R.new('Model');m.Name='HandModel';m.Parent=tool end end)
 end
 local links={}
 local function watch(c)
  for _,l in ipairs(links)do l:Disconnect()end;table.clear(links)
  links[#links+1]=c.ChildAdded:Connect(function(t)if not t:IsA('Tool')then return end
   later(S.RTT/2,function()if t:GetAttribute('SeedPackTool')then holdPack(t)elseif t.Parent==c and not(X.RealFruit and t:GetAttribute('HarvestItemTool'))then visual(t)end end)
  end)
  links[#links+1]=c.ChildRemoved:Connect(function(t)if not t:IsA('Tool')then return end
   local m=t:FindFirstChild('HandModel');if m then m:Destroy()end
   if S.Held==t and not S.Revealing then S.Held=nil;later(S.RTT,function()if S.Held==nil and not S.Revealing then dropBag()end end)end
  end)
 end
 watch(char())
 -- the held pack is opened: its reveal plays `duration` s, then it is gone and the reward seed is handed over (S.Handoff)
 function X.reveal(duration,reward)
  local pack=S.Held;local m=bagModel();if not(pack and m)then return false end
  S.Revealing=true;pack.Enabled=false;m:SetAttribute('RevealAt',R.clock)
  later(duration,function()
   S.Revealing=false;S.Held=nil;pack:Destroy();dropBag()
   local seed=reward();seed.Parent=bag()
   later(S.RTT/2,function()
    local c=char();local inHand=c and c:FindFirstChildOfClass('Tool')
    if S.Handoff=='always'or not inHand then
     if inHand then inHand.Parent=bag();S.Moves[#S.Moves+1]=inHand.Name..' -> Backpack (reward hand-off)'end
     seed.Parent=c;S.Moves[#S.Moves+1]=seed.Name..' -> hand (reward hand-off)'
    end
   end)
  end)
  return true
 end
 -- a respawn: new character, new Backpack (the old tools go with it), the server hands the tools back after 0.25 s in ITS order (`remake` builds them;
 -- `between` runs after CharacterRemoving, before the old Backpack goes)
 function X.respawn(remake,between)
  local old,oldBag=player.Character,bag()
  player.CharacterRemoving:Fire(old)
  if between then between()end -- (whatever happens before the old Backpack goes: a refresh with every item still there)
  for _,t in ipairs(old:GetChildren())do if t:IsA('Tool')then t:Destroy()end end
  for _,t in ipairs(oldBag:GetChildren())do t:Destroy()end;oldBag:Destroy();old:Destroy()
  X.frames(2) -- (the client sees the empty hand and Backpack before the new character arrives)
  local nc=R.new('Model');nc.Name=player.Name;nc.Parent=W.workspace;player.Character=nc
  local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=R.CFrame.new(0,3,100);root.Parent=nc
  local nh=R.new('Humanoid');nh.Health=100;nh.Parent=nc
  local nb=R.new('Backpack');nb.Name='Backpack'
  nh.EquipTool=function(_,tool)for _,t in ipairs(nc:GetChildren())do if t:IsA('Tool')then t.Parent=nb end end;tool.Parent=nc end
  nh.UnequipTools=function()for _,t in ipairs(nc:GetChildren())do if t:IsA('Tool')then t.Parent=nb end end end
  if X.onHumanoid then X.onHumanoid(nh)end
  nb.Parent=player;player.CharacterAdded:Fire(nc);watch(nc);S.Held=nil
  X.frames(2)
  later(.25,function()remake(nb)end)
  X.wait(.5)
  return nh,nc,nb
 end
 -- what the player sees in the hand: a pack's bag (not mid-reveal), or the model of anything else
 function X.shown(tool)
  local c=char();if not tool or tool.Parent~=c then return false end
  if tool:GetAttribute('SeedPackTool')then local m=bagModel();return m~=nil and m:GetAttribute('ForTool')==tool.Name and m:GetAttribute('RevealAt')==nil end
  return tool:FindFirstChild('HandModel')~=nil or tool:FindFirstChild('HeldHarvestArt')~=nil
 end
 return X
end
