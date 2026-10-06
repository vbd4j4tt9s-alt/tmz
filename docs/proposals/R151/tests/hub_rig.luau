--!nocheck
-- R151: the avatar stand-ins of the Roblox mock, shared by hub_harness.luau (the suites) and hub_scene.luau (the whole-map scene): an R15-shaped rig (the 15 body parts + a
-- HumanoidRootPart with Motor6D joints named as Roblox names them, a Humanoid, accessories, an Animate script) and the two Players methods HubDisplayAvatar calls.
-- Usage: local Rig = require('./hub_rig')(W, R); Rig.rig(accessories, heightScale); Rig.install(PlayersService, state)   (state: {Describe, Create, Mode, Accessories, Scale, Last})
-- R153: the joints are Roblox's kind: C0 / C1 put each Part1 where it stands (Part1 = Part0 * C0 * C1:Inverse(), about the joint's pivot), and Model:ScaleTo scales the joints' offsets
-- with the parts (as Roblox's does), so a rig's rest pose can be worked out through its joints.
return function(W,R)
 local V3,CF=R.Vector3.new,R.CFrame.new
 local M={}
 local function copy(v)
  if type(v)~='table'then return v end
  local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
 end
 local PARTS={
  {'HumanoidRootPart',V3(2,2,1),V3(0,3,0)},{'LowerTorso',V3(2,.4,1),V3(0,2.2,0)},{'UpperTorso',V3(2,1.6,1),V3(0,3.2,0)},{'Head',V3(1.2,1.2,1.2),V3(0,4.6,0)},
  {'LeftUpperArm',V3(1,1.2,1),V3(-1.5,3.6,0)},{'LeftLowerArm',V3(1,1.1,1),V3(-1.5,2.55,0)},{'LeftHand',V3(1,.3,1),V3(-1.5,1.9,0)},
  {'RightUpperArm',V3(1,1.2,1),V3(1.5,3.6,0)},{'RightLowerArm',V3(1,1.1,1),V3(1.5,2.55,0)},{'RightHand',V3(1,.3,1),V3(1.5,1.9,0)},
  {'LeftUpperLeg',V3(1,1.2,1),V3(-.5,1.5,0)},{'LeftLowerLeg',V3(1,1.2,1),V3(-.5,.6,0)},{'LeftFoot',V3(1,.3,1),V3(-.5,.15,0)},
  {'RightUpperLeg',V3(1,1.2,1),V3(.5,1.5,0)},{'RightLowerLeg',V3(1,1.2,1),V3(.5,.6,0)},{'RightFoot',V3(1,.3,1),V3(.5,.15,0)},
 }
 local JOINTS={ -- joint, in part, Part0, Part1
  {'Root','LowerTorso','HumanoidRootPart','LowerTorso'},{'Waist','UpperTorso','LowerTorso','UpperTorso'},{'Neck','Head','UpperTorso','Head'},
  {'LeftShoulder','LeftUpperArm','UpperTorso','LeftUpperArm'},{'LeftElbow','LeftLowerArm','LeftUpperArm','LeftLowerArm'},{'LeftWrist','LeftHand','LeftLowerArm','LeftHand'},
  {'RightShoulder','RightUpperArm','UpperTorso','RightUpperArm'},{'RightElbow','RightLowerArm','RightUpperArm','RightLowerArm'},{'RightWrist','RightHand','RightLowerArm','RightHand'},
  {'LeftHip','LeftUpperLeg','LowerTorso','LeftUpperLeg'},{'LeftKnee','LeftLowerLeg','LeftUpperLeg','LeftLowerLeg'},{'LeftAnkle','LeftFoot','LeftLowerLeg','LeftFoot'},
  {'RightHip','RightUpperLeg','LowerTorso','RightUpperLeg'},{'RightKnee','RightLowerLeg','RightUpperLeg','RightLowerLeg'},{'RightAnkle','RightFoot','RightLowerLeg','RightFoot'},
 }
 function M.rig(accessories,heightScale)
  local k=heightScale or 1
  local m=R.new('Model');m.Name='Rig'
  local byName={}
  for _,row in ipairs(PARTS)do
   local p=R.new('Part');p.Name=row[1];p.Size=row[2]*k;p.CFrame=CF(row[3].X*k,row[3].Y*k,row[3].Z*k);p.Anchored=false;p.CanCollide=true;p.CanTouch=true;p.CanQuery=true
   p.Color=R.Color3.fromRGB(226,176,120);p.Transparency=row[1]=='HumanoidRootPart'and 1 or 0;p.Parent=m;byName[row[1]]=p -- (the root is invisible, as in a real rig)
  end
  -- the face and the shirt, as the first and the last thing a description gives (the preview draws them)
  local torso=byName.UpperTorso;torso.Color=R.Color3.fromRGB(70,120,200);byName.Head.Color=R.Color3.fromRGB(245,205,50)
  byName.LeftUpperLeg.Color=R.Color3.fromRGB(60,60,100);byName.RightUpperLeg.Color=R.Color3.fromRGB(60,60,100)
  byName.LeftLowerLeg.Color=R.Color3.fromRGB(60,60,100);byName.RightLowerLeg.Color=R.Color3.fromRGB(60,60,100)
  for _,j in ipairs(JOINTS)do
   local p0,p1=byName[j[3]],byName[j[4]]
   -- the joint's pivot: the top of a hanging limb part, the bottom of the head / the upper torso, the lower torso's middle (the root)
   local side=(j[4]=='Head'or j[4]=='UpperTorso')and -1 or j[4]=='LowerTorso'and 0 or 1
   local pivot=p1.CFrame*CF(0,side*p1.Size.Y/2,0)
   local mo=R.new('Motor6D');mo.Name=j[1];mo.Part0=p0;mo.Part1=p1
   mo.C0=p0.CFrame:Inverse()*pivot;mo.C1=p1.CFrame:Inverse()*pivot;mo.Transform=CF(0,0,0);mo.Enabled=true;mo.Parent=byName[j[2]]
  end
  local hum=R.new('Humanoid');hum.Health=100;hum.MaxHealth=100;hum.HipHeight=2;hum.EvaluateStateMachine=true;hum.AutoRotate=true;hum.RigType=R.Enum.HumanoidRigType.R15;hum.Parent=m
  m.PrimaryPart=byName.HumanoidRootPart
  for i=1,accessories or 0 do
   local a=R.new('Accessory');a.Name='Hat'..i
   local h=R.new('Part');h.Name='Handle';h.Size=V3(1,1,1);h.CFrame=CF(0,5.4+i*.1,0);h.CanCollide=true;h.Parent=a
   a.Parent=m
  end
  local script=R.new('Script');script.Name='Animate';script.Parent=m -- (some rigs carry one: the display's avatar must not)
  return m
 end
 -- Animator:LoadAnimation / GetPlayingAnimationTracks for the dance (the mock's Instance has no Animator). state.Dance = {Mode, Loads, Last, Tracks, Delay, FailFirst}: Mode 'ok' (a track
 -- whose Length is there at once and that plays), 'late' (its Length comes Delay seconds after the load: a fetch that takes a while), 'never loads' (Length stays 0, as an animation
 -- that cannot be fetched), 'not playing' (loads but Play does nothing), 'throws' (LoadAnimation errors); FailFirst = n: the first n loads never load (then Mode). A rig's own
 -- MockDance attribute overrides Mode for the tracks loaded on it (one display's dance can fail while the other's loads). Tracks = every track ever loaded (for the leak checks).
 local host -- (the state table install() was given: its .Dance is looked up at every call, so a test may replace it)
 if not R.Inst.LoadAnimation then
  function R.Inst.LoadAnimation(self,anim)
   local st=host and host.Dance or{Mode='ok',Loads=0}
   st.Loads+=1;st.Tracks=st.Tracks or{}
   local rig=self:FindFirstAncestorOfClass('Model')
   local mode=rig and rig:GetAttribute('MockDance')or st.Mode
   if mode=='throws'then error('Animator: could not load the animation',2)end
   local dud=(st.FailFirst or 0)>=st.Loads
   local readyAt=(dud or mode=='never loads')and math.huge or mode=='late'and R.clock+(st.Delay or 3)or-math.huge
   local track={Animation=anim,Animator=self,Looped=false,IsPlaying=false,Speed=1,Plays=0,Stops=0,Destroyed=false,Priority=nil,Fade=nil}
   setmetatable(track,{__index=function(_,k)if k=='Length'then return R.clock>=readyAt and 2.4 or 0 end end})
   function track:Play(fade)if mode=='not playing'or self.Destroyed then return end;self.IsPlaying=true;self.Plays+=1;self.Fade=fade end
   function track:Stop()if self.IsPlaying then self.Stops+=1 end;self.IsPlaying=false end
   function track:AdjustSpeed(s)self.Speed=s end
   function track:Destroy()self.IsPlaying=false;self.Destroyed=true end
   local list=self._tracks or{};list[#list+1]=track;self._tracks=list
   st.Last=track;st.Tracks[#st.Tracks+1]=track
   return track
  end
  function R.Inst.GetPlayingAnimationTracks(self)
   local out={};for _,t in ipairs(self._tracks or{})do if t.IsPlaying then out[#out+1]=t end end;return out
  end
 end
 -- Model:ScaleTo scales the joints' offsets with the parts (Roblox's does; the shared mock's moves parts only)
 if not R._hubJointScale then
  local raw=R.Inst.ScaleTo
  R._hubJointScale=true
  function R.Inst.ScaleTo(self,k)
   local f=k/(self._scale or 1)
   raw(self,k)
   for _,d in ipairs(self:GetDescendants())do if d._class=='Motor6D'then
    for _,key in ipairs({'C0','C1'})do local c=d._props[key];if c then d._props[key]=CF(c.Position.X*f,c.Position.Y*f,c.Position.Z*f)*c.Rotation end end
   end end
  end
 end
 -- Players:GetHumanoidDescriptionFromUserId / CreateHumanoidModelFromDescription. state: {Describe=0, Create=0, Mode='ok' | 'describe fails' | 'create fails' | 'throws', Accessories=3, Scale=1}
 function M.install(Players,state)
  state.Dance=state.Dance or{Mode='ok',Loads=0}
  host=state
  function Players.GetHumanoidDescriptionFromUserId(_,userId)
   state.Describe+=1
   if state.Mode=='describe fails'or state.Mode=='throws'then error('HTTP 404 (user '..tostring(userId)..')',2)end
   local d=R.new('HumanoidDescription');d._userId=userId
   local list={}
   for i=1,state.Accessories do list[i]={AssetId=1000+i,AccessoryType='Hat',IsLayered=false,Order=i}end
   d._list=list
   d.GetAccessories=function(self,_)return copy(self._list)end
   d.SetAccessories=function(self,l,_)self._list=copy(l)end
   return d
  end
  function Players.CreateHumanoidModelFromDescription(_,desc,rigType)
   state.Create+=1
   if state.Mode=='create fails'or state.Mode=='throws'then error('could not create the rig',2)end
   local rig=M.rig(#desc:GetAccessories(true),state.Scale)
   rig:SetAttribute('FromUser',desc._userId);rig:SetAttribute('RigType',tostring(rigType))
   state.Last=rig
   return rig
  end
  return Players
 end
 return M
end
