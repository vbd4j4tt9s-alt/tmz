--!nocheck
-- R151: the avatar stand-ins of the Roblox mock, shared by hub_harness.luau (the suites) and hub_scene.luau (the whole-map scene): an R15-shaped rig (the 15 body parts + a
-- HumanoidRootPart with Motor6D joints named as Roblox names them, a Humanoid, accessories, an Animate script) and the two Players methods HubDisplayAvatar calls.
-- Usage: local Rig = require('./hub_rig')(W, R); Rig.rig(accessories, heightScale); Rig.install(PlayersService, state)   (state: {Describe, Create, Mode, Accessories, Scale, Last})
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
   local mo=R.new('Motor6D');mo.Name=j[1];mo.Part0=byName[j[3]];mo.Part1=byName[j[4]]
   mo.C0=CF(0,0,0);mo.C1=CF(0,0,0);mo.Transform=CF(0,0,0);mo.Parent=byName[j[2]]
  end
  local hum=R.new('Humanoid');hum.Health=100;hum.RigType=R.Enum.HumanoidRigType.R15;hum.Parent=m
  m.PrimaryPart=byName.HumanoidRootPart
  for i=1,accessories or 0 do
   local a=R.new('Accessory');a.Name='Hat'..i
   local h=R.new('Part');h.Name='Handle';h.Size=V3(1,1,1);h.CFrame=CF(0,5.4+i*.1,0);h.CanCollide=true;h.Parent=a
   a.Parent=m
  end
  local script=R.new('Script');script.Name='Animate';script.Parent=m -- (some rigs carry one: the display's avatar must not)
  return m
 end
 -- R152: Animator:LoadAnimation / GetPlayingAnimationTracks for the dance (the mock's Instance has no Animator). state.Dance = {Mode, Loads, Last}: Mode 'ok' (a track with a length that
 -- plays), 'never loads' (Length stays 0, as an animation that cannot be fetched), 'not playing' (loads but Play does nothing), 'throws' (LoadAnimation errors).
 local host -- (the state table install() was given: its .Dance is looked up at every call, so a test may replace it)
 if not R.Inst.LoadAnimation then
  function R.Inst.LoadAnimation(self,anim)
   local st=host and host.Dance or{Mode='ok',Loads=0}
   st.Loads+=1
   if st.Mode=='throws'then error('Animator: could not load the animation',2)end
   local track={Animation=anim,Looped=false,IsPlaying=false,Length=st.Mode=='never loads'and 0 or 2.4,Speed=1,Plays=0,Stops=0,Priority=nil}
   function track:Play()if st.Mode=='not playing'then return end;self.IsPlaying=true;self.Plays+=1 end
   function track:Stop()self.IsPlaying=false;self.Stops+=1 end
   function track:AdjustSpeed(s)self.Speed=s end
   local list=self._tracks or{};list[#list+1]=track;self._tracks=list
   st.Last=track
   return track
  end
  function R.Inst.GetPlayingAnimationTracks(self)
   local out={};for _,t in ipairs(self._tracks or{})do if t.IsPlaying then out[#out+1]=t end end;return out
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
