do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R79: equip a crop and click/tap a nearby player. No recipient menu or acceptance dialog.
-- R122: the same click/tap/RT gives a held seed pack or seed (inventory items only).
-- R130 (owner): while holding a fruit, seed or pack, the player under the mouse (or the screen centre on a controller)
-- lights up when they are close enough to receive it. Click / tap / RT asks first: "Are you sure you want to give
-- <item> to <player>?" with Give and Cancel. The receiver gets a notice from the server. Hover checks run 12 times a
-- second and only while a giftable item is held.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService')
local Run=game:GetService('RunService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local Remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('FruitGift')
local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI);local Feed=require(RS.NoticeFeed83);local Copy=require(RS.NoticeCopy83);local Audio=require(RS.InteractionAudio)
local RANGE=18;local HOVER_RANGE=250;local SEND_GAP=2.05
local gui=Instance.new('ScreenGui');gui.Name='FruitGifts';gui.ResetOnSpawn=false;gui.DisplayOrder=36;gui.Parent=pg
local status=Instance.new('TextLabel');status.Name='GiftStatus';status.Text='';status.Visible=false;status.AnchorPoint=Vector2.new(.5,0);status.Position=UDim2.new(.5,0,1,-220);status.Size=UDim2.new(.8,0,0,38);status.BackgroundTransparency=1;status.TextWrapped=true;Theme.Text(status,17,true,Theme.Colors.Gold);status.Parent=gui
local serial,last,lastSent=0,-10,-10;local connections={};local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
-- Confirmation popup.
local dialog=Instance.new('Frame');dialog.Name='GiftConfirm';dialog.AnchorPoint=Vector2.new(.5,.5);dialog.Position=UDim2.fromScale(.5,.45);dialog.Size=UDim2.new(.9,0,0,196);dialog.Visible=false;dialog.Active=true;dialog.ZIndex=40;dialog.Parent=gui
Bright.Panel(dialog);local fit=Instance.new('UISizeConstraint');fit.MaxSize=Vector2.new(420,196);fit.Parent=dialog
local title=Instance.new('TextLabel');title.Name='Title';title.Text='🎁 Give item?';title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(14,10);title.Size=UDim2.new(1,-28,0,32);title.ZIndex=41;Bright.Text(title,24);title.Parent=dialog
-- Coloured names need RichText, so this label is styled here rather than by the theme's text fitter (it re-wraps raw text).
local question=Instance.new('TextLabel');question.Name='Question';question.BackgroundTransparency=1;question.Position=UDim2.fromOffset(16,46);question.Size=UDim2.new(1,-32,0,76);question.ZIndex=41
question.Font=Theme.Bold;question.TextColor3=Color3.new(1,1,1);question.TextStrokeColor3=Color3.fromRGB(8,13,24);question.TextStrokeTransparency=.08
question.RichText=true;question.TextWrapped=true;question.TextScaled=true;question.Parent=dialog
local questionSize=Instance.new('UITextSizeConstraint');questionSize.MaxTextSize=19;questionSize.MinTextSize=12;questionSize.Parent=question
local function button(name,caption,x,color)
 local b=Instance.new('TextButton');b.Name=name;b.Text=caption;b.TextSize=20;b.AnchorPoint=Vector2.new(x,1);b.Position=UDim2.new(x,x==0 and 16 or -16,1,-14);b.Size=UDim2.new(.5,-24,0,48);b.ZIndex=42;b.BorderSizePixel=0;b.Parent=dialog
 Bright.Button(b,color);return b
end
local giveButton=button('Give','Give',0,Theme.Colors.Mint);local cancelButton=button('Cancel','Cancel',1,Color3.fromRGB(248,78,106))
-- R150: this dialog has no SeedMenu, so it clicks for itself: MenuClick when it opens, MenuClose when it closes, Bubble06 on Give (the gift is
-- on its way). The two buttons are therefore silent on their own.
giveButton:SetAttribute('ButtonSound',false);cancelButton:SetAttribute('ButtonSound',false)
local glow;local pending;local filtered
local function lastInput()
 local kind=Input:GetLastInputType()
 if kind==Enum.UserInputType.Touch then return'Touch'end
 return tostring(kind):find('Gamepad')and'Gamepad'or'Mouse'
end
-- Returns the held giftable Tool, its inventory id and the remote action.
local function heldItem(character)
 for _,t in ipairs(character and character:GetChildren()or{})do
  if t:IsA('Tool')and t.Enabled then
   if t:GetAttribute('HarvestItemTool')then return t,t:GetAttribute('HarvestInventoryId'),'Give'end
   if t:GetAttribute('SeedPackTool')or t:GetAttribute('GardenSeed')then return t,t:GetAttribute('SeedInventoryId'),'GiveSeed'end
  end
 end
 return nil
end
local function say(message,refused)
 if refused then Audio.Play('Denied')end -- R150: "Get closer", "Hold the item": a refusal clicks Denied
 serial+=1;local current=serial;status.Text=tostring(message or'');status.Visible=status.Text~=''
 task.delay(2.5,function()if gui.Parent and serial==current then status.Text='';status.Visible=false end end)
end
-- The held item when giving is allowed right now (same rules as before).
local function giftable()
 if pg:GetAttribute('SeedMenu')or player:GetAttribute('ChestChaseRunActive')then return nil end
 local character=player.Character;local held,id,action=heldItem(character)
 if action=='GiveSeed'and(player:GetAttribute('ChestChaseSeedCarrying')or player:GetAttribute('ChestChaseQueued'))then return nil end
 if not held or type(id)~='string'then return nil end
 return held,id,action
end
-- The other player under a screen point, and whether they are close enough to receive.
local function playerAt(point)
 local character=player.Character;local camera=workspace.CurrentCamera;if not character or not camera then return nil end
 local ray=camera:ViewportPointToRay(point.X,point.Y)
 if filtered~=character then params.FilterDescendantsInstances={character};filtered=character end
 local result=workspace:Raycast(ray.Origin,ray.Direction*HOVER_RANGE,params);if not result then return nil end
 local node=result.Instance;local target
 while node and node~=workspace do if node:IsA('Model')then target=Players:GetPlayerFromCharacter(node);if target then break end end;node=node.Parent end
 if not target or target==player then return nil end
 return target,character
end
local function inReach(target)
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local other=target and target.Parent and target.Character and target.Character:FindFirstChild('HumanoidRootPart')
 return root~=nil and other~=nil and(root.Position-other.Position).Magnitude<=RANGE
end
-- One local Highlight inside the lit character (it goes away with that character); a new one for a new target.
local function light(target)
 local character=target and target.Character
 if glow and(glow.Parent~=character or not character)then glow:Destroy();glow=nil end
 if not character or glow then return end
 glow=Instance.new('Highlight');glow.Name='GiftTarget';glow.FillColor=Theme.Colors.Gold;glow.FillTransparency=.72
 glow.OutlineColor=Color3.fromRGB(255,244,170);glow.OutlineTransparency=0;glow.DepthMode=Enum.HighlightDepthMode.Occluded
 glow.Adornee=character;glow.Parent=character
end
local function close(quiet)
 if dialog.Visible and not quiet then Audio.Play('MenuClose')end
 pending=nil;dialog.Visible=false
 if GuiService.SelectedObject==giveButton or GuiService.SelectedObject==cancelButton then GuiService.SelectedObject=nil end
end
local function open(target,held,id,action)
 pending={Target=target,Tool=held,Id=id,Action=action}
 local item=held.Name~=''and held.Name or'this item'
 local function esc(s)return(s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'))end
 question.Text=('Give <font color="#FFE547">%s</font> to <font color="#93FF45">%s</font>?'):format(esc(item),esc(target.DisplayName))
 if not dialog.Visible then Audio.Play('MenuClick')end
 dialog.Visible=true;light(target)
 if lastInput()=='Gamepad'then GuiService.SelectedObject=giveButton end
end
local function revealPress()local ok,taken=pcall(function()return require(game:GetService('ReplicatedStorage').RarePullRules).ClaimPress()end);return ok and taken==true end -- R153: a press that skips / closes a pull reveal's card is not the tool's
local function give(point)
 if pending or os.clock()-last<.65 then return end
 local held,id,action=giftable();if not held or revealPress()then return end
 local target=playerAt(point);if not target then return end
 last=os.clock()
 if not inReach(target)then say('Get closer to '..target.DisplayName..' first!',true);return end
 open(target,held,id,action)
end
local function confirm()
 local p=pending;if not p then return end
 -- Matched by inventory id: a refreshed Tool for the same item is still the same gift.
 local held,id,action=giftable()
 if not held or id~=p.Id or action~=p.Action then close(true);say('Hold the item u want to give.',true);return end
 if not p.Target.Parent then close();return end
 if not inReach(p.Target)then close(true);say('Get closer to '..p.Target.DisplayName..' first!',true);return end
 close(true);Audio.Play('Bubble06') -- R150: Give: the dialog closes and the gift goes out on this click
 -- The server accepts one gift every 2 s; a quick second gift is sent as soon as it may be.
 local wait=math.max(0,lastSent+SEND_GAP-os.clock());lastSent=os.clock()+wait
 local function send()Remote:FireServer(action,p.Target.UserId,id)end
 if wait>0 then task.delay(wait,send)else send()end
end
table.insert(connections,giveButton.Activated:Connect(confirm))
table.insert(connections,cancelButton.Activated:Connect(close))
table.insert(connections,Input.InputBegan:Connect(function(input,processed)
 if Input:GetFocusedTextBox()then return end
 if pending and(input.KeyCode==Enum.KeyCode.ButtonB or input.KeyCode==Enum.KeyCode.Escape)then close();return end
 -- The garden's RT action sinks input while a seed is held; it ignores players, so let RT reach here.
 local _,_,action=heldItem(player.Character)
 if processed and not(action=='GiveSeed'and input.KeyCode==Enum.KeyCode.ButtonR2)then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then give(Input:GetMouseLocation())
 elseif input.KeyCode==Enum.KeyCode.ButtonR2 then local camera=workspace.CurrentCamera;if camera then give(camera.ViewportSize*.5)end end
end))
table.insert(connections,Input.TouchTapInWorld:Connect(function(point,processed)if not processed then give(point)end end))
-- Hover: the giftable player under the mouse / screen centre lights up; the popup's player stays lit.
local hoverClock=0
table.insert(connections,Run.RenderStepped:Connect(function(dt)
 hoverClock+=dt;if hoverClock<1/12 then return end;hoverClock=0
 if pending then
  local held,id=giftable()
  if not held or id~=pending.Id or not pending.Target.Parent then close()else light(pending.Target);return end
 end
 local target
 if giftable()then
  local point;local kind=lastInput()
  if kind=='Mouse'and Input.MouseEnabled then point=Input:GetMouseLocation()
  elseif kind=='Gamepad'then local camera=workspace.CurrentCamera;point=camera and camera.ViewportSize*.5 end
  local hit=point and playerAt(point)
  if hit and inReach(hit)then target=hit end
 end
 if target then light(target)elseif glow then light(nil)end
end))
table.insert(connections,Remote.OnClientEvent:Connect(function(action,message,info)
 if action=='Received'then
  -- R131 (owner): the receiver gets a gold notice at the top with a reward chime.
  local text=type(info)=='table'and type(info.From)=='string'and type(info.Item)=='string'and Copy.Gift(info.From,info.Item)
   or(type(message)=='string'and message~=''and Copy.Escape(message))or Copy.Gift('Someone','a gift')
  Feed.Gift(text);return
 end
 if action=='Status'and message~=nil and message~=''then say(message)end
end))
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end;if glow then glow:Destroy()end;gui:Destroy()end)
