--!nocheck
-- R154 B1: the shared helper SmallShadow154 on the Roblox mock (the real module): the 1.5-stud rule, parts it must not touch, no workspace listener.
local W=require('./world');local R=W.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local S=W.module('SmallShadow154')
local function part(x,y,z,props)local p=R.new('Part');p._props.Size=V3(x,y,z);for k,v in pairs(props or{})do p._props[k]=v end;return p end

check(S.MaxSide==1.5,'the rule is 1.5 studs')
check(S.Keeps(V3(1.5,.1,.1))==true and S.Keeps(V3(.1,1.5,.1))==true and S.Keeps(V3(.1,.1,1.5))==true,'a part whose largest side is exactly 1.5 keeps its shadow')
check(S.Keeps(V3(1.49,1.49,1.49))==false and S.Keeps(V3(.2,.2,.2))==false and S.Keeps(V3(1.4,1.2,1.499))==false,'a part whose largest side is under 1.5 does not')
check(S.Keeps(V3(30,.2,.2))==true and S.Keeps(V3(.3,12,.3))==true,'a long thin part (a rail, a pole) is not small: its largest side counts')

local small=part(.5,.5,.5)
check(S.Part(small)==small and small._props.CastShadow==false,'Part: a small part (CastShadow never written, the default true) is switched off and returned')
local big=part(4,2,3)
S.Part(big);check(rawget(big._props,'CastShadow')==nil,'Part: a big part is not written at all (no new property in the fingerprint)')
local bigOn=part(4,2,3,{CastShadow=true})
S.Part(bigOn);check(bigOn._props.CastShadow==true,'Part: a big part that casts keeps casting')
local smallOff=part(.5,.5,.5,{CastShadow=false})
S.Part(smallOff);check(smallOff._props.CastShadow==false,'Part: a small part that already casts nothing stays that way')
local bigOff=part(5,5,5,{CastShadow=false})
S.Part(bigOff);check(bigOff._props.CastShadow==false,'Part: a big part that casts nothing is never switched ON')

-- Tree: a model scaled after it was built (the market's fruit): decided at the final sizes, root included, non-parts ignored
local model=R.new('Model');local a=part(.4,.4,.4);local b=part(2,2,2);local c=part(.3,3,.3);local d=part(.2,.2,.2,{CastShadow=false});local light=R.new('PointLight')
a.Parent=model;b.Parent=model;c.Parent=model;d.Parent=model;light.Parent=a
local n=S.Tree(model)
check(n==1 and a._props.CastShadow==false and rawget(b._props,'CastShadow')==nil and rawget(c._props,'CastShadow')==nil,'Tree: only the small parts that cast are switched off ('..n..' of 4 parts)')
local ownRoot=part(.5,.5,.5);local child=part(.5,.5,.5);child.Parent=ownRoot
check(S.Tree(ownRoot)==2 and ownRoot._props.CastShadow==false and child._props.CastShadow==false,'Tree: the root itself and its descendants')
-- a character or avatar is not passed to the helper by any builder; if one were, its small parts would go: the rule has no exception, so the builders are the guard
-- (run_census154.sh checks the finished world: characters / avatars are as they were)

-- no listener anywhere (perf rule: no workspace-wide DescendantAdded scan)
local listeners=0
for _,o in ipairs({W.workspace,W.game,model,a})do local sig=o.DescendantAdded;if sig and sig._c then for _ in pairs(sig._c)do listeners+=1 end end end
check(listeners==0,'the helper connects to nothing (no DescendantAdded listener): '..listeners)
print(string.format('%d checks, %d failed',checks,fails))
if fails>0 then error('small shadow checks failed',0)end
print('ALL PASS')
