-- R150 (owner: "polish the pack pedestal that players have in base"): the shape of the daily mystery pack pedestal (MysteryPackService owns what it
-- does). A chunky cartoon altar in the game's own style: a round paved apron, a slate plinth with four gem posts at its corners, a stepped base with
-- a gold trim, a column with gold collars and a waist ring, a cup in the biome's accent colour, a slate top with a gold rim and a glowing pad under
-- the floating pack. About 30 static parts, built once per base (no scripts, no per-frame work, nothing to stream: the whole model is Persistent).
--  * Colour: the biome of the pack (the best treadmill's) in the TREADMILL's own theme colours (MysteryPackRules.Palette: Body / Trim / Ink, and the body's
--    surface material); with no owner the violet "mystery" colours. Gold is always gold. Tint repaints only the themed parts, and only when the state or the biome changes.
--  * Light: the glow pad and the four gems are the lit parts: calm violet while Locked, bright gold when Ready, a dim mint ember once Taken, a cold
--    grey-violet when nobody is home (MysteryPackRules.StateLook). The client adds the moving parts (MysteryPedestalFx) around the same frame.
--  * Space: everything stays inside a 9.2 x 9.2 plinth (14.4 across for the flat apron) at pad-space X 34, Z 75, well inside the empty corner (clear of
--    the entrance aisle, the tool boxes and the treadmill: tests/R150/test_pedestal_look). Surfaces that face the same way are never within .02 stud
--    of each other (tools/zfight.py): every layer's top differs from the next layer's top, and a part resting on another meets it face to face.
--  * Collision: four solid parts (plinth, step, column, top), the rest is for show: CanCollide and CanQuery off, CanTouch off, no shadows.
local Rules=require(game:GetService('ReplicatedStorage').MysteryPackRules)
local A={}
local RGB=Color3.fromRGB
local function c3(t)return RGB(t[1],t[2],t[3])end
local function part(parent,name,size,frame,color,material,solid)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=solid==true;p.CanQuery=solid==true;p.CanTouch=false;p.CastShadow=solid==true
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
-- A round part standing up: height first (a Cylinder part runs along its X axis).
local function disc(parent,name,height,diameter,frame,color,material,solid)
 local p=part(parent,name,Vector3.new(height,diameter,diameter),frame*CFrame.Angles(0,0,math.pi/2),color,material,solid)
 p.Shape=Enum.PartType.Cylinder;return p
end
local function ball(parent,name,diameter,frame,color,material)
 local p=part(parent,name,Vector3.new(diameter,diameter,diameter),frame,color,material);p.Shape=Enum.PartType.Ball;return p
end
-- parent: the pedestal Model; o: the CFrame of the pedestal's centre on the pad. Returns what Tint repaints.
function A.Build(parent,o)
 local h={Body={},Ink={},Trim={},Mix={},Lit={}}
 local gold=c3(Rules.Gold);local slate=RGB(105,117,106)
 local function y(n)return o*CFrame.new(0,n,0)end
 -- the apron: a paved round plate, slate like the treadmill's apron, with a lighter inlay
 disc(parent,'Apron',.14,14.4,y(.07),slate,Enum.Material.Slate)
 local inlay=disc(parent,'Apron inlay',.05,12,y(.165),slate,Enum.Material.Slate);h.Mix[#h.Mix+1]=inlay
 local plinth=part(parent,'Plinth',Vector3.new(9.2,.5,9.2),y(.25),slate,Enum.Material.Slate,true);h.Ink[#h.Ink+1]=plinth
 local step=disc(parent,'Step',.7,8.2,y(.85),slate,nil,true);h.Body[#h.Body+1]=step
 disc(parent,'Step trim',.16,8.7,y(1.28),gold)
 disc(parent,'Lower collar',.45,5.6,y(1.585),gold)
 local column=disc(parent,'Column',3,4.2,y(3.31),slate,nil,true);h.Body[#h.Body+1]=column
 disc(parent,'Waist ring',.3,4.7,y(3.3),gold)
 disc(parent,'Upper collar',.45,5.4,y(5.035),gold)
 local cup=disc(parent,'Cup',.5,6.2,y(5.51),slate);h.Trim[#h.Trim+1]=cup
 local top=disc(parent,'Top',.55,7,y(6.035),slate,Enum.Material.Slate,true);h.Ink[#h.Ink+1]=top
 disc(parent,'Top rim',.14,7.5,y(5.92),gold)
 h.Ring=disc(parent,'Glow ring',.1,6,y(6.36),slate,Enum.Material.Neon);h.Lit[#h.Lit+1]=h.Ring
 -- four posts at the plinth's corners, each with a gold cap and a glowing gem
 for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
  local at=o*CFrame.new(sx*3.7,0,sz*3.7)
  local post=part(parent,'Post',Vector3.new(.8,1.9,.8),at*CFrame.new(0,1.45,0),slate);h.Body[#h.Body+1]=post
  part(parent,'Post cap',Vector3.new(1.05,.2,1.05),at*CFrame.new(0,2.5,0),gold)
  local gem=ball(parent,'Gem',.9,at*CFrame.new(0,3.05,0),slate,Enum.Material.Neon);h.Lit[#h.Lit+1]=gem
 end end
 return h
end
-- Paints the themed parts for the biome (stage: nil = the violet default) and the lit parts for the state (Empty / Locked / Ready / Claimed).
function A.Tint(h,state,stage)
 local theme=Rules.Theme(stage);local look=Rules.StateLook[state]or Rules.StateLook.Empty
 local body,ink,trim=c3(theme.Body),c3(theme.Ink),c3(theme.Trim);local material=Enum.Material[theme.Material]or Enum.Material.SmoothPlastic
 for _,p in ipairs(h.Body)do p.Color=body;p.Material=material end
 for _,p in ipairs(h.Ink)do p.Color=ink end
 for _,p in ipairs(h.Trim)do p.Color=trim end
 for _,p in ipairs(h.Mix)do p.Color=ink:Lerp(trim,.3)end
 local lit=c3(look.Color)
 for _,p in ipairs(h.Lit)do
  p.Color=lit;p.Material=look.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic;p.Transparency=look.Transparency
 end
end
return A
