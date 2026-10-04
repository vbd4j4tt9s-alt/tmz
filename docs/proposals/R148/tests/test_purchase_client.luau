--!nocheck
-- R148, client half (the server half is test_purchase.luau): the real PurchaseCelebration on the Roblox mock, driven the way the
-- game drives it: the real PurchaseAnnouncer + NotificationService (server modules, run in the same mock, FireClient wired to
-- OnClientEvent) announce a purchase; the real NotificationClient83 / NoticeFeed83 show "✅ Purchased: <what>!"; the real
-- InteractionAudio (GemClaim) plays the chime; PurchaseCelebration makes the ring + confetti over the screen and the sparkles
-- at the character and removes them again.
-- Covers: the notice text / colour / lifetime, the chime (the existing GemClaim asset, once per purchase), the screen burst
-- (a ring + confetti that move, fade and are destroyed; one RenderStepped connection that is dropped), the character
-- sparkles (emitted once, destroyed), ReducedMotion (chime + notice, no motion), FastMode (fewer pieces), the 0.25 s gap and
-- the two-bursts cap, no character, hostile payloads, and the script being destroyed mid-burst.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
-- Player, character -------------------------------------------------------------------------------------
local Players=W.service('Players');local player=R.new('Player');player.Name='Buyer';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local character=R.new('Model');character.Name='Buyer';character.Parent=W.workspace;player.Character=character
local root=R.new('Part');root.Name='HumanoidRootPart';root.Parent=character
-- Remote events deliver in-process (FireClient -> OnClientEvent); sounds that are always "loaded" and recorded; Emit recorded.
local played={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function(self,p,...)if p==player then self.OnClientEvent:Fire(...)end end end
 if class=='Sound'then o.IsLoaded=true;o.TimeLength=1.2;o.Loaded=R.signal();o.IsPlaying=false
  o.Play=function(self)self.IsPlaying=true;played[#played+1]=self.SoundId end;o.Stop=function(self)self.IsPlaying=false end end
 return o end end
local emitted={};R.Inst.Emit=function(self,n)emitted[#emitted+1]={Emitter=self,Count=n}end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
-- The server half, real: the notification service and the announcer.
local Notifications=W.module('NotificationService').new()
local Announcer=W.module('PurchaseAnnouncer').new({Notifications=Notifications})
local remote=remotes.PurchaseDone
-- The client halves, real.
local Audio=W.module('InteractionAudio')
local Budget=W.module('ClientFxBudget');Budget.Get() -- (its one permanent RenderStepped connection is made now, not mid-test)
local feed=R.new('LocalScript');feed.Name='NotificationClient83';local okF,errF=pcall(W.load,'NotificationClient83',feed);check(okF,'NotificationClient83 loads: '..tostring(errF))
local warnsBefore=W.warns or 0
local celebration=R.new('LocalScript');celebration.Name='PurchaseCelebration';local okC,errC=pcall(W.load,'PurchaseCelebration',celebration);check(okC,'PurchaseCelebration loads: '..tostring(errC))
check((W.warns or 0)==warnsBefore,'loading prints no warnings')
local function connected()local n=0;for _,c in ipairs(W.Run.RenderStepped._c)do if c.Connected then n+=1 end end;return n end
local baseline=connected()
local function frames(n,dt)W.frames(n,dt or 1/60)end
local function seconds(s)frames(math.floor(s*60+.5))end
local function screen()return pg:FindFirstChild('PurchaseCelebration')end
local function layer()local s=screen();return s and s:FindFirstChild('Layer')end
local function count(parent,name)local n=0;if parent then for _,c in ipairs(parent:GetChildren())do if c.Name==name then n+=1 end end end;return n end
local function notices()
 local out={};local gui=pg:FindFirstChild('ChestChaseNotices83');local stack=gui and gui:FindFirstChild('NoticeStack')
 if stack then for _,l in ipairs(stack:GetChildren())do if l.Name=='Announcement'then out[#out+1]=l end end end
 return out
end
local GEM='rbxassetid://82559527540705'
check(W.module('InteractionAudio').AssetIds.GemClaim==82559527540705,'the chime is the existing InteractionAudio GemClaim asset (no new id)')
check(Audio.Asset('GemClaim')==GEM,'InteractionAudio resolves GemClaim to '..GEM)

-- 1. One purchase: notice, chime, ring + confetti, sparkles ----------------------------------------------------------------
check(screen()==nil and root:FindFirstChild('PurchaseSparks')==nil and#notices()==0,'nothing is showing before a purchase')
check(Announcer:Announce(player,'Pack',10)==true,'the announcer sends the purchase')
seconds(.2)
local shown=notices()
check(#shown==1,'one notice is showing ('..#shown..')')
check(shown[1]and shown[1].Text=='<font color="#96FF6E">✅ Purchased: 10 Mech Packs!</font>','the notice reads "✅ Purchased: 10 Mech Packs!" in light green ('..tostring(shown[1]and shown[1].Text)..')')
check(#played==1 and played[1]==GEM,'the chime (GemClaim) played once ('..#played..')')
local s=screen()
check(s~=nil and s:IsA('ScreenGui')and s.ResetOnSpawn==false and s.DisplayOrder>34 and s.DisplayOrder<100,'a ScreenGui over the shop (34) and under the notices (100)')
local L=layer()
check(L~=nil and L.Active==false and L.BackgroundTransparency==1,'its layer is transparent and never catches clicks')
check(count(L,'Ring')==1 and count(L,'Confetti')==24,'a ring and 24 confetti pieces ('..count(L,'Ring')..' / '..count(L,'Confetti')..')')
local sparks=root:FindFirstChild('PurchaseSparks');local emitter=sparks and sparks:FindFirstChild('Sparks')
check(sparks~=nil and sparks:IsA('Attachment')and emitter~=nil and emitter:IsA('ParticleEmitter'),'a sparkle emitter on an attachment at the character')
check(#emitted==1 and emitted[1].Emitter==emitter and emitted[1].Count==22,'the sparkles emit once, 22 particles ('..#emitted..' / '..tostring(emitted[1]and emitted[1].Count)..')')
check(emitter and emitter.Rate==0 and emitter.Texture:find('sparkles_main')~=nil,'the emitter only bursts (rate 0) and uses the stock sparkle texture')
check(connected()==baseline+1,'one RenderStepped connection drives the burst ('..connected()-baseline..')')
-- the pieces move and fade
local moved=false;local rotated=false;local fading=false
for _,piece in ipairs(L:GetChildren())do
 if piece.Name=='Confetti'then
  if piece.Position.X.Offset~=0 or piece.Position.Y.Offset~=0 then moved=true end
  if piece.Rotation~=0 then rotated=true end
 end
end
check(moved and rotated,'confetti flies and spins')
local ring=L.Ring;local early=ring.Size.X.Offset
seconds(.2)
check(ring.Size.X.Offset>early,'the ring grows ('..early..' -> '..ring.Size.X.Offset..')')
check(ring.Edge.Transparency>0 and ring.Edge.Transparency<1,'the ring fades as it grows')
seconds(.7)
for _,piece in ipairs(L:GetChildren())do if piece.Name=='Confetti'and piece.BackgroundTransparency>0 then fading=true end end
check(fading,'confetti fades out near the end')
check(ring.Visible==false,'the ring is gone before the pieces')
-- cleaned up
seconds(.6)
check(screen()==nil,'the screen layer is destroyed once the burst ends')
check(connected()==baseline,'the RenderStepped connection is dropped ('..connected()-baseline..' left)')
check(root:FindFirstChild('PurchaseSparks')~=nil,'the sparkles are still there at ~1.7 s (their particles are still living)')
seconds(.3)
check(root:FindFirstChild('PurchaseSparks')==nil,'the sparkle attachment is removed at ~1.8 s')
check(#root:GetChildren()==0,'the character is left clean')
-- the notice stays for its 4 seconds, then goes
check(#notices()==1,'the notice is still showing at ~2 s')
seconds(1.9)
check(#notices()==1,'the notice is still showing at ~3.9 s (it stays 4 s)')
seconds(.5)
check(#notices()==0,'the notice is gone after its 4 seconds')

-- 2. Every kind of purchase plays the same celebration ---------------------------------------------------------------------
local ids={}
for _,case in ipairs({{'Pack',1,'1 Mech Pack'},{'Bundle','CashMega','+1.4T Cash'},{'Pass','Speed','Double Speed Pass'},{'Gift','Growth','Double Plant Growth Gift'},{'Gems',12,'12 Gems'}})do
 played={};emitted={}
 check(Announcer:Announce(player,case[1],case[2]),'announce '..case[1])
 seconds(.1)
 local shownNow=notices();local last=shownNow[#shownNow]
 check(last and last.Text:find('✅ Purchased: '..case[3]..'!',1,true)~=nil,case[1]..': the notice names "'..case[3]..'"')
 check(#played==1 and played[1]==GEM and screen()~=nil and root:FindFirstChild('PurchaseSparks')~=nil,case[1]..': chime + burst + sparkles')
 seconds(2.2)
 check(screen()==nil and root:FindFirstChild('PurchaseSparks')==nil,case[1]..': all cleaned up')
end
seconds(4)
check(#notices()==0,'notices expire')

-- 3. ReducedMotion: the notice and the chime stay, no motion at all ----------------------------------------------------------
W.Gui.ReducedMotionEnabled=true
played={};emitted={}
Announcer:Announce(player,'Pack',5);seconds(.2)
check(#played==1 and played[1]==GEM,'ReducedMotion: the chime still plays')
check(#notices()==1 and notices()[1].Text:find('5 Mech Packs',1,true)~=nil,'ReducedMotion: the notice still shows')
check(screen()==nil and#emitted==0 and root:FindFirstChild('PurchaseSparks')==nil,'ReducedMotion: no confetti, no ring, no sparkles')
check(connected()==baseline,'ReducedMotion: no frame connection made')
W.Gui.ReducedMotionEnabled=false
seconds(5)

-- 4. FastMode (the effects budget tier 1): fewer pieces -----------------------------------------------------------------------
player:SetAttribute('FastMode',true)
played={};emitted={}
Announcer:Announce(player,'Pack',5);seconds(.1)
check(count(layer(),'Confetti')==8 and#emitted==1 and emitted[1].Count==8,'FastMode: 8 confetti and 8 sparkles ('..count(layer(),'Confetti')..' / '..tostring(emitted[1]and emitted[1].Count)..')')
seconds(2.2)
check(screen()==nil and root:FindFirstChild('PurchaseSparks')==nil and connected()==baseline,'FastMode: cleaned up')
player:SetAttribute('FastMode',nil)

-- 5. The 0.25 s gap and the two-bursts cap ---------------------------------------------------------------------------------------
played={};emitted={}
for _=1,6 do remote.OnClientEvent:Fire({Kind='Pack',Name='1 Mech Pack'})end
check(#played==1 and count(layer(),'Ring')==1 and#emitted==1,'six events in the same instant make ONE burst and ONE chime ('..#played..' / '..count(layer(),'Ring')..')')
seconds(.3);remote.OnClientEvent:Fire({Kind='Pack',Name='1 Mech Pack'})
check(count(layer(),'Ring')==2 and count(layer(),'Confetti')==48 and#played==2,'a second burst 0.3 s later runs beside the first ('..count(layer(),'Ring')..' rings)')
seconds(.3);remote.OnClientEvent:Fire({Kind='Pack',Name='1 Mech Pack'})
check(count(layer(),'Ring')==2 and#played==3 and#emitted==2,'a third while two are alive adds no more pieces (chime only)')
check(connected()==baseline+1,'still one connection for all bursts')
seconds(2)
check(screen()==nil and connected()==baseline and root:FindFirstChild('PurchaseSparks')==nil,'all bursts end and clean up')
seconds(3)

-- 6. Hostile / broken payloads do nothing ---------------------------------------------------------------------------------------
played={};emitted={}
for _,bad in ipairs({'x',5,true,{},{Kind='Pack'},{Name='x'},{Kind='Pack',Name=''},{Kind=5,Name='x'},{Kind='Pack',Name=5},{Kind='Pack',Name=string.rep('x',81)}})do
 remote.OnClientEvent:Fire(bad);seconds(.3)
end
remote.OnClientEvent:Fire(nil)
check(#played==0 and screen()==nil and#emitted==0,'garbage payloads make no sound and no effect')
remote.OnClientEvent:Fire({Kind='Pack',Name=string.rep('x',80)});seconds(.1)
check(#played==1 and screen()~=nil,'an 80-character name is fine')
seconds(2.5)

-- 7. No character / no root part -----------------------------------------------------------------------------------------------------
player.Character=nil;played={};emitted={}
Announcer:Announce(player,'Pack',1);seconds(.1)
check(#played==1 and screen()~=nil and#emitted==0,'no character: the chime and the screen burst still happen, no sparkles')
seconds(2.2)
local bare=R.new('Model');bare.Name='Bare';bare.Parent=W.workspace;player.Character=bare
Announcer:Announce(player,'Pack',1);seconds(.1)
check(screen()~=nil and#emitted==0,'a character without a root part: screen burst only')
seconds(2.2)
player.Character=character
check(screen()==nil and connected()==baseline,'cleaned up')

-- 8. Destroyed mid-burst -----------------------------------------------------------------------------------------------------------------
Announcer:Announce(player,'Pack',1);seconds(.2)
check(screen()~=nil and connected()==baseline+1,'a burst is running')
celebration:Destroy()
check(screen()==nil and connected()==baseline,'destroying the script removes its layer and its connection')
played={};emitted={}
Announcer:Announce(player,'Pack',1);seconds(.2)
check(#played==0 and screen()==nil and#emitted==0,'a destroyed script ignores later purchases')
seconds(2)
check(root:FindFirstChild('PurchaseSparks')==nil,'the sparkle left behind is removed by its own timer')
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
