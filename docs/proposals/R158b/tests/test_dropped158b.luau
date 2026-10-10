--!nocheck
-- R158b (owner: "make it so that dropped packs have a highlight and can be seen"), on the Roblox mock with the REAL DroppedPackHighlight158b client script,
-- the REAL DroppedPackLook158b rules and the REAL ClientFxBudget (its 31-Highlight accounting). A dropped pack is built the way the server builds one
-- (a model DroppedSeed_Stage<N> with the attribute DroppedChest and a Body part, and its SeedPacket tagged BiomeSeedPackVisual).
--  0. the rules      Limits / Rank / Pulse / Distance; the Highlight stays in Fast Mode
--  1. the look       the Highlight (on the pack, always on top, white <-> gold outline, soft fill), handed to ClientFxBudget; the marker (always on top, any distance,
--                    "DROPPED PACK" + the distance); the beam over the walls; the pulse and the bob move; a track pack / carried bag / catalogue pack gets nothing
--  2. gone           taken (the model destroyed), returned, the pack destroyed alone, its tag removed, streamed out, its model losing the attribute, the script
--                    destroyed: every effect is gone at once, the frame loop stops, the budget gets its Highlights back
--  3. the budget     14 drops + 28 other Highlights (weather glows, tracked outlines): never more than the room, the nearest get them, nothing else is pushed out
--                    (31 at most, with the one the budget reserves); markers capped; beams for the nearest; no flicker between two drops
--  4. Fast Mode      the Highlight stays (3), the marker stays, no beam, no pulse, no bob; Reduced Motion: no pulse, no bob; back to normal at once; a slow device (tier 2)
--  5. streaming      the pack before its Body (it waits, then appears), the pack's own pivot, a far drop, streamed out and back in, junk tagged things
--  6. cost / leaks   no instance is made while drops stand still; 400 drops taken / returned / destroyed in 4 ways: nothing is left, every connection is cut
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(e or 1e-6)end
local RS=W.RS;local Run=W.Run;local CS=W.CS;local Gui=W.Gui;local Players=W.service('Players')
local TAG='BiomeSeedPackVisual';local FOLDER='_DroppedPackFx158b'
local me=R.new('Player');me.Name='Me';me.UserId=7;me.Parent=Players;Players.LocalPlayer=me
local L=W.module('DroppedPackLook158b');local Fx=W.module('ClientFxBudget')
local AOT=R.Enum.HighlightDepthMode.AlwaysOnTop
local function conns(sig)local n=0;for _,c in ipairs(sig._c)do if c.Connected then n+=1 end end;return n end
local function frames(n,dt)W.frames(n,dt or 1/60)end

-- 0. the rules ------------------------------------------------------------------------------------------------------------------------------------------
do
 check(L.Attribute=='DroppedChest'and L.PackTag==TAG,'the rules read the server\'s DroppedChest attribute and the pack tag the server already sets')
 check(L.MaxHighlights[1]>=1 and L.MaxHighlights[1]<=L.MaxHighlights[3],'the Highlight STAYS in Fast Mode (tier 1: '..L.MaxHighlights[1]..' of '..L.MaxHighlights[3]..')')
 check(L.MaxBeams[1]==0 and L.MaxBeams[3]>=L.MaxBeams[2]and L.MaxBeams[2]>=1,'the beam is off in Fast Mode, fewer on phones')
 check(L.MaxHighlights[3]<=6,'at most a few Highlights of the 31 ('..L.MaxHighlights[3]..')')
 local h,b,m=L.Limits(3,0,20);check(h==L.MaxHighlights[3]and b==L.MaxBeams[3]and m==L.MaxMarkers,'tier 3 with room to spare: the full limits')
 h=L.Limits(3,0,2);check(h==2,'room 2 left: 2 Highlights, not 4 ('..h..')')
 h=L.Limits(3,0,0);check(h==0,'no room left: no Highlight (the marker still shows)')
 h=L.Limits(3,3,0);check(h==3,'3 held and none to spare: they stay (they are already counted in the budget)')
 h=L.Limits(3,4,-1);check(h==3,'4 held and the world already 1 over: 3 stay, the farthest gives its slot back')
 h=L.Limits(3,4,-5);check(h==0,'5 over: all of ours give theirs back')
 h=L.Limits(3,0,-5);check(h==0,'(never below zero)')
 h=L.Limits(1,0,20);check(h==L.MaxHighlights[1],'tier 1 caps at its own limit')
 h,b=L.Limits(nil,nil,nil);check(h==0 and b==L.MaxBeams[3],'junk input is safe')
 h,b=L.Limits(9,0,20);check(h==L.MaxHighlights[3],'a tier above 3 is tier 3');h=L.Limits(-3,0,20);check(h==L.MaxHighlights[1],'a tier below 1 is tier 1')
 local items={{Distance=50},{Distance=10},{Distance=30,Held=true},{Distance=35}}
 L.Rank(items);check(items[1].Distance==10 and items[2].Distance==30 and items[3].Distance==35 and items[4].Distance==50,'nearest first')
 check(items[1].Rank==1 and items[4].Rank==4,'.Rank is the place')
 local two={{Distance=100.5,Held=false},{Distance=100,Held=true}};L.Rank(two)
 check(two[1].Held==true,'a drop that holds the Highlight keeps it against one a little nearer')
 two={{Distance=90,Held=false},{Distance=100,Held=true}};L.Rank(two);check(two[1].Held==false,'... but not against one much nearer ('..L.Stick..' studs)')
 L.Rank({});check(true,'an empty list is fine')
 local c0,c1,c2=L.Pulse(0),L.Pulse(L.PulseSeconds/2),L.Pulse(L.PulseSeconds)
 check(near(c0.R,1)and near(c0.G,1)and near(c0.B,1),'the pulse starts white')
 check(near(c1.R,L.Gold.R)and near(c1.G,L.Gold.G)and near(c1.B,L.Gold.B),'... is gold half way')
 check(near(c2.B,1,1e-9),'... and white again after '..L.PulseSeconds..' s (about 1 pulse a second: no flashing)')
 check(L.PulseSeconds>=.5,'a pulse no faster than 2 a second')
 check(L.Distance(84.4)=='84 studs'and L.Distance(0)=='0 studs'and L.Distance(-3)=='0 studs'and L.Distance(nil)==''and L.Distance(0/0)=='','the distance text')
 check(L.OutlineTransparency==0 and L.FillTransparency>=.5 and L.FillTransparency<=.75,'an opaque outline and a soft fill')
end

-- world ------------------------------------------------------------------------------------------------------------------------------------------------
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local runtime=R.new('Folder');runtime.Name='_GameplayRuntime';runtime.Parent=map
local camera=W.workspace.CurrentCamera;camera.CFrame=CF(0,3,0)
local function part(parent,name,size,pos)local p=R.new('Part');p.Name=name;p.Size=size;p.CFrame=CF(pos.X,pos.Y,pos.Z);p.Parent=parent;return p end
-- a dropped pack the way the server makes it: the model (attribute, Body = PrimaryPart) in the runtime folder, then the SeedPacket in it, then its tag
local function makeDrop(pos,opts)
 opts=opts or{}
 local host=R.new('Model');host.Name=opts.Name or'DroppedSeed_Stage1'
 if opts.Attr~=false then host:SetAttribute('DroppedChest',true);host:SetAttribute('DroppedSeed',true)end
 if opts.BiomeSeedPack then host:SetAttribute('BiomeSeedPack',true)end
 local body;if not opts.NoBody then body=part(host,'Body',V3(.2,.2,.2),pos);host.PrimaryPart=body end
 local bag=R.new('Model');bag.Name='SeedPacket';bag:SetAttribute('PackRank',opts.Rank or 2);bag:SetAttribute('WorldPack',true)
 if not opts.NoParts then local root=part(bag,'VisualRoot',opts.Size or V3(3,4,1),pos);bag.PrimaryPart=root end
 bag._props.CFrame=CF(pos.X,pos.Y,pos.Z) -- (the pivot Roblox computes from the pack's PrimaryPart)
 host.Parent=opts.Parent or runtime;bag.Parent=host
 if opts.Tag~=false then CS:AddTag(bag,TAG)end
 return {Host=host,Bag=bag,Body=body,Pos=pos}
end
local function fx()return W.workspace:FindFirstChild(FOLDER)end
local function anchors()local f=fx();return f and f:GetChildren()or{}end
local function ofClass(root,class)local out={};for _,o in ipairs(root:GetDescendants())do if o._class==class then out[#out+1]=o end end;return out end
local function liveHighlights()local n=0;for _,h in ipairs(ofClass(W.workspace,'Highlight'))do if h.Parent and h.Enabled~=false then n+=1 end end;return n end
local function mine(class)local f=fx();return f and ofClass(f,class)or{}end
local others={}
local function addGlows(n)for _=1,n do local h=R.new('Highlight');h.Name='WeatherGlow';h.Parent=W.workspace;CS:AddTag(h,'MutationGlow');others[#others+1]=h end end
local function addTracked(n)for _=1,n do local h=R.new('Highlight');h.Name='MutationRainbow';h.Parent=W.workspace;Fx.TrackHighlight(h);others[#others+1]=h end end
local function clearOthers()for _,h in ipairs(others)do h:Destroy()end;table.clear(others)end
local function setRoom(n)clearOthers();addTracked(math.max(0,Fx.MaxHighlights-Fx.HighlightReserve-n))end -- n left for new ones (nothing of ours stands)
local function start()local sc=R.new('LocalScript');sc.Name='DroppedPackHighlight158b';local ok,err=pcall(W.load,'DroppedPackHighlight158b',sc);check(ok,'DroppedPackHighlight158b loads: '..tostring(err));return sc end
local function stop(sc)sc.Destroying:Fire();frames(2)end
local baseRS=conns(Run.RenderStepped)  -- (ClientFxBudget's own frame count is part of it once it has started)
local function drain(list)for _,d in ipairs(list)do if d.Host.Parent then d.Host:Destroy()end end;table.clear(list);frames(3)end
local function byBag(bag)for _,a in ipairs(anchors())do local h=a:FindFirstChildOfClass('Highlight');if h and h.Adornee==bag then return a,h end end;return nil end
local function hasHighlight(bag)local a,h=byBag(bag);return h~=nil end
local function offsetOf(a)local g=a:FindFirstChildOfClass('BillboardGui');return g and g.StudsOffsetWorldSpace end

-- 1. the look ------------------------------------------------------------------------------------------------------------------------------------------
local sc=start()
check(fx()~=nil and #anchors()==0,'a folder for the effects, empty while nothing is dropped')
local base=Fx.HighlightRoom()
Fx.Get();baseRS=conns(Run.RenderStepped) -- (ClientFxBudget starts its own frame count with its first use; the loop of the script is counted on top of it)
local d1=makeDrop(V3(0,3,15))
do
 local a=anchors()[1]
 check(#anchors()==1 and a~=nil,'a dropped pack gets its effects the moment it appears (one anchor part)')
 check(a and a.Anchored==true and a.CanCollide==false and a.CanQuery==false and a.CanTouch==false and a.Transparency==1,'the anchor is an invisible, anchored, non-colliding, non-queryable part (nothing in the game can touch it)')
 check(a and near(a.Position.Z,15)and near(a.Position.Y,3),'at the dropped pack\'s Body ('..tostring(a and a.Position)..')')
 local h=a and a:FindFirstChildOfClass('Highlight')
 check(h and h.Adornee==d1.Bag,'a Highlight on the pack itself')
 check(h and h.DepthMode==AOT,'always on top: found through a wall (like the weather outlines)')
 check(h and h.OutlineTransparency==0 and near(h.FillTransparency,L.FillTransparency)and h.FillColor==L.FillColor,'an opaque outline and a soft pale-gold fill')
 check(h and Fx.HighlightRoom()==base-1,'handed to ClientFxBudget: one Highlight less for the track packs ('..tostring(Fx.HighlightRoom())..' vs '..tostring(base)..')')
 local g=a and a:FindFirstChildOfClass('BillboardGui')
 check(g and g.AlwaysOnTop==true and g.MaxDistance>=2000 and g.Adornee==a and g.Size.X.Offset>0 and g.Size.X.Scale==0,'the marker: always on top, the same pixel size from any distance, seen from 2000+ studs')
 local title=g and g:FindFirstChild('Title');local away=g and g:FindFirstChild('Distance')
 check(title and title.Text=='DROPPED PACK','it says DROPPED PACK')
 check(away and away.Text=='15 studs','... and how far it is ('..tostring(away and away.Text)..')')
 check(g and g:FindFirstChild('Gem')and g.Gem.Rotation==45,'a gold diamond')
 check(g and g.StudsOffsetWorldSpace.Y>=2+L.MarkerAbove-.01 and g.StudsOffsetWorldSpace.Y>3.3+1,'over the pack and clear of the server\'s own timer (3.2 studs over its middle)')
 local b=a and a:FindFirstChildOfClass('Beam')
 check(b and b.FaceCamera==true and b.LightEmission==L.BeamEmission and b.LightEmission>0 and b.Attachment0 and b.Attachment1,'a beam of light')
 check(b and b.Attachment1.CFrame.Position.Y>=60 and b.Attachment1.CFrame.Position.Y==L.BeamHeight,'... that rises well over the track walls ('..tostring(b and b.Attachment1.CFrame.Position.Y)..' studs)')
 check(b and b.Width0>b.Width1 and b.Width0<=4,'... slim: wide at the foot, thin at the top')
 check(#ofClass(a,'Part')==0 and #a:GetChildren()<=5,'nothing else: a handful of instances per drop ('..#a:GetChildren()..')')
end
-- the pulse and the bob move (tier 3, Reduced Motion off)
do
 local h=mine('Highlight')[1];local g=mine('BillboardGui')[1]
 local minB,maxB,minY,maxY,bad=2,0,math.huge,-math.huge,0
 for _=1,130 do
  frames(1)
  local c=h.OutlineColor;minB=math.min(minB,c.B);maxB=math.max(maxB,c.B)
  if c.B<L.Gold.B-1e-6 or c.B>1+1e-6 or c.R<L.Gold.R-1e-6 then bad+=1 end
  local y=g.StudsOffsetWorldSpace.Y;minY=math.min(minY,y);maxY=math.max(maxY,y)
 end
 check(minB<L.Gold.B+.05 and maxB>.97 and bad==0,('the outline pulses between white and gold (blue %.2f .. %.2f, %d off the line)'):format(minB,maxB,bad))
 check(maxY-minY>L.BobStuds and maxY-minY<=2*L.BobStuds+1e-6,('the marker bobs +-%.2f studs (%.2f)'):format(L.BobStuds,maxY-minY))
end
-- not a dropped pack: a track pack, a carried bag, a catalogue picture, the pyramid's pack, a tagged part
do
 local before=#anchors()
 makeDrop(V3(0,3,40),{Attr=false,BiomeSeedPack=true,Name='SeedPack_Slot3'})
 local carrier=R.new('Model');carrier.Name='Rival';carrier.Parent=W.workspace
 makeDrop(V3(0,3,41),{Attr=false,Parent=carrier,Name='CarriedSeed'})
 makeDrop(V3(0,3,42),{Attr=false,Parent=W.workspace,Name='SecretPyramidPack'})
 local stray=R.new('Part');stray.Parent=W.workspace;CS:AddTag(stray,TAG)
 local orphan=R.new('Model');orphan.Parent=W.workspace;CS:AddTag(orphan,TAG)
 frames(20)
 check(#anchors()==before,'a track pack, a carried bag, another pack in the world, a tagged part and a tagged model with no parent model get nothing ('..#anchors()..' vs '..before..')')
 carrier:Destroy()
end
drain({d1})
-- 2. gone ----------------------------------------------------------------------------------------------------------------------------------------------
local function goneCase(name,kill,immediate)
 local before=#anchors();local room=Fx.HighlightRoom()
 local d=makeDrop(V3(0,3,25))
 check(#anchors()==before+1,name..': the effects appear')
 kill(d)
 if not immediate then frames(20)end
 check(#anchors()==before,name..': every effect is gone'..(immediate and' at once'or'')..' ('..#anchors()..' left)')
 check(Fx.HighlightRoom()==room,name..': the Highlight is given back to the budget')
 check(#mine('Highlight')+#mine('Beam')+#mine('BillboardGui')==0,name..': no Highlight, beam or marker left')
 if d.Host.Parent then d.Host:Destroy()end
 frames(2)
end
goneCase('taken (the model is destroyed)',function(d)d.Host:Destroy()end,true)
goneCase('expired and returned home (the model is destroyed)',function(d)d.Host:Destroy()end,true)
goneCase('the pack destroyed alone',function(d)d.Bag:Destroy()end,true)
goneCase('the pack moved out of the world (streamed out)',function(d)d.Bag.Parent=nil end,true)
goneCase('the model moved out of the world (the mock fires AncestryChanged for the moved model only: here the next 0.25 s check finds it)',function(d)d.Host.Parent=nil end,false)
goneCase('its tag removed',function(d)CS:RemoveTag(d.Bag,TAG)end,true)
goneCase('the model no longer a dropped one (attribute cleared)',function(d)d.Host:SetAttribute('DroppedChest',nil)end,false)
do
 local d=makeDrop(V3(0,3,25));d.Host:Destroy();frames(2)
 check(conns(Run.RenderStepped)==baseRS,'the frame loop stops with the last drop ('..conns(Run.RenderStepped)..' vs '..baseRS..')')
 local d2=makeDrop(V3(0,3,25));check(conns(Run.RenderStepped)==baseRS+1,'... and runs while one stands');d2.Host:Destroy();frames(2)
end
-- 3. the budget ------------------------------------------------------------------------------------------------------------------------------------------
do
 local function total()return liveHighlights()+Fx.HighlightReserve end
 clearOthers();addGlows(20);addTracked(8) -- 28 others: room 2
 check(Fx.HighlightRoom()==2,'(28 other Highlights: weather glows + tracked outlines leave a room of 2)')
 local dist={1800,1500,1300,1100,900,700,500,350,200,120,80,45,30,12} -- farthest first, so creation order is not the answer
 local list={};local peak=0
 for _,z in ipairs(dist)do
  list[#list+1]=makeDrop(V3(0,3,z));peak=math.max(peak,total());frames(1);peak=math.max(peak,total())
 end
 frames(20);peak=math.max(peak,total())
 local H=0;for _,d in ipairs(list)do if hasHighlight(d.Bag)then H+=1 end end
 check(H==2,'only 2 of 14 drops get the Highlight: the room that is left ('..H..')')
 check(hasHighlight(list[14].Bag)and hasHighlight(list[13].Bag)and not hasHighlight(list[12].Bag),'... the nearest two (12 and 30 studs)')
 check(peak<=Fx.MaxHighlights,'never more than 31 Highlights in the world, the reserved one included (peak '..peak..')')
 check(liveHighlights()==30,'the 28 other Highlights are all still there (nothing pushed out): '..liveHighlights()..' in the world')
 local M,B=0,0;for _,d in ipairs(list)do local a=nil;for _,x in ipairs(anchors())do local g=x:FindFirstChildOfClass('BillboardGui');if g and near(x.Position.Z,d.Pos.Z)then a=x end end
  if a then M+=1;if a:FindFirstChildOfClass('Beam')then B+=1 end end end
 check(M==14,'every drop keeps its marker, the cheap one ('..M..' of 14)')
 check(B==L.MaxBeams[3],'beams only for the nearest '..L.MaxBeams[3]..' ('..B..')')
 -- the room goes: two more weather glows
 addGlows(2);frames(20)
 check(#mine('Highlight')==0 and total()<=Fx.MaxHighlights,'two more outlines elsewhere: ours give way, the marker stays ('..#mine('Highlight')..' left, '..total()..' in all)')
 check(#mine('BillboardGui')==14,'(all 14 markers still stand)')
 -- the room comes back
 clearOthers();frames(20)
 check(#mine('Highlight')==L.MaxHighlights[3],'with the room free again: the full '..L.MaxHighlights[3]..' ('..#mine('Highlight')..')')
 check(hasHighlight(list[14].Bag)and hasHighlight(list[13].Bag)and hasHighlight(list[12].Bag)and hasHighlight(list[11].Bag)and not hasHighlight(list[10].Bag),'... on the nearest four')
 -- a nearer drop takes the Highlight from the farthest holder, at once
 local near5=makeDrop(V3(0,3,5))
 check(hasHighlight(near5.Bag)and not hasHighlight(list[11].Bag)and #mine('Highlight')==L.MaxHighlights[3],'a new drop 5 studs away takes a Highlight from the farthest holder, at once')
 check(total()<=Fx.MaxHighlights,'(still within 31)')
 drain(list);near5.Host:Destroy();frames(3)
 check(#anchors()==0 and Fx.HighlightRoom()==Fx.MaxHighlights-Fx.HighlightReserve,'all gone: all the room is back')
 -- more drops than markers
 local many={};for i=1,40 do many[i]=makeDrop(V3((i%7)*3,3,20+i*10))end;frames(10)
 local gs=0;for _,x in ipairs(anchors())do if x:FindFirstChildOfClass('BillboardGui')then gs+=1 end end
 check(gs==L.MaxMarkers and #mine('Highlight')==L.MaxHighlights[3]and #mine('Beam')==L.MaxBeams[3],'40 drops: '..gs..' markers (cap '..L.MaxMarkers..'), '..#mine('Highlight')..' Highlights, '..#mine('Beam')..' beams')
 check(#anchors()==40,'(every drop still has its anchor)')
 drain(many);check(#anchors()==0,'40 drops gone: nothing left')
 -- no flicker between two near-equal drops with room for one: B is nearer first and takes it; the camera then moves a little each way
 setRoom(1)
 camera.CFrame=CF(-1,3,0);local Bd=makeDrop(V3(-40,3,100));local A=makeDrop(V3(40,3,100));frames(10)
 check(hasHighlight(Bd.Bag)and not hasHighlight(A.Bag),'room for one: the nearer of two drops has it')
 local swaps=0
 for i=1,60 do camera.CFrame=CF((i%2==0)and 1 or-1,3,0);frames(16);if not hasHighlight(Bd.Bag)then swaps+=1 end end
 check(swaps==0,'the camera moving 2 studs back and forth (the other drop is nearer half the time, by 2 studs) does not flip it ('..swaps..' flips)')
 camera.CFrame=CF(30,3,0);frames(20)
 check(hasHighlight(A.Bag)and not hasHighlight(Bd.Bag),'... but the other drop, much nearer, takes it')
 camera.CFrame=CF(0,3,0)
 A.Host:Destroy();Bd.Host:Destroy();frames(3);clearOthers()
end
-- 4. Fast Mode, Reduced Motion, a slow device -------------------------------------------------------------------------------------------------------------
do
 clearOthers()
 local list={};for i=1,8 do list[i]=makeDrop(V3((i%3)*4,3,20+i*30))end;frames(20)
 check(#mine('Highlight')==L.MaxHighlights[3]and #mine('Beam')==L.MaxBeams[3],'(normal: '..#mine('Highlight')..' Highlights, '..#mine('Beam')..' beams)')
 me:SetAttribute('FastMode',true);frames(20)
 check(#mine('Highlight')==L.MaxHighlights[1],'Fast Mode: the Highlight STAYS, for the nearest '..L.MaxHighlights[1]..' ('..#mine('Highlight')..')')
 check(#mine('Beam')==0,'Fast Mode: no beam')
 check(#mine('BillboardGui')==8,'Fast Mode: every marker stays ('..#mine('BillboardGui')..')')
 check(hasHighlight(list[1].Bag)and hasHighlight(list[2].Bag)and hasHighlight(list[3].Bag)and not hasHighlight(list[4].Bag),'... on the nearest three')
 local created=#R.created;local c0=mine('Highlight')[1].OutlineColor;local offs={};for i,a in ipairs(anchors())do offs[i]=offsetOf(a)end
 local moved=0
 for _=1,130 do frames(1);if mine('Highlight')[1].OutlineColor~=c0 then moved+=1 end end
 check(moved==0 and mine('Highlight')[1].OutlineColor==L.StaticOutline,'Fast Mode: the outline is one steady colour, no pulse')
 local still=true;for i,a in ipairs(anchors())do local o=offsetOf(a);if not near(o.Y,offs[i].Y)then still=false end end
 check(still,'Fast Mode: the markers do not bob')
 check(#R.created==created,'Fast Mode: nothing is made while the drops stand ('..(#R.created-created)..' made in 130 frames)')
 for _,h in ipairs(mine('Highlight'))do check(h.DepthMode==AOT and h.OutlineTransparency==0,'Fast Mode: still always on top, still an opaque outline')end
 me:SetAttribute('FastMode',nil);frames(20)
 check(#mine('Highlight')==L.MaxHighlights[3]and #mine('Beam')==L.MaxBeams[3],'Fast Mode off: the beams and the 4th Highlight are back at once ('..#mine('Highlight')..', '..#mine('Beam')..')')
 local c1=mine('Highlight')[1].OutlineColor;local seen=false;for _=1,60 do frames(1);if mine('Highlight')[1].OutlineColor~=c1 then seen=true end end
 check(seen,'... and the pulse runs again')
 -- Reduced Motion
 Gui.ReducedMotionEnabled=true;frames(20)
 local rc=mine('Highlight')[1].OutlineColor;local moved2=0;for _=1,130 do frames(1);if mine('Highlight')[1].OutlineColor~=rc then moved2+=1 end end
 check(moved2==0 and mine('Highlight')[1].OutlineColor==L.StaticOutline,'Reduced Motion: no pulse')
 local o1=offsetOf(anchors()[1]);frames(60);check(near(offsetOf(anchors()[1]).Y,o1.Y),'Reduced Motion: no bob')
 check(#mine('Highlight')==L.MaxHighlights[3]and #mine('Beam')==L.MaxBeams[3],'Reduced Motion: the Highlights and beams stay ('..#mine('Highlight')..', '..#mine('Beam')..')')
 Gui.ReducedMotionEnabled=false;frames(20)
 local c2=mine('Highlight')[1].OutlineColor;local seen2=false;for _=1,60 do frames(1);if mine('Highlight')[1].OutlineColor~=c2 then seen2=true end end
 check(seen2,'Reduced Motion off: the pulse is back')
 -- only the nearest few move
 local movers=0;local before={};for i,a in ipairs(anchors())do before[i]=offsetOf(a)end;frames(20)
 for i,a in ipairs(anchors())do if not near(offsetOf(a).Y,before[i].Y,1e-9)then movers+=1 end end
 check(movers<=6 and movers>=1 and L.MaxAnimated<=6,'only the nearest 6 markers bob; the rest are drawn still ('..movers..' of 8 moved)')
 drain(list)
end
-- 5. streaming ------------------------------------------------------------------------------------------------------------------------------------------
do
 clearOthers()
 -- the pack arrives before its Body: its own pivot places the effects, the Body arriving later puts them exactly on it
 local d=makeDrop(V3(0,3,60),{NoBody=true});frames(20)
 check(#anchors()==1 and near(anchors()[1].Position.Z,60)and hasHighlight(d.Bag),'the pack before its Body: placed at the pack\'s own pivot, no error')
 local body=part(d.Host,'Body',V3(.2,.2,.2),V3(0,3.4,60.5));d.Host.PrimaryPart=body;frames(20)
 check(#anchors()==1 and near(anchors()[1].Position.Z,60.5)and near(anchors()[1].Position.Y,3.4)and #mine('Highlight')==1,'the Body streams in: the effects move onto it (still one set)')
 d.Host:Destroy();frames(3)
 -- a pack with no parts yet (a model with no parts reports a pivot at the world origin): nothing is drawn there
 local e=makeDrop(V3(0,3,70),{NoBody=true,NoParts=true});frames(20)
 check(#anchors()==0,'a pack with no parts and no Body yet: nothing, and certainly not at the world origin ('..#anchors()..')')
 local body2=part(e.Host,'Body',V3(.2,.2,.2),e.Pos);e.Host.PrimaryPart=body2;frames(20)
 check(#anchors()==1 and near(anchors()[1].Position.Z,70),'its Body arrives: the effects appear at once on it')
 e.Host:Destroy();frames(3)
 -- far away
 local far=makeDrop(V3(0,3,1900));frames(10)
 local g=mine('BillboardGui')[1]
 check(#anchors()==1 and g and g.MaxDistance>=1900 and g:FindFirstChild('Distance').Text=='1900 studs','a drop 1900 studs away: a marker you can see from here, with its distance ('..tostring(g and g:FindFirstChild('Distance').Text)..')')
 check(#mine('Beam')==1,'... and its beam')
 -- streamed out and back in (a new instance)
 far.Bag.Parent=nil;frames(3);check(#anchors()==0,'streamed out: gone')
 local back=makeDrop(V3(0,3,1900));frames(5);check(#anchors()==1 and hasHighlight(back.Bag),'streamed back in (a new instance): tracked again')
 -- the camera moves: the distance text follows
 camera.CFrame=CF(0,3,1000);frames(20);check(mine('BillboardGui')[1]:FindFirstChild('Distance').Text=='900 studs','the distance text follows the camera ('..mine('BillboardGui')[1]:FindFirstChild('Distance').Text..')')
 camera.CFrame=CF(0,3,0)
 back.Host:Destroy();far.Host:Destroy();frames(3)
 -- a tiny / huge pack, a pack with no parts
 local tiny=makeDrop(V3(0,3,30),{Size=V3(.3,.3,.3)});local huge=makeDrop(V3(0,3,50),{Size=V3(80,90,20)})
 local empty=makeDrop(V3(0,3,70),{NoParts=true})
 frames(20)
 local ups={};for _,g2 in ipairs(mine('BillboardGui'))do ups[#ups+1]=g2.StudsOffsetWorldSpace.Y end
 table.sort(ups);check(#ups==3 and ups[1]>=1+L.MarkerAbove-.3 and ups[3]<=20+L.MarkerAbove+L.BobStuds+.01,'a tiny, a huge and an empty pack: the marker sits over each, never inside ('..table.concat(ups,', ')..')')
 tiny.Host:Destroy();huge.Host:Destroy();empty.Host:Destroy();frames(3)
end
-- 6. cost and leaks ------------------------------------------------------------------------------------------------------------------------------------
do
 clearOthers()
 local list={};for i=1,5 do list[i]=makeDrop(V3(i*3,3,20+i*40))end;frames(20)
 local n=#R.created;frames(300)
 check(#R.created==n,'five drops standing for 5 s at 60 fps: not one instance is made ('..(#R.created-n)..')')
 for _,a in ipairs(anchors())do check(#a:GetChildren()<=5,'a few instances per drop')end
 drain(list)
 local room0=Fx.HighlightRoom();local bags={}
 for i=1,400 do
  local d=makeDrop(V3((i%9)*2-8,3,10+(i%50)*20));bags[#bags+1]=d.Bag
  if i%4==0 then frames(3)end
  local kind=i%4
  if kind==0 then d.Host:Destroy()elseif kind==1 then d.Bag:Destroy()elseif kind==2 then CS:RemoveTag(d.Bag,TAG)else d.Bag.Parent=nil end
  if kind==2 or kind==3 then d.Host:Destroy()end
  if i%50==0 then check(#anchors()==0,'cycle '..i..': nothing left ('..#anchors()..')')end
 end
 frames(10)
 check(#anchors()==0 and #fx():GetChildren()==0,'400 drops taken / returned / destroyed / streamed out: nothing left in the folder')
 local live=0;for _,o in ipairs(W.workspace:GetDescendants())do if o.Name=='DroppedPackHighlight'or o.Name=='DroppedPackMarker'or o.Name=='DroppedPackBeam'or o.Name=='DroppedPackFx'then live+=1 end end
 check(live==0,'... and not one of our instances is anywhere in the world ('..live..')')
 check(Fx.HighlightRoom()==room0,'... the budget is whole again')
 check(conns(Run.RenderStepped)==baseRS,'... the frame loop is off ('..conns(Run.RenderStepped)..' vs '..baseRS..')')
 local open=0;for _,bag in ipairs(bags)do for _,sig in ipairs({bag.Destroying,bag.AncestryChanged})do open+=conns(sig)end end
 check(open==0,'... and every connection to a pack is cut ('..open..' left of 800)')
 check(conns(CS:GetInstanceAddedSignal(TAG))==1 and conns(CS:GetInstanceRemovedSignal(TAG))==1,'... only the script\'s two tag connections remain')
end
-- script destroyed: everything goes
do
 local list={};for i=1,6 do list[i]=makeDrop(V3(0,3,20+i*30))end;frames(5)
 check(#anchors()==6 and #mine('Highlight')>0,'(six drops standing)')
 stop(sc)
 check(fx()==nil,'the script destroyed: its folder and every effect are gone')
 check(Fx.HighlightRoom()==Fx.MaxHighlights-Fx.HighlightReserve,'... the budget is whole')
 check(conns(Run.RenderStepped)==baseRS,'... the frame loop is off')
 check(conns(CS:GetInstanceAddedSignal(TAG))==0 and conns(CS:GetInstanceRemovedSignal(TAG))==0,'... no tag connection is left')
 for _,d in ipairs(list)do d.Host:Destroy()end
 -- a second life: drops that already stand when the script starts
 local d=makeDrop(V3(0,3,33));local sc2=start();check(#anchors()==1 and hasHighlight(d.Bag),'a drop that stood before the script started is picked up at start')
 stop(sc2);d.Host:Destroy()
end
-- 7. a slow device: ClientFxBudget lowers the quality tier (first to 2, then to 1); what the dropped packs keep at each
do
 local sc3=start()
 local list={};for i=1,8 do list[i]=makeDrop(V3((i%3)*4,3,20+i*30))end;frames(20)
 check(#mine('Highlight')==L.MaxHighlights[3]and #mine('Beam')==L.MaxBeams[3],'(tier 3: '..#mine('Highlight')..' Highlights, '..#mine('Beam')..' beams)')
 frames(15,.2);frames(5)
 check(Fx.Get()==2,'(a slow device: the quality tier is now 2)')
 check(#mine('Highlight')==L.MaxHighlights[2]and #mine('Beam')==L.MaxBeams[2],'tier 2: '..L.MaxHighlights[2]..' Highlights and '..L.MaxBeams[2]..' beams ('..#mine('Highlight')..', '..#mine('Beam')..')')
 check(#mine('BillboardGui')==8,'tier 2: all the markers')
 frames(15,.2);frames(5)
 check(Fx.Get()==1,'(slower still: tier 1)')
 check(#mine('Highlight')==L.MaxHighlights[1]and #mine('Beam')==0 and #mine('BillboardGui')==8,'tier 1 (low graphics) is Fast Mode: '..L.MaxHighlights[1]..' Highlights, no beam, every marker')
 drain(list);stop(sc3)
end
print(string.format('dropped pack: %d checks, %d failed',checks,fails))
if fails>0 then error('dropped pack test failed')end
