-- A tiny moving clip window over a white copy of the SAME text masks stars to glyphs.
-- No texture uploads, particles, CanvasGroups, or separate loops per label.
local Run=game:GetService('RunService');local Players=game:GetService('Players')
local M={};local entries={};local connection;local elapsed=0;local clock=0
local PROPERTIES={'Text','Font','TextSize','TextScaled','TextWrapped','TextXAlignment','TextYAlignment','LineHeight','TextTruncate','MaxVisibleGraphemes','TextDirection'}
local function visible(label)
 if label.Text==''or label.AbsoluteSize.X<1 or label.AbsoluteSize.Y<1 then return false end
 local p=label
 while p do
  if p:IsA('GuiObject')and not p.Visible then return false end
  if p:IsA('LayerCollector')and not p.Enabled then return false end
  if p:IsA('GuiObject')and p.ClipsDescendants then
   local lo,hi=label.AbsolutePosition,label.AbsolutePosition+label.AbsoluteSize;local a,b=p.AbsolutePosition,p.AbsolutePosition+p.AbsoluteSize
   if hi.X<a.X or hi.Y<a.Y or lo.X>b.X or lo.Y>b.Y then return false end
  end
  p=p.Parent
 end
 return label.Parent~=nil
end
local function release(entry)
 if entry.Root then entry.Root:Destroy();entry.Root=nil;entry.Stars=nil;entry.Cache=nil end
end
function M.Clear(label)
 local entry=entries[label];if not entry then return end
 entries[label]=nil;entry.Destroy:Disconnect();release(entry)
 if not next(entries)and connection then connection:Disconnect();connection=nil end
end
local function draw(label,entry,paused)
 if not entry.Root then
  local root=Instance.new('Frame');root.Name='CosmicStars';root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Active=false;root.Parent=label;entry.Root=root;entry.Stars={};entry.Cache={};entry.Width=nil;entry.Minimum=nil
  for i=1,6 do
   local window=Instance.new('Frame');window.Name='Star'..i;window.BackgroundTransparency=1;window.BorderSizePixel=0;window.Size=UDim2.fromOffset(i%3==0 and 2 or 1.5,i%3==0 and 2 or 1.5);window.ClipsDescendants=true;window.Active=false;window.Parent=root
   local glyph=Instance.new('TextLabel');glyph.Name='GlyphMask';glyph.BackgroundTransparency=1;glyph.BorderSizePixel=0;glyph.TextColor3=Color3.new(1,1,1);glyph.TextStrokeTransparency=1;glyph.RichText=false;glyph.Active=false;glyph.Parent=window
   local constraint=Instance.new('UITextSizeConstraint');constraint.Parent=glyph
   entry.Stars[i]={Window=window,Glyph=glyph,Constraint=constraint}
  end
 end
 local size=label.AbsoluteSize;local constraint=label:FindFirstChildOfClass('UITextSizeConstraint')
 local resized=entry.Width~=size.X or entry.Height~=size.Y
 local minimum=constraint and constraint.MinTextSize or 1;local maximum=constraint and constraint.MaxTextSize or 100
 local refit=entry.Minimum~=minimum or entry.Maximum~=maximum
 entry.Width=size.X;entry.Height=size.Y;entry.Minimum=minimum;entry.Maximum=maximum
 if not paused or not entry.Phase then entry.Phase=clock end
 local phase=entry.Phase
 for _,property in ipairs(PROPERTIES)do
  local value=label[property]
  if value~=nil and entry.Cache[property]~=value then entry.Cache[property]=value;for _,star in ipairs(entry.Stars)do star.Glyph[property]=value end end
 end
 for i,star in ipairs(entry.Stars)do
  local x=((i*.173+phase*.018)%1)*math.max(1,size.X-2)
  local y=((i*.317+phase*.009)%1)*math.max(1,size.Y-2)
  star.Window.Position=UDim2.fromOffset(x,y)
  star.Glyph.Position=UDim2.fromOffset(-x,-y)
  if resized then star.Glyph.Size=UDim2.fromOffset(size.X,size.Y)end
  star.Glyph.TextTransparency=.08+.18*(1+math.sin(phase+i*2))
  if refit then star.Constraint.MinTextSize=minimum;star.Constraint.MaxTextSize=maximum end
 end
end
function M.Apply(label)
 if entries[label]then return end
 local entry={};entries[label]=entry;entry.Destroy=label.Destroying:Connect(function()M.Clear(label)end)
 if connection then return end
 connection=Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1/12 then return end;clock+=elapsed;elapsed=0
  local player=Players.LocalPlayer;local mode=player and player:GetAttribute('StudioPlantEffects')
  local paused=player and(player:GetAttribute('FastMode')or mode=='low'or mode=='off')
  local used=0
  for label0,state in pairs(entries)do
   if visible(label0)and used<8 then
    used+=1
    if not paused or not state.Root or state.Cache.Text~=label0.Text or state.Width~=label0.AbsoluteSize.X or state.Height~=label0.AbsoluteSize.Y then draw(label0,state,paused)end
   else release(state)end
  end
 end)
end
return M
