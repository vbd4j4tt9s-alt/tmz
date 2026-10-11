
-- R158 bats (appended by run_bats158.sh to the set-up of docs/proposals/R156/tests/test_pyramid_server156.luau, its sections 1-5: the REAL map pass,
-- PlayerDataService, ChestService, ChaseService and SecretPyramid156; Ava now carries the Desert's secret pack, chased by the Sand Snake).
-- A REAL bat hit on her: the REAL BatService (the swing request with its start, the history in Step, the claim through BatLagComp's check) calls the
-- REAL HitByBat, and the secret pack goes back into the pyramid exactly as with today's server-decided hits ('Bat' -> SecretPyramid156).
-- R158 review: the real KeeperHit packet names the hitter (AttackerUserId). R158 (owner, no "SMACK"): the real pack drop shows no notice for a bat hit
-- (ZAP / CAUGHT as before), and the pyramid's bat notice is 'THE PACK WENT BACK IN THE PYRAMID'.
do
 for _,p in pairs(present)do if not p.CharacterAdded then p.CharacterAdded=R.signal();p.CharacterRemoving=R.signal()end end -- (the mock players had none)
 local Bats=server('BatService').new(chase);Bats:Start()
 check(Bats.Remote and Bats.Remote.Name=='BatSwing'and Bats.Remote.Parent==chase.RunAlertRemote.Parent,'R158: BatService starts beside the chase (the BatSwing remote next to RunAlert)')
 local Bo=makePlayer(758,'Bo');Bo.CharacterAdded=R.signal();Bo.CharacterRemoving=R.signal();Players.PlayerAdded:Fire(Bo)
 local aRoot=A.Character.HumanoidRootPart;local ap=aRoot.Position
 local bChar=character(Bo,R.CFrame.lookAt(V3(ap.X,ap.Y,ap.Z-7),ap))
 bChar.HumanoidRootPart.CFrame=R.CFrame.lookAt(V3(ap.X,ap.Y,ap.Z-7),ap)
 Bats:Give(Bo,bChar);Bats:Give(A,A.Character)
 local tool=Bats.Tools[Bo];check(tool~=nil,'R158: Bo has a bat');tool.Parent=bChar
 local Run=W.service('RunService')
 local function frames(n)for _=1,n do R.clock+=1/60;Run.Heartbeat:Fire(1/60)end end
 frames(4*60) -- (past the 3 s spawn grace of both; the history fills at 30 Hz)
 local start=R.clock
 check(Bats:Request(Bo,{Kind='Swing',Start=start,Id=1}),'R158: Bo swings (the request carries the click\'s start)')
 frames(18)
 local bp=bChar.HumanoidRootPart.Position;local look=(ap-bp).Unit
 local runBefore=chase.Runs[A];local drops=0;for _ in pairs(chase.Drops)do drops+=1 end;local nHits=#hits
 local packets={};chase.HitRemote.FireAllClients=function(_,p)packets[#packets+1]=p end -- (the KeeperHit packets everyone gets)
 local ok,why=Bats:Claim(Bo,{Kind='Hit',Id=1,Victim=A,ViewTime=start+.30,Own=bp,Look=V3(look.X,0,look.Z)})
 check(ok and why=='hit','R158: Bo\'s claim on the carrier passes the server\'s check ('..tostring(why)..')')
 check(#hits==nHits+1 and hits[#hits].P==A and hits[#hits].Why=='Bat','R158: ... and HitByBat knocks her down as today (Ragdoll cause \'Bat\')')
 local pk=packets[#packets]
 check(#packets==1 and pk.Cause=='Bat'and pk.VictimUserId==A.UserId and pk.AttackerUserId==Bo.UserId,'R158 review: the KeeperHit packet of the bat hit names its hitter (AttackerUserId '..tostring(pk and pk.AttackerUserId)..'): only Bo\'s own screen skips it')
 local dropsAfter=0;for _ in pairs(chase.Drops)do dropsAfter+=1 end
 check(runBefore~=nil and chase.Runs[A]==nil and A:GetAttribute(Rules.Attr)=='Open'and lastNote(A)==Rules.Text.Bat,'R158: the secret pack goes back into the pyramid ("'..tostring(lastNote(A))..'")')
 check(dropsAfter==drops and not Rules.Claimed(Data:GetPremium(A)),'R158: ... nothing is dropped on the track and nothing is claimed')
 local again=Bats:Claim(Bo,{Kind='Hit',Id=1,Victim=A,ViewTime=start+.30,Own=bp,Look=V3(look.X,0,look.Z)})
 check(not again and #hits==nHits+1,'R158: the same claim again does nothing (one claim per swing)')
 -- the owner: no "SMACK" anywhere. The REAL pack drop of ConcurrentKeeperService (its class method; the pyramid's wrapper sits on the chase object) for an
 -- ordinary pack: a bat hit shows NO notice; lightning, a keeper's catch and a hole as before
 local Class=getmetatable(chase);local said={}
 local fake=setmetatable({DropSerial=0,Drops={},Config=Config,Notifications={Show=function(_,p,text)said[#said+1]=text end},
  _getGroundedDropPosition=function()return V3(0,3,0)end,_createDroppedChest=function()return nil end,_returnPackToOrigin=function()end,
  _applyGuardianFling=function()end,_applyLightningFling=function()end},{__index=Class})
 local function notice(hit)table.clear(said);Class._dropChestAfterCatch(fake,{Player=Bo,Character=bChar,Chest={Kind='Pack'},Stage=1},hit);return table.concat(said,' | ')end
 local bat,zap,caught,hole=notice({Cause='Bat',ImpactApplied=true}),notice({Cause='Lightning',Center=V3(0,0,0)}),notice(nil),notice({Cause='Hole',ImpactApplied=true})
 check(bat==''and zap=='ZAP! PACK DROPPED'and caught=='CAUGHT! PACK DROPPED'and hole=='','R158 (owner): a bat hit that drops a pack shows no notice ("'..bat..'"); lightning "'..zap..'", a catch "'..caught..'", a hole "'..hole..'" as before')
 check(Rules.Text.Bat=='THE PACK WENT BACK IN THE PYRAMID'and not Rules.Text.Bat:upper():find('SMACK'),'R158 (owner): the pyramid pack\'s bat notice has no SMACK ("'..Rules.Text.Bat..'")')
end
print(string.format('%d checks, %d failed',checks,fails))
if fails>0 then error('pyramid bat test failed')end
