--!nocheck
-- Dumps the real GardenCardMotion border instances (8 rarities) at a few times for render.py.
-- Output lines: pose;rarity;kind;...  (see render.py). Run from the run.sh scratch dir: luau dump.luau > borders.txt
local W=require('./world');local R=W.R
local Players=W.service('Players');local player=R.new('Player');player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Parent=player
local Theme=W.module('GardenTheme');local Borders=W.module('GardenCardMotion')
local sheet=R.Instance.new('ScreenGui');sheet.Parent=pg
local ORDER={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'};local cards={}
for _,r in ipairs(ORDER)do local f=R.Instance.new('Frame');f.Size=R.UDim2.fromOffset(104,104);Theme.Corner(f,8);f.Parent=sheet;Theme.CardBorder(f,r);cards[r]=f end
local function c3(c)return string.format('%d,%d,%d',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function seq(g)if not g then return''end;local t={};for _,k in ipairs(g.Color.A)do t[#t+1]=string.format('%.3f:%s',k.T,c3(k.V))end
 return table.concat(t,' ')..';'..tostring(g.Rotation or 0)..';'..tostring(g.Offset and g.Offset.X or 0)end
local function ud(u)return string.format('%g,%g,%g,%g',u.X.Scale,u.X.Offset,u.Y.Scale,u.Y.Offset)end
local function dump(pose)
 for _,r in ipairs(ORDER)do local f=cards[r];local s=f.AnimatedBorder
  print(table.concat({pose,r,'stroke',c3(s.Color),s.Thickness,s.Transparency,seq(s:FindFirstChild('BorderShine'))},';'))
  local o=f:FindFirstChild('RarityBorder')
  if o then for _,c in ipairs(o:GetChildren())do
   if c.Name=='Glow'or c.Name=='InnerLine'then local l=c.Line
    print(table.concat({pose,r,c.Name,ud(c.Position),c.UICorner.CornerRadius.Offset,c3(l.Color),l.Thickness,l.Transparency,seq(l:FindFirstChild('Shimmer'))},';'))
   elseif c.Name:find('^CrownGem')then
    print(table.concat({pose,r,'gem',ud(c.Position),c.Size.X.Offset,c3(c.BackgroundColor3),c3(c.Line.Color),c3(c.Core.BackgroundColor3),c.Core.Size.X.Offset},';'))
   elseif c.Name:find('^Sparkle')then
    print(table.concat({pose,r,'sparkle',ud(c.Position),c.Size.X.Offset,c.BackgroundTransparency},';'))
   end
  end end
 end
end
W.frames(5*60+12);dump('motion-a') -- 5.2 s into the loop
W.frames(48);dump('motion-b')
player:SetAttribute('FastMode',true);W.frames(10);dump('static')
