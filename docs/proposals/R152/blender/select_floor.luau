--!nocheck
-- R152: picks the new keepers' floor samples from the hull candidates (floor_candidates.py) with the game's REAL pose code.
-- Grounding lifts a keeper so that the lowest floor sample touches y = -4. A uniform lift never changes which point of a group
-- is lowest, so the samples that matter are the points that are the lowest of their group in some pose: this runs BeastPose /
-- KeeperUpgradePose (+ CrystalKnightPose), KeeperStrikeFrames (the server's hit frames) and KeeperSignatureStrike (the client's)
-- over a grid of states, keeps every per-group lowest point plus each group's extreme points, then checks the pick on random
-- poses: error = how much lower the full hull reaches than the picked samples (0 = the same grounding).
-- Usage (a folder holding roblox.luau, world.luau, rs_bundle.luau and candidates.luau): luau select_floor.luau > floor.json
local W=require('./world');local C=require('./candidates')
local Pose=W.module('BeastPose');local Sig=W.module('KeeperSignatureStrike');local Strike=W.module('KeeperStrikeFrames');local Combat=W.module('KeeperCombat')
local seed=152
local function rnd()seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
local function posesFor(stage,train)
 local list={}
 if train then
  for _,t in ipairs({0,1.3})do for _,awake in ipairs({0,.5,1})do for _,moving in ipairs({0,1})do for k=0,15 do for _,urg in ipairs({0,1})do for _,turn in ipairs({-1,0,1})do
   list[#list+1]=Pose.Frames(stage,t,awake,moving,k/16*math.pi*2,urg,40,turn)
  end end end end end end
  local w=Combat.Get(stage).Windup;local e=0
  while e<=w+Combat.Recovery do list[#list+1]=Sig.Frames(stage,10+e,10);list[#list+1]=Strike.Frames(stage,10+e,10);e+=.025 end
 else
  for _=1,600 do list[#list+1]=Pose.Frames(stage,rnd()*10,rnd(),rnd(),rnd()*math.pi*6,rnd(),5+rnd()*75,rnd()*2-1)end
  local w=Combat.Get(stage).Windup
  for _=1,120 do local e=rnd()*(w+Combat.Recovery);list[#list+1]=Sig.Frames(stage,10+e,10);list[#list+1]=Strike.Frames(stage,10+e,10)end
 end
 return list
end
local function ys(frame,pts)
 local _,y,_,_,_,_,r10,r11,r12=frame:GetComponents()
 local out={};for i,p in ipairs(pts)do out[i]=y+r10*p[1]+r11*p[2]+r12*p[3]end;return out
end
local result={}
for stage=1,7 do
 local cand=C[stage];local picked={}
 for g,pts in pairs(cand)do
  local set={}
  -- each group's extreme points (lowest, and the four sides) in the rest pose
  local ext={1,1,1,1,1}
  for i,p in ipairs(pts)do
   if p[2]<pts[ext[1]][2]then ext[1]=i end;if p[1]<pts[ext[2]][1]then ext[2]=i end;if p[1]>pts[ext[3]][1]then ext[3]=i end
   if p[3]<pts[ext[4]][3]then ext[4]=i end;if p[3]>pts[ext[5]][3]then ext[5]=i end
  end
  for _,i in ipairs(ext)do set[i]=true end
  picked[g]=set
 end
 for _,frames in ipairs(posesFor(stage,true))do
  for g,pts in pairs(cand)do
   local f=frames[g];if f then
    local y=ys(f,pts);local best=1;for i=2,#y do if y[i]<y[best]then best=i end end;picked[g][best]=true
   end
  end
 end
 -- check on poses the pick never saw
 local worst,count=0,0
 for _,frames in ipairs(posesFor(stage,false))do
  local all,sel=math.huge,math.huge
  for g,pts in pairs(cand)do
   local f=frames[g];if f then
    local y=ys(f,pts)
    for i,v in ipairs(y)do all=math.min(all,v);if picked[g][i]then sel=math.min(sel,v)end end
   end
  end
  worst=math.max(worst,sel-all);count+=1
 end
 local groups={};local total,cands=0,0
 for g,pts in pairs(cand)do
  local idx={};for i in pairs(picked[g])do idx[#idx+1]=i end;table.sort(idx)
  local row={};for _,i in ipairs(idx)do row[#row+1]=string.format('[%.4f,%.4f,%.4f]',pts[i][1],pts[i][2],pts[i][3])end
  groups[#groups+1]=string.format('"%s":[%s]',g,table.concat(row,','));total+=#idx;cands+=#pts
 end
 table.sort(groups)
 result[#result+1]=string.format('"%d":{"Samples":{%s},"Picked":%d,"Candidates":%d,"WorstError":%.5f,"Checked":%d}',stage,table.concat(groups,','),total,cands,worst,count)
end
print('{'..table.concat(result,',')..'}')
