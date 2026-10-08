-- R154 B1 (owner: "for the lag fixes we can implement B3 and B1"): appended to the census world (lag153_census.luau minus its last line) by run_census154.sh.
-- Counts the sun's shadow casters in the finished world, split by what the rule is about:
--   saved   = parts the owner's place file holds (the mock marks them _place when it loads the map): never touched by B1
--   scripted = parts the game's scripts built or cloned; "tiny" = largest side under 1.5 studs; the keyboard's own keys are counted apart (B3 changes how many there are)
--   chars   = parts of a model that holds a Humanoid (the runner, the hub display avatars, the Verity NPC ...): never touched by B1
-- Printed as "SHADOWS tier= spot= k=v ..." for both sides; run_census154.sh compares them.
do
 local ws=W.workspace
 local function chain(o)
  local inWs,kb,char=false,false,false
  local p=o._parent
  while p do
   if p==ws then inWs=true end
   if p._props and p._props.Name=='KeyboardTrackVisuals' then kb=true end
   if not char and p._class=='Model' then for _,c in ipairs(p._children) do if c._class=='Humanoid' then char=true;break end end end
   p=p._parent
  end
  return inWs,kb,char
 end
 local n={casters=0,tiny_casters=0,tiny_scripted=0,tiny_saved=0,big_casters=0,big_nocast=0,kb_casters=0,char_casters=0,char_tiny_casters=0,char_nocast=0,saved_casters=0,saved_nocast=0}
 local radius={casters=0,tiny=0}
 local rx,rz=0,(SPOT=='hub') and -330 or (RUNNER and RUNNER[2] or 1300)
 for _,o in ipairs(R.created) do
  if o._class and not o._destroyed and o:IsA('BasePart') and (o._props.Transparency or 0)<1 then -- (drawn parts only: a fully transparent anchor casts no shadow)
   local inWs,kb,char=chain(o)
   if inWs then
    local s=o._props.Size;local side=math.max(s.X,s.Y,s.Z)
    local casts=o._props.CastShadow~=false
    local saved=o._place~=nil
    if casts then
     n.casters+=1
     local cf=o._props.CFrame.Position
     if (cf.X-rx)^2+(cf.Z-rz)^2<=400*400 then radius.casters+=1;if side<1.5 then radius.tiny+=1 end end
    end
    if saved then if casts then n.saved_casters+=1 else n.saved_nocast+=1 end end
    if kb then if casts then n.kb_casters+=1 end
    elseif char then if casts then n.char_casters+=1;if side<1.5 then n.char_tiny_casters+=1 end else n.char_nocast+=1 end
    elseif side<1.5 then
     if casts then n.tiny_casters+=1;if saved then n.tiny_saved+=1 else n.tiny_scripted+=1 end end
    else
     if casts then n.big_casters+=1 else n.big_nocast+=1 end
    end
   end
  end
 end
 local keys={'casters','tiny_casters','tiny_scripted','tiny_saved','big_casters','big_nocast','kb_casters','char_casters','char_tiny_casters','char_nocast','saved_casters','saved_nocast'}
 local out={}
 for _,k in ipairs(keys) do out[#out+1]=k..'='..n[k] end
 print(string.format('SHADOWS tier=%d spot=%s %s within400=%d within400_tiny=%d',TIER,SPOT,table.concat(out,' '),radius.casters,radius.tiny))
end
print('SHADOWS154 DONE')
