--!nocheck
-- R132 (owner: "for each player add a home emoji at the middle of their base"): the real HomeMarker client on the mock.
-- Only your own base gets the 🏠, over the middle of its pad (the centre aisle), sized in studs; it follows a base
-- change and goes away when you have no base.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
local function base(i,x,owner)
 local b=R.new('Model');b.Name='Base'..i;b.Parent=bases;b:SetAttribute('BaseOwnerUserId',owner)
 local pad=R.new('Part');pad.Name='Pad';pad.Size=V3(110,1,190);pad.CFrame=CF(x,3,-50);pad.Parent=b
 return b,pad
end
local b1,p1=base(1,-200,12);local b2,p2=base(2,0,0);local b3,p3=base(3,200,0)
local script=R.new('LocalScript');script.Name='HomeMarker'
W.load('HomeMarker',script)
W.frames(70)
local function markers()local n=0;for _,g in ipairs(pg:GetChildren())do if g.Name=='HomeMarker'then n+=1 end end;return n end
check(markers()==0,'no base yet: no marker')
-- The server gives me base 2.
b2:SetAttribute('BaseOwnerUserId',7);W.frames(70)
local gui=pg:FindFirstChild('HomeMarker')
check(gui and gui.Adornee==p2,'marker sits on my own base pad')
check(markers()==1,'one marker only')
check(gui and gui.Icon and gui.Icon.Text=='🏠','it is the home emoji')
check(gui and gui.AlwaysOnTop==false and gui.LightInfluence==0,'not drawn through walls, unlit')
check(gui and gui.Size.X.Scale>=5 and gui.Size.X.Scale<=8 and gui.Size.X.Offset<=30 and gui.Size.Y.Scale==gui.Size.X.Scale,'sized in studs (about 6.5) with a small pixel floor')
local y1=gui and gui.StudsOffsetWorldSpace.Y
check(y1 and y1>p2.Size.Y/2+9 and y1<p2.Size.Y/2+11,('floats about 10 studs over the middle (%.2f)'):format(y1 or -1))
check(gui and math.abs(gui.StudsOffsetWorldSpace.X)<1e-6 and math.abs(gui.StudsOffsetWorldSpace.Z)<1e-6,'straight above the pad centre')
W.frames(40);local y2=gui and gui.StudsOffsetWorldSpace.Y
check(y2 and math.abs(y2-y1)>.01 and math.abs(y2-(p2.Size.Y/2+10))<=.46,'bobs gently')
check(gui and gui.MaxDistance>=600,'visible from the track')
-- Someone else's base never gets my marker; a base change moves it.
b2:SetAttribute('BaseOwnerUserId',0);b3:SetAttribute('BaseOwnerUserId',7);W.frames(70)
gui=pg:FindFirstChild('HomeMarker')
check(gui and gui.Adornee==p3 and markers()==1,'follows me to my new base')
b3:SetAttribute('BaseOwnerUserId',0);W.frames(70)
check(markers()==0,'no base: marker removed')
-- Back again after a respawn wiped it.
b1:SetAttribute('BaseOwnerUserId',7);W.frames(70);gui=pg:FindFirstChild('HomeMarker')
check(gui and gui.Adornee==p1,'comes back on the next base')
gui:Destroy();W.frames(70)
check(markers()==1 and pg:FindFirstChild('HomeMarker').Adornee==p1,'rebuilt if something removed it')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
