-- R151 Seed Festival Square, client. Builds the hub's "life" on this screen (HubLifeArt151: trees, bushes, flower beds, lamps, benches,
-- signposts, bunting, the Seed Fountain, verges, wall lanterns, grass patches, pebbles, butterflies) once the server's
-- ChestChaseMap.HubDecor151 exists, and keeps it light:
--  * detail by device tier (ClientFxBudget; FastMode = tier 1): tier 1 builds only the "core" level, tier 2 adds "detail", tier 3 "fine";
--  * detail by distance, checked twice a second per 100-stud cell: "detail" within 230 studs (160 on tier 2, phones), "fine" within 130,
--    everything hidden when
--    the camera is far down the track (z > 320); hidden levels are unparented Folders (no per-part work);
--  * per-frame work only for the tiny ambience (butterflies, the fountain's jet / ripples / pack, petals and sparkles), and only while the
--    camera is within 150 studs of it, at tier >= 2 and without Reduced Motion (Reduced Motion: everything stands still, no particles);
--  * lamps with a PointLight switch on in the dark (The Darkened's blackout via EnvironmentLighting.Level, Rain / Thunderstorm);
--  * the track gate's keys turn green with a tick for the biomes this player is already fast enough for (KeeperSpeedLabels' rule);
--  * signposts show the bases' owners; three quiet ambience layers near the gardens (existing BiomeMood sounds only).
-- Nothing here collides, can be touched or queried, or changes gameplay.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local GuiService=game:GetService('GuiService');local SoundService=game:GetService('SoundService')
local K=require(RS:WaitForChild('HubDecorKit151'));local Art=require(RS:WaitForChild('HubLifeArt151'))
local Budget=require(RS:WaitForChild('ClientFxBudget'))
local player=Players.LocalPlayer
local map=workspace:WaitForChild('ChestChaseMap')
local V=Vector3.new
local GREEN,WHITE=Color3.fromRGB(110,236,96),Color3.fromRGB(255,255,255)
local NEAR={detail=230,detailPhone=160,fine=130};local AMBIENCE_RANGE=150;local FAR_TRACK_Z=320

local state={Root=nil,Ctx=nil,Tier=nil,Clock=0,Ambience=nil,Dark=false,LastKeys={},LastSigns={}}
local connections={}
local function reduced()local ok,v=pcall(function()return GuiService.ReducedMotionEnabled end);return ok and v==true end
local function tier()
 if player:GetAttribute('FastMode')==true then return 1 end
 local ok,t=pcall(Budget.Get);return ok and math.clamp(tonumber(t)or 2,1,3)or 2
end
local function decor()return map:FindFirstChild(K.FolderName)end
local function baseModel(i)
 local bases=map:FindFirstChild('Bases');if not bases then return nil end
 for _,b in ipairs(bases:GetChildren())do if b:GetAttribute('BaseIndex')==i then return b end end
 return nil
end
local function ownerName(i)
 local b=baseModel(i);local n=b and b:GetAttribute('BaseOwnerDisplayName')
 return(type(n)=='string'and n~='')and n or nil
end
local function readBases(dec)
 local out={}
 for i=1,6 do local f,s,c=dec:GetAttribute('Pad'..i),dec:GetAttribute('PadSize'..i),dec:GetAttribute('Color'..i)
  if typeof(f)=='CFrame'and typeof(s)=='Vector3'then out[i]={Frame=f,Size=s,Color=typeof(c)=='Color3'and c or Color3.new(1,1,1)}end
 end
 return out
end

-- Detail by distance ----------------------------------------------------------------------------------------------------------------------
local function cameraPos()local cam=workspace.CurrentCamera;return cam and cam.CFrame.Position or V(0,0,-360)end
local function applyLod()
 local ctx=state.Ctx;if not ctx then return end
 local p=cameraPos();local t=math.min(tier(),state.Tier or 1);local far=p.Z>FAR_TRACK_Z;local rm=reduced()
 for _,cell in pairs(ctx.Cells)do
  local d=V(cell.Center.X-p.X,0,cell.Center.Z-p.Z).Magnitude
  for level,f in pairs(cell.Levels)do
   local want=not far and(level=='core'or(level=='detail'and t>=2 and d<(t>=3 and NEAR.detail or math.min(NEAR.detail,NEAR.detailPhone)))or(level=='fine'and t>=3 and d<NEAR.fine))
   local parent=want and cell.Folder or nil
   if f.Parent~=parent then f.Parent=parent end
  end
 end
 for _,pe in ipairs(ctx.Emitters)do local on=not rm and pe:IsDescendantOf(workspace);if pe.Enabled~=on then pe.Enabled=on end end
end

-- Ambience: butterflies flutter and drift round their flowers; the fountain's jet pulses, its ripples spread, the pack turns --------------
local function ambienceStep(dt)
 local ctx=state.Ctx;if not ctx then return end
 state.Clock+=dt;local c=state.Clock
 local parts,cfs={},{}
 for _,b in ipairs(ctx.Butterflies)do if b.Left:IsDescendantOf(workspace)then
  local t=c*b.Speed+b.Phase
  local pos=b.Home+V(math.sin(t*.7)*3,math.sin(t*1.3)*.7,math.cos(t*.5)*3)
  local vel=V(math.cos(t*.7)*2.1,0,-math.sin(t*.5)*1.5)
  local heading=CFrame.lookAt(pos,pos+(vel.Magnitude>.01 and vel or V(0,0,-1)))
  local flap=math.sin(c*14+b.Phase)*.9
  parts[#parts+1]=b.Left;cfs[#cfs+1]=heading*CFrame.Angles(0,0,flap)*CFrame.new(-.5,0,0)
  parts[#parts+1]=b.Right;cfs[#cfs+1]=heading*CFrame.Angles(0,0,-flap)*CFrame.new(.5,0,0)
 end end
 local F=ctx.Fountain
 if F then
  if F.Jet and F.JetBase then local k=1+math.sin(c*3)*.12;F.Jet.Size=V(F.JetSize.X*k,F.JetSize.Y,F.JetSize.Z);parts[#parts+1]=F.Jet;cfs[#cfs+1]=F.JetBase*CFrame.new((k-1)*F.JetSize.X/2,0,0)end
  if F.Pack and F.PackBase then
   local cf=F.PackBase*CFrame.new(0,math.sin(c*1.6)*.35,0)*CFrame.Angles(0,c*.5,0)
   if F.Pack:IsA('Model')then F.Pack:PivotTo(cf)else parts[#parts+1]=F.Pack;cfs[#cfs+1]=cf end
  end
  for i,r in ipairs(F.Ripples)do if r:IsDescendantOf(workspace)then
   local u=((c*.35)+(i-1)*.5)%1;local d=8+u*11
   r.Size=V(r.Size.X,d,d);r.Transparency=.45+u*.55
  end end
 end
 if #parts>0 then workspace:BulkMoveTo(parts,cfs,Enum.BulkMoveMode.FireCFrameChanged)end
end
local function setAmbience(on)
 if on and not state.Ambience then state.Ambience=Run.RenderStepped:Connect(ambienceStep)
 elseif not on and state.Ambience then state.Ambience:Disconnect();state.Ambience=nil end
end
local function ambienceWanted()
 local ctx=state.Ctx;if not ctx or tier()<2 or reduced()then return false end
 local p=cameraPos()
 if ctx.Fountain and(V(p.X,0,p.Z)-V(ctx.Fountain.Center.X,0,ctx.Fountain.Center.Z)).Magnitude<AMBIENCE_RANGE then return true end
 for _,b in ipairs(ctx.Butterflies)do if(p-b.Home).Magnitude<AMBIENCE_RANGE*.7 then return true end end
 return false
end

-- Lamps in the dark --------------------------------------------------------------------------------------------------------------------------
local Env;pcall(function()Env=require(RS:WaitForChild('EnvironmentLighting',5))end)
local function isDark()
 local level=Env and tonumber(Env.Level)or 0
 local weather=RS:GetAttribute('GlobalWeather')
 return level>.3 or weather=='Rain'or weather=='Thunderstorm'
end
local function applyLamps(force)
 local ctx=state.Ctx;if not ctx then return end
 local dark=isDark();if dark==state.Dark and not force then return end;state.Dark=dark
 for _,l in ipairs(ctx.Lights)do l.Enabled=dark end
end

-- Gate keys: a tick for the biomes this player is already faster than the keeper -------------------------------------------------------------
local Progress;pcall(function()Progress=require(RS:WaitForChild('Progression81',5))end)
local function applyKeys()
 local dec=decor();local gate=dec and dec:FindFirstChild('Gate');if not gate then return end
 local mine=tonumber(player:GetAttribute('PhysicalWalkSpeed'))
 if not mine then local ok,v=pcall(function()return Progress.Speed(0)end);mine=ok and v or 0 end
 for _,key in ipairs(gate:GetChildren())do local stage=key:GetAttribute('R151Stage')
  if stage then
   local escape=tonumber(key:GetAttribute('R151EscapeSpeed'))or math.huge;local need=tostring(key:GetAttribute('R151Need')or'?')
   local fast=mine>escape
   if state.LastKeys[key]~=fast then
    local gui=key:FindFirstChild('KeyLegend');local line=gui and gui:FindFirstChild('Line3')
    if line then line.Text=(fast and'✓ 'or'⚡ ')..need;line.TextColor3=fast and GREEN or WHITE;state.LastKeys[key]=fast end
   end
  end
 end
end

-- Signposts: the owners' names --------------------------------------------------------------------------------------------------------------
local function applySigns()
 local ctx=state.Ctx;if not ctx then return end
 for _,s in ipairs(ctx.Signs)do
  local text=(ownerName(s.Base)or('Base '..s.Base))..(s.Other and(' · '..(ownerName(s.Other)or('Base '..s.Other)))or'')
  if s.Line.Text~=text then s.Line.Text=text end
 end
end

-- Ambience layers near the gardens (the existing BiomeMood loops, quietly, on the Ambience slider) ---------------------------------------------
local sounds={}
local ZONES={
 {Key='Birds',Volume=.014,Points={V(60,0,-205),V(-60,0,-205),V(84,0,-280),V(-84,0,-280),V(80,0,-370),V(-80,0,-370),V(240,0,-269),V(0,0,-560)},Radius=75},
 {Key='Crystal',Volume=.006,Points={V(-262,0,-112)},Radius=60},
 {Key='Rumble',Volume=.009,Points={V(-240,0,-269)},Radius=80},
}
local function setupSounds()
 local ok=pcall(function()
  local Mood=require(RS:WaitForChild('BiomeMood',5));local Mixer=require(RS:WaitForChild('AudioMixer',5))
  for _,z in ipairs(ZONES)do for _,row in ipairs(Mood.Audio)do if row.Key==z.Key then
   local id=Mood.AudioId(row)
   if id then
    local s=Instance.new('Sound');s.Name='Hub'..z.Key..'151';s.SoundId=id;s.Looped=true;s.Volume=0;s.PlaybackSpeed=.94
    pcall(function()s.SoundGroup=Mixer.Group('Ambience')end);s.Parent=SoundService;sounds[z.Key]={Sound=s,Zone=z}
   end
  end end end
 end)
 return ok
end
local function applySounds(dt)
 local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
 local p=root and root.Position
 for _,e in pairs(sounds)do
  local target=0
  if p and p.Z<-99 then
   local best=math.huge;for _,q in ipairs(e.Zone.Points)do best=math.min(best,(V(p.X,0,p.Z)-q).Magnitude)end
   target=e.Zone.Volume*math.clamp(1-best/e.Zone.Radius,0,1)
  end
  local s=e.Sound;local v=s.Volume+(target-s.Volume)*math.min(1,dt*2)
  if math.abs(v-target)<.0005 then v=target end
  if v~=s.Volume then s.Volume=v end
  if v>0 and not s.IsPlaying then s:Play()elseif v==0 and s.IsPlaying then s:Pause()end
 end
end

-- Build / rebuild -------------------------------------------------------------------------------------------------------------------------------
local function teardown()
 setAmbience(false)
 if state.Root then state.Root:Destroy()end
 state.Root=nil;state.Ctx=nil;state.LastKeys={}
end
local function build()
 local dec=decor();if not dec then teardown();return false end
 teardown()
 local root=Instance.new('Folder');root.Name='HubLife151'
 local t=tier()
 local ok,ctx=pcall(Art.Build,root,t,readBases(dec),ownerName)
 if not ok then warn('[R151] Hub life skipped: '..tostring(ctx));root:Destroy();return false end
 root:SetAttribute('Tier',t);root:SetAttribute('Core',ctx.Counts.core);root:SetAttribute('Detail',ctx.Counts.detail);root:SetAttribute('Fine',ctx.Counts.fine)
 state.Root=root;state.Ctx=ctx;state.Tier=t
 applyLod();applyLamps(true);applySigns()
 root.Parent=workspace -- (built unparented: one hand-over, no per-part streaming work)
 return true
end

local elapsed,slow,builtFor=0,0,nil
local function tick(dt)
 elapsed+=dt;slow+=dt
 applySounds(dt)
 if elapsed<.5 then return end
 elapsed=0
 local dec=decor()
 if dec~=builtFor then builtFor=dec;build()end
 if not state.Ctx then return end
 -- the device got faster (or FastMode was switched off): build the extra levels once
 local t=tier();if t>(state.Tier or 1)then build()end
 applyLod();applyLamps(false);applyKeys()
 setAmbience(ambienceWanted())
 if slow>=1 then slow=0;applySigns()end
end
setupSounds()
connections[#connections+1]=Run.Heartbeat:Connect(tick)
connections[#connections+1]=map.ChildRemoved:Connect(function(c)if c.Name==K.FolderName then builtFor=nil;teardown()end end)
script.Destroying:Connect(function()
 for _,c in ipairs(connections)do c:Disconnect()end
 teardown()
 for _,e in pairs(sounds)do e.Sound:Destroy()end
end)
script:SetAttribute('R151Loaded',true)
-- (the offline tests set R151TestHook on the script to drive it; in the game nothing is returned)
if script:GetAttribute('R151TestHook')then
 return{State=state,Build=build,ApplyLod=applyLod,ApplyLamps=applyLamps,ApplyKeys=applyKeys,ApplySigns=applySigns,Tick=tick,AmbienceStep=ambienceStep,
  AmbienceWanted=ambienceWanted,Teardown=teardown,Sounds=sounds,Near=NEAR}
end
