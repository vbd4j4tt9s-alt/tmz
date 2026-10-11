do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R158b (owner: "make it so that dropped packs have a highlight and can be seen"). A pack that drops on the track when its carrier is caught, hit or zapped (the
-- server's model DroppedSeed_Stage<N>, attribute DroppedChest; its SeedPacket is tagged BiomeSeedPackVisual) is easy to find for every player:
--   * a Highlight on the pack (white <-> gold outline, pale gold fill), always on top, for the nearest few drops only (DroppedPackLook158b.Limits: 4, 3 in Fast Mode,
--     and never more than ClientFxBudget.HighlightRoom() leaves: Roblox draws 31 at once; every one is handed to ClientFxBudget.TrackHighlight so the track packs give way);
--   * a marker over it (a gold diamond, "DROPPED PACK" and the distance; always on top, the same size from any distance) and a slim beam of light that rises over the walls.
-- Nothing runs on the server: the client reads what the server already makes. Every drop's effects are children of ONE local part in workspace._DroppedPackFx158b, so
-- the pack being taken, expiring (it goes home), being destroyed or streaming out is one Destroy. The frame loop exists only while a drop does.
-- Fast Mode / low graphics: the Highlight stays (3), the marker stays; the beam and the animations (pulse, bob) are off. Reduced Motion: no pulse, no bob.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local Run=game:GetService('RunService')
local CS=game:GetService('CollectionService');local Gui=game:GetService('GuiService')
local L=require(RS:WaitForChild('DroppedPackLook158b'))
local Fx;pcall(function()Fx=require(RS:WaitForChild('ClientFxBudget',10))end)
local V3,CF,U2=Vector3.new,CFrame.new,UDim2.new
local drops,items,stale={},{},{} -- bag -> drop; the ranked drops (reused); drops to remove (reused)
local count,clock,sinceSelect,moving,loop,alive=0,0,L.SelectSeconds,false,nil,true
local folder=Instance.new('Folder');folder.Name=L.Folder;folder.Parent=workspace
local function tierNow()if Fx then local ok,t=pcall(Fx.Get);if ok and type(t)=='number'then return t end end;return 3 end
-- The room left for Highlights (may be negative: every other Highlight, ours included, already adds up to more than Roblox draws; then ours give theirs back first).
local function roomNow()
 if Fx and Fx.HighlightsUsed then local ok,n=pcall(Fx.HighlightsUsed);if ok and type(n)=='number'then return Fx.MaxHighlights-n end end
 if Fx then local ok,n=pcall(Fx.HighlightRoom);if ok and type(n)=='number'then return n end end
 return 0
end
-- Where a drop is and how tall its pack is: the server's Body part (the pack's middle), else the pack's own pivot; the height from the pack's extents (2 .. 40 studs).
local function whereIs(d) -- position, true when it is the Body's
 local host=d.Host;local body=host and(host.PrimaryPart or host:FindFirstChild('Body'))
 if body and body:IsA('BasePart')then return body.Position,true end
 if not d.Bag:FindFirstChildWhichIsA('BasePart',true)then return nil end -- (a model with no parts reports a pivot at the world origin)
 local ok,pivot=pcall(function()return d.Bag:GetPivot()end)
 return ok and pivot and pivot.Position or nil,false
end
local function heightOf(bag)
 local ok,size=pcall(function()return bag:GetExtentsSize()end)
 return math.clamp(ok and size and size.Y or 4,2,40)
end
local function label(parent,name,y,size,color)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Size=U2(1,0,0,size+4);t.Position=U2(0,0,0,y);t.Font=Enum.Font.FredokaOne
 t.TextSize=size;t.TextColor3=color;t.TextStrokeColor3=L.Ink;t.TextStrokeTransparency=0;t.Parent=parent;return t
end
local function makeMarker(d)
 local g=Instance.new('BillboardGui');g.Name='DroppedPackMarker';g.Adornee=d.Anchor;g.AlwaysOnTop=true;g.LightInfluence=0;g.MaxDistance=L.MarkerRange
 -- (the picture is the top half of the 160 x 132 gui; the world point is its middle, so the diamond stands just above it)
 g.Size=UDim2.fromOffset(160,132);g.ResetOnSpawn=false;g.ClipsDescendants=false;g.StudsOffsetWorldSpace=V3(0,d.Up,0)
 label(g,'Title',0,16,Color3.new(1,1,1)).Text='DROPPED PACK'
 d.Away=label(g,'Distance',17,14,L.Gold)
 local gem=Instance.new('Frame');gem.Name='Gem';gem.AnchorPoint=Vector2.new(.5,.5);gem.Position=U2(.5,0,0,50);gem.Size=UDim2.fromOffset(18,18);gem.Rotation=45
 gem.BackgroundColor3=L.Gold;gem.BorderSizePixel=0;gem.Parent=g
 local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,4);round.Parent=gem
 local edge=Instance.new('UIStroke');edge.Color=L.Ink;edge.Thickness=2.5;edge.Parent=gem
 local dot=Instance.new('Frame');dot.Name='Dot';dot.AnchorPoint=Vector2.new(.5,.5);dot.Position=U2(.5,0,.5,0);dot.Size=UDim2.fromOffset(6,6);dot.BackgroundColor3=Color3.new(1,1,1)
 dot.BorderSizePixel=0;dot.Parent=gem
 local dotRound=Instance.new('UICorner');dotRound.CornerRadius=UDim.new(1,0);dotRound.Parent=dot
 g.Parent=d.Anchor;d.Gui=g
end
local function makeBeam(d)
 local a0=Instance.new('Attachment');a0.Name='BeamFoot';a0.CFrame=CF(0,d.Height*.5,0);a0.Parent=d.Anchor
 local a1=Instance.new('Attachment');a1.Name='BeamTop';a1.CFrame=CF(0,L.BeamHeight,0);a1.Parent=d.Anchor
 local b=Instance.new('Beam');b.Name='DroppedPackBeam';b.Attachment0=a0;b.Attachment1=a1;b.Width0=L.BeamFoot;b.Width1=L.BeamTop;b.FaceCamera=true;b.Segments=1
 b.LightEmission=L.BeamEmission;b.LightInfluence=0;b.Color=ColorSequence.new(L.Gold,L.White)
 b.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(L.BeamFade[1][1],L.BeamFade[1][2]),NumberSequenceKeypoint.new(L.BeamFade[2][1],L.BeamFade[2][2]),NumberSequenceKeypoint.new(L.BeamFade[3][1],L.BeamFade[3][2])})
 b.Parent=d.Anchor;d.Beam=b;d.BeamAt={a0,a1}
end
local function makeHighlight(d)
 local h=Instance.new('Highlight');h.Name='DroppedPackHighlight';h.Adornee=d.Bag;h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
 h.FillColor=L.FillColor;h.FillTransparency=L.FillTransparency;h.OutlineColor=moving and L.Pulse(clock)or L.StaticOutline;h.OutlineTransparency=L.OutlineTransparency
 h.Parent=d.Anchor;d.Highlight=h
 if Fx then pcall(Fx.TrackHighlight,h)end -- (counted in the shared 31-Highlight budget: the track packs give way)
end
local function build(d,pos)
 local a=Instance.new('Part');a.Name='DroppedPackFx';a.Size=V3(.2,.2,.2);a.Transparency=1;a.Anchored=true;a.CanCollide=false;a.CanTouch=false;a.CanQuery=false;a.CastShadow=false
 a.CFrame=CF(pos);a.Parent=folder
 d.Anchor=a;d.Pos=pos;d.Height=heightOf(d.Bag);d.Up=d.Height*.5+L.MarkerAbove
end
local function release(d)
 if drops[d.Bag]~=d then return end
 drops[d.Bag]=nil;count-=1
 for _,c in ipairs(d.Conns)do c:Disconnect()end
 if d.Anchor then d.Anchor:Destroy()end
 d.Highlight,d.Beam,d.Gui,d.Anchor=nil,nil,nil,nil
 if count<=0 and loop then loop:Disconnect();loop=nil end
end
local function dispose(item,what)if item[what]then item[what]:Destroy();item[what]=nil end end
-- Who gets what, now (every SelectSeconds and when a drop arrives).
local function choose()
 local camera=workspace.CurrentCamera;local eye=camera and camera.CFrame.Position
 local now=os.clock();local tier=tierNow()
 table.clear(items);table.clear(stale)
 for bag,d in pairs(drops)do
  local host=bag.Parent
  if not alive or not host or not bag:IsDescendantOf(workspace)or host:GetAttribute(L.Attribute)~=true or now-d.Born>L.MaxAge then stale[#stale+1]=d
  else
   if not d.Anchor then
    local pos,fromBody=whereIs(d);if pos then local ok=pcall(build,d,pos);if not ok then stale[#stale+1]=d else d.FromBody=fromBody end end
   elseif not d.FromBody then -- placed from the pack's pivot while its Body had not streamed in: onto the Body now
    local pos,fromBody=whereIs(d);if fromBody then d.Anchor.CFrame=CF(pos);d.Pos=pos;d.FromBody=true end
   end
   if d.Anchor then d.Distance=eye and(eye-d.Pos).Magnitude or 0;d.Held=d.Highlight~=nil;items[#items+1]=d end
  end
 end
 for _,d in ipairs(stale)do release(d)end
 L.Rank(items)
 local held=0;for _,d in ipairs(items)do if d.Highlight then held+=1 end end
 local nH,nB,nM=L.Limits(tier,held,roomNow())
 moving=tier>1 and Gui.ReducedMotionEnabled~=true
 for _,d in ipairs(items)do -- first give back what is over the limit (this frees Highlight room), then make what is new
  if d.Rank>nH then dispose(d,'Highlight')end
  if d.Rank>nB then dispose(d,'Beam');if d.BeamAt then for _,a in ipairs(d.BeamAt)do a:Destroy()end;d.BeamAt=nil end end
  if d.Rank>nM then dispose(d,'Gui');d.Away=nil end
 end
 for _,d in ipairs(items)do
  if d.Rank<=nH and not d.Highlight then makeHighlight(d)end
  if d.Rank<=nB and not d.Beam then makeBeam(d)end
  if d.Rank<=nM and not d.Gui then makeMarker(d)end
  if d.Away then local text=L.Distance(d.Distance);if d.Away.Text~=text then d.Away.Text=text end end
  if moving then d.Still=false
  elseif not d.Still or(d.Highlight and d.Highlight.OutlineColor~=L.StaticOutline)then -- still: the outline in its one colour, the marker at rest (written once, not every tick)
   d.Still=true
   if d.Highlight then d.Highlight.OutlineColor=L.StaticOutline end
   if d.Gui then d.Gui.StudsOffsetWorldSpace=V3(0,d.Up,0)end
  end
 end
end
local function frame(dt)
 clock+=dt;sinceSelect+=dt
 if sinceSelect>=L.SelectSeconds then sinceSelect=0;choose()end
 if not moving then return end
 local color=L.Pulse(clock);local bob=math.sin(clock*2*math.pi/L.BobSeconds)*L.BobStuds
 for i=1,math.min(#items,L.MaxAnimated)do -- (the nearest few; the ranked list is already in order)
  local d=items[i]
  if d.Highlight then d.Highlight.OutlineColor=color end
  if d.Gui then d.Gui.StudsOffsetWorldSpace=V3(0,d.Up+bob,0)end
 end
end
local function remove(bag)local d=drops[bag];if d then release(d)end end
local function add(bag)
 if not alive or drops[bag]or not bag:IsA('Model')then return end
 local host=bag.Parent
 if not host or host:GetAttribute(L.Attribute)~=true then return end -- (a track pack, a carried bag, a catalogue picture: not a dropped one)
 local d={Bag=bag,Host=host,Born=os.clock(),Conns={}}
 drops[bag]=d;count+=1
 table.insert(d.Conns,bag.Destroying:Connect(function()remove(bag)end))
 table.insert(d.Conns,bag.AncestryChanged:Connect(function()if not bag:IsDescendantOf(workspace)then remove(bag)end end))
 if not loop then loop=Run.RenderStepped:Connect(frame)end
 choose();sinceSelect=0
end
for _,bag in ipairs(CS:GetTagged(L.PackTag))do add(bag)end
local conns={CS:GetInstanceAddedSignal(L.PackTag):Connect(add),CS:GetInstanceRemovedSignal(L.PackTag):Connect(remove)}
script.Destroying:Connect(function()
 alive=false;for _,c in ipairs(conns)do c:Disconnect()end
 local all={};for _,d in pairs(drops)do all[#all+1]=d end;for _,d in ipairs(all)do release(d)end
 if loop then loop:Disconnect();loop=nil end;folder:Destroy()
end)
