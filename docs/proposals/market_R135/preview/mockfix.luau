--!nocheck
-- Mock gaps the R132 tests need (Roblox does these natively): Models pivot like Roblox (PrimaryPart, else the stored
-- pivot, else the box centre) and PivotTo moves every part; ScaleTo scales every part about the pivot; a full lookAt.
return function(W)
 local R=W.R;local V3=R.Vector3.new;local Inst=R.Inst
 local partPivot,partGet=Inst.PivotTo,Inst.GetPivot
 function Inst:GetPivot()
  if self._class=='Model'then local pp=self._props.PrimaryPart;if pp then return pp.CFrame end;if self._pivot then return self._pivot end;return(self:GetBoundingBox())end
  return partGet(self)
 end
 function Inst:PivotTo(cf)
  if self._class~='Model'then return partPivot(self,cf)end
  local delta=cf*self:GetPivot():Inverse()
  for _,d in ipairs(self:GetDescendants())do if d:IsA('BasePart')then d.CFrame=delta*d.CFrame end end
  if not self._props.PrimaryPart then self._pivot=cf end
 end
 function Inst:GetScale()return self._scale or 1 end
 function Inst:ScaleTo(k)
  local f=k/(self._scale or 1);self._scale=k;local pivot=self:GetPivot()
  for _,d in ipairs(self:GetDescendants())do if d:IsA('BasePart')then
   local rel=pivot:Inverse()*d.CFrame;d.Size=d.Size*f
   -- Test-only: keep the art-size attribute in step so HarvestGeometry measures the scaled model (Roblox keeps
   -- the attribute as built; the market measures before scaling).
   local art=d:GetAttribute('ArtSize');if art then d:SetAttribute('ArtSize',art*f)end
   d.CFrame=pivot*R.CFrame.new(rel.Position.X*f,rel.Position.Y*f,rel.Position.Z*f)*rel.Rotation
  end end
 end
 R.CFrame.lookAt=function(p,t,up)
  local f=(t-p).Unit;local u0=up or V3(0,1,0)
  if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
  local r=f:Cross(u0).Unit;local u=r:Cross(f)
  return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
 end
 W.env.CFrame=R.CFrame
end
