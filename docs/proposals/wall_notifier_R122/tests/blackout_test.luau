--!nocheck
-- R122: TrackBlackout (old vs new) + RefreshBarrier geometry against the real track (place file numbers).
local R=require('./roblox');local Bn=require('./wall_bundle')
local new=R.new;local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local env=setmetatable({Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,UDim=R.UDim,UDim2=R.UDim2,Color3=R.Color3,Enum=R.Enum,typeof=R.typeof,task=R.task},{__index=_G})
local function load(n)local fn=assert(loadstring(Bn[n],'='..n));setfenv(fn,setmetatable({script=new('ModuleScript')},{__index=env}));return fn()end
local New,Old=load('TrackBlackout'),load('OldBlackout');local Bar=load('RefreshBarrier')
-- R83 route: order 1,6,2,3,4,5,7 from Z=-100
local order={1,6,2,3,4,5,7};local len={[1]=180,[6]=450,[2]=650,[3]=850,[4]=1050,[5]=1300,[7]=1600}
local map=new('Folder');map:SetAttribute('FieldWidth',180);local z=-100
for _,id in ipairs(order)do map:SetAttribute('BiomeStartZ_'..id,z);map:SetAttribute('BiomeEndZ_'..id,z+len[id]);z+=len[id]end
local trackEnd=z
local function parts(B)local f=B.Build(map,new('Folder'),nil);local out={};for _,p in ipairs(f:GetChildren())do out[#out+1]=p end;return out end
local function ext(p)local c,s=p.CFrame.Position,p.Size;return c.X-s.X/2,c.X+s.X/2,c.Y-s.Y/2,c.Y+s.Y/2,c.Z-s.Z/2,c.Z+s.Z/2 end
local old,cur=parts(Old),parts(New)
local x0,x1,y0,y1=ext(old[1]);print(('OLD cover: X %.0f..%.0f (%.0f wide), Y %.0f..%.0f (%.0f tall)'):format(x0,x1,x1-x0,y0,y1,y1-y0))
x0,x1,y0,y1=ext(cur[1]);print(('NEW cover: X %.0f..%.0f (%.0f wide), Y %.0f..%.0f (%.0f tall)'):format(x0,x1,x1-x0,y0,y1,y1-y0))
check(#cur==#old,'same number of cover segments ('..#cur..')')
local covered={}
for _,p in ipairs(cur)do
 local a,b,c,d,e,f=ext(p)
 check(a==-94 and b==94,'cover spans exactly the track incl. side walls ±94 ('..a..','..b..')')
 check(c<=3 and d>=51 and d<=60,'cover encloses ground..side-wall top, not taller (Y '..c..'..'..d..')')
 check(p.Anchored and not p.CanCollide and not p.CanQuery and p.Transparency==0 and p:GetAttribute('TrackBlackout'),'cover flags unchanged')
 covered[#covered+1]={e,f}
end
-- every Z of the track is covered
for zz=-100,trackEnd,5 do local ok=false;for _,r in ipairs(covered)do if zz>=r[1]and zz<=r[2]then ok=true end end;check(ok,'Z '..zz..' covered')end
-- Tallest visible track content in the place file (non-invisible): side walls top 51, jungle tree crown 50.5, crystal 46.2
for _,h in ipairs({51,50.5,46.2})do check(h<=New.Top,'content top '..h..' under the roof')end
-- Camera blackout bounds agree with the cover box
local bounds=New.Bounds(map)
check(bounds.HalfWidth==94,'bounds half width 94')
local pts={{0,15,0,true},{80,40,500,true},{0,54,3000,true},{0,15,-140,false},{0,60,200,false},{120,20,200,false},{0,15,trackEnd+50,false},{93,-10,100,true}}
for _,q in ipairs(pts)do check(New.InBounds(bounds,R.Vector3.new(q[1],q[2],q[3]))==q[4],('InBounds(%d,%d,%d)==%s'):format(q[1],q[2],q[3],tostring(q[4])))end
-- any point the client blacks out is inside a cover part (no black screen while outside the box)
local n=0
for xx=-100,100,10 do for yy=-20,70,5 do for zz=-110,trackEnd+10,97 do
 if New.InBounds(bounds,R.Vector3.new(xx,yy,zz))then
  local inside=false;for _,p in ipairs(cur)do local a,b,c,d,e,f=ext(p);if xx>=a and xx<=b and yy>=c and yy<=d and zz>=e and zz<=f then inside=true end end
  n+=1;if not inside then check(false,('blackout point outside cover %d,%d,%d'):format(xx,yy,zz))end
 end
end end end
check(n>100,'sampled '..n..' in-bounds points')
-- Wall in front: hides the cover's front face from the lobby and still blocks the entrance
local line=new('Part');line.Size=R.Vector3.new(180,.24,1);line.CFrame=R.CFrame.new(0,4.12,-99.275)
local wall=Bar.Build(line,-100,new('Folder'))
local a,b,c,d,e,f=ext(wall);local ca,cb,cc,cd,ce=ext(cur[1])
print(('NEW wall: X %.0f..%.0f, Y %.2f..%.2f, Z %.0f..%.0f; cover front Z %.0f'):format(a,b,c,d,e,f,ce))
-- R153: the wall is the rook gate's opening (between the shafts, under the keys), no longer the cover's whole cross-section: the rest of the cover's front face
-- (x +-94, up to Y 55) lies behind the gate (gatehouse above 44, tower shafts, haunches) or is the dark strip over the panel. It still stands in front of it.
check(a>=-94 and b<=94 and c<=4.12 and d<=44,'wall inside the cover cross-section, under the gatehouse edge')
check(e<ce,'wall front face in front of the cover front (no z-fight)')
check(e<=-99.275 and f>=-100,'wall still straddles the track start line')
print(('blackout checks %d, fails %d'):format(checks,fails))
