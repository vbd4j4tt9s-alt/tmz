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
-- R150: the pedestal's fx and spin only run for pedestals the camera can see: the player stands 32 studs away looking at the pedestal (the mock's own camera looks the other way).
local function lookAtPedestal()return R.CFrame.lookAt(R.Vector3.new(0,20,-30),R.Vector3.new(0,9,0))end
W.workspace.CurrentCamera.CFrame=lookAtPedestal()
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
check(g~=nil and g:IsA('BillboardGui')and g.Adornee==earlyAnchor and g.MaxDistance==90 and g.AlwaysOnTop==false and g.LightInfluence==0,'a pedestal that was already there gets its label (BillboardGui "MysteryLabel" on the pack anchor)')
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
check(gm.Status.Text=='UNLOCKED! GRAB IT 🎁'and rgb(gm.Status.TextColor3,255,214,90),'status: UNLOCKED! TAKE IT 🎁')
check(gm.Bar.Visible==true and gm.Bar.Fill.Size.X.Scale==1 and rgb(gm.Bar.Fill.BackgroundColor3,255,214,90),'the bar is full and gold')
check(minePrompt.Enabled==true,'the prompt turns on for the owner')
check(bursts()==b0+1,'a burst of light when MY pack unlocks (Locked -> Ready)')
local ring=lastBurst()
check(ring and rgb(ring.Color,255,214,90)and near(ring.Size.Y,16,1e-9)and ring.Shape==R.Enum.PartType.Cylinder and ring.Anchored and not ring.CanCollide and not ring.CanQuery and not ring.CanTouch,'a big gold ring, anchored and not solid')
local padY=9-(M.AnchorHeight-M.PadTop-.12) -- (R150: the ring spreads over the glowing pad under the pack, not through it; the flash and the sparks are at the pack)
check(ring and near(ring.Position.Y,padY,1e-9)and near(ring.Position.X,0,1e-9),'under the pack anchor, over the glowing pad')
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
other:SetAttribute('OwnerUserId',77);check(otherPrompt.Enabled==true and go.Status.Text=='UNLOCKED! GRAB IT 🎁','if the owner becomes me: the prompt turns on and the text changes')
other:SetAttribute('OwnerUserId',999);check(otherPrompt.Enabled==false,'and off again')
-- Claimed.
local nextAt=R.clock+10000
mine:SetAttribute('NextAt',nextAt);local b2=bursts()
mine:SetAttribute('State','Claimed')
check(gm.Title.Text=='✓ GRABBED TODAY'and rgb(gm.Title.TextColor3,120,236,110),'Claimed: ✓ TAKEN TODAY (mint)')
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
check(label(other).Title.Text=='✓ GRABBED TODAY'and label(other).Status.Text=='NEW PACK IN 1h 1m'and bursts()==b3,'someone else\'s taken pedestal: ✓ TAKEN TODAY, NEW PACK IN 1h 1m, no burst')
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
check(label(seen).Status.Text=='UNLOCKED! GRAB IT 🎁'and seenPrompt.Enabled==true and bursts()==b5,'a pedestal that is already Ready when the client first sees it: shown at once, no burst (nothing "just" unlocked)')
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
W.workspace.CurrentCamera.CFrame=lookAtPedestal()
W.Gui.ReducedMotionEnabled=true;pk:PivotTo(R.CFrame.new(0,9,0));W.Run.RenderStepped:Fire(1/60)
check(near(pk:GetPivot().Position.Y,9,1e-9),'with reduced motion nothing spins')
W.Gui.ReducedMotionEnabled=false
-- R148 (owner: "make sure that the bar is on top of the pack and it doesn't enlarge and obscure everything when far away"):
-- the label is a sign in the world (Size in studs, so it shrinks with distance and stops growing up close) that hangs clearly
-- ABOVE the pack at every bob phase.
do
 local function pxPerStud(d)return 720/(2*d*math.tan(math.rad(35)))end -- a 70 degree view on a 720 px tall screen
 local AY=9
 local lab,labAnchor=pedestal('LabelAbove',{State='Locked',OwnerUserId=77,OwnerName='Tester',UnlockAt=R.clock+400})
 labAnchor.CFrame=R.CFrame.new(0,AY,0)
 local lholder=R.new('Model');lholder.Name='MysteryPack';lholder.Parent=lab
 local lpack=R.new('Model');lpack.Name='SeedPacket';lpack:SetAttribute('MysteryOrigin',R.CFrame.new(0,AY,0));lpack.Parent=lholder
 local function buildPack(up,down) -- a pack whose root is at its centre, `up` studs of it above and `down` below
  for _,c in ipairs(lpack:GetChildren())do c:Destroy()end
  local root=R.new('Part');root.Name='PackRoot';root.Size=R.Vector3.new(1,1,1);root.CFrame=R.CFrame.new(0,AY,0);root.Transparency=1;root.Parent=lpack;lpack.PrimaryPart=root
  local body=R.new('Part');body.Name='Body';body.Size=R.Vector3.new(3.4,up+down,.2);body.CFrame=R.CFrame.new(0,AY+(up-down)/2,0);body.Parent=lpack
 end
 local g=label(lab)
 local function bottomY(gui)return AY+gui.StudsOffsetWorldSpace.Y-gui.Size.Y.Scale/2 end
 local function topY(gui)return AY+gui.StudsOffsetWorldSpace.Y+gui.Size.Y.Scale/2 end
 -- Size: studs, not pixels.
 check(g.Size.X.Offset==0 and g.Size.Y.Offset==0 and g.Size.X.Scale>=8 and g.Size.X.Scale<=12 and g.Size.Y.Scale>=3 and g.Size.Y.Scale<=4.5,'[size] the label is sized in studs (about 10 x 3.6), not in pixels: it shrinks with distance like a sign ('..tostring(g.Size.X.Scale)..' x '..tostring(g.Size.Y.Scale)..' studs)')
 check(g.StudsOffset==nil or(g.StudsOffset.X==0 and g.StudsOffset.Y==0 and g.StudsOffset.Z==0),'(placed in world space, not relative to the camera)')
 local tf=g.Title.Size.Y.Scale -- (R150: the caption is .27 of the sign, the state line .42: both read at 20-40 studs)
 check(g.Size.Y.Scale*tf*pxPerStud(30)>=12 and g.Size.Y.Scale*tf*pxPerStud(20)>=12 and g.Size.Y.Scale*tf*pxPerStud(40)>=9 and g.Size.Y.Scale*g.Status.Size.Y.Scale>=g.Size.Y.Scale*tf,'[size] it reads at 20-40 studs: the title is 12+ px tall at 20 and 30 studs, still 9+ px at 40, and the state line is bigger than the caption')
 check(g.Size.Y.Scale*pxPerStud(90)/720<.1 and g.Size.X.Scale*pxPerStud(90)/1280<.06 and g.Size.Y.Scale*pxPerStud(120)/720<.08,'[size] from far away it is small: at 90 studs under 10% of the screen height and 6% of the width (it never covers the screen)')
 local near0=g.DistanceLowerLimit or 0
 check(near0>=12 and near0<=30 and g.Size.Y.Scale*pxPerStud(near0)/720<=.2 and g.Size.X.Scale*pxPerStud(near0)/1280<=.3,'[size] up close it stops growing (DistanceLowerLimit '..tostring(g.DistanceLowerLimit)..': at most 20% of the screen height there)')
 check(g.MaxDistance==120 and label(other).MaxDistance==90 and label(early).MaxDistance==90,'[size] it shows up to 90 studs away, 120 over your own pedestal')
 other:SetAttribute('OwnerUserId',77);check(label(other).MaxDistance==120,'(the longer range follows the owner)');other:SetAttribute('OwnerUserId',999);check(label(other).MaxDistance==90,'(and goes back)')
 -- Above the pack: the bottom edge clears the pack's top at its highest bob, for every bob phase and camera angle.
 buildPack(2.5,2.5);adv(1)
 local MINGAP=.5
 local topMax=AY+2.5+.35
 check(bottomY(g)>=topMax+MINGAP,'[above] the label\'s bottom edge ('..string.format('%.2f',bottomY(g))..') is clear of the pack\'s top at its highest bob ('..string.format('%.2f',topMax)..') by at least half a stud')
 check(near(topY(g)-bottomY(g),g.Size.Y.Scale,1e-9)and bottomY(g)<topMax+4,'(and close above it, not floating far away)')
 local worst=math.huge;local phases=0
 W.workspace.CurrentCamera.CFrame=lookAtPedestal()
 local saved=R.clock
 for k=0,47 do
  R.clock=saved+k*(2*math.pi/1.6)/48;W.Run.RenderStepped:Fire(1/60)
  local packTop=lpack:GetPivot().Position.Y+2.5 -- (the pack's real top now: the script bobbed its pivot)
  worst=math.min(worst,bottomY(g)-packTop);phases+=1
 end
 R.clock=saved
 check(phases==48 and worst>=MINGAP,'[above] at every one of 48 bob phases over a full bob the pack\'s top stays under the label by at least half a stud (closest: '..string.format('%.2f',worst)..')')
 local angleOk=true
 for pitch=-85,85,5 do -- a camera looking up or down at the sign: its lowest point is centre - half height x cos(pitch)
  local lowest=AY+g.StudsOffsetWorldSpace.Y-g.Size.Y.Scale/2*math.cos(math.rad(pitch))
  if lowest<topMax+MINGAP then angleOk=false end
 end
 check(angleOk,'[above] and from every camera pitch (-85 .. +85 degrees) no part of the sign dips to the pack\'s top')
 -- A bigger pack lifts it; a smaller one lets it come down; no pack at all (taken): the default height.
 local before=g.StudsOffsetWorldSpace.Y
 buildPack(4.2,2.5);adv(1)
 check(bottomY(g)>=AY+4.2+.35+MINGAP and g.StudsOffsetWorldSpace.Y>before,'[above] a taller pack (4.2 studs up) lifts the label above its top too ('..string.format('%.2f',bottomY(g))..' over '..string.format('%.2f',AY+4.2+.35)..')')
 buildPack(1.6,1.6);adv(1)
 check(bottomY(g)>=AY+1.6+.35+MINGAP and g.StudsOffsetWorldSpace.Y<before,'[above] a smaller pack lets it come down, still clear above it')
 lholder:ClearAllChildren();adv(1)
 check(bottomY(g)>=AY+3.2+.35+MINGAP-1e-6,'[above] with no pack on the pedestal (taken / not arrived) it hangs at the default height, above the biggest packs')
 -- The real flow: the pack of a Ready pedestal arrives later than its State, and is swapped for a bigger one.
 lab:SetAttribute('UnlockAt',nil);lab:SetAttribute('Variant','Pack03');lab:SetAttribute('State','Ready')
 local newPack=R.new('Model');newPack.Name='SeedPacket';newPack:SetAttribute('MysteryOrigin',R.CFrame.new(0,AY,0));newPack.Parent=lholder
 local r2=R.new('Part');r2.Name='PackRoot';r2.Size=R.Vector3.new(1,1,1);r2.CFrame=R.CFrame.new(0,AY,0);r2.Parent=newPack;newPack.PrimaryPart=r2
 local b2=R.new('Part');b2.Name='Body';b2.Size=R.Vector3.new(3.4,6.4,.2);b2.CFrame=R.CFrame.new(0,AY+1.5,0);b2.Parent=newPack -- (up 4.7)
 adv(1)
 check(bottomY(g)>=AY+4.7+.35+MINGAP,'[above] a Ready pack that arrives after the State attribute: the label rises over it within half a second')
 -- The label's own parts and every state keep the same stud size.
 lab:SetAttribute('NextAt',R.clock+100);lab:SetAttribute('State','Claimed');lholder:ClearAllChildren();adv(1)
 check(g.Size.Y.Scale==3.6 and g.Size.X.Scale==10 and bottomY(g)>=AY+3.2+.35+MINGAP-1e-6,'the same size and height in every state (Claimed: no pack, the default height)')
 CS:RemoveTag(lab,'MysteryPedestal')
end
adv(2)
-- Reduced motion: the burst ring does not tween (the sparks still show).
W.Gui.ReducedMotionEnabled=true;local b4=bursts()
mine:SetAttribute('UnlockAt',nil);mine:SetAttribute('State','Ready')
check(bursts()==b4+1 and lastBurst().Transparency==1,'reduced motion: the ring is invisible (no tween), the burst still happens')
W.Gui.ReducedMotionEnabled=false
-- Streaming (the place uses StreamingEnabled): pedestals and their parts arrive late and can come back as new instances; only the
-- owner ever sees an enabled Take prompt (the server enables it while the pack is Ready, for every client).
do
 local function bare(name,attrs) -- a pedestal Model as a streaming client first sees it: tagged and in the world, but without its parts yet
  local m=R.new('Model');m.Name=name
  for k,v in pairs(attrs or{})do m:SetAttribute(k,v)end
  m.Parent=workspace;CS:AddTag(m,'MysteryPedestal');return m
 end
 local function addAnchor(m)local a=R.new('Part');a.Name='PackAnchor';a.Size=R.Vector3.new(1,1,1);a.CFrame=R.CFrame.new(0,9,0);a.Parent=m;return a end
 local function addPrompt(a,enabled)local pr=R.new('ProximityPrompt');pr.Name='TakeMysteryPack';pr.Enabled=enabled;pr.Parent=a;return pr end
 adv(2);local b0=bursts()
 -- A pedestal whose PackAnchor has not streamed in: it gets its label at once and never gives up waiting (no one-shot 10 s wait).
 local lateM=bare('LateAnchor',{State='Ready',OwnerUserId=999,OwnerName='Zed',Variant='Pack02',Stage=1})
 local lg=label(lateM)
 check(lg~=nil and lg.Enabled==true and lg.Adornee==nil and lg.Title.Text=="✨ ZED'S MYSTERY PACK"and lg.Status.Text=='UNLOCKED!','[streaming] a pedestal without its PackAnchor yet already has its label (up to date, nothing to adorn)')
 adv(12)
 check(label(lateM)==lg and lg.Parent==lateM,'[streaming] 12 s later (past the old 10 s wait) it is still there, still waiting for the parts')
 lateM:SetAttribute('State','Locked');lateM:SetAttribute('UnlockAt',R.clock+300)
 check(lg.Status.Text=='🔒 5:00','[streaming] and it follows the attributes meanwhile ('..lg.Status.Text..')')
 lateM:SetAttribute('UnlockAt',nil);lateM:SetAttribute('State','Ready')
 local la=addAnchor(lateM)
 check(lg.Adornee==la,'[streaming] the PackAnchor streams in late: the label is attached to it')
 local lp=addPrompt(la,true)
 check(lp.Enabled==false,'[streaming] [prompt] the Take prompt arrives (the server has it on, Ready): off for me, it is not my pedestal')
 lp.Enabled=true;check(lp.Enabled==false,'[prompt] and when the server changes it again it is switched off again')
 -- Mine, parts arriving late: no burst for a pack that was already Ready; the prompt works.
 local mineLate=bare('LateMine',{State='Locked',OwnerUserId=77,OwnerName='Tester',UnlockAt=R.clock+60})
 mineLate:SetAttribute('UnlockAt',nil);mineLate:SetAttribute('Variant','Pack03');mineLate:SetAttribute('State','Ready')
 local ma=addAnchor(mineLate);local mp=addPrompt(ma,false)
 check(label(mineLate).Adornee==ma and mp.Enabled==true and bursts()==b0,'[streaming] mine, Ready, parts arriving late: label on the anchor, the prompt is on for me, no burst (the anchor was not there when it unlocked)')
 mineLate:SetAttribute('State','Claimed');check(mp.Enabled==false and bursts()==b0+1 and near(lastBurst().Position.Y,9-(M.AnchorHeight-M.PadTop-.12),1e-9),'(and taking it turns the prompt off and bursts around the new anchor)')
 adv(2)
 -- Non-owners never see an enabled prompt, whatever the server does to it.
 local nm=bare('NonOwner',{State='Empty'});local na=addAnchor(nm);local np=addPrompt(na,true)
 check(np.Enabled==false,'[prompt] a non-owner\'s prompt that arrives enabled is switched off at once')
 local allOff=true;local seen={}
 for _,owner in ipairs({false,999})do
  for _,st in ipairs({'Empty','Locked','Ready','Claimed','Ready','Empty'})do
   nm:SetAttribute('OwnerUserId',owner or nil);nm:SetAttribute('State',st)
   np.Enabled=true -- (the server's value reaching this client: it is Enabled while Ready)
   if np.Enabled~=false then allOff=false;seen[#seen+1]=tostring(owner)..'/'..st end
  end
 end
 check(allOff,'[prompt] a non-owner (nobody / someone else) never has an enabled prompt in any state, after every server-side Enabled change '..table.concat(seen,' '))
 -- The owner: on only while Ready, whatever the server wrote.
 nm:SetAttribute('OwnerUserId',77);local ownerOk=true
 for _,case in ipairs({{'Empty',false},{'Locked',false},{'Ready',true},{'Claimed',false},{'Ready',true}})do
  nm:SetAttribute('State',case[1]);np.Enabled=true;if np.Enabled~=case[2]then ownerOk=false end
  np.Enabled=false;if np.Enabled~=case[2]then ownerOk=false end
 end
 check(ownerOk,'[prompt] for the owner it is on only while Ready, even if the server\'s value is wrong for a moment')
 -- Re-streamed: the same pedestal comes back as a NEW instance. The old one is forgotten, the new one gets a fresh label, prompt and burst state.
 local old=bare('Restream',{State='Ready',OwnerUserId=77,OwnerName='Tester',Variant='Pack03',Stage=1});local oa=addAnchor(old);local op=addPrompt(oa,true)
 local oldLabel=label(old);local oldStatus=oldLabel.Status
 check(oldLabel~=nil and oldLabel.Adornee==oa and op.Enabled==true,'(a pedestal of mine, Ready, with its parts)')
 local b1=bursts();old.Parent=nil -- streamed out
 check(oldLabel.Parent==nil and bursts()==b1,'[streaming] a pedestal that streams out loses its label (nothing stale is kept)')
 old:SetAttribute('State','Locked');check(oldStatus.Text=='UNLOCKED! GRAB IT 🎁','(and the old instance is not updated any more)')
 local nu=bare('Restream',{State='Ready',OwnerUserId=77,OwnerName='Tester',Variant='Pack03',Stage=1});local na2=addAnchor(nu);local np2=addPrompt(na2,true)
 local nl=label(nu)
 check(nl~=nil and nl~=oldLabel and nl.Adornee==na2 and nl.Status.Text=='UNLOCKED! GRAB IT 🎁'and np2.Enabled==true and bursts()==b1,'[streaming] it comes back as a new instance: a label of its own on the new anchor, the prompt on for me, no burst for a pack that was already Ready')
 nu:SetAttribute('State','Claimed')
 check(nl.Title.Text=='✓ GRABBED TODAY'and np2.Enabled==false and bursts()==b1+1 and rgb(lastBurst().Color,120,236,110),'[streaming] and the new instance works like any other (taking it: mint burst, prompt off)')
 adv(2)
 -- Re-streamed again as Locked: its countdown runs on the new instance after a long time in the world.
 CS:RemoveTag(nu,'MysteryPedestal')
 adv(3000)
 local again=bare('Restream',{State='Locked',OwnerUserId=77,OwnerName='Tester',UnlockAt=R.clock+120,Stage=1});local aa=addAnchor(again);addPrompt(aa,true)
 check(label(again).Status.Text=='🔒 2:00'and label(again).Adornee==aa,'[streaming] 50 minutes later a streamed-back pedestal shows its countdown (🔒 2:00)')
 adv(60);check(label(again).Status.Text=='🔒 1:00','[streaming] and it ticks on the new instance ('..label(again).Status.Text..')')
 -- The anchor and prompt come back as new instances inside a model that stayed.
 local keep=bare('PartsBack',{State='Ready',OwnerUserId=999,OwnerName='Yan'});local ka=addAnchor(keep);local kp=addPrompt(ka,true)
 check(kp.Enabled==false and label(keep).Adornee==ka,'(a pedestal of Yan\'s with its parts: prompt off for me)')
 ka.Parent=nil
 local ka2=addAnchor(keep);local kp2=addPrompt(ka2,true)
 check(label(keep).Adornee==ka2 and kp2.Enabled==false,'[streaming] [prompt] parts that come back as new instances are picked up: the label moves to the new anchor and the new prompt is switched off')
 kp2.Enabled=true;check(kp2.Enabled==false,'[prompt] and it is watched: the next server change is overridden too')
 kp.Enabled=true;check(kp.Enabled==true,'(the old prompt is no longer watched)')
 -- Moving a pedestal inside the world keeps its label; only leaving the world removes it.
 local folder=R.new('Folder');folder.Parent=workspace;local g0=label(keep);keep.Parent=folder
 check(label(keep)==g0 and g0.Parent==keep,'a pedestal reparented inside the workspace keeps its label')
 keep.Parent=nil;check(g0.Parent==nil,'(and loses it when it leaves the workspace)')
 -- Everything left from this block goes away with its tag.
 for _,m in ipairs({lateM,mineLate,nm,again})do CS:RemoveTag(m,'MysteryPedestal')end
end
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
-- R148 (owner: "the indicator is too big; make sure the speed needed is in numbers (must be whole numbers and multiples of
-- 5)"; then "B or mil can have decimal points"): a small fixed-size sign that always shows a number: the points needed
-- (strictly faster: PointsFor + 1) rounded UP to 2 significant figures (under 100: the next multiple of 5). Under a million
-- it is whole (3,800 / 18K / 540K); from a million up it may have one decimal and the plain suffix (1.2M, 16M, 2.6B, 22B).
local GREEN,RED=function(c)return rgb(c,110,236,96)end,function(c)return rgb(c,255,86,86)end
local function keeper(name,escape,y,height)
 local m=R.new('Model');m.Name=name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=R.Vector3.new(2,2,1);root.CFrame=R.CFrame.new(0,y or 10,0);root.Parent=m
 local body=R.new('Part');body.Name='Body';body.Size=R.Vector3.new(4,height or 6,2);body.CFrame=R.CFrame.new(0,(y or 10)+((height or 6)/2-1),0);body.Parent=m
 m.PrimaryPart=root;if escape~=nil then m:SetAttribute('KeeperEscapeSpeed',escape)end
 m.Parent=workspace;CS:AddTag(m,'BiomeKeeper');return m,root
end
-- The pure rounding and writing (SpeedPoints.RoundUp2 / NeedText), on their own first.
do
 local function rt(v)return Points.RoundUp2(v)end
 local cases={{0,'0'},{1,'5'},{4,'5'},{5,'5'},{6,'10'},{13,'15'},{95,'95'},{96,'100'},{99,'100'},{100,'100'},{101,'110'},{109,'110'},{110,'110'},{111,'120'},{999,'1000'},{1000,'1000'},{1001,'1100'},
  {3751,'3800'},{9999,'10000'},{10000,'10000'},{10001,'11000'},{17401,'18000'},{99999,'100000'},{501,'510'},{1165456,'1200000'},{999999,'1000000'},{1000001,'1100000'},{100000000001,'110000000000'}}
 local ok=true;local d={}
 for _,c in ipairs(cases)do local got=rt(c[1]);if got~=c[2]then ok=false;d[#d+1]=tostring(c[1])..' -> '..got..' (want '..c[2]..')'end end
 check(ok,'RoundUp2 rounds up to 2 significant figures (under 100: the next multiple of 5): 1 -> 5, 96 -> 100, 101 -> 110, 3751 -> 3800, 501 -> 510, 99,999 -> 100,000'..(#d>0 and(': '..table.concat(d,'; '))or''))
 check(rt('3751')=='3800'and rt('00000451')=='460'and rt('1'..string.rep('0',34)..'1')=='11'..string.rep('0',34)and rt(string.rep('9',36))=='1'..string.rep('0',36)and rt(nil)=='0'and rt(-5)=='0'and rt(0/0)=='0'and rt('x')=='0','RoundUp2 also takes exact decimal text of any size (and nonsense reads as 0)')
 local texts={{0,'0'},{1,'5'},{5,'5'},{100,'100'},{501,'510'},{3751,'3,800'},{9999,'10K'},{9500,'9,500'},{10000,'10K'},{10001,'11K'},{17401,'18K'},{45901,'46K'},{91501,'92K'},{99999,'100K'},{203638,'210K'},{538183,'540K'},{990000,'990K'},
  {999000,'1M'},{999999,'1M'},{1000000,'1M'},{1000001,'1.1M'},{1165456,'1.2M'},{2896228,'2.9M'},{7084907,'7.1M'},{2000000,'2M'},{15462266,'16M'},{24212979,'25M'},{44354655,'45M'},{153658835,'160M'},{368389545,'370M'},{682127276,'690M'},
  {999999999,'1B'},{1000000000,'1B'},{1100000001,'1.2B'},{2538961247,'2.6B'},{7094390884,'7.1B'},{21171107576,'22B'},{100000000001,'110B'},{1e12,'1T'},{1e12+1,'1.1T'},{1e15,'1Qa'},{2.6e15,'2.6Qa'},{1e15+1,'1.1Qa'}}
 local okT=true;local dT={}
 for _,c in ipairs(texts)do local got=Points.NeedText(c[1]);if got~=c[2]then okT=false;dT[#dT+1]=tostring(c[1])..' -> '..got..' (want '..c[2]..')'end end
 check(okT,'NeedText: whole under a million (3,800 / 18K / 540K, thousands separators below 10,000), from a million up the 2-figure value with at most one decimal and the plain suffix (1.2M / 16M / 2.6B / 22B / 1.1T)'..(#dT>0 and(': '..table.concat(dT,'; '))or''))
 check(Points.NeedText('1'..string.rep('0',33))=='1Dc'and Points.NeedText('26'..string.rep('0',33))=='26Dc'and Points.NeedText('26'..string.rep('0',32))=='2.6Dc'and Points.NeedText('99'..string.rep('0',34))=='990Dc'and Points.NeedText('1'..string.rep('0',32))=='100No'and Points.NeedText('15'..string.rep('0',29))=='1.5No'and Points.NeedText('15'..string.rep('0',30))=='15No','the biggest names go up to Dc (10^33): 1Dc, 2.6Dc, 26Dc, 990Dc, 100No, 1.5No')
 check(Points.NeedText('1'..string.rep('0',36))=='∞'and Points.NeedText('5'..string.rep('0',1011))=='∞'and Points.NeedText('9'..string.rep('9',35))=='∞','from 10^36 on (past the names, or past 10^36 after rounding up) it is "∞"')
 local shapeT=true;for _,c in ipairs(texts)do
  local t=Points.NeedText(c[1])
  if t:find('e')or t:find(',%d%d%d%a')then shapeT=false end -- (no e-notation, no "1,200K")
  local dots=select(2,t:gsub('%.',''))
  if dots>1 or(dots==1 and not t:find('^%d%.%d%a+$'))then shapeT=false end -- (one decimal, after a single digit, with a suffix)
  if c[1]<999000 and dots>0 then shapeT=false end -- (whole below a million)
 end
 check(shapeT and Points.NeedText(0)=='0','never e-notation; no decimal point below a million, at most one (after a single digit) from a million up; nothing needed is "0"')
end
local keepers={}
local pre=keeper('Forest',20);keepers[1]=pre
local ks=R.new('LocalScript');ks.Name='KeeperSpeedLabels'
local okK,errK=pcall(W.load,'KeeperSpeedLabels',ks);check(okK,'KeeperSpeedLabels loads: '..tostring(errK))
-- R153: the sign hangs on its own anchor part (KeeperSignAnchors, one per keeper, an ObjectValue 'Keeper' says whose), not on the keeper.
local function signOf(m)
 local f=workspace:FindFirstChild('KeeperSignAnchors');if not f then return nil end
 for _,a in ipairs(f:GetChildren())do local link=a:FindFirstChild('Keeper');if link and link.Value==m then return a:FindFirstChild('SpeedReq'),a end end
 return nil
end
local function pill(m)local gui=signOf(m);return gui,gui and gui.Pill and gui.Pill.Value,gui and gui.Pill and gui.Pill.Edge end
local gui,value,edge=pill(pre)
check(gui~=nil and gui:IsA('BillboardGui')and gui.Name=='SpeedReq'and gui.Pill.Caption.Text=='SPEED NEEDED'and gui.MaxDistance==250 and gui.AlwaysOnTop==false and gui.LightInfluence==0,'a keeper that was already tagged gets a "SpeedReq" billboard with the caption SPEED NEEDED, visible up to 250 studs (R153: raised from 160 for the higher sign)')
local rootOf=pre:FindFirstChild('HumanoidRootPart')
local _,anchor0=signOf(pre)
check(gui.Adornee==anchor0 and anchor0~=nil and anchor0~=rootOf and near(anchor0.Position.X,rootOf.Position.X)and near(anchor0.Position.Y,rootOf.Position.Y)and near(anchor0.Position.Z,rootOf.Position.Z),'R153: the label hangs on its own anchor at the keeper\'s spawn point (where it stood), not on the keeper\'s root')
-- height: top of the body (15) minus the root (10) = 5, +18 (R153: LIFT; it was +2.5 on the keeper's head).
check(near(gui.StudsOffsetWorldSpace.Y,23,1e-9)and gui.Size.X.Scale==0 and gui.Size.Y.Scale==0 and gui.Size.X.Offset==104 and gui.Size.Y.Offset==36,'[size] it floats well above the head (offset 23 = 5 + 18) as a small fixed 104x36 pixel sign (it was 150x50)')
local cap=gui.Pill.Caption
check(near(cap.Size.Y.Scale,.3,1e-9)and near(gui.Pill.Value.Size.Y.Scale,.6,1e-9)and cap.Size.Y.Scale*36<12 and gui.Pill.Value.Size.Y.Scale*36>=20,'[size] the caption takes about 30% of the height (under 12 px), the number about 60% (over 20 px)')
-- No PhysicalWalkSpeed yet: the player is a new runner (24).
check(value.Text=='⚡ 0  ✓'and GREEN(value.TextColor3)and GREEN(edge.Color),'The Forest keeper (20): nothing is needed and a new runner (24) is faster: green "⚡ 0  ✓" ('..value.Text..')')
-- The real keepers (RouteBalance83.KeeperSpeeds: three per biome) and the owner's numbers, exactly.
local Route=W.module('RouteBalance83')
local expected={
 {'Forest',1,{20,23,26},{'0','0','510'}},{'Jungle',6,{32,37,42},{'3,800','18K','46K'}},{'Desert',2,{50,57,65},{'92K','210K','540K'}},
 {'Snow',3,{80,92,104},{'1.2M','2.9M','7.1M'}},{'Lava',4,{128,147,166},{'16M','25M','45M'}},{'Crystal',5,{205,236,266},{'160M','370M','690M'}},
 {'Storm',7,{330,379,429},{'2.6B','7.1B','22B'}}}
local realOk=true
for _,row in ipairs(expected)do for i,e in ipairs(row[3])do if Route.KeeperSpeeds[row[2]][i]~=e then realOk=false end end end
check(realOk,'(the speeds below are the live RouteBalance83.KeeperSpeeds: 20 23 26 / 32 37 42 / 50 57 65 / 80 92 104 / 128 147 166 / 205 236 266 / 330 379 429)')
local bySpeed={}
for _,row in ipairs(expected)do for i,e in ipairs(row[3])do bySpeed[e]=e==20 and pre or keeper(row[1]..i,e,10,6)end end
player:SetAttribute('PhysicalWalkSpeed',24)
local function vtext(m)local _,v=pill(m);return v.Text end
local function vcolor(m)local _,v=pill(m);return v.TextColor3 end
local function plain(t)return(t:gsub('  ✓$',''))end
local textsOk=true;local diag={}
for _,row in ipairs(expected)do for i,e in ipairs(row[3])do
 local t=vtext(bySpeed[e]);local want='⚡ '..row[4][i]..(e<24 and'  ✓'or'')
 if t~=want then textsOk=false;diag[#diag+1]=row[1]..' '..e..' '..t..' (want '..want..')'end
end end
check(textsOk,'at walk speed 24, all 21 keepers: Forest 0 / 0 / 510, Jungle 3,800 / 18K / 46K, Desert 92K / 210K / 540K, Snow 1.2M / 2.9M / 7.1M, Lava 16M / 25M / 45M, Crystal 160M / 370M / 690M, Storm 2.6B / 7.1B / 22B'..(#diag>0 and(': '..table.concat(diag,'; '))or''))
check(RED(vcolor(bySpeed[32]))and RED(vcolor(bySpeed[330]))and GREEN(vcolor(bySpeed[20]))and GREEN(vcolor(bySpeed[23])),'red when the keeper is faster than me, green when I am faster')
local _,_,edgeJ=pill(bySpeed[32]);check(RED(edgeJ.Color),'(the outline follows)')
check(not vtext(bySpeed[32]):find('✓',1,true),'no ✓ while the keeper is faster')
-- My walk speed changes.
player:SetAttribute('PhysicalWalkSpeed',31);check(GREEN(vcolor(bySpeed[20]))and RED(vcolor(bySpeed[32]))and vtext(bySpeed[32])=='⚡ 3,800','31: still slower than the 32 keeper')
player:SetAttribute('PhysicalWalkSpeed',32);check(RED(vcolor(bySpeed[32]))and not vtext(bySpeed[32]):find('✓',1,true),'exactly 32: not faster (it takes MORE than the keeper)')
player:SetAttribute('PhysicalWalkSpeed',32.01);check(GREEN(vcolor(bySpeed[32]))and vtext(bySpeed[32])=='⚡ 3,800  ✓','32.01: green with ✓ (the number stays the points needed)')
player:SetAttribute('PhysicalWalkSpeed',51);check(GREEN(vcolor(bySpeed[50]))and vtext(bySpeed[50])=='⚡ 92K  ✓'and RED(vcolor(bySpeed[80])),'51 beats the Desert keeper (50), not the Snow one (80)')
player:SetAttribute('PhysicalWalkSpeed',331);check(GREEN(vcolor(bySpeed[330]))and vtext(bySpeed[330])=='⚡ 2.6B  ✓','331 beats the Storm keeper')
player:SetAttribute('PhysicalWalkSpeed',nil);check(vtext(bySpeed[32])=='⚡ 3,800'and RED(vcolor(bySpeed[32]))and GREEN(vcolor(bySpeed[20])),'no PhysicalWalkSpeed attribute: treated as a new runner (24)')
player:SetAttribute('PhysicalWalkSpeed','fast');check(GREEN(vcolor(bySpeed[20]))and RED(vcolor(bySpeed[32])),'(a text value too)')
player:SetAttribute('PhysicalWalkSpeed',24)
-- Independent reference (plain arithmetic, for needs under 10^15): the points needed rounded up to 2 significant figures.
local function refRound(n)
 if n<=0 then return 0 end
 if n<100 then return math.ceil(n/5)*5 end
 local step=10^(#string.format('%.0f',n)-2);return math.ceil(n/step)*step
end
local function refCommas(v)local s=string.format('%.0f',v):reverse():gsub('(%d%d%d)','%1,'):reverse();return(s:gsub('^,',''))end
local function refText(v)
 if v<10000 then return refCommas(v)end
 if v<1e6 then return string.format('%.0f',v/1e3)..'K'end
 for _,s in ipairs({{1e15,'Qa'},{1e12,'T'},{1e9,'B'},{1e6,'M'}})do
  if v>=s[1]then local q=string.format('%.1f',v/s[1]);return(q:gsub('%.0$',''))..s[2]end
 end
end
-- Reading a sign's text back: the number of points it shows, or nil when the text is not in the allowed shape: whole under a
-- million (commas only below 10,000, otherwise 1-3 digits and K), from a million up 1-3 digits with at most one non-zero
-- decimal and M / B / T / Qa ... (never "1,200K", never ".0", never e-notation).
local MULT={K=1e3,M=1e6,B=1e9,T=1e12,Qa=1e15,Qi=1e18,Sx=1e21,Sp=1e24,Oc=1e27,No=1e30,Dc=1e33}
local function shownValue(t)
 local body=plain(t):gsub('^⚡ ','')
 if body=='∞'then return math.huge,'∞',0 end
 local digits,dot,dec,suffix=body:match('^([%d,]+)(%.?)(%d*)(%a*)$');if not digits then return nil,body end
 local whole=tonumber((digits:gsub(',','')))
 if not whole or digits~=refCommas(whole)then return nil,body end -- (separators only between thousands)
 if suffix==''then if dot~=''or whole>=10000 then return nil,body end return whole,body,0 end
 local mult=MULT[suffix];if not mult or digits:find(',',1,true)or #digits>3 or whole<1 then return nil,body end
 if dot~=''and(#dec~=1 or dec=='0'or mult<1e6)then return nil,body end
 if dot==''and dec~=''then return nil,body end
 return(whole*10+(tonumber(dec)or 0))*(mult/10),body,#dec
end
-- Friend boost (R149: the boost speeds up the speed GAINED from training, never how fast you run, so the number needed
-- does not depend on it at all: whatever FriendSpeedBoost says, the signs are the same).
local escapes={20,23,26,32,37,42,50,57,65,80,92,104,128,147,166,205,236,266,330,379,429}
local function texts(b)
 player:SetAttribute('FriendSpeedBoost',b);local out={}
 -- (nudge PhysicalWalkSpeed so every sign repaints whether or not the script listens to the boost)
 local cur=player:GetAttribute('PhysicalWalkSpeed');player:SetAttribute('PhysicalWalkSpeed',(tonumber(cur)or 24)+.001);player:SetAttribute('PhysicalWalkSpeed',cur)
 for _,e in ipairs(escapes)do out[#out+1]=vtext(bySpeed[e])end
 return out
end
local function core(list)local pick={};for _,i in ipairs({1,4,7,10,13,16,19})do pick[#pick+1]=plain(list[i])end;return table.concat(pick,' | ')end
local base=texts(nil)
check(core(base)=='⚡ 0 | ⚡ 3,800 | ⚡ 92K | ⚡ 1.2M | ⚡ 16M | ⚡ 160M | ⚡ 2.6B','no friends (the first keeper of each biome): 0, 3,800, 92K, 1.2M, 16M, 160M, 2.6B')
check(core(texts(1))==core(base)and core(texts(1.1))==core(base)and core(texts(1.2))==core(base)and core(texts(1.3))==core(base),'friends do not change a single number: +10% / +20% / +30% give the same 0, 3,800, 92K, 1.2M, 16M, 160M, 2.6B ('..core(texts(1.3))..')')
-- Every sign is a whole number, a multiple of 5, never below the true need (strictly faster) and at most about 10% above it,
-- equal to the independent reference, and that many points really do beat the keeper (the plain speed curve, no boost).
local formulaOk,pointsOk,shapeOk,tightOk,sameOk=true,true,true,true,true;local fd={}
local checked=0
for _,boost in ipairs({1,1.05,1.1,1.15,1.2,1.25,1.3,5,.5})do
 local row=texts(boost)
 for i,e in ipairs(escapes)do
  if row[i]~=base[i]then sameOk=false;fd[#fd+1]='changed '..e..'/'..boost..' '..row[i]..' vs '..base[i]end
  local t=plain(row[i]);checked+=1
  local v,body,decimals=shownValue(row[i])
  if not v or v~=v or v%5~=0 or v~=math.floor(v)or t:find('e')or(v<1e6 and decimals~=0)or decimals>1 or t:find('ANY',1,true)or t:find('TOO FAST',1,true)then shapeOk=false;fd[#fd+1]='shape '..e..'/'..boost..' '..row[i]end
  if e<24 then if t~='⚡ 0'then formulaOk=false;fd[#fd+1]='0 '..e..'/'..boost..' '..row[i]end
  else
   local n=Progress.PointsFor(e)+1
   if v and v<n then pointsOk=false;fd[#fd+1]='below need '..e..'/'..boost..' '..row[i]..' < '..n end
   if v and(n>=100 and v>n*1.1 or n<100 and v>n+4)then tightOk=false;fd[#fd+1]='too far above '..e..'/'..boost..' '..row[i]..' vs '..n end
   if t~='⚡ '..refText(refRound(n))then formulaOk=false;fd[#fd+1]=e..'/'..boost..' '..row[i]..' (want '..refText(refRound(n))..')'end
   if v and not(Progress.Speed(v)>e-1e-9)then pointsOk=false;fd[#fd+1]='does not beat '..e..'/'..boost..' '..row[i]end
  end
 end
end
check(sameOk,'every sign is identical with FriendSpeedBoost at 1 / 1.05 / 1.1 / 1.15 / 1.2 / 1.25 / 1.3 / 5 / 0.5 ('..checked..' keeper / attribute combinations)'..(#fd>0 and(': '..table.concat(fd,'; '))or''))
check(shapeOk,'all '..checked..' keeper / attribute signs read a whole multiple of 5 points: whole under a million, at most one decimal from a million up (1.2M is 1,200,000), never e-notation, never "ANY" / "TOO FAST"'..(#fd>0 and(': '..table.concat(fd,'; '))or''))
check(formulaOk,'and each equals the reference (PointsFor(escape) + 1 rounded up to 2 significant figures, written as above), "0" below 24 ('..checked..' combinations)')
check(pointsOk,'and each is never below the true need, and that many points really beat the keeper (no boost counted)')
check(tightOk,'and at most 10% above the true need (+4 under 100)')
check(plain(texts(1.2)[7])=='⚡ 92K'and plain(texts(1.2)[7])=='⚡ '..refText(refRound(Progress.PointsFor(50)+1)),'(+20% friends, Desert keeper 50: still 91,501 points, rounded up to 92K)')
check(table.concat(texts(5),'|')==table.concat(base,'|')and table.concat(texts(.5),'|')==table.concat(base,'|')and table.concat(texts(0/0),'|')==table.concat(base,'|')and table.concat(texts('x'),'|')==table.concat(base,'|'),'(a boost above +30%, below 1, NaN or text changes nothing either)')
check(W.B.KeeperSpeedLabels:find('FriendSpeedBoost',1,true)==nil and W.B.KeeperSpeedLabels:find('DailyRewards',1,true)==nil,'the script does not read or listen to the friend boost at all')
-- Changing the boost while a sign is showing does not touch it.
do
 player:SetAttribute('FriendSpeedBoost',nil);local before=vtext(bySpeed[50]);player:SetAttribute('FriendSpeedBoost',1.3);adv(.5)
 check(vtext(bySpeed[50])==before and vtext(bySpeed[50])=='⚡ 92K','a friend arriving or leaving does not move the number on a sign (92K stays 92K)')
 player:SetAttribute('PhysicalWalkSpeed',51);player:SetAttribute('FriendSpeedBoost',1.3);adv(.5)
 check(GREEN(vcolor(bySpeed[50]))and RED(vcolor(bySpeed[57])),'with friends the check still compares your PhysicalWalkSpeed (51) with the keeper: green for 50, red for 57')
 player:SetAttribute('PhysicalWalkSpeed',40);player:SetAttribute('FriendSpeedBoost',1.3);adv(.5)
 check(RED(vcolor(bySpeed[50]))and RED(vcolor(bySpeed[65])),'40 x 1.3 = 52 would have beaten 50 before; now the friend boost is not a speed, so it is red ('..vtext(bySpeed[50])..')')
 player:SetAttribute('FriendSpeedBoost',nil);player:SetAttribute('PhysicalWalkSpeed',24)
end
-- Random speeds over the whole curve (a keeper at any speed): the same properties.
do
 math.randomseed(148);local bad={};local n0=0
 for _=1,400 do
  local e=24+math.random()*476;local k=keeper('Rnd',e,10,6);local t=vtext(k);local v,_,decimals=shownValue(t)
  local n=Progress.PointsFor(e)+1;n0+=1
  local ok=v and v==math.floor(v)and v%5==0 and v>=n and(n>=100 and v<=n*1.1 or n<100 and v<=n+4)and not t:find('e')and(v>=1e6 or decimals==0)and plain(t)=='⚡ '..refText(refRound(n))
  if not ok and #bad<5 then bad[#bad+1]=string.format('%.4f -> %s (need %.0f)',e,t,n)end
  CS:RemoveTag(k,'BiomeKeeper');k:Destroy()
 end
 check(#bad==0,'400 random keeper speeds (24 .. 500): each sign is a multiple of 5, whole under a million and at most one decimal from a million up, between the true need and 10% above it'..(#bad>0 and(': '..table.concat(bad,'; '))or''))
end
-- The new-runner threshold: below 24 nothing is needed ("0"); exactly 24 needs a single point, shown as 5.
local e23,e24,e2401=keeper('Edge23',23.9,10,6),keeper('Edge24',24,10,6),keeper('Edge2401',24.01,10,6)
check(plain(vtext(e23))=='⚡ 0'and vtext(e24)=='⚡ 5'and vtext(e2401)=='⚡ 5','below 24: "0"; exactly 24: 1 point (you need more than 24), shown as 5; 24.01: also 5 ('..vtext(e24)..' / '..vtext(e2401)..')')
player:SetAttribute('FriendSpeedBoost',1.3)
check(vtext(e24)=='⚡ 5'and vtext(e2401)=='⚡ 5','with +30% friends 24 and 24.01 still need a point (the number is not divided by the boost): 5')
local k31=keeper('Edge31',31,10,6)
check(plain(vtext(k31))=='⚡ '..refText(refRound(Progress.PointsFor(31)+1))and vtext(k31)~='⚡ 0','with +30% friends a 31 keeper needs the same points as without (PointsFor(31) + 1 = 3,001, rounded up: '..vtext(k31)..')')
player:SetAttribute('PhysicalWalkSpeed',31.2);check(GREEN(vcolor(k31))and RED(vcolor(bySpeed[32])),'(31.2 beats 31, not 32)')
player:SetAttribute('FriendSpeedBoost',nil);player:SetAttribute('PhysicalWalkSpeed',24)
-- The Darkened: a fixed 600 needs about 10^1011 points: "∞" (never "TOO FAST", "ANY" or a huge number).
local dark=keeper('TheVeiledOne',600)
local dt=vtext(dark)
check(dt=='⚡ ∞','without a boost The Darkened (600) needs 10^1011 points: ⚡ ∞ ('..dt..')')
check(not dt:find('TOO FAST',1,true)and not dt:find('ANY',1,true)and not dt:find('inf',1,true)and not dt:find('nan',1,true)and not dt:find('✓',1,true),'(never "TOO FAST", "ANY", inf or nan)')
check(RED(vcolor(dark)),'and it is red for a normal runner')
-- With friends The Darkened stays "∞" (the boost no longer lowers the number: it used to bring 600 / 1.3 into reach).
for _,boost in ipairs({1.1,1.2,1.3,5})do
 player:SetAttribute('FriendSpeedBoost',boost);local dtb=vtext(dark)
 check(dtb=='⚡ ∞'and RED(vcolor(dark)),'with FriendSpeedBoost '..boost..' The Darkened still shows ⚡ ∞, red ('..dtb..')')
end
player:SetAttribute('FriendSpeedBoost',1.3)
check(not vtext(dark):find('TOO FAST',1,true)and not vtext(dark):find('ANY',1,true)and not vtext(dark):find('inf',1,true)and not vtext(dark):find('nan',1,true),'(still never "TOO FAST", "ANY", inf or nan)')
player:SetAttribute('PhysicalWalkSpeed',24*1.3);check(RED(vcolor(dark)),'(31.2 is far from 600)')
player:SetAttribute('PhysicalWalkSpeed',500);check(RED(vcolor(dark))and vtext(dark)=='⚡ ∞','a max-speed runner (500) with friends here is still behind The Darkened (600): red ('..vtext(dark)..')')
player:SetAttribute('PhysicalWalkSpeed',650);check(GREEN(vcolor(dark))and vtext(dark)=='⚡ ∞  ✓','a PhysicalWalkSpeed above 600 outruns The Darkened: green with a ✓ (the number stays ∞) ('..vtext(dark)..')')
player:SetAttribute('PhysicalWalkSpeed',24)
player:SetAttribute('FriendSpeedBoost',nil)
check(Progress.PointsText(600)==('1'..string.rep('0',1011)),'(PointsText(600) is a 1 and 1011 zeros)')
-- Needs above a quadrillion points (speed above ~500.4) are still numbers, written with a big suffix, never 0.
local huge=keeper('Huge',500.45)
local ht=vtext(huge)
check(ht~='⚡ 0'and shownValue(ht)>=1e15 and not ht:find('e'),'a 500.45 keeper needs thousands of trillions of points: a number with a big name (at most one decimal), not 0 ('..ht..')')
do
 local exact=Points.Add(Progress.PointsText(500.45),'1');local want=Points.NeedText(exact);local v=shownValue(ht)
 check(ht=='⚡ '..want and v>=tonumber(exact)*(1-1e-12)and v<=tonumber(exact)*1.1 and v%5==0,'(from the exact decimal text, not tostring: '..ht..')')
end
-- Edge: from the first keeper on to the biggest number the names reach.
do
 local ok=true;local d={}
 for _,s in ipairs({500.1,500.3,500.49,500.5})do
  local k=keeper('Far'..s,s,10,6);local t=vtext(k);local v=shownValue(t)
  if not v or v~=math.floor(v)or t:find('e')then ok=false;d[#d+1]=s..' '..t end
  CS:RemoveTag(k,'BiomeKeeper');k:Destroy()
 end
 check(ok,'out past 500 the sign is still a number of points with a name suffix (at most one decimal), or ∞ when there is no name for it'..(#d>0 and(': '..table.concat(d,'; '))or''))
end
-- A keeper without the attribute gets no label until it has one.
local plainK=keeper('Plain',nil);local gp=pill(plainK)
check(gp~=nil and gp.Enabled==false,'a keeper without KeeperEscapeSpeed: the label stays off')
plainK:SetAttribute('KeeperEscapeSpeed',50);check(gp.Enabled==true and select(2,pill(plainK)).Text=='⚡ 92K','and appears when the server stamps it')
plainK:SetAttribute('KeeperEscapeSpeed',20);check(select(2,pill(plainK)).Text=='⚡ 0  ✓','(and follows changes)')
-- A keeper that is tagged before it has parts: the label finds its root when it arrives.
local late2=R.new('Model');late2.Name='LateKeeper';late2:SetAttribute('KeeperEscapeSpeed',80);late2.Parent=workspace;CS:AddTag(late2,'BiomeKeeper')
local gl=pill(late2)
check(gl==nil,'a keeper with no parts yet: no sign yet (it waits for a place and a body)')
local lr=R.new('Part');lr.Name='HumanoidRootPart';lr.Size=R.Vector3.new(2,2,1);lr.CFrame=R.CFrame.new(0,10,0);lr.Parent=late2
adv(1);check(signOf(late2)==nil,'its root alone is not a body: still no sign')
local lb=R.new('Part');lb.Name='Body';lb.Size=R.Vector3.new(4,6,2);lb.CFrame=R.CFrame.new(0,12,0);lb.Parent=late2
adv(1);gl=pill(late2)
check(gl~=nil and gl.Adornee~=lr and gl.Enabled==true and gl.Size.X.Offset==104 and gl.Size.Y.Offset==36 and near(gl.StudsOffsetWorldSpace.Y,5+18,1e-9),'R153: its body arrives: the sign appears over it, pinned at its spawn point (the same small size)')
-- Tall keepers: higher up, but the sign stays the same small size (it is never scaled up).
local tall=keeper('Giant',330,10,40)
local gt=pill(tall)
check(near(gt.StudsOffsetWorldSpace.Y,(10+(40/2-1)+40/2-10)+18,1e-6),'a 40-stud keeper: the label hangs higher up, 18 studs above the head ('..tostring(gt.StudsOffsetWorldSpace.Y)..')')
check(gt.Size.X.Offset==104 and gt.Size.Y.Offset==36 and gt.Size.X.Scale==0 and gt.Size.Y.Scale==0,'[size] and it is still 104x36 pixels (it used to grow to 330x110): the same as over a normal keeper')
local sizesOk=true;for _,k in ipairs({tall,pre,bySpeed[330],dark,huge,bySpeed[26]})do local g=pill(k);if g.Size.X.Offset~=104 or g.Size.Y.Offset~=36 then sizesOk=false end end
check(sizesOk,'[size] every keeper\'s sign is 104x36: small, fixed, whatever the keeper\'s size')
local giant2=keeper('Colossus',429,10,200);local g2=pill(giant2)
check(g2.Size.X.Offset==104 and g2.Size.Y.Offset==36 and near(g2.StudsOffsetWorldSpace.Y,80+18,1e-6),'[size] a 200-stud keeper: still 104x36, and the height offset stays capped (80 + 18)')
-- Tag removal and teardown.
CS:RemoveTag(plainK,'BiomeKeeper');check(gp.Parent==nil,'a keeper that loses the tag loses its label')
plainK:SetAttribute('KeeperEscapeSpeed',99);check(gp.Parent==nil,'(and is not updated)')
local tagged=#CS:GetTagged('BiomeKeeper')
ks.Destroying:Fire()
local left=0;for _,m in ipairs(CS:GetTagged('BiomeKeeper'))do if signOf(m)then left+=1 end end
check(left==0 and workspace:FindFirstChild('KeeperSignAnchors')==nil,'removing the script removes every label and every anchor ('..tagged..' keepers)')
local post=keeper('Post',50);check(signOf(post)==nil,'and new keepers get none')
player:SetAttribute('PhysicalWalkSpeed',100);check(true,'(no errors after teardown)')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
