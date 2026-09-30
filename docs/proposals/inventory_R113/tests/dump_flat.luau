--!nocheck
-- Dumps the flat fallback icons (low graphics / failed build) as nested boxes for an HTML render.
local W=require('./world');local F=require('./fixtures');local R=W.R
local Players=W.service('Players');local player=R.new('Player');player.Parent=Players;Players.LocalPlayer=player
player:SetAttribute('FastMode',true)
local P=W.module('ItemPictures');local h=R.new('Folder')
local tools={F.pack(W,h,1,'Pack01',1,'None'),F.pack(W,h,2,'Pack05',2.5,'Gold'),F.seed(W,h,'SunflowerSeed',1,'None'),F.seed(W,h,'BluebellSeed',1,'Gold'),
 F.fruit(W,h,'AppleSeed',1,'None'),F.fruit(W,h,'SunflowerSeed',1,'None'),F.fruit(W,h,'BluebellSeed',1,'Diamond'),F.shovel(W,h),F.bat(W,h)}
local function c3(c)return string.format('"#%02x%02x%02x"',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function node(f)
 local kids={}
 for _,k in ipairs(f:GetChildren())do if k._class=='Frame'then kids[#kids+1]=node(k)end end
 local corner=f:FindFirstChildOfClass('UICorner');local g=f:FindFirstChildOfClass('UIGradient');local s=f:FindFirstChildOfClass('UIStroke')
 local p,z=f.Position,f.Size
 local a=f.AnchorPoint or R.Vector2.new(0,0)
 return string.format('{"ax":%.2f,"ay":%.2f,"x":%.3f,"y":%.3f,"w":%.3f,"h":%.3f,"c":%s,"t":%.2f,"r":%.1f,"round":%s,"g":%s,"s":%s,"k":[%s]}',a.X,a.Y,p.X.Scale,p.Y.Scale,z.X.Scale,z.Y.Scale,c3(f.BackgroundColor3 or R.Color3.new(0,0,0)),f.BackgroundTransparency or 0,f.Rotation or 0,
  corner and tostring(corner.CornerRadius.Scale)or'null',g and string.format('[%s,%s,%d]',c3(g.Color.A),c3(g.Color.B or g.Color.A),g.Rotation)or'null',
  s and c3(s.Color)or'null',table.concat(kids,','))
end
local out={}
for i,t in ipairs(tools)do local f=R.new('Frame');f.Size=R.UDim2.fromOffset(100,100);P.Show(f,t,2);local icon=f:FindFirstChild('FlatIcon')
 local kids={};for _,k in ipairs(icon:GetChildren())do if k._class=='Frame'then kids[#kids+1]=node(k)end end
 out[#out+1]='['..table.concat(kids,',')..']'
end
print('['..table.concat(out,',')..']')
