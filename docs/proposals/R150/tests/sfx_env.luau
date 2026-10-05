--!nocheck
-- R150 shared mock set-up for the SFX tests: every Sound made by a script is recorded (plays, start position, speed, group), a file can be
-- made "cold" (it loads later), InteractionAudio can be replaced by a recorder, and a logged-in local player with a character exists.
-- Usage: local W=require('./world');local E=require('./sfx_env')(W)
return function(W)
 local R=W.R
 local E={W=W,R=R,sounds={},cold={},preloaded={}}
 W.service('Debris').AddItem=function()end
 W.service('ContentProvider').PreloadAsync=function(_,list,cb)for _,s in ipairs(list)do E.preloaded[s]=true;if cb then cb(s.SoundId,R.Enum.AssetFetchStatus.Success)end end end
 W.service('HttpService').JSONDecode=function()return {}end
 do local n=0;W.service('HttpService').GenerateGUID=function()n+=1;return 'guid-'..n end end
 do local CAS=W.service('ContextActionService');W.actions=W.actions or{}
  if not CAS.BindActionAtPriority then function CAS.BindActionAtPriority(_,name,fn)W.actions[name]=fn end end
  if not CAS.UnbindAction then function CAS.UnbindAction(_,name)W.actions[name]=nil end end
  if not CAS.BindAction then function CAS.BindAction(_,name,fn)W.actions[name]=fn end end end
 do
  local inew=R.Instance.new
  R.Instance.new=function(class,parent)
   local o=inew(class,parent)
   if class=='Sound'then
    o.Ended=R.signal();o.Loaded=R.signal();o.TimeLength=12;o.IsPlaying=false;o.TimePosition=0;o.PlaybackSpeed=1;o.Plays=0;o.PlayLog={}
    o.IsLoaded=true
    local id=nil
    o.Play=function(self)
     self.IsPlaying=true;self.Plays+=1
     self.PlayLog[#self.PlayLog+1]={At=R.clock,TimePosition=self.TimePosition,Speed=self.PlaybackSpeed,Volume=self.Volume,Group=self.SoundGroup}
     self.PlayedAt=R.clock
    end
    o.Stop=function(self)self.IsPlaying=false;self.Stops=(self.Stops or 0)+1 end
    -- A "cold" file: IsLoaded is false until E.load(sound) (the engine fires Loaded when the asset arrives).
    o.Changed:Connect(function(k)
     if k=='SoundId'and E.cold[o.SoundId]then o._props.IsLoaded=false end
    end)
    E.sounds[#E.sounds+1]=o
   end
   if class:find('Button')then o.MouseButton1Down=R.signal();o.MouseButton1Up=R.signal()end
   if class=='RemoteEvent'then o.OnClientEvent=R.signal();o.OnServerEvent=R.signal();o.FireServer=function()end;o.FireClient=function()end;o.FireAllClients=function()end end
   return o
  end
 end
 function E.load(sound)sound._props.IsLoaded=true;sound.Loaded:Fire()end
 -- sounds by instance name (optionally by SoundId)
 function E.named(name,id)local out={};for _,s in ipairs(E.sounds)do if s.Name==name and(not id or s.SoundId==id)then out[#out+1]=s end end;return out end
 function E.plays(name)local n=0;for _,s in ipairs(E.named(name))do n+=s.Plays end;return n end
 function E.totalPlays()local n=0;for _,s in ipairs(E.sounds)do n+=s.Plays end;return n end
 function E.resetPlays()for _,s in ipairs(E.sounds)do s.Plays=0;s.PlayLog={};s.IsPlaying=false end end
 -- InteractionAudio replaced by a recorder (key, gap, time); everything else a client script calls on it is a no-op.
 function E.recorder()
  local log={}
  local A={Log=log,AssetIds={},Muted={}}
  function A.Play(key,gap)log[#log+1]={Key=key,Gap=gap,At=R.clock};return true end
  function A.Mute(key,seconds)A.Muted[key]=(A.Muted[key]or 0)+1 end
  function A.Preload()end
  function A.Transaction(kind)if kind=='Buy'or kind=='Sell'then return A.Play('KaChing')elseif kind=='Equip'then return A.Play('Equip')end;return false end
  function A.Asset(key)return 'rbxassetid://1'end
  function A.count(key)local n=0;for _,e in ipairs(log)do if not key or e.Key==key then n+=1 end end;return n end
  function A.keys()local out={};for _,e in ipairs(log)do out[#out+1]=e.Key end;return table.concat(out,',')end
  function A.clear()table.clear(log);table.clear(A.Muted)end
  W.stub('InteractionAudio',A)
  return A
 end
 -- a local player with a character, PlayerGui and Backpack
 function E.player(name)
  local Players=W.service('Players');local p=R.new('Player');p.Name=name or'Tester';p.UserId=7;p.Parent=Players;Players.LocalPlayer=p
  if not Players.PlayerAdded then Players.PlayerAdded=R.signal()end;if not Players.PlayerRemoving then Players.PlayerRemoving=R.signal()end
  function Players.GetPlayers()local out={};for _,c in ipairs(Players:GetChildren())do if c:IsA('Player')then out[#out+1]=c end end;return out end
  p.CharacterAdded=R.signal();p.CharacterRemoving=R.signal()
  local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=p
  local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=p
  local char=R.new('Model');char.Name=p.Name;char.Parent=W.workspace;p.Character=char
  local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=R.CFrame.new(0,3,100);root.Parent=char
  local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
  hum.EquipTool=function(_,tool)for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=bag end end;tool.Parent=char end
  hum.UnequipTools=function()for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=bag end end end
  E.Player,E.pg,E.bag,E.char,E.root,E.hum=p,pg,bag,char,root,hum
  return p
 end
 function E.frames(n,dt)W.frames(n,dt)end
 function E.advance(s)R.advance(s)end
 return E
end
