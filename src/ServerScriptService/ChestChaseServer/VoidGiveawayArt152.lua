-- R152: the Void Pack giveaway's pedestal, in the middle of the hub's plaza (where the Seed Fountain stood). Styled like the market's Fruit of the Hour pedestal (stone plinth, column,
-- capital, a glowing cradle with four prongs, a soft projector beam, lettering on the column; no discs or rings) in Void colours: black obsidian and dark purple with a violet glow.
-- ~32 anchored parts (the stone is solid, the glow and the beam are not), four SurfaceGui plaques, one light, the prompt. Nothing here moves and nothing is per frame.
--  * The pack itself, its glow and particles, and the number are the CLIENT's (VoidGiveawayClient152): a Void Pack built the way the game renders one (SeedPackVisuals.Bag +
--    EclipsePackArt + VoidPackFx), hovering and turning over the cradle; the number as a BillboardGui over it. The server keeps three invisible anchors for them (PackAnchor,
--    SignAnchor, and PromptAnchor for the prompt).
--  * Heights are studs over the plaza's top (`top`): the footing's foot is sunk .26 into it so a plaza that is not there (a different floor) leaves no gap.
--  * No two faces that point the same way share a plane: every layer is a different size, its overhang is at least .1, plaques stand .11 proud of the column, studs and caps
--    rest on a face that points the other way (R149's detector, docs/proposals/R152/tests).
local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('VoidGiveawayRules152'))
local A={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local K=Rules.Scale
local C={Obsidian=RGB(18,12,32),Dark=RGB(44,26,80),Purple=RGB(72,40,130),Violet=RGB(122,70,214),Glow=RGB(178,112,255),Pale=RGB(232,206,255),Ink=RGB(14,9,26)}
A.Colors=C
-- The stone (heights over the plaza top; every size is the first design's times Rules.Scale).
A.Layout={
 Footing={Size=13.2*K,Y0=-.26,Y1=1.3*K},Trim={Size=13.5*K,Y0=1.3*K,Y1=1.6*K},Plinth={Size=9.2*K,Y0=1.6*K,Y1=2.7*K},Stud=.6*K,StudAt=4.0*K,
 Column={Size=5.4*K,Y0=2.7*K,Y1=6.5*K},Plaque={W=4*K,H=1.6*K,D=.12*K,Y=4.55*K,Out=.03*K},Band={Size=5.9*K,Y=5.75*K,H=.32*K},Capital={Size=6.4*K,Y0=6.5*K,Y1=7.4*K},Top={Size=7.2*K,Y0=7.4*K,Y1=7.76*K},
 Glow={Size=3.2*K,Y0=7.76*K,Y1=7.86*K},Prong={R=1.75*K,H=2.0*K,Lean=18,W=.3*K},Pylon={At=5.7*K,Size=1.4*K,Y0=1.3*K,Y1=5.5*K,CapH=.35*K},Beam={D=2.6*K,Alpha=.88},
 PromptY=4.6*K,PromptDistance=19,
}
local function part(parent,name,size,frame,color,material,solid)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=solid==true;p.CanQuery=solid==true;p.CanTouch=false;p.CastShadow=solid==true
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
-- A box by its footprint and its foot / top heights (over y0).
local function slab(parent,name,size,y0,y1,color,material,solid,y)
 return part(parent,name,V(size,y1-y0,size),CF(0,y+(y0+y1)/2,0),color,material,solid)
end
-- An upright cylinder (a Roblox cylinder lies along X: it is turned onto Y).
local function drum(parent,name,diameter,y0,y1,color,material,y)
 local p=part(parent,name,V(y1-y0,diameter,diameter),CF(0,y+(y0+y1)/2,0)*CFrame.Angles(0,0,math.pi/2),color,material,false)
 p.Shape=Enum.PartType.Cylinder;p.CastShadow=false;return p
end
-- Builds the pedestal into `parent` at the plaza centre; `top` = the plaza's top (a number). Returns {Model, Prompt, PackAnchor, SignAnchor, PromptAnchor, Plaques, Light, Parts}.
function A.Build(parent,top)
 local old=parent:FindFirstChild(Rules.ModelName);if old then old:Destroy()end
 local L=A.Layout;local y=top
 local m=Instance.new('Model');m.Name=Rules.ModelName;m.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 m:SetAttribute('VoidGiveaway152',Rules.Version);m:SetAttribute(Rules.Attr.Cap,Rules.Cap);m:SetAttribute(Rules.Attr.State,'Loading')
 local frame=CF(Rules.Center.X,0,Rules.Center.Z)
 local holder=Instance.new('Model');holder.Name='Stone';holder.Parent=m -- (everything is built at the origin, then moved to the plaza in one go: no per-part offsets to get wrong)
 local f=L.Footing
 slab(holder,'Void footing',f.Size,f.Y0,f.Y1,C.Obsidian,Enum.Material.Slate,true,y)
 slab(holder,'Footing trim',L.Trim.Size,L.Trim.Y0,L.Trim.Y1,C.Purple,nil,false,y)
 slab(holder,'Void plinth',L.Plinth.Size,L.Plinth.Y0,L.Plinth.Y1,C.Dark,Enum.Material.Slate,true,y)
 for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
  local s=part(holder,'Plinth stud',V(L.Stud,L.Stud,L.Stud),CF(sx*L.StudAt,y+L.Plinth.Y1+L.Stud/2,sz*L.StudAt)*CFrame.Angles(0,math.rad(45),0),C.Glow,Enum.Material.Neon,false)
  s.CastShadow=false
 end end
 slab(holder,'Void column',L.Column.Size,L.Column.Y0,L.Column.Y1,C.Dark,Enum.Material.Slate,true,y)
 -- the lettering on every face of the column ("FREE VOID PACK", "ALL CLAIMED" when none are left): a dark plate standing .09 proud of the column with a SurfaceGui on it
 local plaques={};local pl=L.Plaque;local half=L.Column.Size/2
 for i,face in ipairs({{0,-1,0},{0,1,math.pi},{1,0,-math.pi/2},{-1,0,math.pi/2}})do
  local p=part(holder,'Column plaque',V(pl.W,pl.H,pl.D),CF(face[1]*(half+pl.Out),y+pl.Y,face[2]*(half+pl.Out))*CFrame.Angles(0,face[3],0),C.Ink,nil,false)
  local gui=Instance.new('SurfaceGui');gui.Name='Lettering';gui.Face=Enum.NormalId.Front;gui.CanvasSize=Vector2.new(500,200);gui.LightInfluence=0;gui.Parent=p
  local t=Instance.new('TextLabel');t.Name='Line1';t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1);t.Font=Enum.Font.FredokaOne;t.TextScaled=true
  t.Text=Rules.Title;t.TextColor3=C.Pale;t.TextStrokeColor3=C.Purple;t.TextStrokeTransparency=.35;t.Parent=gui
  plaques[i]=t
 end
 slab(holder,'Column band',L.Band.Size,L.Band.Y-L.Band.H/2,L.Band.Y+L.Band.H/2,C.Violet,nil,false,y)
 slab(holder,'Void capital',L.Capital.Size,L.Capital.Y0,L.Capital.Y1,C.Obsidian,Enum.Material.Slate,true,y)
 slab(holder,'Capital top',L.Top.Size,L.Top.Y0,L.Top.Y1,C.Violet,nil,true,y)
 local glow=slab(holder,'Cradle glow',L.Glow.Size,L.Glow.Y0,L.Glow.Y1,C.Glow,Enum.Material.Neon,false,y);glow.CastShadow=false
 local pr=L.Prong
 for i=0,3 do
  local a=i*math.pi/2+math.pi/4
  part(holder,'Cradle prong',V(pr.W,pr.H,pr.W),CF(math.cos(a)*pr.R,y+L.Glow.Y0+pr.H/2,math.sin(a)*pr.R)*CFrame.Angles(0,-a,0)*CFrame.Angles(0,0,math.rad(-pr.Lean)),C.Purple,nil,false)
 end
 local py=L.Pylon
 for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
  part(holder,'Corner pylon',V(py.Size,py.Y1-py.Y0,py.Size),CF(sx*py.At,y+(py.Y0+py.Y1)/2,sz*py.At),C.Obsidian,Enum.Material.Slate,true)
  local cap=part(holder,'Pylon cap',V(py.Size*.72,py.CapH,py.Size*.72),CF(sx*py.At,y+py.Y1+py.CapH/2,sz*py.At),C.Glow,Enum.Material.Neon,false);cap.CastShadow=false
 end end
 -- the soft projector beam from the cradle up to the pack's foot (it stops under the pack: nothing stands behind it)
 local packBottom=Rules.PackHeight-Rules.PackSize/2-Rules.PackBob-.3
 local beam=drum(holder,'Projector beam',L.Beam.D,L.Glow.Y1+.05,packBottom,C.Glow,Enum.Material.Neon,y);beam.Transparency=L.Beam.Alpha
 -- invisible anchors: the pack (and the light), the sign, the prompt
 local function anchor(name,height)
  local p=part(m,name,V(.5,.5,.5),CF(0,y+height,0),C.Ink,nil,false);p.Transparency=1;p.CastShadow=false;return p
 end
 local packAnchor=anchor('PackAnchor',Rules.PackHeight)
 local signAnchor=anchor('SignAnchor',Rules.PackHeight+Rules.PackSize/2+Rules.PackBob+Rules.SignGap+Rules.Sign.H/2)
 local promptAnchor=anchor('PromptAnchor',L.PromptY)
 local light=Instance.new('PointLight');light.Name='VoidGlow';light.Color=RGB(170,96,255);light.Range=34;light.Brightness=1.3;light.Shadows=false;light.Parent=packAnchor
 local prompt=Instance.new('ProximityPrompt');prompt.Name='ClaimVoidPack';prompt.ActionText=Rules.PromptAction;prompt.ObjectText=Rules.PromptObject
 prompt.HoldDuration=.4;prompt.MaxActivationDistance=L.PromptDistance;prompt.RequiresLineOfSight=false;prompt.Enabled=false;prompt.Parent=promptAnchor
 -- one move: the whole pedestal to the plaza (parts were built around X 0 / Z 0)
 local count=0
 for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then d.CFrame=frame*d.CFrame;count+=1 end end
 m.PrimaryPart=packAnchor
 m.Parent=parent
 game:GetService('CollectionService'):AddTag(m,Rules.Tag)
 game:GetService('CollectionService'):AddTag(m,'SnowAvoid') -- (R151 blizzard drifts keep off it)
 return{Model=m,Prompt=prompt,PackAnchor=packAnchor,SignAnchor=signAnchor,PromptAnchor=promptAnchor,Plaques=plaques,Light=light,Parts=count}
end
-- The lettering: the title, or "ALL CLAIMED" once none are left (dimmer).
function A.SetPlaque(art,done)
 for _,t in ipairs(art.Plaques)do
  local text=done and Rules.TitleDone or Rules.Title
  if t.Text~=text then t.Text=text end
  t.TextColor3=done and RGB(150,132,184)or C.Pale
 end
 if art.Light then art.Light.Brightness=done and .5 or 1.3 end
end
return A
