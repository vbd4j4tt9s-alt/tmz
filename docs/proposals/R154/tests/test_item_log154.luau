--!nocheck
-- R154 (owner: Studio's Output was flooded with "[R112] Item picture fallback Pack|1|Pack06|None|6: Pack shape is still loading", one line per item while
-- pack shapes load): the real ItemPictures on the mock, in Studio. Builds that fail with "... is still loading" are counted and summarised in ONE line per
-- LoadingNoteSeconds ("[R112] 23 item pictures waiting for pack shapes"); a real failure still warns once, with its key and reason. Logging only: the retry
-- times, the pictures and the holders are what they were (checked: the same holders fill with the same pictures once the shapes "arrive").
-- R157 (owner: Studio's Output showed the summary as a yellow warning and he called it a bug): the summary is a normal loading note, a plain print() with the same text;
-- only a real failure still uses warn(). `lines` = what warn() got, `prints` = what print() got.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
F.packAssets(W)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=9;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
W.service('RunService').IsStudio=function()return true end -- (the warnings are Studio-only)
local lines,prints={},{}
W.env.warn=function(...)local t={};for i=1,select('#',...)do t[#t+1]=tostring((select(i,...)))end;lines[#lines+1]=table.concat(t,' ')end
W.env.print=function(...)local t={};for i=1,select('#',...)do t[#t+1]=tostring((select(i,...)))end;prints[#prints+1]=table.concat(t,' ')end
local P=W.module('ItemPictures')
local Visuals=W.module('SeedPackVisuals')
local realBag=Visuals.Bag
local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=pg
local tools=R.new('Folder');tools.Parent=W.workspace
local function holder(i)
 local h=R.new('Frame');h.Name='Holder'..i;h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui
 h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new((i-1)%20*62,math.floor((i-1)/20)*62)
 return h
end

-- 1. 42 packs whose shapes are still loading: the build errors "Pack shape is still loading" (retried every LoadingRetrySeconds)
local loading=true
Visuals.Bag=function(...)if loading then error('Pack shape is still loading',0)end;return realBag(...)end
local holders,looks={},{}
for stage=1,7 do for d=1,6 do looks[#looks+1]=F.pack(W,tools,stage,string.format('Pack%02d',d),1,'None')end end
for i,t in ipairs(looks)do local h=holder(i);holders[i]=h;P.Show(h,t,2)end
local frames=0
for _=1,30*12 do W.frames(1,1/30);frames+=1 end -- 12 s: six retries of every look
local notes,perItem={},0
for _,l in ipairs(lines)do if l:find('Item picture fallback',1,true)then perItem+=1 end end
for _,l in ipairs(prints)do if l:find('item picture',1,true)and l:find('waiting for pack shapes',1,true)then notes[#notes+1]=l end end
check(perItem==0,'no "Item picture fallback ...: still loading" line per item ('..perItem..')')
check(#notes>=1,'a summary line is printed ('..#notes..' lines in 12 s)')
check(#notes<=3,'at most one summary line per 5 s: '..#notes..' lines in 12 s')
local first=notes[1] and tonumber(notes[1]:match('^%[R112%] (%d+) item pictures? waiting for pack shapes$'))
check(first~=nil and first>=20,'the first line counts the pictures waiting, as "[R112] N item pictures waiting for pack shapes": '..tostring(notes[1]))
check(#prints==#notes,'nothing else is printed while shapes load ('..#prints..' prints, '..#notes..' summaries)')
check(#lines==0,'R157: the loading summary is a print, never a warn (nothing reached warn: '..#lines..' lines)')
for _,n in ipairs(notes)do print('LOG '..n)end

-- 2. the shapes arrive: the same pictures are built (logging only: the retry and the pictures are unchanged)
loading=false
local filled=0
for _=1,30*8 do W.frames(1,1/30)end
for _,h in ipairs(holders)do if h:FindFirstChild('ItemViewport')then filled+=1 end end
check(filled==#holders,'once the shapes are there every holder shows its picture ('..filled..' / '..#holders..')')
local before,beforePrints=#lines,#prints
for _=1,30*8 do W.frames(1,1/30)end
check(#lines==before and #prints==beforePrints,'and the log stays quiet afterwards')

-- 3. a real failure still warns once, with its key and its reason (not summarised, not repeated on every retry)
for _,h in ipairs(holders)do h:Destroy()end -- (the first 42 holders are gone: only the new one is built from here)
P.Reset()
lines={};prints={}
Visuals.Bag=function()error('no model',0)end
local h2=holder(99)
local look=F.pack(W,tools,2,'Pack03',1,'None');P.Show(h2,look,1)
for _=1,30*40 do W.frames(1,1/30)end -- 40 s: two retries after the 15 s wait
local real=0
for _,l in ipairs(lines)do if l:find('[R112] Item picture fallback',1,true)and l:find(': no model',1,true)then real+=1 end end
check(real==1,'a real failure warns exactly once, "[R112] Item picture fallback <key>: no model" ('..real..'; '..#lines..' lines in all)')
check(#lines==real and #prints==0,'no summary line for a real failure')

-- 4. one kind of wait, singular: "1 item picture waiting for ..." and kinds are separate
h2:Destroy()
P.Reset()
lines={};prints={}
local h3=holder(100)
Visuals.Bag=function()error('Fruit mesh is still loading: Apple',0)end
P.Show(h3,F.pack(W,tools,3,'Pack01',1,'None'),1)
for _=1,30*7 do W.frames(1,1/30)end
check(#prints>=1 and prints[1]=='[R112] 1 item picture waiting for fruit meshes' and #lines==0,'one picture, another kind (a print, no warn): '..tostring(prints[1]))

print(string.format('%d checks, %d failed',checks,fails))
if fails>0 then error('item log checks failed',0)end
print('ALL PASS')
