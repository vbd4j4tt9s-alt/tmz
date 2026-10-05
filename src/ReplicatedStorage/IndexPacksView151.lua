-- R151 (owner: "add a pack index in the index and state rate of spawn and drop rates ... shapes for visual representation can just use the default pack shape"): the
-- Index's PACKS tab. IndexPackData151 says WHAT is listed (every pack, its spawn rate, its drop rates, how to get it); this module draws it in the Index's own style
-- (the panel / card / chip / pill look of ChestIndex: FredokaOne, GardenTheme colours, BrightUI cards, rarity text colours, 1/N odds) and keeps it cheap on a phone.
--  * One full-width card per pack in a ScrollingFrame, grouped under a header per biome (the order of the Index's tabs) and one SPECIAL PACKS group (starter, mystery,
--    Void, Mech, Verity), after a PACK SIZES card. Everything is placed with explicit offsets (V.Metrics / V.Plan are pure: tests lay out every card at any width
--    and check that nothing overlaps or leaves its card), so the card list needs no layout engine and a card's height is known before it exists.
--  * Card: the pack's picture (ItemPictures, the DEFAULT pouch: the proxy carries DefaultPackShape, so a pack shape variation is never asked for), the name, the pack tier
--    and the biome as chips, then SPAWN (1/N of the packs on its track) or, for a pack that does not spawn on the track, FROM (where you get it) with the how-to lines;
--    the DROPS: one chip per seed rarity the pack can give (colour, name, 1/N); a tap on the card opens EVERY SEED, each seed's own 1/N.
--  * LAZY: all the cards are placed at once (cheap shells), but a card's contents (about 40 Gui objects and a picture) are built only when the card is within a screen or so of
--    what is on show, a few per frame (PerPass), as the list scrolls. ItemPictures draws a picture only while its holder is on screen or just beside it, and shares one
--    template per look with the hotbar and the Bag (the Void and the Mech pack are even the same look), so nothing is built twice.
local RS=game:GetService('ReplicatedStorage')
local Theme=require(RS:WaitForChild('GardenTheme'));local Bright=require(RS:WaitForChild('BrightUI'))
local V={Revision=151,PerPass=3,Margin=160}
local RGB=Color3.fromRGB
local C=Theme.Colors
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
local function rect(x,y,w,h)return{x=x,y=y,w=w,h=h}end
-- Layout (pure) ----------------------------------------------------------------------------------------------------------------------------------------------
-- The numbers every card of this width shares. `width` is the card's width in px.
function V.Metrics(width)
 width=math.max(160,math.floor(width or 300))
 local m={Width=width,Pad=10,Gap=6,ChipH=24,CaptionH=16,SeedH=22,SeedGap=4,HeaderH=30,ItemGap=10}
 m.Compact=width<520
 m.Pic=m.Compact and 84 or 100
 m.Head=m.Pic+m.Pad*2
 m.TextW=width-m.Pad*2
 m.Cols=clamp(math.floor((m.TextW+m.Gap)/(128+m.Gap)),1,8)
 m.ChipW=math.floor((m.TextW-(m.Cols-1)*m.Gap)/m.Cols)
 m.SeedCols=clamp(math.floor((m.TextW+m.Gap)/(176+m.Gap)),1,5)
 m.SeedW=math.floor((m.TextW-(m.SeedCols-1)*m.Gap)/m.SeedCols)
 return m
end
-- How many lines `text` needs at `size` px in `w` px (a generous FredokaOne estimate: .58 em a character; TextScaled shrinks the text if it is wrong, never overflows).
local function lines(text,size,w)return math.max(1,math.ceil(#text*size*.58/math.max(20,w)))end
local function howText(a)return a.Source..(a.Text and(': '..a.Text)or'')end
local function alsoText(entry)
 local t={};for _,a in ipairs(entry.Also or{})do t[#t+1]=a.Source..(a.Text and(' '..a.Text)or'')end
 return'Also from: '..table.concat(t,'  •  ')
end
V.HowText,V.AlsoText=howText,alsoText
local function hasSeeds(entry)for _,g in ipairs(entry.Drops)do if g.Count>0 then return true end end;return false end
V.HasSeeds=hasSeeds
-- The card's layout: {Height, Rects = {Picture, Name, Tier, Biome, SpawnCaption / SpawnValue / SpawnOf (a track pack) or SourceCaption / SourceValue (any other), HowTitle +
-- How[i] (a pack with how-to lines) or Also (a track pack), DropTitle, DropHint, Chips[i], SeedsTitle + Seeds[i] (open cards)}}. Rects are {x, y, w, h} inside the card.
function V.Plan(entry,m,expanded)
 local R={};local pad=m.Pad
 R.Picture=rect(pad,pad,m.Pic,m.Pic)
 local x0=pad+m.Pic+10;local tw=m.Width-x0-pad
 R.Name=rect(x0,pad,tw,26)
 local tierW=math.min(84,math.floor((tw-6)*.56));R.Tier=rect(x0,pad+30,tierW,20)
 R.Biome=rect(x0+tierW+6,pad+30,math.min(84,tw-tierW-6),20)
 local sy=pad+m.Pic-30
 if entry.Spawn then
  R.SpawnCaption=rect(x0,sy+8,44,14);R.SpawnValue=rect(x0+46,sy,76,30);R.SpawnOf=rect(x0+126,sy+1,math.max(10,tw-126),28)
 else
  R.SourceCaption=rect(x0,sy+8,40,14);R.SourceValue=rect(x0+42,sy,math.max(10,tw-42),30)
 end
 local y=m.Head-4
 if entry.How then
  R.HowTitle=rect(pad,y,m.TextW,m.CaptionH);y+=m.CaptionH;R.How={}
  for i,a in ipairs(entry.How)do local h=lines(howText(a),12,m.TextW)*14+2;R.How[i]=rect(pad,y,m.TextW,h);y+=h+2 end
  y+=4
 elseif entry.Also and #entry.Also>0 then
  local h=lines(alsoText(entry),11,m.TextW)*13+2;R.Also=rect(pad,y,m.TextW,h);y+=h+4
 end
 R.DropTitle=rect(pad,y,math.floor(m.TextW*.55),m.CaptionH);R.DropHint=rect(pad+math.floor(m.TextW*.55),y,m.TextW-math.floor(m.TextW*.55),m.CaptionH);y+=m.CaptionH
 R.Chips={}
 for i in ipairs(entry.Drops)do local col=(i-1)%m.Cols;local row=(i-1)//m.Cols;R.Chips[i]=rect(pad+col*(m.ChipW+m.Gap),y+row*(m.ChipH+m.Gap),m.ChipW,m.ChipH)end
 y+=math.ceil(#entry.Drops/m.Cols)*(m.ChipH+m.Gap)-m.Gap
 if expanded and hasSeeds(entry)then
  y+=8;R.SeedsTitle=rect(pad,y,m.TextW,m.CaptionH);y+=m.CaptionH;R.Seeds={}
  local n=0;for _,g in ipairs(entry.Drops)do for _ in ipairs(g.Seeds)do n+=1 end end
  for i=1,n do local col=(i-1)%m.SeedCols;local row=(i-1)//m.SeedCols;R.Seeds[i]=rect(pad+col*(m.SeedW+m.Gap),y+row*(m.SeedH+m.SeedGap),m.SeedW,m.SeedH)end
  y+=math.ceil(n/m.SeedCols)*(m.SeedH+m.SeedGap)-m.SeedGap
 end
 return{Height=y+pad,Rects=R}
end
-- The PACK SIZES card: a title and one chip per size.
function V.PlanSizes(data,m)
 local R={Title=rect(m.Pad,m.Pad,m.TextW,m.CaptionH+2),Chips={}};local y=m.Pad+m.CaptionH+6
 for i in ipairs(data.Sizes)do local col=(i-1)%m.Cols;local row=(i-1)//m.Cols;R.Chips[i]=rect(m.Pad+col*(m.ChipW+m.Gap),y+row*(m.ChipH+m.Gap),m.ChipW,m.ChipH)end
 y+=math.ceil(#data.Sizes/m.Cols)*(m.ChipH+m.Gap)-m.Gap
 return{Height=y+m.Pad,Rects=R}
end
-- The whole list: the items (the sizes card, then a header and the cards of each section) with their y and height. open[key] = the card is open.
function V.PlanList(data,m,open)
 local items,y={},0
 local function add(item,h)item.Y=y;item.H=h;items[#items+1]=item;y+=h+m.ItemGap end
 local sizes=V.PlanSizes(data,m);add({Kind='Sizes',Plan=sizes},sizes.Height)
 for _,section in ipairs(data.Sections)do
  add({Kind='Header',Title=section.Title,Section=section},m.HeaderH)
  for _,entry in ipairs(section.Entries)do local plan=V.Plan(entry,m,open and open[entry.Key]);add({Kind='Card',Entry=entry,Plan=plan},plan.Height)end
 end
 return items,math.max(0,y-m.ItemGap)
end
-- Drawing ----------------------------------------------------------------------------------------------------------------------------------------------------
local function pos(o,r)o.Position=UDim2.fromOffset(r.x,r.y);o.Size=UDim2.fromOffset(r.w,r.h)end
local function corner(o,r)local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,r);c.Parent=o;return c end
local function stroke(o,color,thickness,transparency)local s=Instance.new('UIStroke');s.Color=color;s.Thickness=thickness;s.Transparency=transparency or 0;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=o;return s end
local function frame(parent,name,r,color,alpha)
 local f=Instance.new('Frame');f.Name=name;f.BorderSizePixel=0;f.Active=false;f.BackgroundColor3=color;f.BackgroundTransparency=alpha or 0;if r then pos(f,r)end;f.Parent=parent;return f
end
local function label(parent,name,text,r,size,color,align,wrap)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.BorderSizePixel=0;t.Active=false;t.Font=Theme.Bold;t.Text=text;t.TextColor3=color
 t.TextStrokeColor3=RGB(8,13,24);t.TextStrokeTransparency=.2;t.RichText=false;t.TextScaled=true;t.TextWrapped=wrap==true
 t.TextXAlignment=align or Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Center
 local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=size;fit.MinTextSize=math.min(8,size);fit.Parent=t
 pos(t,r);t.Parent=parent;return t
end
local LEFT,RIGHT,CENTER=Enum.TextXAlignment.Left,Enum.TextXAlignment.Right,Enum.TextXAlignment.Center
-- A chip of the drops / sizes grid: a dark pill, a colour bar, the name in its colour, the 1/N in white.
local function chip(parent,name,r,color,caption,odds)
 local f=frame(parent,name,r,RGB(10,14,32),.15);corner(f,6)
 local bar=frame(f,'Bar',rect(4,4,3,r.h-8),color);corner(bar,2)
 local split=math.floor(r.w*.58)
 label(f,'Name',caption,rect(11,0,split-11,r.h),12,color,LEFT)
 label(f,'Odds',odds,rect(split,0,r.w-split-6,r.h),13,RGB(255,255,255),RIGHT)
 return f
end
local function pictureProxy(entry)
 local f=Instance.new('Folder');f.Name='IndexPackPicture';f:SetAttribute('SeedPackTool',true);f:SetAttribute('Stage',entry.Stage);f:SetAttribute('BagVariant',entry.Variant);f:SetAttribute('PackMutation','None')
 f:SetAttribute('DefaultPackShape',true) -- the Index always asks for the default pouch (ItemPictures: the |Plain look), never a pack shape variation
 return f
end
V.PictureProxy=pictureProxy
-- The picture of a pack in `holder`. A silhouette (the mystery pack) tints the ViewportFrame black while it is in the holder and restores it when ItemPictures parks it.
function V.ShowPicture(Pictures,holder,entry,priority,silhouette)
 if silhouette then
  local function tint(child,color)if child:IsA('ViewportFrame')then child.ImageColor3=color end end
  holder.ChildAdded:Connect(function(child)tint(child,RGB(8,6,20))end)
  holder.ChildRemoved:Connect(function(child)tint(child,RGB(255,255,255))end)
 end
 local ok,why=pcall(Pictures.Show,holder,pictureProxy(entry),priority or 2)
 return ok,why
end
local function limitedLook(entry)return entry.Limited==true end
local function rarityName(entry)local n=entry.Tier.Name;return Theme.Rarities[n]and n or nil end
-- Builds the contents of a card shell (once).
local function fillCard(view,item)
 local entry,plan,card=item.Entry,item.Plan,item.Card;local R=plan.Rects;local tier=entry.Tier
 item.Built=true;view.BuiltCount+=1
 Bright.Card(card,tier.Color,limitedLook(entry),rarityName(entry))
 local glow=frame(card,'Glow',rect(R.Picture.x+R.Picture.w/2-R.Picture.w*.6,R.Picture.y+R.Picture.h/2-R.Picture.h*.6,R.Picture.w*1.2,R.Picture.h*1.2),tier.Color,.82);corner(glow,R.Picture.w)
 local holder=frame(card,'Picture',R.Picture,Color3.new(),1);holder.ZIndex=3
 V.ShowPicture(view.Pictures,holder,entry,2,entry.Silhouette)
 local name=label(card,'Name',entry.Name,R.Name,18,RGB(255,255,255),LEFT)
 local tierChip=frame(card,'TierChip',R.Tier,RGB(10,14,32),.2);corner(tierChip,10);stroke(tierChip,tier.Color,1.5,.1)
 label(tierChip,'Label',string.upper(tier.Name),rect(4,0,R.Tier.w-8,R.Tier.h),12,tier.Color,CENTER)
 local biomeChip=frame(card,'BiomeChip',R.Biome,RGB(10,14,32),.2);corner(biomeChip,10);stroke(biomeChip,C.Line,1.5,.15)
 label(biomeChip,'Label',string.upper(entry.Biome),rect(4,0,R.Biome.w-8,R.Biome.h),12,RGB(255,255,255),CENTER)
 if entry.Spawn then
  label(card,'SpawnCaption','SPAWN',R.SpawnCaption,11,C.Muted,LEFT)
  label(card,'SpawnValue',entry.Spawn.Text,R.SpawnValue,24,C.Gold,LEFT)
  label(card,'SpawnOf',entry.Spawn.Of,R.SpawnOf,11,C.Muted,LEFT,true)
 else
  label(card,'SourceCaption','FROM',R.SourceCaption,11,C.Muted,LEFT)
  label(card,'SourceValue',(entry.How and entry.How[1]and entry.How[1].Source)or'',R.SourceValue,15,C.Gold,LEFT,true)
 end
 if R.HowTitle then
  label(card,'HowTitle','HOW YOU GET IT',R.HowTitle,11,C.Muted,LEFT)
  for i,a in ipairs(entry.How)do label(card,'How'..i,howText(a),R.How[i],12,RGB(255,255,255),LEFT,true)end
 elseif R.Also then
  label(card,'Also',alsoText(entry),R.Also,11,C.Muted,LEFT,true)
 end
 label(card,'DropTitle',entry.DropTitle,R.DropTitle,11,C.Muted,LEFT)
 local seeds=hasSeeds(entry)
 local hint=label(card,'DropHint',seeds and'TAP FOR EVERY SEED'or'',R.DropHint,10,C.Muted,RIGHT);hint.Name='DropHint'
 for i,g in ipairs(entry.Drops)do chip(card,'Chip'..g.Key,R.Chips[i],g.Color,g.Label..(g.Count>1 and(' x'..g.Count)or''),g.Text)end
 item.Hint=hint
 if seeds then
  card.Activated:Connect(function()view:Toggle(entry.Key)end)
 end
 view:Apply(item)
end
-- The EVERY SEED block of an open card (built the first time it opens).
local function fillSeeds(view,item)
 local entry,card=item.Entry,item.Card;local R=item.Plan.Rects
 if not R.SeedsTitle then return end
 local block=Instance.new('Frame');block.Name='Seeds';block.BackgroundTransparency=1;block.BorderSizePixel=0;block.Active=false;block.Size=UDim2.fromScale(1,1);block.Parent=card;item.SeedsBlock=block
 label(block,'SeedsTitle','EVERY SEED  •  ONE IN',R.SeedsTitle,11,C.Muted,LEFT)
 local i=0
 for _,g in ipairs(entry.Drops)do for _,seed in ipairs(g.Seeds)do
  i+=1;local r=R.Seeds[i]
  local f=frame(block,'Seed'..seed.Id,r,RGB(10,14,32),.15);corner(f,6)
  frame(f,'Bar',rect(4,4,3,r.h-8),g.Color)
  label(f,'Name',seed.Name,rect(11,0,r.w-11-62,r.h),12,RGB(255,255,255),LEFT)
  label(f,'Odds',seed.Text,rect(r.w-62,0,56,r.h),12,g.Color,RIGHT)
 end end
end
-- The view -------------------------------------------------------------------------------------------------------------------------------------------------
local View={};View.__index=View
-- scroll: the ScrollingFrame the list lives in. opts.Data: IndexPackData151.Build's result. opts.Pictures: ItemPictures.
function V.new(scroll,opts)
 local self=setmetatable({Scroll=scroll,Data=opts.Data,Pictures=opts.Pictures,Open={},Items={},BuiltCount=0,Width=0,Dead=false},View)
 scroll.CanvasPosition=Vector2.zero
 self.Connection=scroll:GetPropertyChangedSignal('CanvasPosition'):Connect(function()self:Refresh()end)
 self.SizeConnection=scroll:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:Refresh()end) -- (a taller window shows cards that were beyond the first reading)
 return self
end
-- (Re)places everything for a card width. A new width makes new shells (and drops the contents built for the old one); the same width does nothing.
function View:Layout(width)
 if self.Dead then return self.Total or 0 end
 local m=V.Metrics(width)
 if self.Width==m.Width then return self.Total end
 for _,item in ipairs(self.Items)do if item.Card then item.Card:Destroy()end;if item.Frame then item.Frame:Destroy()end end
 self.Metrics=m;self.Width=m.Width;self.BuiltCount=0
 local items,total=V.PlanList(self.Data,m,self.Open)
 for i,item in ipairs(items)do
  if item.Kind=='Card'then
   local card=Instance.new('TextButton');card.Name=item.Entry.Key;card.Text='';card.AutoButtonColor=false;card.BorderSizePixel=0;card.BackgroundColor3=C.Card;corner(card,8)
   card.LayoutOrder=i;card.Position=UDim2.fromOffset(0,item.Y);card.Size=UDim2.fromOffset(m.Width,item.H);card.Parent=self.Scroll;item.Card=card;item.Built=false
  elseif item.Kind=='Header'then
   local f=Instance.new('Frame');f.Name='Header'..tostring(item.Section.Key);f.BackgroundTransparency=1;f.BorderSizePixel=0;f.LayoutOrder=i
   f.Position=UDim2.fromOffset(0,item.Y);f.Size=UDim2.fromOffset(m.Width,item.H);f.Parent=self.Scroll;item.Frame=f
   label(f,'Title',item.Title,rect(2,0,m.Width-4,m.HeaderH-6),19,C.Gold,LEFT)
   local line=frame(f,'Line',rect(0,m.HeaderH-3,m.Width,2),C.Line,.55);corner(line,1)
  else
   local f=Instance.new('Frame');f.Name='Sizes';f.BorderSizePixel=0;f.BackgroundColor3=C.Card;f.LayoutOrder=i;corner(f,8);stroke(f,C.Line,1.5,.4)
   f.Position=UDim2.fromOffset(0,item.Y);f.Size=UDim2.fromOffset(m.Width,item.H);f.Parent=self.Scroll;item.Frame=f
   local R=item.Plan.Rects
   label(f,'Title','PACK SIZES  •  HOW OFTEN A PACK COMES BIGGER',R.Title,12,C.Muted,LEFT)
   for k,size in ipairs(self.Data.Sizes)do chip(f,'Size'..k,R.Chips[k],C.Gold,size.Label,size.Text)end
  end
 end
 self.Items=items;self.Scroll.CanvasSize=UDim2.fromOffset(0,total);self.Total=total
 self:Refresh()
 return total
end
-- Opens / closes a card (a tap): the rest of the list moves up or down, the card's seed list is built the first time.
function View:Toggle(key)
 if self.Dead then return end
 self.Open[key]=not self.Open[key]or nil
 self:Reflow()
end
function View:Reflow()
 local m=self.Metrics;if not m then return end
 local items,total=V.PlanList(self.Data,m,self.Open)
 for i,item in ipairs(items)do
  local prev=self.Items[i]
  item.Card=prev.Card;item.Frame=prev.Frame;item.Built=prev.Built;item.Hint=prev.Hint;item.SeedsBlock=prev.SeedsBlock;item.SeedsBuilt=prev.SeedsBuilt
  if item.Card then item.Card.Position=UDim2.fromOffset(0,item.Y);item.Card.Size=UDim2.fromOffset(m.Width,item.H)end
  if item.Frame then item.Frame.Position=UDim2.fromOffset(0,item.Y)end
  if item.Kind=='Card'and item.Built then self:Apply(item)end
 end
 self.Items=items;self.Scroll.CanvasSize=UDim2.fromOffset(0,total);self.Total=total
 self:Refresh()
end
-- Shows a built card as open or closed (its seeds block, its hint).
function View:Apply(item)
 local open=self.Open[item.Entry.Key]==true
 if open and not item.SeedsBuilt then fillSeeds(self,item);item.SeedsBuilt=true end
 if item.SeedsBlock then item.SeedsBlock.Visible=open end
 if item.Hint and V.HasSeeds(item.Entry)then item.Hint.Text=open and'TAP TO CLOSE'or'TAP FOR EVERY SEED'end
 item.Card:SetAttribute('Open',open)
end
-- Builds the cards that are on screen or within V.Margin + 3/4 of a screen of it, the ones on screen first, V.PerPass per call (the rest on the next frame).
function View:Refresh()
 if self.Dead or not self.Scroll.Parent then return end
 local top=self.Scroll.CanvasPosition.Y;local h=math.max(self.Scroll.AbsoluteSize.Y,160);local margin=h*.75+V.Margin
 local built,more=0,false
 for pass=1,2 do
  local lo,hi=top,top+h;if pass==2 then lo,hi=top-margin,top+h+margin end
  for _,item in ipairs(self.Items)do
   if item.Kind=='Card'and not item.Built and item.Y+item.H>=lo and item.Y<=hi then
    if built<V.PerPass then fillCard(self,item);built+=1 else more=true end
   end
  end
 end
 if more and not self.Queued then self.Queued=true;task.defer(function()self.Queued=false;self:Refresh()end)end
end
function View:Destroy()
 self.Dead=true;if self.Connection then self.Connection:Disconnect()end;if self.SizeConnection then self.SizeConnection:Disconnect()end
 for _,item in ipairs(self.Items)do if item.Card then item.Card:Destroy()end;if item.Frame then item.Frame:Destroy()end end
 self.Items={}
end
-- Tests / tools: how many cards have their contents.
function View:Built()local n=0;for _,item in ipairs(self.Items)do if item.Kind=='Card'and item.Built then n+=1 end end;return n end
return V
