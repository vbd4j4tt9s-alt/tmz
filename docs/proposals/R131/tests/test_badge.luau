--!nocheck
-- R131 (owner): garden owner name bubbles no longer cover other gardens. Real GardenFenceArt on the mock: new and old
-- (R99) badges are sized in studs with a small pixel floor and are not drawn on top of everything; no blank circle
-- when there is no avatar picture. Plus the on-screen size at several distances, before and after.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players');function Players.GetUserThumbnailAsync()return 'rbxthumb://x',true end
local SSS=W.service('ServerScriptService');local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
local G=R.new('ModuleScript');G.Name='GardenFenceArt';G._source='GardenFenceArt';G.Parent=folder
local Art=W.require(G)
local function base(id,name)
 local b=R.new('Model');b.Name='Base';b.Parent=W.workspace
 local pad=R.new('Part');pad.Name='Pad';pad.Size=V3(60,1,60);pad.CFrame=CF(0,0,0);pad.Parent=b
 b:SetAttribute('BaseOwnerUserId',id);return b
end
-- New garden
local b1=base(5);local ok,err=pcall(Art.Build,b1,1)
check(ok,'fence builds: '..tostring(err))
Art.UpdateOwner(b1,'Sunny')
local gui=b1:FindFirstChild('GardenOwnerBadge',true)
check(gui and gui.Enabled and gui.OwnerName.Text=='Sunny','badge shows the owner name')
check(gui and gui.AlwaysOnTop==false,'not drawn on top of everything (nearer gardens hide it)')
check(gui and gui.Size.X.Scale==11 and gui.Size.Y.Scale==7 and gui.Size.X.Offset<=40 and gui.Size.Y.Offset<=24,'size in studs (11 x 7) with a small pixel floor')
check(gui and gui.Portrait.Visible==true,'avatar picture shown for a real player')
-- Studio test player: no picture, no blank circle
local b2=base(-2);Art.Build(b2,1);Art.UpdateOwner(b2,'Player2')
local g2=b2:FindFirstChild('GardenOwnerBadge',true)
check(g2 and g2.Portrait.Visible==false and g2.OwnerName.Position.Y.Scale<.5,'no avatar: name only, centred (no blank circle)')
-- An R99 badge already in the place is restyled on the next owner update.
local b3=base(9);local root=R.new('Model');root.Name='GardenFence34';root:SetAttribute('Tier',1);root:SetAttribute('DesignRevision',99);root.Parent=b3
local anchor=R.new('Part');anchor.Parent=root
local old=R.new('BillboardGui');old.Name='GardenOwnerBadge';old.Size=R.UDim2.fromOffset(210,128);old.AlwaysOnTop=true;old.Parent=anchor
local p=R.new('ImageLabel');p.Name='Portrait';p.Size=R.UDim2.fromOffset(78,78);p.Parent=old
local n=R.new('TextLabel');n.Name='OwnerName';n.Position=R.UDim2.fromOffset(4,85);n.Parent=old
Art.UpdateOwner(b3,'Old')
check(old.AlwaysOnTop==false and old.Size.X.Scale==11 and old:GetAttribute('BadgeRevision')==131,'old badges are restyled in place')
-- On-screen size (720p, 70 degree view) and the gap to the garden 64 studs below it.
local f=360/math.tan(math.rad(35))
print('distance  before(px)  after(px)   gap to its garden(px)')
for _,d in ipairs({40,100,200,400,800})do
 local aw,ah=11*f/d+gui.Size.X.Offset,7*f/d+gui.Size.Y.Offset;local gap=64*f/d
 print(('%5d     210 x 128   %3d x %3d   %d'):format(d,aw,ah,gap))
 if d>=100 then check(ah/2<gap,('at %d studs the badge (%d px tall) stays above its garden (%d px gap)'):format(d,ah,gap))end
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
