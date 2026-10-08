-- R52: reference-style blue frame, planted feet and tall white ranking cards.
local M={Width=18,Height=26}
local Shadow=require(script.Parent.SmallShadow154) -- R154 (lag audit B1): a part under 1.5 studs casts no shadow
function M.Apply(model)
 if not model then return end
 local walk=require(script.Parent.WalkthroughProps90)
 if model:GetAttribute('LandscapeRevision')==52 then walk.Model(model,true);return end
 local board=model:FindFirstChild('Board');local base=model:FindFirstChild('Base')
 if not board or not base then return end
 local ground=base.Position.Y-base.Size.Y/2;local rotation=board.CFrame.Rotation
 local origin=CFrame.new(board.Position.X,ground,board.Position.Z)*rotation
 for _,p in ipairs(model:GetChildren())do if p:IsA('BasePart')and p~=board and p~=base then p:Destroy()end end
 local function part(name,size,offset,color,material)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=origin*CFrame.new(offset);p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanTouch=false;p.Parent=model;return Shadow.Part(p)
 end
 local blue=Color3.fromRGB(69,158,241);local light=Color3.fromRGB(142,215,255)
 base.Size=Vector3.new(24,1.4,10);base.CFrame=origin*CFrame.new(0,.7,0);base.Color=blue
 board.Size=Vector3.new(M.Width,M.Height,.7);board.CFrame=origin*CFrame.new(0,16,0);board.Color=Color3.fromRGB(24,33,45)
 for _,x in ipairs({-10,10})do
  part('Frame column',Vector3.new(2,29,2),Vector3.new(x,16,0),blue)
  part('Front light strip',Vector3.new(.25,25,.16),Vector3.new(x,16,-1.08),light,Enum.Material.Neon)
  part('Planted foot',Vector3.new(5,2.5,8),Vector3.new(x,2.5,0),light)
 end
 for _,y in ipairs({2,30})do part('Blue frame',Vector3.new(22,2,2),Vector3.new(0,y,0),blue)end
 for x=-9,9,3 do
  local stud=part('Top stud',Vector3.new(.4,1.4,1.4),Vector3.new(x,31.2,0),light);stud.Shape=Enum.PartType.Cylinder;stud.CFrame*=CFrame.Angles(0,0,math.pi/2)
 end
 walk.Model(model,true)
 model:SetAttribute('LandscapeRevision',52)
end
return M
