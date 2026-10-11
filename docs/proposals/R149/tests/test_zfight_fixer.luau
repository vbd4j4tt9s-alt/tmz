--!nocheck
-- R149: ZFightFix149 (the saved place parts the installer cannot edit, nudged out of z-fighting when the server starts).
-- On the Roblox mock with the real module: its data is sane; on a mock map it moves exactly the parts that match a fix (path, name,
-- saved CFrame and Size) by exactly the fix's small local move, and nothing else: not a part moved / turned / resized since, not two
-- identical candidates (ambiguous), not twice (idempotent), and it logs one line. With the owner's place (place_tree.luau present,
-- written by tools/rbxl_geom.py --tree) every fix finds its one part and no other part of the map changes. MapService.new calls it
-- first, inside a pcall. Run by run_zfight.sh.
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do W.RS[n].Parent=folder end
local F=W.require(folder.ZFightFix149)
local logs={};W.env.print=function(...)local t={};for i=1,select('#',...)do t[i]=tostring(select(i,...))end;logs[#logs+1]=table.concat(t,' ')end
local function cf(t)return R.CFrame.new(t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9],t[10],t[11],t[12])end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local function sameCF(a,b,e)
 e=e or 1e-5
 if not(near(a.X,b.X,e)and near(a.Y,b.Y,e)and near(a.Z,b.Z,e))then return false end
 for i=1,3 do for j=1,3 do if not near(a.R[i][j],b.R[i][j],e)then return false end end end
 return true
end

-- 1. The data ------------------------------------------------------------------------------------------------------------------------
check(type(F.Fixes)=='table'and #F.Fixes>0,'there are fixes ('..#F.Fixes..')')
local seen={}
for i,f in ipairs(F.Fixes)do
 local tag='fix '..i..' ('..tostring(f.Name)..'): '
 check(type(f.Path)=='string'and #f.Path>0 and not f.Path:find('^/')and type(f.Name)=='string','path and name')
 check(type(f.CFrame)=='table'and #f.CFrame==12 and type(f.Size)=='table'and #f.Size==3 and type(f.Move)=='table'and #f.Move==3,tag..'CFrame (12), Size (3), Move (3)')
 local r=f.CFrame;local ortho=true
 for a=0,2 do for b=0,2 do
  local d=r[4+a]*r[4+b]+r[7+a]*r[7+b]+r[10+a]*r[10+b]
  if not near(d,a==b and 1 or 0,1e-3)then ortho=false end
 end end
 check(ortho,tag..'the saved rotation is a rotation')
 check(f.Size[1]>0 and f.Size[2]>0 and f.Size[3]>0,tag..'positive size')
 local m=math.sqrt(f.Move[1]^2+f.Move[2]^2+f.Move[3]^2)
 check(m>.01 and m<=.1,tag..('a few hundredths of a stud (%.3f)'):format(m))
 local key=f.Path..'/'..f.Name..'@'..table.concat(f.CFrame,',',1,3)
 check(not seen[key],tag..'listed once');seen[key]=true
end
check(F.Position<=.02 and F.Rotation<=.002 and F.Size<=.02,'tight match tolerances')

-- 2. A mock map with every fix's part, plus decoys -----------------------------------------------------------------------------------
local function makeMap()
 local map=R.new('Model');map.Name='ChestChaseMap'
 local function at(path)
  local node=map
  for name in path:gmatch('[^/]+')do
   local c=node:FindFirstChild(name);if not c then c=R.new('Folder');c.Name=name;c.Parent=node end;node=c
  end
  return node
 end
 local targets,decoys={},{}
 for i,f in ipairs(F.Fixes)do
  local parent=at(f.Path)
  local p=R.new(i%2==0 and'Part'or'WedgePart');p.Name=f.Name;p.Size=V3(f.Size[1],f.Size[2],f.Size[3]);p.CFrame=cf(f.CFrame);p.Parent=parent
  targets[i]=p
  -- a decoy: same name, one stud away
  local d=R.new('Part');d.Name=f.Name;d.Size=p.Size;d.CFrame=p.CFrame+V3(1,0,0);d.Parent=parent;decoys[#decoys+1]=d
 end
 return map,targets,decoys,at
end
local map,targets,decoys,at=makeMap()
local before={};for _,d in ipairs(map:GetDescendants())do if d:IsA('BasePart')then before[d]=d.CFrame end end
logs={}
local n=F.Apply(map)
check(n==#F.Fixes,('every fix moved its part (%d of %d)'):format(n,#F.Fixes))
check(map:GetAttribute('ZFightFix149')==n,'the map remembers it ran')
check(#logs==1 and logs[1]:find('%[R149%]')and logs[1]:find(('%d of %d'):format(n,#F.Fixes),1,true),'one log line: '..tostring(logs[1]))
for i,f in ipairs(F.Fixes)do
 local p=targets[i]
 check(sameCF(p.CFrame,before[p]*CF(f.Move[1],f.Move[2],f.Move[3])),'fix '..i..': moved by exactly its move, in its own frame')
 check(p:GetAttribute('ZFightFix149')==true,'fix '..i..': marked')
 check(p.Size==V3(f.Size[1],f.Size[2],f.Size[3]),'fix '..i..': size untouched')
end
local untouched=true;for _,d in ipairs(decoys)do if not sameCF(d.CFrame,before[d],0)or d:GetAttribute('ZFightFix149')then untouched=false end end
check(untouched,'decoys one stud away are never moved')
-- idempotent
local snap={};for _,d in ipairs(map:GetDescendants())do if d:IsA('BasePart')then snap[d]=d.CFrame end end
check(F.Apply(map)==0,'a second Apply does nothing')
map:SetAttribute('ZFightFix149',nil)
check(F.Apply(map)==0,'even with the map flag cleared, a moved part no longer matches (and is marked): nothing moves twice')
local still=true;for d,c in pairs(snap)do if not sameCF(d.CFrame,c,0)then still=false end end
check(still,'nothing moved on the repeats')
check(F.Apply(nil)==0,'no map: nothing, no error')

-- 3. Parts that changed since the place was saved are left alone ---------------------------------------------------------------------
local map2,targets2,_,at2=makeMap()
local f1,f2,f3=F.Fixes[1],F.Fixes[2],F.Fixes[3]
targets2[1].CFrame=targets2[1].CFrame*R.CFrame.Angles(0,math.rad(10),0)                       -- turned
targets2[2].Size=targets2[2].Size+V3(.1,0,0)                                                  -- resized
local twin=R.new('Part');twin.Name=f3.Name;twin.Size=targets2[3].Size;twin.CFrame=targets2[3].CFrame;twin.Parent=targets2[3].Parent -- two identical candidates
local b1,b2,b3=targets2[1].CFrame,targets2[2].CFrame,targets2[3].CFrame
logs={}
local n2=F.Apply(map2)
check(n2==#F.Fixes-3,('a turned, a resized and an ambiguous part are skipped (%d moved)'):format(n2))
check(sameCF(targets2[1].CFrame,b1,0)and sameCF(targets2[2].CFrame,b2,0)and sameCF(targets2[3].CFrame,b3,0)and sameCF(twin.CFrame,b3,0),'and none of them moved')
check(logs[1]and logs[1]:find('3 skipped',1,true),'the log counts them: '..tostring(logs[1]))
-- a part moved a little more than the tolerance is skipped, one moved a little less is fixed
local map3,targets3=makeMap()
targets3[1].CFrame=targets3[1].CFrame+V3(0,.03,0);targets3[2].CFrame=targets3[2].CFrame+V3(0,.01,0)
F.Apply(map3)
check(not targets3[1]:GetAttribute('ZFightFix149')and targets3[2]:GetAttribute('ZFightFix149'),'position tolerance .02: .03 off is skipped, .01 off is fixed')

-- 4. The owner's place: each fix finds exactly one part, nothing else changes ------------------------------------------------------
local okTree,tree=pcall(require,'./place_tree')
if okTree and type(tree)=='table'then
 local root=Z.loadPlace(tree,W.workspace)
 local all={};for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then all[d]={CF=d.CFrame,Size=d.Size}end end
 for i,f in ipairs(F.Fixes)do check(#F.Find(root,f)==1,'place: fix '..i..' ('..f.Path..'/'..f.Name..') matches exactly one part ('..#F.Find(root,f)..')')end
 logs={}
 local moved=F.Apply(root)
 check(moved==#F.Fixes,('place: all %d fixes applied (%d)'):format(#F.Fixes,moved))
 local changed=0;local wrong=0
 for d,s in pairs(all)do
  if not sameCF(d.CFrame,s.CF,0)or d.Size~=s.Size then
   changed+=1
   if not d:GetAttribute('ZFightFix149')then wrong+=1 end
  end
 end
 check(changed==#F.Fixes and wrong==0,('place: only the %d fixed parts changed (%d changed, %d unmarked)'):format(#F.Fixes,changed,wrong))
 print('place checks ran on the owner\'s place ('..#tree..' instances)')
else
 print('(no place_tree.luau: the owner\'s place checks were skipped)')
end

-- 5. MapService.new runs it first (before any start-up pass moves the map), inside a pcall --------------------------------------------
local src=W.B.MapService
local call=src:find('require(script.Parent.ZFightFix149).Apply(mapRoot)',1,true)
local art=src:find('local art=require(script.Parent.BiomeVisuals)',1,true)
check(call and art and call<art,'MapService.new calls ZFightFix149.Apply before the map passes')
local line=call and src:sub(src:sub(1,call):match('.*()\n')or 1,src:find('\n',call,true)or #src)
check(line and line:find('pcall',1,true),'inside a pcall (a problem there never stops the map)')
for _,pass in ipairs({'TrackExpansion83','ForestLayout87','GardenBaseLayout','HideBushes124','MarketLayout'})do
 local at3=src:find('require(script.Parent.'..pass..')',1,true)
 check(at3 and call<at3,'before '..pass)
end
W.env.print=print
print(('%d checks, %d failed'):format(checks,fails))
if fails>0 then error('test_zfight_fixer failed')end
