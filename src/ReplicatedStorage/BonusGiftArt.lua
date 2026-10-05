-- R150: small UI-shape builders for the treadmill bonus UI (the HUD button, the gift timer and the roll screen). Only frames,
-- gradients, strokes and text: no uploaded images. Nothing here animates by itself; TreadmillBonusClient drives the few
-- moving parts (and only while they are visible).
--  * Gift(parent,size)       a little wrapped gift (box, lid, ribbon, bow); :Fill(f) fills the box from the bottom with colour.
--  * Bow(parent,size)        two ribbon loops and a knot.
--  * Candy(parent,name,...)  chunky 3D button: darker lip, gradient face, top gloss, label; Press() squashes it.
--  * Badge / Shine / Rays / Stripes / Burst   count chip, shine sweep pane, light beams, wrapping-paper stripes, sparkle burst.
-- Gotchas kept in mind: ClipsDescendants clips to the rectangle (never the rounded corners), so shine panes are inset;
-- a rotated ClipsDescendants frame does not clip, so only unrotated frames clip here; UIGradient colour sequences are not
-- tweenable (they are rebuilt); a hard colour step needs two keypoints a hair apart.
local A={}
local RGB=Color3.fromRGB
A.INK=RGB(10,14,28);A.GOLD=RGB(255,206,72);A.WHITE=Color3.new(1,1,1)
A.Pink={RGB(255,164,200),RGB(240,66,122)}
A.Dim={RGB(104,110,168),RGB(58,62,114)}
A.Ribbon={RGB(255,238,136),RGB(255,176,40)}
A.Confetti={RGB(255,214,79),RGB(120,232,110),RGB(110,190,255),RGB(255,110,150),RGB(200,140,255),RGB(255,255,255)}
local INK,WHITE=A.INK,A.WHITE

function A.make(class,props,parent)
 local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o
end
local make=A.make
function A.round(o,radius)return make('UICorner',{CornerRadius=UDim.new(0,radius)},o)end
function A.pill(o)return make('UICorner',{CornerRadius=UDim.new(.5,0)},o)end
function A.stroke(o,color,thickness,transparency)
 return make('UIStroke',{Color=color,Thickness=thickness,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o)
end
local round,pill,stroke=A.round,A.pill,A.stroke
function A.gradient(o,top,bottom,rotation)
 return make('UIGradient',{Color=ColorSequence.new(top,bottom),Rotation=rotation or 90},o)
end
-- Top highlight, body colour, darker bottom: the candy look of every chunky face.
function A.candyGradient(o,color,rotation)
 return make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,color:Lerp(WHITE,.5)),ColorSequenceKeypoint.new(.5,color),
  ColorSequenceKeypoint.new(1,color:Lerp(INK,.18))}),Rotation=rotation or 90},o)
end
function A.text(parent,name,value,size,color,font)
 return make('TextLabel',{Name=name,Text=value,TextSize=size,Font=font or Enum.Font.GothamBlack,TextColor3=color or WHITE,
  TextStrokeColor3=INK,TextStrokeTransparency=.15,BackgroundTransparency=1,TextWrapped=true},parent)
end
-- A label that scales to its box (never past maxSize, never below minSize).
function A.fitText(parent,name,value,maxSize,minSize,color,font)
 local label=A.text(parent,name,value,maxSize,color,font);label.TextScaled=true
 make('UITextSizeConstraint',{MaxTextSize=maxSize,MinTextSize=minSize},label)
 return label
end

-- Bow: two ribbon loops and a knot, in a size x (0.62 size) box. colors = {top, bottom} (the gold ribbon by default).
function A.Bow(parent,size,name,colors)
 colors=colors or A.Ribbon
 local h=math.floor(size*.62+.5)
 local root=make('Frame',{Name=name or'Bow',BackgroundTransparency=1,Size=UDim2.fromOffset(size,h),ZIndex=6},parent)
 local line=size>=36 and 2 or 1.5
 -- Parts are sized in fractions of the box (kept at 1 : 0.62), so resizing the bow later keeps it whole.
 for i,side in ipairs({-1,1})do
  local loop=make('Frame',{Name=i==1 and'LoopL'or'LoopR',AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=WHITE,BorderSizePixel=0,
   Position=UDim2.fromScale(.5+side*.22,.46),Size=UDim2.fromScale(.44,.30/.62),Rotation=-side*28,ZIndex=6},root)
  pill(loop);stroke(loop,INK,line);A.gradient(loop,colors[1],colors[2])
 end
 local knot=make('Frame',{Name='Knot',AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=WHITE,BorderSizePixel=0,Position=UDim2.fromScale(.5,.52),
  Size=UDim2.fromScale(.2,.2/.62),ZIndex=7},root)
 pill(knot);stroke(knot,INK,line);A.gradient(knot,colors[1],colors[2])
 return root
end

-- Gift: a box that fills with colour from the bottom as :Fill(f) rises (a hard gradient step: no clipping, so the whole
-- icon can rotate for the wiggle). Lid, ribbon bands and bow are always in colour.
function A.Gift(parent,size,name)
 local root=make('Frame',{Name=name or'Icon',BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(size,size),ZIndex=3},parent)
 local line=size>=30 and 2.5 or 2
 local body=make('Frame',{Name='Body',BackgroundColor3=WHITE,BorderSizePixel=0,Position=UDim2.fromScale(.13,.47),Size=UDim2.fromScale(.74,.45),ZIndex=3},root)
 round(body,math.max(2,size*.09));stroke(body,INK,line)
 local fillGradient=make('UIGradient',{Name='Fill',Rotation=90},body)
 local lid=make('Frame',{Name='Lid',BackgroundColor3=WHITE,BorderSizePixel=0,Position=UDim2.fromScale(.07,.34),Size=UDim2.fromScale(.86,.17),ZIndex=4},root)
 round(lid,math.max(2,size*.07));stroke(lid,INK,line);A.gradient(lid,A.Pink[1]:Lerp(WHITE,.25),A.Pink[1]:Lerp(A.Pink[2],.4))
 local lower=make('Frame',{Name='BandLower',BackgroundColor3=WHITE,BorderSizePixel=0,Position=UDim2.fromScale(.425,.52),Size=UDim2.fromScale(.15,.4),ZIndex=5},root)
 A.gradient(lower,A.Ribbon[1],A.Ribbon[2])
 local upper=make('Frame',{Name='BandUpper',BackgroundColor3=WHITE,BorderSizePixel=0,Position=UDim2.fromScale(.425,.34),Size=UDim2.fromScale(.15,.17),ZIndex=5},root)
 A.gradient(upper,A.Ribbon[1],A.Ribbon[2])
 local bow=A.Bow(root,size*.62);bow.AnchorPoint=Vector2.new(.5,1);bow.Position=UDim2.fromScale(.5,.42)
 local gift={Root=root,Body=body,Lid=lid,Bow=bow,Gradient=fillGradient,Level=-1}
 -- f = 0..1 how full the box is. Quantised so a slow count-up does not rebuild the gradient every frame.
 function gift:Fill(f)
  f=tonumber(f)or 0;if f~=f then f=0 end
  f=math.floor(math.clamp(f,0,1)*24+.5)/24
  if f==self.Level then return end
  self.Level=f
  local kp=ColorSequenceKeypoint.new
  if f>=1 then self.Gradient.Color=ColorSequence.new(A.Pink[1],A.Pink[2])
  elseif f<=0 then self.Gradient.Color=ColorSequence.new(A.Dim[1],A.Dim[2])
  else
   local edge=math.clamp(1-f,.04,.96)
   self.Gradient.Color=ColorSequence.new({kp(0,A.Dim[1]),kp(edge-.002,A.Dim[2]),kp(edge,A.Pink[1]),kp(1,A.Pink[2])})
  end
 end
 gift:Fill(1)
 return gift
end

-- Count chip (red disc, white ring).
function A.Badge(parent,name,size,textSize)
 local chip=make('Frame',{Name=name,BackgroundColor3=RGB(236,52,84),BorderSizePixel=0,Size=UDim2.fromOffset(size,size),AnchorPoint=Vector2.new(.5,.5),ZIndex=12},parent)
 pill(chip);stroke(chip,WHITE,2);A.gradient(chip,RGB(255,112,132),RGB(214,36,70))
 local label=A.text(chip,'Count','2',textSize);label.Size=UDim2.fromScale(1,1);label.ZIndex=13;label.TextWrapped=false
 make('UIScale',{Name='Pop'},chip)
 return chip,label
end

-- Chunky 3D button: a transparent TextButton (the hit area) holding a darker Lip and a gradient Face; the label sits on the
-- face. Press(true) sinks the face onto the lip. color = the candy colour; opts.Lip px, opts.TextSize, opts.Z (face z+1, gloss z+3, label z+4), opts.NoLabel.
function A.Candy(parent,name,color,caption,opts)
 opts=opts or {};local lip=opts.Lip or 4;local z=opts.Z or 4
 local button=make('TextButton',{Name=name,Text='',AutoButtonColor=false,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z},parent)
 button:SetAttribute('Lip',lip)
 pill(button) -- the shared hover / press outline (ButtonHighlights) follows the capsule, not a square
 local lipFrame=make('Frame',{Name='Lip',BackgroundColor3=color:Lerp(INK,.58),BorderSizePixel=0,Position=UDim2.fromOffset(0,lip),Size=UDim2.new(1,0,1,-lip),ZIndex=z},button)
 pill(lipFrame);stroke(lipFrame,INK,opts.Stroke or 2)
 local face=make('Frame',{Name='Face',BackgroundColor3=WHITE,BorderSizePixel=0,Size=UDim2.new(1,0,1,-lip),ZIndex=z+1},button)
 pill(face);stroke(face,INK,opts.Stroke or 2);A.candyGradient(face,color)
 local gloss=make('Frame',{Name='Gloss',BackgroundColor3=WHITE,BorderSizePixel=0,Position=UDim2.fromOffset(8,3),Size=UDim2.new(1,-16,.4,0),ZIndex=z+3},face)
 pill(gloss);make('UIGradient',{Rotation=90,Transparency=NumberSequence.new(.55,1)},gloss)
 if not opts.NoLabel then
  local label=A.fitText(face,'Label',caption,opts.TextSize or 16,opts.MinTextSize or 10)
  label.Position=UDim2.fromOffset(8,0);label.Size=UDim2.new(1,-16,1,0);label.ZIndex=z+4
 end
 return button
end
function A.Press(button,down)
 local face=button:FindFirstChild('Face');if not face then return end
 local lip=tonumber(button:GetAttribute('Lip'))or 4
 face.Position=UDim2.fromOffset(0,down and lip-1 or 0)
end
function A.Recolor(button,color)
 local face,lip=button:FindFirstChild('Face'),button:FindFirstChild('Lip')
 if lip then lip.BackgroundColor3=color:Lerp(INK,.58)end
 local gradient=face and face:FindFirstChildOfClass('UIGradient')
 if gradient then
  gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,color:Lerp(WHITE,.5)),ColorSequenceKeypoint.new(.5,color),ColorSequenceKeypoint.new(1,color:Lerp(INK,.18))})
 end
end

-- Shine: a pane (clips its children) with a slanted soft stripe; SetShine(shine,u) sweeps it across for u in 0..1, hides it
-- outside. The pane is inset so the rectangle never pokes out of rounded corners.
function A.Shine(parent,insetX,insetY,alpha,z)
 local pane=make('Frame',{Name='ShinePane',BackgroundTransparency=1,ClipsDescendants=true,BorderSizePixel=0,Position=UDim2.fromOffset(insetX,insetY),
  Size=UDim2.new(1,-2*insetX,1,-2*insetY),ZIndex=z or 8},parent)
 local stripe=make('Frame',{Name='Sweep',BackgroundColor3=WHITE,BackgroundTransparency=alpha or .55,BorderSizePixel=0,Rotation=22,Size=UDim2.fromScale(.22,1.9),
  Position=UDim2.fromScale(-.4,-.45),Visible=false,ZIndex=z or 8},pane)
 make('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.2),NumberSequenceKeypoint.new(1,1)})},stripe)
 return {Pane=pane,Stripe=stripe}
end
function A.SetShine(shine,u)
 local stripe=shine.Stripe
 if u<=0 or u>=1 then if stripe.Visible then stripe.Visible=false end;return end
 -- -.6 .. 1.4: the stripe starts and ends fully outside the pane. Roblox rotates a GuiObject about its CENTRE (not its AnchorPoint), so a 22 degree stripe
 -- reaches far beyond its own box; the old -.35 .. 1.15 left it popping in and out inside a tall winner card.
 stripe.Visible=true;stripe.Position=UDim2.fromScale(-.6+u*2,-.45)
end

-- Rays: crossing light beams (every beam is a full-length bar through the centre = two rays, with a brighter narrow core).
-- Rotate the root to turn them.
local RAY_FADE=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.55),NumberSequenceKeypoint.new(.5,0),
 NumberSequenceKeypoint.new(.7,.55),NumberSequenceKeypoint.new(1,1)})
function A.Rays(parent,beams,length,width,z)
 local root=make('Frame',{Name='Rays',BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(length,length),ZIndex=z or 6},parent)
 local list={}
 for i=1,beams do
  local beam=make('Frame',{Name='Beam'..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(width,length),Rotation=(i-1)*180/beams,
   BackgroundColor3=WHITE,BackgroundTransparency=.7,BorderSizePixel=0,ZIndex=z or 6},root)
  make('UIGradient',{Rotation=90,Transparency=RAY_FADE},beam)
  local core=make('Frame',{Name='Core',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(0,math.max(4,math.floor(width*.34)),1,0),
   BackgroundColor3=WHITE,BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=z or 6},beam)
  make('UIGradient',{Rotation=90,Transparency=RAY_FADE},core)
  list[i]=beam
 end
 return {Root=root,Beams=list}
end
-- Tint every beam; alpha = the transparency of the wide beam (the core is brighter).
function A.TintRays(rays,color,alpha)
 for _,beam in ipairs(rays.Beams)do
  beam.BackgroundColor3=color;beam.BackgroundTransparency=alpha
  local core=beam:FindFirstChild('Core');if core then core.BackgroundColor3=color:Lerp(WHITE,.5);core.BackgroundTransparency=math.clamp(1-(1-alpha)*1.7,0,1)end
 end
end

-- Wrapping paper: soft diagonal stripes over a frame (a hard-edged transparency gradient; 4 stripes = 18 keypoints, the
-- limit for a NumberSequence is 20).
function A.Stripes(parent,count,rotation,alpha,z)
 local frame=make('Frame',{Name='Wrap',BackgroundColor3=WHITE,BackgroundTransparency=alpha,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=z or 2},parent)
 local kp=NumberSequenceKeypoint.new;local keys={kp(0,1)}
 count=math.min(count,4);local period=1/count
 for k=0,count-1 do
  local a=k*period+period*.31;local b=a+period*.38
  keys[#keys+1]=kp(a,1);keys[#keys+1]=kp(a+.002,0);keys[#keys+1]=kp(b,0);keys[#keys+1]=kp(b+.002,1)
 end
 keys[#keys+1]=kp(1,1)
 make('UIGradient',{Rotation=rotation,Transparency=NumberSequence.new(keys)},frame)
 return frame
end

-- Sparkle / confetti burst from (x,y) in the layer. Every piece is ONE Frame (a sparkle is a spinning diamond: a square at 45 degrees; a confetti bit is a
-- tall rectangle): a Secret reveal draws 160 pieces on one frame, so a piece must not cost 5 instances. opts: Count, Shape 'Star' (diamonds) or 'Confetti' (bits), Size, Life, Speed {lo,hi},
-- Arc {lo,hi} radians (negative = up), Gravity, Colors, Z. Step(dt) returns true when finished; Destroy() removes the pieces.
function A.Burst(layer,x,y,opts)
 local rng=Random.new();local colors=opts.Colors or A.Confetti;local star=opts.Shape~='Confetti'
 local arc=opts.Arc or{-math.pi,math.pi};local speed=opts.Speed or{80,200};local size=opts.Size or 8;local life=opts.Life or .9
 local pieces={}
 for i=1,opts.Count do
  local color=colors[(i-1)%#colors+1]
  -- A sparkle's side is .62 of the old cross's arm (a diamond's diagonal is 1.41 x its side), so it covers about the same space.
  local w=star and math.max(4,math.floor(size*rng:NextNumber(.7,1.2)*.62+.5))or math.floor(size*rng:NextNumber(.7,1.1));local h=star and w or math.floor(w*rng:NextNumber(1.3,1.9))
  local frame=make('Frame',{Name=star and'Spark'or'Confetti',AnchorPoint=Vector2.new(.5,.5),BorderSizePixel=0,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
   Rotation=star and 45 or rng:NextNumber(0,360),BackgroundColor3=color,BackgroundTransparency=0,ZIndex=opts.Z or 30},layer)
  local angle=rng:NextNumber(arc[1],arc[2]);local v=rng:NextNumber(speed[1],speed[2])
  pieces[i]={Frame=frame,X=0,Y=0,VX=math.cos(angle)*v,VY=math.sin(angle)*v,Angle=frame.Rotation,Spin=rng:NextNumber(-540,540)*(star and .5 or 1),Life=rng:NextNumber(life*.6,life)}
 end
 local burst={Age=0,Life=life,Pieces=pieces}
 local gravity=opts.Gravity or 0
 function burst:Step(dt)
  self.Age+=dt;local drag=1-math.min(1,dt*(opts.Drag or 2))
  for _,p in ipairs(self.Pieces)do
   local t=self.Age/p.Life
   if t>=1 then if p.Frame.Visible then p.Frame.Visible=false end
   else
    p.VY+=gravity*dt;p.VX*=drag;p.VY*=star and drag or 1;p.X+=p.VX*dt;p.Y+=p.VY*dt;p.Angle+=p.Spin*dt
    p.Frame.Position=UDim2.fromOffset(x+p.X,y+p.Y);p.Frame.Rotation=p.Angle
    p.Frame.BackgroundTransparency=t<.5 and 0 or(t-.5)/.5
   end
  end
  return self.Age>=self.Life
 end
 function burst:Destroy()for _,p in ipairs(self.Pieces)do p.Frame:Destroy()end;table.clear(self.Pieces)end
 return burst
end

return A
