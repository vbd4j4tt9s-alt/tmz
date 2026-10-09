-- R155 (owner: "allow people to discard items"): the confirm popup of the Bag's Discard (InventoryPanel155 opens it; the server decides, InventoryService155).
--  * the item (its picture, its name in its rarity colour) and how many: a stack picks 1, a number (- / + or typed) or All. One item asks nothing more.
--  * "u sure? it's gone forever". Keep it / Discard. A rare item (InventoryStacks155.Rare: Secret / Cosmic / King, a Mech / Verity / Void pack, a Mech /
--    Verity seed or fruit, anything mutated) needs the Discard button HELD for HoldSeconds (its bar fills; letting go early starts it again), so a mis-tap
--    can't throw it away. A gamepad holds A on it.
--  * while the server answers the button says so; a refusal is shown in red and the popup stays; a success closes it.
-- Its own ScreenGui (DiscardConfirm, above the hotbar and the Bag). Silent itself: its buttons are ordinary buttons (ButtonFeedback clicks for them).
local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService');local Run=game:GetService('RunService');local GuiService=game:GetService('GuiService')
local Theme=require(RS:WaitForChild('GardenTheme'));local Pictures=require(RS:WaitForChild('ItemPictures'))
local D={HoldSeconds=1,DisplayOrder=60}
local ui,state,conns=nil,nil,{}
local RED=Color3.fromRGB(255,110,110)
local function corner(p,r)local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,r or 8);c.Parent=p;return c end
local function text(parent,name,t,size,pos,sz,color,bold)
 local l=Instance.new('TextLabel');l.Name=name;l.Text=t;l.BackgroundTransparency=1;l.Position=pos;l.Size=sz;l.Font=bold and Theme.Bold or Theme.Font;l.TextSize=size
 l.TextColor3=color or Color3.new(1,1,1);l.TextWrapped=true;l.ZIndex=62;l.Parent=parent;return l
end
local function btn(parent,name,t,pos,sz,color)
 local b=Instance.new('TextButton');b.Name=name;b.Text=t;b.Position=pos;b.Size=sz;b.BackgroundColor3=color;b.TextColor3=Color3.new(1,1,1);b.Font=Theme.Bold;b.TextSize=16
 b.AutoButtonColor=true;b.ZIndex=63;b.Parent=parent;corner(b,10);return b
end
local function build(pg)
 local gui=Instance.new('ScreenGui');gui.Name='DiscardConfirm';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.DisplayOrder=D.DisplayOrder;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false;gui.Parent=pg
 local shade=Instance.new('TextButton');shade.Name='Shade';shade.Text='';shade.AutoButtonColor=false;shade.BackgroundColor3=Color3.new(0,0,0);shade.BackgroundTransparency=.45;shade.Size=UDim2.fromScale(1,1);shade.ZIndex=60;shade.Parent=gui
 shade:SetAttribute('ButtonSound',false)
 local f=Instance.new('Frame');f.Name='Dialog';f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale(.5,.47);f.Size=UDim2.fromOffset(360,262);f.BackgroundColor3=Color3.fromRGB(20,46,35);f.Active=true;f.ZIndex=61;f.Parent=gui;corner(f,14)
 local st=Instance.new('UIStroke');st.Color=Theme.Colors.Mint;st.Transparency=.4;st.Thickness=1.5;st.Parent=f
 local fit=Instance.new('UISizeConstraint');fit.MaxSize=Vector2.new(360,262);fit.Parent=f
 text(f,'Title','throw it away?',22,UDim2.fromOffset(16,10),UDim2.new(1,-32,0,30),Color3.new(1,1,1),true)
 local pic=Instance.new('Frame');pic.Name='Picture';pic.BackgroundColor3=Color3.fromRGB(37,76,57);pic.Position=UDim2.fromOffset(16,48);pic.Size=UDim2.fromOffset(72,72);pic.ZIndex=62;pic.Parent=f;corner(pic,10)
 local name=text(f,'ItemName','',17,UDim2.fromOffset(98,48),UDim2.new(1,-114,0,40),nil,true);name.TextXAlignment=Enum.TextXAlignment.Left
 local warn=text(f,'Warning',"u sure? it's gone forever",14,UDim2.fromOffset(98,90),UDim2.new(1,-114,0,32),Color3.fromRGB(255,214,140));warn.TextXAlignment=Enum.TextXAlignment.Left
 local row=Instance.new('Frame');row.Name='Amount';row.BackgroundTransparency=1;row.Position=UDim2.fromOffset(16,130);row.Size=UDim2.new(1,-32,0,36);row.ZIndex=62;row.Parent=f
 local tile=Color3.fromRGB(37,76,57)
 btn(row,'One','1',UDim2.fromOffset(0,0),UDim2.fromOffset(44,36),tile)
 btn(row,'Less','-',UDim2.fromOffset(52,0),UDim2.fromOffset(40,36),tile)
 local box=Instance.new('TextBox');box.Name='Count';box.Text='1';box.ClearTextOnFocus=false;box.Position=UDim2.fromOffset(100,0);box.Size=UDim2.new(1,-252,0,36);box.BackgroundColor3=Color3.fromRGB(14,33,25)
 box.TextColor3=Color3.new(1,1,1);box.Font=Theme.Bold;box.TextSize=18;box.ZIndex=63;box.Parent=row;corner(box,8)
 btn(row,'More','+',UDim2.new(1,-144,0,0),UDim2.fromOffset(40,36),tile)
 btn(row,'All','All',UDim2.new(1,-96,0,0),UDim2.fromOffset(96,36),tile)
 local status=text(f,'Status','',13,UDim2.fromOffset(16,170),UDim2.new(1,-32,0,24),RED);status.Visible=false
 local keep=btn(f,'Keep','Keep it',UDim2.new(0,16,1,-62),UDim2.new(.5,-24,0,48),Color3.fromRGB(70,110,86))
 local go=btn(f,'Confirm','Discard',UDim2.new(.5,8,1,-62),UDim2.new(.5,-24,0,48),Color3.fromRGB(196,64,72))
 local fill=Instance.new('Frame');fill.Name='HoldFill';fill.BackgroundColor3=Color3.new(1,1,1);fill.BackgroundTransparency=.62;fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(0,1);fill.ZIndex=64;fill.Active=false;fill.Parent=go;corner(fill,10)
 ui={Gui=gui,Shade=shade,Frame=f,Picture=pic,Name=name,Warning=warn,Row=row,Box=box,Status=status,Keep=keep,Confirm=go,Fill=fill}
 return ui
end
local function amountText()return state.Amount>=state.Max and state.Max>1 and('all '..state.Max)or tostring(state.Amount)end
local function paint()
 if not state then return end
 state.Amount=math.clamp(math.floor(state.Amount),1,state.Max)
 if ui.Box.Text~=tostring(state.Amount)then ui.Box.Text=tostring(state.Amount)end
 ui.Warning.Text=state.Max>1 and("u sure? "..amountText().." of them, gone forever")or"u sure? it's gone forever"
 local busy=state.Busy
 ui.Confirm.Text=busy and'...'or state.Rare and(state.Holding and'keep holding...'or'hold to discard')or(state.Max>1 and'Discard '..state.Amount or'Discard')
 ui.Confirm.AutoButtonColor=not busy
 if not state.Holding then ui.Fill.Size=UDim2.fromScale(0,1)end
end
local stepConn
local function stopHold()if state then state.Holding=nil;state.HoldAt=nil end;if stepConn then stepConn:Disconnect();stepConn=nil end;if ui then ui.Fill.Size=UDim2.fromScale(0,1)end;paint()end
local function confirm()
 if not state or state.Busy then return end
 state.Busy=true;ui.Status.Visible=false;paint()
 local cb=state.OnConfirm;local amount=state.Amount
 task.spawn(function()local ok,err=pcall(cb,amount);if not ok then warn('[R155] discard: '..tostring(err));D.Fail('try again!')end end)
end
local function step()
 if not state or not state.HoldAt then stopHold();return end
 local u=math.clamp((os.clock()-state.HoldAt)/D.HoldSeconds,0,1)
 ui.Fill.Size=UDim2.fromScale(u,1)
 if u>=1 then stopHold();confirm()end
end
local function startHold()
 if not state or not state.Rare or state.Busy or state.Holding then return end
 state.Holding=true;state.HoldAt=os.clock();paint()
 if not stepConn then stepConn=Run.RenderStepped:Connect(step)end
end
local function wire()
 local function on(sig,fn)conns[#conns+1]=sig:Connect(fn)end
 local go=ui.Confirm
 on(go.Activated,function()if state and not state.Rare then confirm()end end)
 on(go.InputBegan,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then startHold()end end)
 if go.MouseButton1Down then on(go.MouseButton1Down,startHold)end
 if go.MouseButton1Up then on(go.MouseButton1Up,function()if state and state.Holding then stopHold()end end)end
 on(go.MouseLeave,function()if state and state.Holding then stopHold()end end)
 on(Input.InputEnded,function(i)
  local t=i.UserInputType
  if state and state.Holding and(t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch or i.KeyCode==Enum.KeyCode.ButtonA)then stopHold()end
 end)
 on(Input.InputBegan,function(i)
  if not state then return end
  if i.KeyCode==Enum.KeyCode.ButtonA and GuiService.SelectedObject==go then startHold()
  elseif i.KeyCode==Enum.KeyCode.Escape or i.KeyCode==Enum.KeyCode.ButtonB then D.Close()end
 end)
 on(ui.Keep.Activated,function()D.Close()end)
 on(ui.Shade.Activated,function()if state and not state.Busy then D.Close()end end)
 local row=ui.Row
 on(row.One.Activated,function()if state then state.Amount=1;paint()end end)
 on(row.All.Activated,function()if state then state.Amount=state.Max;paint()end end)
 on(row.Less.Activated,function()if state then state.Amount-=1;paint()end end)
 on(row.More.Activated,function()if state then state.Amount+=1;paint()end end)
 on(ui.Box.FocusLost,function()if state then state.Amount=tonumber((ui.Box.Text:gsub('%D','')))or state.Amount;paint()end end)
end
-- spec: {Tool=, Name=, Rarity=, Count= (the stack), Rare=bool}; onConfirm(amount) runs in its own thread and answers with D.Done / D.Fail.
function D.Open(pg,spec,onConfirm)
 if not ui then build(pg);wire()end
 if ui.Gui.Parent~=pg then ui.Gui.Parent=pg end
 stopHold()
 state={Tool=spec.Tool,Max=math.max(1,math.floor(tonumber(spec.Count)or 1)),Amount=1,Rare=spec.Rare==true,OnConfirm=onConfirm}
 ui.Name.Text=spec.Name or(spec.Tool and spec.Tool.Name)or'';Theme.RarityText(ui.Name,spec.Rarity or'Common',17,false)
 ui.Name.TextXAlignment=Enum.TextXAlignment.Left
 pcall(Pictures.Show,ui.Picture,spec.Tool,1)
 ui.Row.Visible=state.Max>1;ui.Status.Visible=false;ui.Status.Text=''
 ui.Gui.Enabled=true;paint()
 return ui
end
function D.IsOpen()return state~=nil and ui~=nil and ui.Gui.Enabled end
function D.Close()
 stopHold();state=nil
 if ui then ui.Gui.Enabled=false;pcall(Pictures.Clear,ui.Picture)end
end
function D.Done()D.Close()end
function D.Fail(why)
 if not state then return end
 state.Busy=nil;ui.Status.Text=tostring(why or'try again!');ui.Status.Visible=true;paint()
end
function D.State()return state end
function D.UI()return ui end
function D.Destroy()D.Close();for _,c in ipairs(conns)do c:Disconnect()end;table.clear(conns);if ui then ui.Gui:Destroy();ui=nil end end
return D
