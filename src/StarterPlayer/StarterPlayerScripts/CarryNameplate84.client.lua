-- Root-relative nameplates do not shake with the 10x carry/run head animation.
local Players=game:GetService('Players');local Run=game:GetService('RunService')
local records={};local elapsed=0
local function clear(character)
 local r=records[character];if not r then return end
 if r.Humanoid.Parent then r.Humanoid.NameDisplayDistance=r.Distance end
 r.Gui:Destroy();records[character]=nil
end
local function step()
 local wanted={};local camera=workspace.CurrentCamera
 for _,player in ipairs(Players:GetPlayers())do
  local c=player.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local root=c and c:FindFirstChild('HumanoidRootPart')
  local carried=c and (c:FindFirstChild('CarriedSeed')or player:GetAttribute('ChestChaseSeedCarrying')==true)
  if not carried and c then for _,v in ipairs(c:GetChildren())do if v:IsA('Tool')and v:GetAttribute('SeedPackTool')then carried=true;break end end end
  if carried and h and root and h.Health>0 and camera and (root.Position-camera.CFrame.Position).Magnitude<140 then
   wanted[c]=true;local r=records[c]
   if not r then
    local gui=Instance.new('BillboardGui');gui.Name='StableCarryName84';gui.Adornee=root;gui.Size=UDim2.fromOffset(230,34);gui.StudsOffsetWorldSpace=Vector3.new(0,math.clamp(h.HipHeight+root.Size.Y/2+1.3,3.2,7),0)
    gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.MaxDistance=100;gui.Parent=c
    local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.Font=Enum.Font.FredokaOne;label.TextSize=19;label.TextXAlignment=Enum.TextXAlignment.Center;label.TextYAlignment=Enum.TextYAlignment.Center;label.TextScaled=true;local fit=Instance.new('UITextSizeConstraint');fit.MinTextSize=11;fit.MaxTextSize=19;fit.Parent=label;label.TextColor3=Color3.new(1,1,1);label.TextStrokeTransparency=.12;label.Parent=gui
    r={Gui=gui,Humanoid=h,Distance=h.NameDisplayDistance,Label=label};records[c]=r
    gui.MaxDistance=math.min(100,math.max(0,r.Distance))
   end
   h.NameDisplayDistance=0;r.Label.Text=h.DisplayName~=''and h.DisplayName or player.DisplayName
  end
 end
 for c in pairs(records)do if not wanted[c]or not c.Parent then clear(c)end end
end
local heartbeat=Run.Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed>=.1 then elapsed=0;step()end end)
script.Destroying:Connect(function()heartbeat:Disconnect();for c in pairs(records)do clear(c)end end)
