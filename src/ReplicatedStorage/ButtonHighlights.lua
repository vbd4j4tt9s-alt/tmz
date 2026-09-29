-- Shared, event-driven feedback; no idle animation loop and no changes to layout.
local Tween=game:GetService('TweenService');local Gui=game:GetService('GuiService');local H={}
function H.Bind(button)
 if not button:IsA('GuiButton')or button:GetAttribute('ButtonHighlight')==false or button.Name=='Shade'or button.Name=='Backdrop'then return function()end end
 if button:FindFirstChild('InteractionHighlight')then return function()end end
 if (button.BackgroundTransparency or 0)<.95 then require(script.Parent.GuiShine).Attach(button)end
 local stroke=Instance.new('UIStroke');stroke.Name='InteractionHighlight';stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Color=Color3.fromRGB(205,252,255);stroke.Thickness=2.5;stroke.Transparency=1;stroke.Parent=button
 local hovering,focused,pressed=false,false,false;local dead=false;local current;local connections={}
 local function paint()
  if dead then return end
  local active=button.Active and button.Interactable~=false and button:GetAttribute('ButtonHighlight')~=false
  local value=active and((pressed and 0)or((hovering or focused)and .12)or 1)or 1
  if current then current:Cancel()end
  if Gui.ReducedMotionEnabled then stroke.Transparency=value else current=Tween:Create(stroke,TweenInfo.new(pressed and .055 or .13),{Transparency=value});current:Play()end
 end
 local function watch(signal,fn)table.insert(connections,signal:Connect(fn))end
 watch(button.MouseEnter,function()hovering=true;paint()end);watch(button.MouseLeave,function()hovering=false;pressed=false;paint()end)
 watch(button.SelectionGained,function()focused=true;paint()end);watch(button.SelectionLost,function()focused=false;pressed=false;paint()end)
 local function sound()
  if button.Active and button.Interactable~=false and button:GetAttribute('ButtonSound')~=false then require(script.Parent.InteractionAudio).Play(button:GetAttribute('ButtonSound')or'Bubble04')end
 end
 watch(button.Activated,sound)
 local function press(input,value)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonA then pressed=value;paint()end
 end
 watch(button.InputBegan,function(input)press(input,true)end);watch(button.InputEnded,function(input)press(input,false)end)
 watch(button:GetPropertyChangedSignal('Active'),paint);watch(button:GetPropertyChangedSignal('Interactable'),paint);watch(button:GetPropertyChangedSignal('Visible'),function()if not button.Visible then hovering=false;focused=false;pressed=false end;paint()end)
 watch(button:GetAttributeChangedSignal('ButtonHighlight'),paint)
 local function stop()
  if dead then return end;dead=true;if current then current:Cancel()end;for _,c in ipairs(connections)do c:Disconnect()end;stroke:Destroy()
 end
 watch(button.Destroying,stop);return stop
end
function H.Start(playerGui)
 local stops={};local dead=false
 local function attach(item)if not dead and item:IsA('GuiButton')and not stops[item]then stops[item]=H.Bind(item)end end
 for _,item in ipairs(playerGui:GetDescendants())do attach(item)end
 local add=playerGui.DescendantAdded:Connect(attach)
 local remove=playerGui.DescendantRemoving:Connect(function(item)local stop=stops[item];if stop then stops[item]=nil;stop()end end)
 return function()if dead then return end;dead=true;add:Disconnect();remove:Disconnect();for _,stop in pairs(stops)do stop()end;table.clear(stops)end
end
return H
