-- R124: the Forest and Jungle track bushes are big enough to hide in. MapService runs Apply once, after the track
-- stretch, so the bushes are already where they end up. Each 'Bush' grows together with its 'Bush top' about the bush's
-- bottom centre (it stays on the ground) until the whole bush is Height studs tall and at least MinWidth studs across.
-- Both parts stay walk-through and are skipped by raycasts (camera, shovel aim). HideBushClient makes the bush you are in
-- see-through for you and hides other players' names while they are inside one.
local H={Biomes={SUNNY_MEADOW=true,JUNGLE=true},Height=7.5,MinWidth=9,WidthScale={1.2,1.7},HeightScale={1,1.9},Tag='HideBush'}
local Tags=game:GetService('CollectionService')

local function flat(v)return Vector3.new(v.X,0,v.Z)end
-- The 'Bush top' that belongs to this bush: the closest unclaimed one in the same model.
local function topOf(body)
 local best,dist=nil,6
 for _,s in ipairs(body.Parent:GetChildren())do
  if s:IsA('BasePart')and s.Name=='Bush top'and s:GetAttribute('HideBushId')==nil then
   local d=(flat(s.Position)-flat(body.Position)).Magnitude;if d<dist then best,dist=s,d end
  end
 end
 return best
end

function H.Scale(body,top)
 local base=body.CFrame*CFrame.new(0,-body.Size.Y*.5,0) -- bottom centre
 local height=body.Size.Y
 if top then height=math.max(height,base:PointToObjectSpace(top.Position).Y+top.Size.Y*.5)end
 local sy=math.clamp(H.Height/math.max(height,.1),H.HeightScale[1],H.HeightScale[2])
 local sw=math.clamp(H.MinWidth/math.max(math.min(body.Size.X,body.Size.Z),.1),H.WidthScale[1],H.WidthScale[2])
 local s=Vector3.new(sw,sy,sw)
 for _,p in ipairs({body,top})do
  local rel=base:ToObjectSpace(p.CFrame)
  p.Size=p.Size*s
  p.CFrame=base*CFrame.new(rel.Position*s)*rel.Rotation
 end
 return s
end

function H.Apply(map)
 local biomes=map:FindFirstChild('Obby')and map.Obby:FindFirstChild('Biomes')
 if not biomes then return 0 end
 local count=0
 for _,biome in ipairs(biomes:GetChildren())do
  local kind=biome.Name:match('^Biome_%d+_(.+)$')
  local scenery=kind and H.Biomes[kind]and biome:FindFirstChild('GeneratedScenery')
  if scenery then
   for _,body in ipairs(scenery:GetDescendants())do
    if body:IsA('BasePart')and body.Name=='Bush'and body:GetAttribute('HideBushId')==nil then
     local top=topOf(body)
     H.Scale(body,top)
     count+=1
     for _,p in ipairs({body,top})do
      p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
      p:SetAttribute('HideBushId',count);Tags:AddTag(p,H.Tag)
     end
    end
   end
  end
 end
 map:SetAttribute('HideBushes124',count)
 return count
end
return H
