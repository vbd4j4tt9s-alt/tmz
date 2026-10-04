--!nocheck
-- R147 client side on the Roblox mock, with the real scripts: MysteryPackClient (the label over every base's mystery
-- pedestal, the take prompt, the burst, the spin), KeeperSpeedLabels (the "SPEED NEEDED" pill over every keeper) and the
-- Speed curve they rest on (Progression81.PointsFor must be the exact inverse of Progression81.Speed over the live
-- BalanceValues81.PointCurve). Pedestals and keepers are built by hand with the attributes / tags the server stamps
-- (the server half is in test_mystery.luau). Mock time = R.clock = server time.
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-9)end
local function rgb(c,r,g,b)return c and math.abs(c.R*255-r)<.5 and math.abs(c.G*255-g)<.5 and math.abs(c.B*255-b)<.5 end
F.packAssets(W)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.DisplayName='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
-- Debris is not part of the shared mock: remove items after their time.
W.service('Debris').AddItem=function(_,o,t)R.task.delay(t,function()o:Destroy()end)end
local workspace=W.workspace;local CS=W.CS
R.clock=20000*86400+3600
local M=W.module('MysteryPackRules');local D=W.module('DailyRewards')
local function adv(seconds)for _=1,math.floor(seconds/.5+.5)do R.advance(.5)end end
local function pedestal(name,attrs,withPrompt)
 local m=R.new('Model');m.Name=name
 local a=R.new('Part');a.Name='PackAnchor';a.Size=R.Vector3.new(1,1,1);a.CFrame=R.CFrame.new(0,9,0);a.Parent=m
 local pr;if withPrompt~=false then pr=R.new('ProximityPrompt');pr.Name='TakeMysteryPack';pr.Enabled=true;pr.Parent=a end
 for k,v in pairs(attrs or{})do m:SetAttribute(k,v)end
 m.Parent=workspace;CS:AddTag(m,'MysteryPedestal');return m,a,pr
end
local function label(m)return m:FindFirstChild('MysteryLabel')end
local function bursts()local n=0;for _,c in ipairs(workspace:GetChildren())do if c.Name=='MysteryBurst'then n+=1 end end;return n end
local function lastBurst()local last;for _,c in ipairs(workspace:GetChildren())do if c.Name=='MysteryBurst'then last=c end end;return last end

-- 1. MysteryPackClient --------------------------------------------------------------------------------------------------
-- A pedestal that exists before the script starts (found with GetTagged), one that is added later (added signal).
local early,earlyAnchor,earlyPrompt=pedestal('Early',{State='Empty'})
local ms=R.new('LocalScript');ms.Name='MysteryPackClient'
local ok,err=pcall(W.load,'MysteryPackClient',ms);check(ok,'MysteryPackClient loads: '..tostring(err))
local g=label(early)
check(g~=nil and g:IsA('BillboardGui')and g.Adornee==earlyAnchor and g.MaxDistance==160 and g.AlwaysOnTop==false and g.LightInfluence==0,'a pedestal that was already there gets its label (BillboardGui "MysteryLabel" on the pack anchor)')
check(g.Enabled==false and earlyPrompt.Enabled==false,'Empty: the label is off and the prompt is disabled')
check(g.Title and g.Status and g.Bar and g.Bar.Fill,'the label has Title, Status and a Bar with a Fill')
local mine,mineAnchor,minePrompt=pedestal('Mine',{State='Empty'})
local label2=label(mine)
check(label2~=nil and label2.Enabled==false,'a pedestal tagged after the script started gets a label too (GetInstanceAddedSignal)')
local other,otherAnchor,otherPrompt=pedestal('Other',{State='Empty'})
-- Locked: mine.
local UNLOCK=R.clock+900
mine:SetAttribute('OwnerUserId',77);mine:SetAttribute('OwnerName','Tester');mine:SetAttribute('Stage',1);mine:SetAttribute('NextAt',(20001)*86400)
mine:SetAttribute('UnlockAt',UNLOCK);mine:SetAttribute('State','Locked')
local gm=label(mine)
check(gm.Enabled==true,'Locked: the label shows')
check(gm.Title.Text=='❓ YOUR MYSTERY PACK'and rgb(gm.Title.TextColor3,190,140,255),'title: ❓ YOUR MYSTERY PACK (violet)')
check(gm.Status.Text=='🔒 15:00','status: 🔒 15:00 ('..gm.Status.Text..')')
check(gm.Bar.Visible==true and near(gm.Bar.Fill.Size.X.Scale,0,1e-9)and gm.Bar.Fill.Size.Y.Scale==1 and rgb(gm.Bar.Fill.BackgroundColor3,190,140,255),'the bar is empty and violet')
check(minePrompt.Enabled==false,'the prompt stays off while locked, even for the owner')
adv(300)
check(gm.Status.Text=='🔒 10:00'and near(gm.Bar.Fill.Size.X.Scale,1/3,1e-9),'5 minutes later: 🔒 10:00 and a third of the bar (counts down with the server clock)')
adv(599)
check(gm.Status.Text=='🔒 0:01'and near(gm.Bar.Fill.Size.X.Scale,1-1/900,1e-9),'at 899 s: 🔒 0:01 and the bar almost full')
adv(5)
check(gm.Status.Text=='🔒 0:00'and gm.Bar.Fill.Size.X.Scale==1,'past UnlockAt it waits at 0:00 until the server flips the state (never negative)')
-- Someone else's locked pedestal.
other:SetAttribute('OwnerUserId',999);other:SetAttribute('OwnerName','Ben D');other:SetAttribute('UnlockAt',R.clock+450);other:SetAttribute('State','Locked')
local go=label(other)
check(go.Title.Text=="❓ BEN D'S MYSTERY PACK",'another player\'s: ❓ BEN D\'S MYSTERY PACK ('..go.Title.Text..')')
check(go.Status.Text=='🔒 7:30'and near(go.Bar.Fill.Size.X.Scale,.5,1e-9),'🔒 7:30, half the bar')
check(otherPrompt.Enabled==false,'and the prompt is off for me')
-- A locked pedestal without UnlockAt yet shows the full time.
local fresh,_,freshPrompt=pedestal('Fresh',{State='Locked',OwnerUserId=999,OwnerName='Cy'})
check(label(fresh).Status.Text=='🔒 15:00','no UnlockAt (yet): the full 15:00')
-- Ready: mine.
mine:SetAttribute('UnlockAt',nil);mine:SetAttribute('Variant','Pack03');local b0=bursts()
mine:SetAttribute('State','Ready')
check(gm.Title.Text=='✨ YOUR MYSTERY PACK'and rgb(gm.Title.TextColor3,255,214,90),'Ready, mine: ✨ YOUR MYSTERY PACK in gold')
check(gm.Status.Text=='UNLOCKED! TAKE IT 🎁'and rgb(gm.Status.TextColor3,255,214,90),'status: UNLOCKED! TAKE IT 🎁')
check(gm.Bar.Visible==true and gm.Bar.Fill.Size.X.Scale==1 and rgb(gm.Bar.Fill.BackgroundColor3,255,214,90),'the bar is full and gold')
check(minePrompt.Enabled==true,'the prompt turns on for the owner')
check(bursts()==b0+1,'a burst of light when MY pack unlocks (Locked -> Ready)')
local ring=lastBurst()
check(ring and rgb(ring.Color,255,214,90)and near(ring.Size.Y,16,1e-9)and ring.Shape==R.Enum.PartType.Cylinder and ring.Anchored and not ring.CanCollide and not ring.CanQuery and not ring.CanTouch,'a big gold ring, anchored and not solid')
check(ring and near(ring.Position.Y,9,1e-9)and near(ring.Position.X,0,1e-9),'around the pack anchor')
check(bursts()==b0+1,'(and only one)')
mine:SetAttribute('OwnerName','Tester2');check(bursts()==b0+1,'other attribute changes make no burst')
mine:SetAttribute('State','Ready');check(bursts()==b0+1,'setting the same state again makes no burst')
adv(2);check(bursts()==0,'the ring is cleaned up after 1.4 s')
-- Ready: someone else's pedestal; no burst, no prompt.
local b1=bursts()
other:SetAttribute('UnlockAt',nil);other:SetAttribute('Variant','Pack02');other:SetAttribute('State','Ready')
check(go.Status.Text=='UNLOCKED!'and go.Title.Text=="✨ BEN D'S MYSTERY PACK",'Ready, theirs: UNLOCKED! and no "take it": '..go.Status.Text)
check(otherPrompt.Enabled==false,'the prompt stays off for me')
check(bursts()==b1,'no burst for somebody else\'s pack')
-- Ownership changes flip the prompt (a base changing hands).
other:SetAttribute('OwnerUserId',77);check(otherPrompt.Enabled==true and go.Status.Text=='UNLOCKED! TAKE IT 🎁','if the owner becomes me: the prompt turns on and the text changes')
other:SetAttribute('OwnerUserId',999);check(otherPrompt.Enabled==false,'and off again')
-- Claimed.
local nextAt=R.clock+10000
mine:SetAttribute('NextAt',nextAt);local b2=bursts()
mine:SetAttribute('State','Claimed')
check(gm.Title.Text=='✓ TAKEN TODAY'and rgb(gm.Title.TextColor3,120,236,110),'Claimed: ✓ TAKEN TODAY (mint)')
check(gm.Status.Text=='NEW PACK IN 2h 46m','status: NEW PACK IN 2h 46m ('..gm.Status.Text..')')
check(gm.Bar.Visible==false,'no bar')
check(minePrompt.Enabled==false,'the prompt is off again')
check(bursts()==b2+1 and rgb(lastBurst().Color,120,236,110)and near(lastBurst().Size.Y,9,1e-9),'a small mint burst when I take it')
adv(120)
check(gm.Status.Text=='NEW PACK IN 2h 44m','the countdown ticks while claimed ('..gm.Status.Text..')')
adv(9800)
check(gm.Status.Text=='NEW PACK IN 1m 20s','near midnight: NEW PACK IN 1m 20s ('..gm.Status.Text..')')
mine:SetAttribute('NextAt',R.clock+75);check(gm.Status.Text=='NEW PACK IN 1m 15s','under an hour: minutes and seconds')
adv(80);check(gm.Status.Text=='NEW PACK IN 0s','never negative')
mine:SetAttribute('NextAt',nil);check(gm.Status.Text=='NEW PACK IN 0s','no NextAt: 0s')
-- Not mine, claimed: no burst (the other player took it).
local b3=bursts();other:SetAttribute('NextAt',R.clock+3700);other:SetAttribute('State','Claimed')
check(label(other).Title.Text=='✓ TAKEN TODAY'and label(other).Status.Text=='NEW PACK IN 1h 1m'and bursts()==b3,'someone else\'s taken pedestal: ✓ TAKEN TODAY, NEW PACK IN 1h 1m, no burst')
-- Back to Empty (the owner left).
mine:SetAttribute('OwnerUserId',nil);mine:SetAttribute('State','Empty')
check(gm.Enabled==false and minePrompt.Enabled==false,'Empty again: the label is off and the prompt disabled')
-- Locked again the next day (counts from a new UnlockAt).
mine:SetAttribute('OwnerUserId',77);mine:SetAttribute('Variant',nil);mine:SetAttribute('UnlockAt',R.clock+900);mine:SetAttribute('State','Locked')
check(gm.Enabled==true and gm.Status.Text=='🔒 15:00'and rgb(gm.Title.TextColor3,190,140,255)and bursts()==0,'the next day: back to 🔒 15:00 in violet, no burst for Locked')
-- A prompt that arrives after the label (replication order) is picked up.
local late,lateAnchor=pedestal('Late',{State='Ready',OwnerUserId=77,OwnerName='Tester'},false)
local latePrompt=R.new('ProximityPrompt');latePrompt.Name='TakeMysteryPack';latePrompt.Enabled=false;latePrompt.Parent=lateAnchor
check(latePrompt.Enabled==true,'a prompt that replicates after the pedestal is switched on for its owner')
local odd=R.new('Model');odd.Name='Odd';odd.Parent=workspace
local b5=bursts()
local seen,_,seenPrompt=pedestal('AlreadyReady',{State='Ready',OwnerUserId=77,OwnerName='Tester',Variant='Pack02',Stage=1})
check(label(seen).Status.Text=='UNLOCKED! TAKE IT 🎁'and seenPrompt.Enabled==true and bursts()==b5,'a pedestal that is already Ready when the client first sees it: shown at once, no burst (nothing "just" unlocked)')
local joiner,_,joinPrompt=pedestal('Joiner',{State='Empty'})
joiner:SetAttribute('OwnerUserId',77);joiner:SetAttribute('Variant','Pack04');joiner:SetAttribute('State','Ready')
check(joinPrompt.Enabled==true and bursts()==b5+1,'my base waking up with the pack already unlocked (Empty -> Ready) also bursts and lights the prompt')
adv(2)
local nobody=pedestal('Nobody',{},true)
check(label(nobody)~=nil and label(nobody).Enabled==false,'a pedestal with no attributes at all counts as Empty')
-- The spin and bob of the pack on the pedestal (near the camera only).
local holder=R.new('Model');holder.Name='MysteryPack';holder.Parent=mine
local pk=R.new('Model');pk.Name='SeedPacket';pk:SetAttribute('MysteryOrigin',R.CFrame.new(0,9,0));pk.Parent=holder
W.Run.RenderStepped:Fire(1/60)
local py=pk:GetPivot().Position.Y
check(near(py,9+math.sin(R.clock*1.6)*.35,1e-6),'the pack bobs around its origin ('..tostring(py)..')')
local pivotBefore=pk:GetPivot()
R.clock+=1;W.Run.RenderStepped:Fire(1/60)
check(near(pk:GetPivot().Position.Y,9+math.sin(R.clock*1.6)*.35,1e-6)and not near(pk:GetPivot().Position.Y,pivotBefore.Position.Y,1e-6),'and moves with time')
local lv=pk:GetPivot().LookVector
check(near(lv.X,-math.sin(R.clock*.8%(math.pi*2)),1e-6)and near(lv.Z,-math.cos(R.clock*.8%(math.pi*2)),1e-6)and near(lv.Y,0,1e-9),'turning about the vertical axis (0.8 rad/s)')
W.workspace.CurrentCamera.CFrame=R.CFrame.new(900,20,0);pk:PivotTo(R.CFrame.new(0,9,0));W.Run.RenderStepped:Fire(1/60)
check(near(pk:GetPivot().Position.Y,9,1e-9),'a pack more than 130 studs from the camera is left alone')
W.workspace.CurrentCamera.CFrame=R.CFrame.new(0,20,-30)
W.Gui.ReducedMotionEnabled=true;pk:PivotTo(R.CFrame.new(0,9,0));W.Run.RenderStepped:Fire(1/60)
check(near(pk:GetPivot().Position.Y,9,1e-9),'with reduced motion nothing spins')
W.Gui.ReducedMotionEnabled=false
-- Reduced motion: the burst ring does not tween (the sparks still show).
W.Gui.ReducedMotionEnabled=true;local b4=bursts()
mine:SetAttribute('UnlockAt',nil);mine:SetAttribute('State','Ready')
check(bursts()==b4+1 and lastBurst().Transparency==1,'reduced motion: the ring is invisible (no tween), the burst still happens')
W.Gui.ReducedMotionEnabled=false
-- Removing the tag removes the label.
local g3=label(late);CS:RemoveTag(late,'MysteryPedestal')
check(g3.Parent==nil,'a pedestal that loses its tag loses its label')
late:SetAttribute('State','Locked');check(g3.Parent==nil,'(and is not updated any more)')
-- Teardown.
ms.Destroying:Fire()
check(label(mine)==nil and label(early)==nil and label(other)==nil,'removing the script removes every label')
local after=pedestal('After',{State='Locked',OwnerUserId=77})
check(label(after)==nil,'and new pedestals get none')
mine:SetAttribute('State','Claimed');check(true,'(no errors after teardown)')

-- 2. Progression81: PointsFor is the exact inverse of Speed ----------------------------------------------------------------
local Progress=W.module('Progression81');local T=W.module('BalanceValues81');local Points=W.module('SpeedPoints')
local K=T.PointCurve
local function inverseOk(v)
 local n=Progress.PointsFor(v);local s=Progress.Speed(n);local below=n>0 and Progress.Speed(n-1)or-math.huge
 return s>=v-1e-6 and below<v,n,s,below
end
local failures={};local tested=0
local function inverse(v,tag)
 tested+=1;local ok,n,s,below=inverseOk(v)
 if not ok and #failures<8 then failures[#failures+1]=('%s v=%.12g n=%.17g Speed(n)=%.12g Speed(n-1)=%.12g'):format(tag,v,n,s,below)end
 return ok
end
check(Progress.PointsFor(24)==0 and Progress.PointsFor(0)==0 and Progress.PointsFor(-5)==0 and Progress.PointsFor(12)==0 and Progress.Speed(0)==24,'speeds up to 24 (a new player) need 0 points')
check(Progress.PointsFor(nil)==0 and Progress.PointsFor('x')==0 and Progress.PointsFor('50')==Progress.PointsFor(50),'nil / junk -> 0, numeric text is read as a number')
check(#K==11 and K[1][1]==0 and K[1][2]==24 and K[#K][1]==100000000000 and K[#K][2]==500,'the live curve: 24 at 0 points ... 500 at 100B points')
-- Every knot: exactly its points.
local knotsOk=true;for i=1,#K do if Progress.PointsFor(K[i][2])~=K[i][1]then knotsOk=false;failures[#failures+1]='knot '..i..' -> '..string.format('%.17g',Progress.PointsFor(K[i][2]))end end
check(knotsOk,'each knot speed (24, 26, 28, 31, 35, 55, 88, 141, 226, 363, 500) needs exactly its points')
for i=1,#K do inverse(K[i][2],'knot'..i)end
-- Linear and logarithmic segments, from the start to the end of each (fractions that make exact integers and ones that do not).
local fractions={1e-12,1e-9,1e-6,.001,.01,.1,.25,1/3,.333,.5,.618,2/3,.75,.9,.99,.999,.999999,1-1e-9}
local segments=0
for i=2,#K do
 local a,b=K[i-1],K[i];local log=a[1]>=2000000
 for _,f in ipairs(fractions)do inverse(a[2]+(b[2]-a[2])*f,('seg%d%s f=%g'):format(i,log and' log'or' lin',f));segments+=1 end
end
check(#failures==0,'segment samples: Speed(PointsFor(v)) >= v and Speed(PointsFor(v)-1) < v ('..tested..' speeds on all 10 segments: '..table.concat(failures,'; ')..')')
failures={};tested=0
-- Speeds that come from whole numbers of points (the exact-integer cases, where float noise could cost a point).
local grid={1,2,3,10,17,499,500,501,999,1000,1118,1499,1501,2999,3001,5999,6001,44000,119999,120001,999999,1499999,1500001,
 1999999,2000000,2000001,5000000,19999999,20000001,123456789,299999999,300000001,2000000000,4999999999,5000000001,12345678901,99999999999}
local gridBad=0
for _,n in ipairs(grid)do
 local v=Progress.Speed(n);local ok,m=inverseOk(v)
 if not ok or m~=n then gridBad+=1;if #failures<8 then failures[#failures+1]=('Speed(%d)=%.12g -> PointsFor=%.17g'):format(n,v,m)end end
end
check(gridBad==0,'PointsFor(Speed(n)) == n for '..#grid..' whole point counts across the curve: '..table.concat(failures,'; '))
failures={};tested=0
-- Pseudo-random speeds (seeded) over the whole curve.
math.randomseed(147)
local badRandom=0
for _=1,6000 do local v=24+math.random()*476;if not inverse(v,'rand')then badRandom+=1 end end
for _=1,2000 do local v=24+math.random()*3;if not inverse(v,'rand-low')then badRandom+=1 end end
for _=1,2000 do local v=363+math.random()*137;if not inverse(v,'rand-top')then badRandom+=1 end end
check(badRandom==0,'10,000 pseudo-random speeds 24..500 are exact ('..tested..' tested; '..table.concat(failures,'; ')..')')
failures={};tested=0
-- The tail past 500 (0.1 per tenfold). Around 1e11 points one point moves the speed by only 4e-13 and a double speed
-- near 500 resolves 6e-14, so it is exact there only as far as R.Speed itself is: tested to the point just above 500.
for _,v in ipairs({500.0000001,500.000001,500.000005,500.00001,500.00005,500.0001,500.0005,500.001})do inverse(v,'tail')end
check(#failures==0,'the start of the tail (500.0000001 .. 500.001): Speed(PointsFor(v)) >= v and Speed(PointsFor(v)-1) < v: '..table.concat(failures,'; '))
failures={}
-- Further out a single point is smaller than a double can show in a speed (~1e-13), so: reaching v, and within one part in 1e9.
local tailOk=true
for _,v in ipairs({500.002,500.01,500.02,500.05,500.1,500.2,500.3,500.4,500.45,500.49})do
 local n=Progress.PointsFor(v)
 if not(Progress.Speed(n)>=v-1e-6 and Progress.Speed(math.floor(n*(1-1e-9)))<v)then tailOk=false;failures[#failures+1]=('v=%g n=%.17g'):format(v,n)end
end
check(tailOk,'the far tail (500.02 .. 500.49): reaches v, and 1e-9 fewer points do not: '..table.concat(failures,'; '))
local mono=true;local prevN=-1
for v=24,500.4,.37 do local n=Progress.PointsFor(v);if n<prevN then mono=false end;prevN=n end
check(mono,'PointsFor never goes down as the speed goes up (24 .. 500.4)')
check(Progress.PointsFor(26)==500 and Progress.PointsFor(31)==3000 and Progress.PointsFor(35)==6000 and Progress.PointsFor(55)==120000 and Progress.PointsFor(88)==1500000,'spot values: 26 -> 500, 31 -> 3,000, 35 -> 6,000, 55 -> 120,000, 88 -> 1.5M')
check(Progress.PointsFor(141)==20000000 and Progress.PointsFor(226)==300000000 and Progress.PointsFor(363)==5000000000 and Progress.PointsFor(500)==100000000000,'141 -> 20M, 226 -> 300M, 363 -> 5B, 500 -> 100B (the logarithmic part)')
check(Progress.PointsFor(32)==3750 and Progress.PointsFor(50)==91500,'32 -> 3,750 and 50 -> 91,500 (the linear part)')
-- The log segments really are logarithmic and the linear ones linear (midpoints).
local midLog=Progress.Speed(math.sqrt(20000000*300000000));local midLin=Progress.Speed((1500000+20000000)/2)
check(near(midLog,(141+226)/2,1e-6)and near(midLin,88+(141-88)*((21500000/2-1500000)/18500000),1e-6),'segments from 2,000,000 up are logarithmic (the geometric mean is the speed midpoint), the ones below are linear')

-- 3. KeeperSpeedLabels ------------------------------------------------------------------------------------------------------
local GREEN,RED=function(c)return rgb(c,110,236,96)end,function(c)return rgb(c,255,86,86)end
local function keeper(name,escape,y,height)
 local m=R.new('Model');m.Name=name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=R.Vector3.new(2,2,1);root.CFrame=R.CFrame.new(0,y or 10,0);root.Parent=m
 local body=R.new('Part');body.Name='Body';body.Size=R.Vector3.new(4,height or 6,2);body.CFrame=R.CFrame.new(0,(y or 10)+((height or 6)/2-1),0);body.Parent=m
 m.PrimaryPart=root;if escape~=nil then m:SetAttribute('KeeperEscapeSpeed',escape)end
 m.Parent=workspace;CS:AddTag(m,'BiomeKeeper');return m,root
end
local keepers={}
local pre=keeper('Forest',20);keepers[1]=pre
local ks=R.new('LocalScript');ks.Name='KeeperSpeedLabels'
local okK,errK=pcall(W.load,'KeeperSpeedLabels',ks);check(okK,'KeeperSpeedLabels loads: '..tostring(errK))
local function pill(m)local gui=m:FindFirstChild('SpeedReq');return gui,gui and gui.Pill and gui.Pill.Value,gui and gui.Pill and gui.Pill.Edge end
local gui,value,edge=pill(pre)
check(gui~=nil and gui:IsA('BillboardGui')and gui.Name=='SpeedReq'and gui.Pill.Caption.Text=='SPEED NEEDED'and gui.MaxDistance==220 and gui.AlwaysOnTop==false and gui.LightInfluence==0,'a keeper that was already tagged gets a "SpeedReq" billboard with the caption SPEED NEEDED')
local rootOf=pre:FindFirstChild('HumanoidRootPart')
check(gui.Adornee==rootOf,'the label hangs on the keeper\'s root')
-- height: top of the box (15) minus the root (10) = 5, +2.5.
check(near(gui.StudsOffsetWorldSpace.Y,7.5,1e-9)and gui.Size.X.Offset==150 and gui.Size.Y.Offset==50,'it floats just above the head (offset 7.5) at the normal size (150x50)')
-- No PhysicalWalkSpeed yet: the player is a new runner (24 x boost).
check(value.Text=='⚡ ANY  ✓'and GREEN(value.TextColor3)and GREEN(edge.Color),'The Forest keeper (20): a new runner (24) is faster: green "⚡ ANY  ✓" ('..value.Text..')')
-- The seven biome keepers and The Darkened.
local expected={{'Forest',20,'⚡ ANY'},{'Jungle',32,'⚡ 3751'},{'Desert',50,'⚡ 91501'},{'Snow',80,'⚡ 1.1M'},{'Lava',128,'⚡ 15.4M'},{'Crystal',205,'⚡ 153.6M'},{'Storm',330,'⚡ 2.5B'}}
local bySpeed={}
for _,row in ipairs(expected)do
 local m=row[1]=='Forest'and pre or keeper(row[1],row[2],10,6);bySpeed[row[2]]=m
end
player:SetAttribute('PhysicalWalkSpeed',24)
local function vtext(m)local _,v=pill(m);return v.Text end
local function vcolor(m)local _,v=pill(m);return v.TextColor3 end
local textsOk=true;local diag={}
for _,row in ipairs(expected)do
 local m=bySpeed[row[2]];local t=vtext(m)
 local want=row[3]..(row[2]<24 and'  ✓'or'')
 if t~=want then textsOk=false;diag[#diag+1]=row[1]..' '..t..' (want '..want..')'end
end
check(textsOk,'at walk speed 24: the Speed needed for each keeper (ANY, 3751, 91,501, 1.1M, 15.4M, 153.6M, 2.5B)'..(#diag>0 and(': '..table.concat(diag,'; '))or''))
check(RED(vcolor(bySpeed[32]))and RED(vcolor(bySpeed[330]))and GREEN(vcolor(bySpeed[20])),'red when the keeper is faster than me, green when I am faster')
local _,_,edgeJ=pill(bySpeed[32]);check(RED(edgeJ.Color),'(the outline follows)')
check(not vtext(bySpeed[32]):find('✓',1,true),'no ✓ while the keeper is faster')
-- My walk speed changes.
player:SetAttribute('PhysicalWalkSpeed',31);check(GREEN(vcolor(bySpeed[20]))and RED(vcolor(bySpeed[32]))and vtext(bySpeed[32])=='⚡ 3751','31: still slower than the 32 keeper')
player:SetAttribute('PhysicalWalkSpeed',32);check(RED(vcolor(bySpeed[32]))and not vtext(bySpeed[32]):find('✓',1,true),'exactly 32: not faster (it takes MORE than the keeper)')
player:SetAttribute('PhysicalWalkSpeed',32.01);check(GREEN(vcolor(bySpeed[32]))and vtext(bySpeed[32])=='⚡ 3751  ✓','32.01: green with ✓ (the number stays the points needed)')
player:SetAttribute('PhysicalWalkSpeed',51);check(GREEN(vcolor(bySpeed[50]))and vtext(bySpeed[50])=='⚡ 91501  ✓'and RED(vcolor(bySpeed[80])),'51 beats the Desert keeper (50), not the Snow one (80)')
player:SetAttribute('PhysicalWalkSpeed',331);check(GREEN(vcolor(bySpeed[330]))and vtext(bySpeed[330])=='⚡ 2.5B  ✓','331 beats the Storm keeper')
player:SetAttribute('PhysicalWalkSpeed',nil);check(vtext(bySpeed[32])=='⚡ 3751'and RED(vcolor(bySpeed[32]))and GREEN(vcolor(bySpeed[20])),'no PhysicalWalkSpeed attribute: treated as a new runner (24)')
player:SetAttribute('PhysicalWalkSpeed','fast');check(GREEN(vcolor(bySpeed[20]))and RED(vcolor(bySpeed[32])),'(a text value too)')
player:SetAttribute('PhysicalWalkSpeed',24)
-- Friend boost.
local escapes={20,32,50,80,128,205,330}
local function texts(b)
 player:SetAttribute('FriendSpeedBoost',b);local out={}
 for _,e in ipairs(escapes)do out[#out+1]=vtext(bySpeed[e])end
 return out
end
local function plain(t)return(t:gsub('  ✓$',''))end
local b13=texts(1.3)
local want13={'⚡ ANY','⚡ 155','⚡ 25732','⚡ 393428','⚡ 5.1M','⚡ 34M','⚡ 531.4M'}
local ok13=true;local d13={};for i,w in ipairs(want13)do if plain(b13[i])~=w then ok13=false;d13[#d13+1]=b13[i]..' (want '..w..')'end end
check(ok13,'a +30% friend boost lowers every number: ANY, 155, 25,732, 393,428, 5.1M, 34M, 531.4M'..(#d13>0 and(': '..table.concat(d13,'; '))or''))
local b11=texts(1.1);check(plain(b11[1])=='⚡ ANY'and plain(b11[2])=='⚡ 2047'and plain(b11[3])=='⚡ 65592'and plain(b11[4])=='⚡ 861324'and plain(b11[5])=='⚡ 11.4M','+10%: ANY, 2047, 65,592, 861,324, 11.4M ('..table.concat(b11,', ')..')')
local b12=texts(1.2);check(plain(b12[1])=='⚡ ANY'and plain(b12[2])=='⚡ 835'and plain(b12[4])=='⚡ 607880'and plain(b12[5])=='⚡ 8M','+20%: ANY, 835, (50: see below), 607,880, 8M ('..table.concat(b12,', ')..')')
-- Whatever the boost, the label is the spec formula (PointsFor(escape / boost) + 1) and is right to within a point: that many
-- points (times the boost) beat the keeper and two fewer do not.
local formulaOk,pointsOk=true,true;local fd={}
for _,boost in ipairs({1,1.05,1.1,1.15,1.2,1.25,1.3})do
 local row=texts(boost)
 for i,e in ipairs(escapes)do
  local walk=e/boost
  if walk<24 then if plain(row[i])~='⚡ ANY'then formulaOk=false;fd[#fd+1]='ANY '..e..'/'..boost end
  else
   local n=Progress.PointsFor(walk)+1
   if plain(row[i])~='⚡ '..Points.Compact(string.format('%.0f',n))then formulaOk=false;fd[#fd+1]=e..'/'..boost..' '..row[i]end
   if not(Progress.Speed(n)*boost>e-1e-9 and Progress.Speed(n-2)*boost<=e+1e-9)then pointsOk=false;fd[#fd+1]='points '..e..'/'..boost..' n='..n end
  end
 end
end
check(formulaOk,'28 keeper / boost combinations all read Compact(PointsFor(escape / boost) + 1), ANY below 24 ('..table.concat(fd,'; ')..')')
check(pointsOk,'and each is within a point of the true minimum: n points x boost beat the keeper, n-2 do not')
check(plain(b12[3])=='⚡ 44001'or plain(b12[3])=='⚡ 44002','(+20%, Desert keeper: 50 / 1.2 sits on a whole 44,000 points: '..b12[3]..')')
local bOver=texts(5);check(table.concat(bOver,'|')==table.concat(b13,'|'),'a boost above +30% counts as +30% (the same as 1.3)')
local bUnder=texts(.5);check(bUnder[2]=='⚡ 3751'and plain(bUnder[1])=='⚡ ANY','a boost below 1 counts as 1')
local bNan=texts(0/0);check(bNan[2]=='⚡ 3751','a NaN boost counts as 1')
local bText=texts('x');check(bText[2]=='⚡ 3751','a text boost counts as 1')
local bNil=texts(nil);check(bNil[2]=='⚡ 3751','no boost attribute counts as 1')
-- ANY threshold: escape / boost below 24.
local e23,e24,e2401=keeper('Edge23',23.9,10,6),keeper('Edge24',24,10,6),keeper('Edge2401',24.01,10,6)
check(vtext(e23):find('ANY',1,true)and vtext(e24)=='⚡ 1'and vtext(e2401)=='⚡ 4','below 24: ANY; exactly 24: 1 point (you need more than 24); 24.01: 4 ('..vtext(e24)..' / '..vtext(e2401)..')')
player:SetAttribute('FriendSpeedBoost',1.3)
check(vtext(e24):find('ANY',1,true)and vtext(e2401):find('ANY',1,true),'with +30%: 24 and 24.01 (18.5) are ANY')
local k31=keeper('Edge31',31,10,6)
check(vtext(k31):find('ANY',1,true),'with +30% a 31 keeper (23.85) is ANY too')
player:SetAttribute('PhysicalWalkSpeed',24*1.3);check(GREEN(vcolor(k31))and RED(vcolor(bySpeed[32])),'(24 x 1.3 = 31.2 beats 31, not 32)')
player:SetAttribute('FriendSpeedBoost',nil);player:SetAttribute('PhysicalWalkSpeed',24)
-- The Darkened: a fixed 600.
local dark=keeper('TheVeiledOne',600)
local dt=vtext(dark)
check(dt~='⚡ 0'and dt~=''and not dt:find('inf',1,true)and not dt:find('nan',1,true),'The Darkened (600): never "⚡ 0" or inf: '..dt)
check(dt=='⚡ TOO FAST','without a boost it takes 10^1011 points (nobody has that): ⚡ TOO FAST ('..dt..')')
check(RED(vcolor(dark)),'and it is red for a normal runner')
player:SetAttribute('FriendSpeedBoost',1.3)
local dt13=vtext(dark);local walk13=600/1.3;local n13=Progress.PointsFor(walk13)
check(dt13==('⚡ '..Points.Compact(string.format('%.0f',n13+1))),'with +30% it is a real number again ('..dt13..')')
check(n13>4e10 and n13<5e10 and Progress.Speed(n13+1)*1.3>600 and Progress.Speed(n13-1)*1.3<600,'and that is right: that many points (x1.3) beat 600, one fewer does not')
player:SetAttribute('PhysicalWalkSpeed',24*1.3);check(RED(vcolor(dark)),'(31.2 is far from 600)')
player:SetAttribute('PhysicalWalkSpeed',650);check(GREEN(vcolor(dark))and vtext(dark):find('✓',1,true),'a +30% runner at 500 base (650) outruns The Darkened: green ✓')
player:SetAttribute('PhysicalWalkSpeed',24)
player:SetAttribute('FriendSpeedBoost',1.2);local dt12=vtext(dark);check(dt12=='⚡ 100B','at +20% 600 / 1.2 = 500: 100B points (+1): ⚡ 100B ('..dt12..')')
player:SetAttribute('FriendSpeedBoost',1.1);local dt11=vtext(dark)
check(dt11=='⚡ TOO FAST','at +10% (545.5) it is still out of reach: ⚡ TOO FAST ('..dt11..')')
check(Progress.PointsText(600)==('1'..string.rep('0',1011))and #Progress.PointsText(600/1.1)==466,'(PointsText(600) is a 1 and 1011 zeros)')
player:SetAttribute('FriendSpeedBoost',nil)
-- Needs above a quadrillion points (speed above ~500.4) never read as 0.
local huge=keeper('Huge',500.45)
local ht=vtext(huge)
check(ht~='⚡ 0'and(ht:find('Qa',1,true)or ht:find('Qi',1,true)or ht:find('Sx',1,true)),'a 500.45 keeper needs thousands of trillions of points, not 0 ('..ht..')')
check(ht==('⚡ '..Points.Compact(string.format('%.0f',Progress.PointsFor(500.45)+1))),'(written with %.0f, not tostring)')
-- A keeper without the attribute gets no label until it has one.
local plain=keeper('Plain',nil);local gp=pill(plain)
check(gp~=nil and gp.Enabled==false,'a keeper without KeeperEscapeSpeed: the label stays off')
plain:SetAttribute('KeeperEscapeSpeed',50);check(gp.Enabled==true and select(2,pill(plain)).Text=='⚡ 91501','and appears when the server stamps it')
plain:SetAttribute('KeeperEscapeSpeed',20);check(select(2,pill(plain)).Text:find('ANY',1,true),'(and follows changes)')
-- A keeper that is tagged before it has parts: the label finds its root when it arrives.
local late2=R.new('Model');late2.Name='LateKeeper';late2:SetAttribute('KeeperEscapeSpeed',80);late2.Parent=workspace;CS:AddTag(late2,'BiomeKeeper')
local gl=pill(late2)
check(gl~=nil and gl.Adornee==nil,'a keeper with no parts yet: a label that waits')
local lr=R.new('Part');lr.Name='HumanoidRootPart';lr.Size=R.Vector3.new(2,2,1);lr.CFrame=R.CFrame.new(0,10,0);lr.Parent=late2
check(gl.Adornee==lr and gl.Enabled==true,'its root appears: the label hangs on it')
-- Tall keepers get a bigger label, higher up.
local tall=keeper('Giant',330,10,40)
local gt=pill(tall)
check(near(gt.StudsOffsetWorldSpace.Y,(10+(40/2-1)+40/2-10)+2.5,1e-6)and gt.Size.X.Offset==330 and gt.Size.Y.Offset==110,'a 40-stud keeper: the label is 2.2x (330x110) and higher up ('..tostring(gt.StudsOffsetWorldSpace.Y)..')')
-- Tag removal and teardown.
CS:RemoveTag(plain,'BiomeKeeper');check(gp.Parent==nil,'a keeper that loses the tag loses its label')
plain:SetAttribute('KeeperEscapeSpeed',99);check(gp.Parent==nil,'(and is not updated)')
local tagged=#CS:GetTagged('BiomeKeeper')
ks.Destroying:Fire()
local left=0;for _,m in ipairs(CS:GetTagged('BiomeKeeper'))do if m:FindFirstChild('SpeedReq')then left+=1 end end
check(left==0,'removing the script removes every label ('..tagged..' keepers)')
local post=keeper('Post',50);check(post:FindFirstChild('SpeedReq')==nil,'and new keepers get none')
player:SetAttribute('PhysicalWalkSpeed',100);check(true,'(no errors after teardown)')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
