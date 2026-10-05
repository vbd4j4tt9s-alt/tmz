-- R147 (owner): timestamp-driven growth of the Verity plant (same API as MechGrowth; PlantGrowth calls it for def.Verity).
-- "The ball grows into a giant Verity fruit which is just a ball, with leaves at its bottom."
--  * Ball: diameter D = 1.3 + 20.7*s(f) with s(x)=x*x*(3-2x). f is the plant's progress during the first growth, and the
--    slot-1 regrow fraction after the first harvest. It scales about the socket at its bottom, so it always rests on the
--    leaf ring. Colour and material never change. During the first growth it also rises from the ground onto the leaf
--    ring (a seed Ø1.3 sits on the soil, not 1.6 studs above it). Hidden while picked.
--  * Leaves (group 0): each grows from its base, staggered by four, over the first 45% of the growth; after that they stay.
--  * No sprout, bud or stalk pieces: state.Buds / state.Sprout stay empty for PlantVisuals.EndGrowth.
local Rules=require(script.Parent.PlantRules)
local Art=require(script.Parent.VerityPlantArt)
local M={}
local function smooth(x)x=math.clamp(x,0,1);return x*x*(3-2*x)end
M.SeedDiameter=Art.SeedBall;M.FullDiameter=Art.Ball
-- Ball diameter at progress f (0..1), studs at plant scale 1.
function M.Diameter(f)return Art.SeedBall+(Art.Ball-Art.SeedBall)*smooth(f)end
-- Fraction of its full size a leaf has at body progress `body` (leaf number `index` staggers the start).
function M.LeafFactor(body,index)return smooth((body-.02-.03*(index%4))/.45)end
-- Where the ball sits: 0 = on the soil, 1 = on the leaf ring (first growth only; later it is always on the ring).
function M.Lift(body)return body>=1 and 1 or smooth(body/.33)end
local function decals(p)local out={};for _,d in ipairs(p:GetChildren())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
function M.Capture(model,id,def,crop,origin,sockets)
 local art=Art.Get(id)
 local state={Verity=true,Model=model,Id=id,Def=def,Origin=origin,Parts={},Buds={},Sprout={},Sockets=sockets,Scale=Rules.Scale(crop.PlantScale)}
 for _,p in ipairs(model:GetDescendants())do
  -- Every piece built from a spec (even a fully transparent one) moves with its ball or leaf.
  if p:IsA('BasePart')and p:GetAttribute('GrowthForm')~=nil then
   local g=p:GetAttribute('GrowthGroup')or 0;local index=p:GetAttribute('ArtSpecIndex')or 1
   local spec=art.Specs[index];local base=g==0 and spec and spec.base
   table.insert(state.Parts,{Part=p,Frame=origin:ToObjectSpace(p.CFrame),Size=p.Size,Alpha=p.Transparency,Query=p.CanQuery,Group=g,Index=index,
    Base=base and Vector3.new(base[1],base[2],base[3])*state.Scale or nil,Faces=decals(p)})
  end
 end
 return state
end
function M.Apply(state,crop,now,progress)
 local body=progress(crop,state.Def,now)
 local fruit={};local ready={}
 for i=1,state.Def.FruitCount do local _,f=progress(crop,state.Def,now,i);fruit[i]=f;ready[i]=Rules.FruitReady(crop,i,now)end
 -- During the first growth the ball follows the plant's own progress; after the first harvest, its regrow fraction.
 local f=body<1 and body or fruit[1]or 1
 state.Model:SetAttribute('VisualGrowth',body);state.Model:SetAttribute('VisualFruitGrowth',fruit[1]or 0)
 -- Growth takes hours, so most calls change nothing visible: rewrite the parts only when the ball or the leaves moved by
 -- more than 1/2000 of their growth (a 22-stud ball moves 0.01 stud), or when its picked / ready state changed.
 local picked=Rules.IsPicked(crop,1)
 local qf,qb=math.floor(f*2000),math.floor(body*2000)
 if state.QF==qf and state.QB==qb and state.Picked==picked and state.Ready==ready[1]then return body,fruit[1]or 0 end
 state.QF,state.QB,state.Picked,state.Ready=qf,qb,picked,ready[1]
 local k=M.Diameter(f)/Art.Ball
 local anchor=(state.Sockets and state.Sockets[1]or Vector3.new(table.unpack(Art.Socket)))*state.Scale
 local sink=(1-M.Lift(body))*anchor.Y
 for _,r in ipairs(state.Parts)do if r.Part.Parent then
  local p=r.Part;local pos=r.Frame.Position;local factor=1;local alpha=r.Alpha;local hidden=false
  if r.Group>0 then
   factor=k;pos=anchor+(pos-anchor)*k-Vector3.new(0,sink,0)
   hidden=picked
   if hidden then alpha=1 end
  elseif r.Base then
   factor=M.LeafFactor(body,r.Index);pos=r.Base+(pos-r.Base)*factor
   if factor<=.001 then alpha=1 end
  end
  p.Size=Vector3.new(math.max(.01,r.Size.X*factor),math.max(.01,r.Size.Y*factor),math.max(.01,r.Size.Z*factor))
  p.CFrame=state.Origin*(CFrame.new(pos)*r.Frame.Rotation)
  p.Transparency=alpha;p.CanCollide=false
  p.CanQuery=r.Group>0 and ready[r.Group]==true and not hidden and r.Query or false
  for _,d in ipairs(r.Faces)do d.Transparency=(hidden or alpha>=1)and 1 or 0 end -- Verity's face goes with its ball
 end end
 return body,fruit[1]or 0
end
return M
