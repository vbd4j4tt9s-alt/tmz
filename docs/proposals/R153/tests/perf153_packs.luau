--!nocheck
-- R153 performance patch, lag audit D7: the track packs' Highlight outlines, with the REAL SeedPackRender and ClientFxBudget on the R153 jitter world
-- (R149 zfight world + the frame driver). 30 packs ahead of the camera, 20 to 600 studs, all on screen; tiers 3 / 2 / 1, without and with the 16
-- weather glows the server can put on packs (Highlights tagged MutationGlow). Prints per case:
--   FACT near ...   the packs within 150 studs that wear an outline, with its look (run_perf153.sh: identical on both sides)
--   PERF ...        how many outlines the packs wear, the weather glows, and every Highlight in the workspace (Roblox draws at most 31)
local J=require('./jitter_world');local W,R=J.W,J.R;local V3,CF=R.Vector3.new,R.CFrame.new
local CS=W.CS
-- the real shared budget behind the world's ClientFxBudget stand-in (the tier stays the world's J.tier)
do local stub=W.module('ClientFxBudget');local ok,real=pcall(W.load,'ClientFxBudget',W.RS:FindFirstChild('ClientFxBudget'))
 if ok and type(real)=='table'and real.HighlightRoom then stub.HighlightRoom=real.HighlightRoom;stub.TrackHighlight=real.TrackHighlight end
end
local me=J.player('Me',7,true);J.character(me,V3(0,3,-20))
local CAM,AT=V3(0,12,-10),V3(0,5,300)
J.look(CAM,AT)
local function pack(name,at,rank)
 local m=R.new('Model');m.Name=name
 local specs={{'Body',V3(1.9,2.3,.5),CF(0,0,0)},{'Band',V3(1.95,.3,.55),CF(0,.9,0)},{'Label',V3(1.2,.8,.05),CF(0,0,-.27)}}
 for i,s in ipairs(specs)do
  local p=R.new('Part');p.Name=s[1];p.Size=s[2];p.CFrame=at*s[3];p.Anchored=true;p:SetAttribute('PackLocalFrame',s[3]);p.Parent=m
  if i==1 then m.PrimaryPart=p end
 end
 for k,v in pairs({CompactPackReady=true,CompactPackPartCount=#specs,WorldPack=true,HoverOrigin=at,PackRank=rank,Stage=1,VisualScale=1,PackMutation='None',HoverPhase=.3,PackArtKey='Forest_01'})do m:SetAttribute(k,v)end
 m.Parent=W.workspace;CS:AddTag(m,'BiomeSeedPackVisual');return m
end
local packs={}
for i=1,30 do local z=20*i;local x=((i*37)%21)-10;packs[i]=pack(string.format('Pack%02d',i),CF(x,5,z),1+(i%6))end
local sc=R.new('LocalScript');sc.Name='SeedPackRender';W.load('SeedPackRender',sc)
local function dist(m)return(m.PrimaryPart.Position-CAM).Magnitude end
local function outlines()
 local by={};local all=0
 for _,d in ipairs(W.workspace:GetDescendants())do if d:IsA('Highlight')then
  all+=1
  if d.Name=='PackBrightness'and d.Adornee then by[d.Adornee]=d end
 end end
 return by,all
end
local glows={}
local function weather(on)
 for _,h in ipairs(glows)do h:Destroy()end;table.clear(glows)
 if not on then return end
 for i=15,30 do local h=R.new('Highlight');h.Name='MutationGlow';h.Adornee=packs[i];h.Parent=packs[i];CS:AddTag(h,'MutationGlow');glows[#glows+1]=h end
end
for _,tier in ipairs({3,2,1})do for _,wx in ipairs({false,true})do
 J.tier=tier;weather(wx);J.look(CAM,AT);J.run(1.2,60)
 local by,all=outlines()
 local near,packsLit={},0
 for _,m in ipairs(packs)do local h=by[m];if h then packsLit+=1 end
  if dist(m)<=150 then near[#near+1]=m.Name..(h and string.format('(outline %.3f fill %.3f %s)',h.OutlineTransparency or -1,h.FillTransparency or -1,tostring(h.Enabled))or'(none)')end
 end
 local label=string.format('tier=%d weather=%s',tier,tostring(wx))
 print('FACT near '..label..'\t'..table.concat(near,' '))
 print(string.format('PERF packs %s pack_outlines=%d weather_glows=%d highlights_in_workspace=%d',label,packsLit,#glows,all))
end end
sc:Destroy()
print('PERF153 PACKS DONE')
