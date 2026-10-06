--!nocheck
-- R152 doc helper: prints, for every tier, the beats of its presentation (seconds) and the sounds cued on them (RarePullRules cue sheets)
-- - the "Timelines" table of docs/proposals/R152/seed_opening.md. Run from a folder with the mock + bundle (run_seed_opening.sh's cl/).
local W=require('./world')
local L=W.module('RarePullRules')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local function sheet(tag,tl,cues)
 local beats={}
 for k,v in pairs(tl)do if type(v)=='number'and k~='SkipFrom'then beats[#beats+1]={k,v}end end
 table.sort(beats,function(a,b)return a[2]<b[2]or(a[2]==b[2]and a[1]<b[1])end)
 local at={}
 for _,c in ipairs(cues)do
  local key=string.format('%.2f',c.At);at[key]=at[key]or{}
  local s=c.Flight and('Flight('..c.Flight..', swell '..string.format('%.2f',c.PeakAt)..')')or c.Slot
  table.insert(at[key],s)
 end
 local times={};for k in pairs(at)do times[#times+1]=k end;table.sort(times,function(a,b)return tonumber(a)<tonumber(b)end)
 local b={};for _,x in ipairs(beats)do b[#b+1]=x[1]..' '..string.format('%.2f',x[2])end
 print('## '..tag);print('beats: '..table.concat(b,', '))
 for _,k in ipairs(times)do print('  '..k..'  '..table.concat(at[k],' + '))end
end
for rank=1,5 do sheet(names[rank]..' card',L.CardTimeline(rank,false),L.LadderCues(rank,false))end
for rank=6,8 do local tl=L.Timeline(rank,'Full');sheet(names[rank]..' story (Full)',tl,L.SceneCues(rank,tl))end
