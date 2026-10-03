-- R132 (owner): the Fruit of the Hour floats over the market pedestal, turning slowly, with its bonus and time left
-- above it. The fruit is the game's own fruit model (HarvestPresentation). Animated only while the camera is near.
-- R133 (owner: "the fruit is not big enough and the text is obscuring the fruit; the fruit should be the emphasis"):
-- sized and centred on its VISIBLE parts (the model also carries the hidden plant, which made it tiny and off-centre),
-- 4.2 studs, and a small two-line label sits above the fruit instead of over it.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Hour=require(RS:WaitForChild('FruitOfHour'));local Harvest=require(RS:WaitForChild('HarvestPresentation'))
local Geometry=require(RS:WaitForChild('HarvestGeometry'))
local SIZE=4.2;local NEAR=170;local LABEL_GAP=.5;local LABEL_HEIGHT=1.5
local folder=Instance.new('Folder');folder.Name='FruitOfHourDisplay';folder.Parent=workspace
local anchor,model,offset,turn,shownId,retryAt,label,lines=nil,nil,nil,nil,nil,0,nil,{}
local function findAnchor()
 local map=workspace:FindFirstChild('ChestChaseMap');local hub=map and map:FindFirstChild('EconomyHub')
 local stands=hub and hub:FindFirstChild('MerchantStands');local holder=stands and stands:FindFirstChild('FruitOfTheHour')
 return holder and holder:FindFirstChild('FruitAnchor')
end
local function buildLabel()
 local gui=Instance.new('BillboardGui');gui.Name='FruitOfHourLabel';gui.Size=UDim2.fromScale(5.6,LABEL_HEIGHT)
 gui.StudsOffsetWorldSpace=Vector3.new(0,SIZE/2+LABEL_GAP+LABEL_HEIGHT/2,0)
 gui.LightInfluence=0;gui.MaxDistance=120;gui.AlwaysOnTop=false;gui.Parent=folder
 local rows={{'FruitName',Color3.new(1,1,1),0,.56},{'Bonus',Color3.fromRGB(147,255,69),.56,.44}}
 for _,r in ipairs(rows)do
  local t=Instance.new('TextLabel');t.Name=r[1];t.Text='';t.TextColor3=r[2];t.Position=UDim2.fromScale(0,r[3]);t.Size=UDim2.fromScale(1,r[4])
  t.BackgroundTransparency=1;t.Font=Enum.Font.FredokaOne;t.TextScaled=true;t.TextStrokeTransparency=.25;t.TextStrokeColor3=Color3.fromRGB(20,25,40);t.Parent=gui
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
 -- Visible parts only; ScaleTo scales about the pivot, so the visible centre scales about it too.
 local center,box=Geometry.Bounds(m);local biggest=math.max(box.X,box.Y,box.Z)
 local pivot=m:GetPivot().Position
 if biggest>0 then local k=SIZE/biggest;m:ScaleTo(m:GetScale()*k);center=pivot+(center-pivot)*k end
 offset=pivot-center;turn=m:GetPivot().Rotation
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
  local left=math.max(0,math.floor(current.EndsAt-workspace:GetServerTimeNow()))
  lines.FruitName.Text=current.Name or''
  lines.Bonus.Text=('×%.1f  ·  %d:%02d'):format(current.Multiplier,left//60,left%60)
 end
 if not anchor or not model then return end
 local camera=workspace.CurrentCamera
 if camera and(camera.CFrame.Position-anchor.Position).Magnitude>NEAR then return end
 spin=(spin+dt*.7)%(math.pi*2)
 local bob=math.sin(os.clock()*1.6)*.25
 -- Turn about the fruit's visible centre, which floats at the anchor.
 model:PivotTo(CFrame.new(anchor.Position+Vector3.new(0,bob,0))*CFrame.Angles(0,spin,0)*CFrame.new(offset)*turn)
end)
script.Destroying:Connect(function()connection:Disconnect();folder:Destroy()end)
