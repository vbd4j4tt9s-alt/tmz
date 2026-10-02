-- R132 (owner): the Fruit of the Hour floats over the market pedestal, turning slowly, with its bonus and time left
-- above it. The fruit is the game's own fruit model (HarvestPresentation). Animated only while the camera is near.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Hour=require(RS:WaitForChild('FruitOfHour'));local Harvest=require(RS:WaitForChild('HarvestPresentation'))
local SIZE=2.6;local NEAR=170
local folder=Instance.new('Folder');folder.Name='FruitOfHourDisplay';folder.Parent=workspace
local anchor,model,offset,shownId,retryAt,label,lines=nil,nil,nil,nil,0,nil,{}
local function findAnchor()
 local map=workspace:FindFirstChild('ChestChaseMap');local hub=map and map:FindFirstChild('EconomyHub')
 local stands=hub and hub:FindFirstChild('MerchantStands');local holder=stands and stands:FindFirstChild('FruitOfTheHour')
 return holder and holder:FindFirstChild('FruitAnchor')
end
local function buildLabel()
 local gui=Instance.new('BillboardGui');gui.Name='FruitOfHourLabel';gui.Size=UDim2.new(9,40,4.6,26);gui.StudsOffsetWorldSpace=Vector3.new(0,3.4,0)
 gui.LightInfluence=0;gui.MaxDistance=160;gui.AlwaysOnTop=false;gui.Parent=folder
 local rows={{'Title','⭐ FRUIT OF THE HOUR ⭐',Color3.fromRGB(255,229,71),0,.24},{'FruitName','',Color3.new(1,1,1),.24,.32},{'Bonus','',Color3.fromRGB(147,255,69),.56,.24},{'TimeLeft','',Color3.fromRGB(220,235,255),.8,.2}}
 for _,r in ipairs(rows)do
  local t=Instance.new('TextLabel');t.Name=r[1];t.Text=r[2];t.TextColor3=r[3];t.Position=UDim2.fromScale(0,r[4]);t.Size=UDim2.fromScale(1,r[5])
  t.BackgroundTransparency=1;t.Font=Enum.Font.FredokaOne;t.TextScaled=true;t.TextStrokeTransparency=.2;t.TextStrokeColor3=Color3.fromRGB(20,25,40);t.Parent=gui
  lines[r[1]]=t
 end
 return gui
end
local function clearModel()if model then model:Destroy();model=nil end end
local function build(id)
 clearModel()
 local ok,m=pcall(Harvest.Build,{SeedId=id,Mutation='None',Weather='None'})
 if not ok or not m then return false end
 for _,d in ipairs(m:GetDescendants())do
  if d:IsA('BasePart')then d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false;d.CastShadow=false
  elseif d:IsA('BaseScript')then d:Destroy()end
 end
 local _,box=m:GetBoundingBox();local biggest=math.max(box.X,box.Y,box.Z)
 if biggest>0 then m:ScaleTo(m:GetScale()*SIZE/biggest)end
 local center=m:GetBoundingBox();offset=m:GetPivot().Position-center.Position
 m.Name='FruitOfTheHour';m.Parent=folder;model=m;return true
end
local spin,clock=0,0
local connection=Run.RenderStepped:Connect(function(dt)
 clock+=dt
 if clock>=.5 then
  clock=0
  if not anchor or not anchor.Parent then anchor=findAnchor();if label then label.Adornee=anchor end end
  if not anchor then return end
  label=label or buildLabel();label.Adornee=anchor
  local current=Hour.At(workspace:GetServerTimeNow())
  if current.SeedId~=shownId and os.clock()>=retryAt then
   if current.SeedId and build(current.SeedId)then shownId=current.SeedId else retryAt=os.clock()+3 end
  end
  lines.FruitName.Text=current.Name or'';lines.Bonus.Text=('SELLS ×%.1f'):format(current.Multiplier)
  local left=math.max(0,math.floor(current.EndsAt-workspace:GetServerTimeNow()))
  lines.TimeLeft.Text=('%d:%02d left'):format(left//60,left%60)
 end
 if not anchor or not model then return end
 local camera=workspace.CurrentCamera
 if camera and(camera.CFrame.Position-anchor.Position).Magnitude>NEAR then return end
 spin=(spin+dt*.7)%(math.pi*2)
 local bob=math.sin(os.clock()*1.6)*.25
 model:PivotTo(CFrame.new(anchor.Position+Vector3.new(0,bob,0))*CFrame.Angles(0,spin,0)*CFrame.new(offset))
end)
script.Destroying:Connect(function()connection:Disconnect();folder:Destroy()end)
