-- R158l (owner: "give me a command that can make me giant and I can give packs and I can make them rain from the sky and disco all over", then "a server-wide sound"): the game owner's
-- party commands. OwnerUpdateCommands82 dispatches here (X.Actions). Four SEPARATE commands, each with its own on / off, none starting another; all of them GAME OWNER ONLY (an admin in
-- AdminUserIds is refused) and all session only (nothing here is saved). givepack is not here: it is the normal /test pack code (StudioTestCommands) with the words of PartyRules158l.GivePlan.
--   giant [1-20|off] [@name]   scales the target's character (Model:ScaleTo: R15 and R6) by that much (5 when no number), keeping the game's own size rule (Config.PlayerScaleMultiplier) under it.
--              Walk speed stays the game's (earned speed): a giant does not run faster. JumpPower grows with sqrt(scale) (JumpHeight with scale) so the jump keeps its look, HipHeight is
--              scaled by ScaleTo, the camera may zoom out further, the character is lifted by the added height so no one grows into the floor. It SURVIVES RESPAWN (the new character is
--              scaled again once the game has applied its own scale) until giant off (or scale 1) or the player leaves. MovementGuard is told (OwnerTestState82.Giant: no wall sweep; MovementGuard.Reset
--              after every change, so the sudden height is no "teleport"). A giant's root is high above the ground, so Hold-E prompts out of reach: giant off first.
--   disco [on|off|seconds]    the server-wide party: ONE workspace attribute (Disco158l: nil = off, -1 = until off, a server time = until then; DiscoCenter158l = the hub) that every client draws
--              (DiscoClient158l: beams, a ball, a dance floor, confetti, a colour tint, fewer lights in Fast Mode, no flashing for Reduced Motion). The server does nothing else.
--   packrain [count] [biome] [rarity] [seconds] | off    PackRain158l.
--   sound <id> [volume 0-10] [loop] | stop    one Sound (OwnerSound158l) in SoundService, played from the server: everyone hears it, also a player who joins during it; a new one replaces the old.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local SoundService=game:GetService('SoundService')
local Access=require(script.Parent.OwnerCommandAccess)
local State=require(script.Parent.OwnerTestState82)
local Rules=require(RS:WaitForChild('PartyRules158l'))
local M={}
M.Actions={giant=true,packrain=true,disco=true,sound=true}
M.OwnerOnly={giant=true,packrain=true,disco=true,sound=true}
local function isOwner(p)local f=Access.IsOwner;return type(f)=='function'and f(p)==true end
-- giant -----------------------------------------------------------------------------------------------------------------------------------------------------------
local giants=setmetatable({},{__mode='k'}) -- player -> {Scale, Connection}
local originals=setmetatable({},{__mode='k'}) -- character -> {Walk, Jump, JumpHeight} as the game made them (before the first giant scale)
local hooked=false
local function standing(character,humanoid,root)
 local leg=humanoid.RigType==Enum.HumanoidRigType.R6 and character:FindFirstChild('Left Leg')
 return root.Size.Y/2+humanoid.HipHeight+(leg and leg.Size.Y or 0)
end
-- Scales the character to scale x the game's own size (nil = back to the game's own size). Returns true when it did.
local function scaleCharacter(p,character,scale)
 local humanoid=character:FindFirstChildOfClass('Humanoid');local root=character:FindFirstChild('HumanoidRootPart')
 if not humanoid or not root or humanoid.Health<=0 then return false end
 local was=originals[character]
 if not was then was={Walk=humanoid.WalkSpeed,Jump=humanoid.JumpPower,JumpHeight=humanoid.JumpHeight};originals[character]=was end
 local before=standing(character,humanoid,root)
 local base=tonumber(character:GetAttribute('ChestChaseAvatarScale'))or 1
 local ok,message=pcall(function()character:ScaleTo(base*(scale or 1))end)
 if not ok then warn('[R158l] Giant scaling failed: '..tostring(message));return false end
 -- ScaleTo scales WalkSpeed / JumpPower / JumpHeight too: speed stays the game's (the Bases tick keeps setting it), the jump grows with the body.
 humanoid.WalkSpeed=was.Walk
 local jump,height=tonumber(was.Jump)or 50,tonumber(was.JumpHeight)or 7.2
 humanoid.JumpPower=scale and math.min(jump*math.sqrt(scale),400)or jump
 humanoid.JumpHeight=scale and math.min(height*scale,500)or height
 character:PivotTo(character:GetPivot()+Vector3.new(0,standing(character,humanoid,root)-before,0)) -- (the pivot stays fixed while the legs grow: lift by the added height, or lower it again)
 if not scale then originals[character]=nil end
 pcall(function()require(script.Parent.MovementGuard).Reset(p,1.5)end)
 return true
end
-- Runs fn once the game has applied its own size to this character (BaseService.ApplyCharacterScale sets ChestChaseAvatarScale), or after 10 s whatever happens.
local function whenReady(character,fn)
 if character:GetAttribute('ChestChaseAvatarScale')~=nil then fn();return end
 local done=false;local connection
 connection=character:GetAttributeChangedSignal('ChestChaseAvatarScale'):Connect(function()if done then return end;done=true;connection:Disconnect();fn()end)
 task.delay(10,function()if done then return end;done=true;connection:Disconnect();fn()end)
end
local function hook()
 if hooked then return end;hooked=true
 Players.PlayerRemoving:Connect(function(p)
  local g=giants[p];if g and g.Connection then g.Connection:Disconnect()end;giants[p]=nil;State.SetGiant(p,nil)
 end)
end
local function setGiant(p,scale)
 hook()
 local g=giants[p]
 if not g then
  g={Scale=scale}
  g.Connection=p.CharacterAdded:Connect(function(character)
   whenReady(character,function()
    task.spawn(function() -- (the new character: its parts arrive a moment after CharacterAdded)
     character:WaitForChild('Humanoid',5);character:WaitForChild('HumanoidRootPart',5)
     task.wait(.25) -- (the game's own spawn set-up moves the character to its base right after it sizes it: the giant comes after that, so it is lifted from where it really stands)
     if giants[p]==g and p.Character==character then scaleCharacter(p,character,g.Scale)end
    end)
   end)
  end)
  giants[p]=g
 end
 g.Scale=scale;State.SetGiant(p,scale);p:SetAttribute(Rules.Giant.Attribute,scale)
 p.CameraMaxZoomDistance=math.clamp(50*scale,100,1000) -- (the camera may stand back far enough to see a giant)
 local character=p.Character
 if character and scaleCharacter(p,character,scale)then return true,'@'..p.Name..' is a giant: x'..scale..' (the game\'s own size under it). Walk speed is unchanged. giant off puts them back; it also survives a respawn.'end
 return true,'@'..p.Name..': giant x'..scale..' is set; it applies as soon as their character is there (and after every respawn) until giant off.'
end
local function clearGiant(p)
 local g=giants[p]
 if not g then return true,'@'..p.Name..' is not a giant.'end
 giants[p]=nil;if g.Connection then g.Connection:Disconnect()end
 State.SetGiant(p,nil);p:SetAttribute(Rules.Giant.Attribute,nil);p.CameraMaxZoomDistance=Rules.Giant.ZoomDefault
 local character=p.Character;if character then scaleCharacter(p,character,nil)end
 return true,'@'..p.Name..' is normal size again.'
end
local function giant(_,p,a)
 local scale,usage=Rules.ParseGiant(a);if not scale then return false,usage end
 if scale=='off'then return clearGiant(p)end
 return setGiant(p,scale)
end
-- disco -------------------------------------------------------------------------------------------------------------------------------------------------------------
local disco={Token=0}
local function discoCenter(ctx)
 local map=ctx.Map;local spawn=map and map.FallbackSpawn
 if spawn and spawn.Position then return spawn.Position end
 local lobby=map and map.LobbyFolder;local floor=lobby and lobby:FindFirstChild('LobbyFloor')
 if floor then return Vector3.new(floor.Position.X,floor.Position.Y+floor.Size.Y/2,floor.Position.Z)end
 return Vector3.new(0,5,0)
end
local function discoLeft()
 local v=workspace:GetAttribute(Rules.Disco.Attribute)
 if v==nil or v==0 then return nil end
 if v<0 then return math.huge end
 return math.max(0,v-workspace:GetServerTimeNow())
end
local function discoOff()
 disco.Token+=1
 workspace:SetAttribute(Rules.Disco.Attribute,nil);workspace:SetAttribute(Rules.Disco.CenterAttribute,nil)
end
local function discoOn(ctx,seconds)
 disco.Token+=1;local token=disco.Token
 workspace:SetAttribute(Rules.Disco.CenterAttribute,discoCenter(ctx))
 workspace:SetAttribute(Rules.Disco.Attribute,seconds and(workspace:GetServerTimeNow()+seconds)or Rules.Disco.Forever)
 if seconds then task.delay(seconds,function()if disco.Token==token then discoOff()end end)end
end
local function discoCommand(ctx,a)
 local spec,usage=Rules.ParseDisco(a);if not spec then return false,usage end
 if spec.Mode=='status'then
  local left=discoLeft()
  return true,left==nil and'The disco is off.'or(left==math.huge and'The disco is on until /test disco off.'or string.format('The disco is on for %d more seconds.',math.ceil(left)))
 end
 if spec.Mode=='off'then
  local was=discoLeft()~=nil;discoOff()
  return true,was and'The disco is off: the lights, the ball and the tint are gone on every screen.'or'The disco was not on.'
 end
 discoOn(ctx,spec.Seconds)
 return true,spec.Seconds and string.format('DISCO for %d seconds: every player sees the lights, the ball, the dance floor, the confetti and the tint. /test disco off ends it. (Fast Mode: fewer lights; Reduced Motion: no flashing.)',spec.Seconds)
  or'DISCO until /test disco off: every player sees the lights, the ball, the dance floor, the confetti and the tint. (Fast Mode: fewer lights; Reduced Motion: no flashing.)'
end
-- sound -------------------------------------------------------------------------------------------------------------------------------------------------------------
local soundToken=0
local function stopSound()
 soundToken+=1
 local old=SoundService:FindFirstChild(Rules.Sound.Name)
 if old then pcall(function()old:Stop()end);old:Destroy()end
 return old~=nil
end
local function soundCommand(_,a)
 local spec,usage=Rules.ParseSound(a);if not spec then return false,usage end
 if spec.Stop then return true,stopSound()and'The sound is stopped and removed.'or'No sound is playing.'end
 stopSound();local token=soundToken
 local s=Instance.new('Sound');s.Name=Rules.Sound.Name;s.SoundId=spec.Id;s.Volume=spec.Volume;s.Looped=spec.Loop;s.Parent=SoundService -- (in SoundService: not positional; everyone hears it)
 local loaded=s.IsLoaded==true
 local connection=s.Loaded:Connect(function()loaded=true end)
 for _=1,Rules.Sound.LoadTicks do
  if loaded or s.IsLoaded==true or soundToken~=token then break end
  task.wait(Rules.Sound.LoadTick)
 end
 connection:Disconnect()
 if soundToken~=token then if s.Parent then s:Destroy()end;return false,'A newer /test sound replaced this one.'end
 if not(loaded or s.IsLoaded==true)then s:Destroy();return false,Rules.Sound.FailText end
 s:Play()
 s.Ended:Connect(function()if s.Parent and soundToken==token then s:Destroy()end end)
 return true,string.format('Playing %s for everyone (volume %s%s). /test sound stop ends it; a new /test sound replaces it.',spec.Id,tostring(spec.Volume),spec.Loop and', looping'or'')
end
-- dispatch ----------------------------------------------------------------------------------------------------------------------------------------------------------
function M.Execute(ctx,p,action,a,requester)
 requester=requester or p
 if M.OwnerOnly[action]and not isOwner(requester)then return false,'/test '..action..' is for the game owner only (admins cannot use it).'end
 local ok,okay,text=pcall(function()
  if action=='giant'then return giant(ctx,p,a)
  elseif action=='disco'then return discoCommand(ctx,a)
  elseif action=='sound'then return soundCommand(ctx,a)
  elseif action=='packrain'then
   local spec,usage=Rules.ParseRain(a);if not spec then return false,usage end
   local Rain=require(script.Parent.PackRain158l)
   if spec.Off then return Rain.Stop(ctx)elseif spec.Status then return Rain.Status()end
   return Rain.Start(ctx,spec)
  end
  return false,'Unknown command.'
 end)
 if not ok then warn('[R158l] /test '..action..': '..tostring(okay));return false,'Command failed; check server Output.'end
 return okay,text
end
return M
