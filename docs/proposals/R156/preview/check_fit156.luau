--!nocheck
-- R156 preview check (not game code): the card's fit, on the AFTER tree (reveal_fixes.patch applied) under the Roblox mock, on 19 screen sizes (PC, laptops, a narrow window,
-- phones landscape / portrait, tablets) for every rank 1-5 (the Common..Mythic card) and for 6-8 (the compact card of an opening in place): the band RarePullCard.FitBand gives
-- (below BASE / TRACK, above the pity bars and the hotbar's item name; the compact card also in the upper part of the screen) holds all five rows
-- (the rarity word, the seed at rest, "1 in N", the name, the hint) in order and not overlapping, the title is not above the band, the hint not below it, the seed is a square no wider than
-- 62 % of the screen's width. Prints one line per screen and "problem cases 0" when all hold. Run from the AFTER tree's mock directory (run_reveal_fixes_preview.sh does).
local W=require('./world');local R=W.R
local Rules=W.module('RarePullRules');local Card=W.module('RarePullCard')
local V2=R.Vector2.new
local sizes={{1920,1080,false},{1366,768,false},{1280,720,false},{2560,1440,false},{1891,733,false},{1280,400,false},{800,600,false},{530,593,false},{420,420,false},
 {844,390,true},{932,430,true},{667,375,true},{568,320,true},{390,844,true},{375,667,true},{360,640,true},{414,896,true},{768,1024,true},{1024,768,true}}
local bad=0
for _,v in ipairs(sizes)do
 local w,h,touch=v[1],v[2],v[3]
 W.UIS.TouchEnabled=touch;W.UIS.KeyboardEnabled=not touch
 W.workspace.CurrentCamera.ViewportSize=V2(w,h)
 W.Gui.GetInsetArea=function()return{Min=V2(0,0),Width=w,Height=h}end
 local gui=R.Instance.new('ScreenGui');gui.AbsoluteSize=V2(w,h)
 local phone=touch or math.min(w,h)<500
 local cells={}
 for rank=1,8 do
  local compact=rank>=6
  local top,bottom=Card.FitBand(gui,V2(w,h),rank,phone,compact)
  local L=Rules.FitLayout(phone,rank,top,bottom,w,h,compact)
  -- (a row's top and bottom in px; the seed rests Float below its Y)
  local function span(k)local off=k=='Seed'and Rules.Fit.Float or 0;return(L[k].Y+off)*h-L[k].H*h/2,(L[k].Y+off)*h+L[k].H*h/2 end
  local problems={}
  if span('Title')<top-.5 then problems[#problems+1]='title above the band'end
  local _,last=span('Hint');if last>bottom+.5 then problems[#problems+1]=string.format('hint below the band (%.0f > %.0f)',last,bottom)end
  if L.Seed.W*w>Rules.Fit.SeedWidth*w+.5 or math.abs(L.Seed.W*w-L.Seed.H*h)>.5 then problems[#problems+1]='seed not a square within 62% of the width'end
  local prev=-1e9
  for _,k in ipairs({'Title','Seed','Odds','Name','Hint'})do local a,b=span(k);if a<prev-.5 then problems[#problems+1]=k..' overlaps the row above'end;prev=b end
  cells[#cells+1]=string.format('%s%d %d..%d k=%.2f seed %dpx%s',compact and'c'or'r',rank,top,bottom,L.Fit.K,L.Seed.H*h,#problems>0 and(' !! '..table.concat(problems,'; '))or'')
  if #problems>0 then bad+=1 end
 end
 print(string.format('%4dx%-4d touch=%-5s %s',w,h,tostring(touch),table.concat(cells,' | ')))
end
print('problem cases',bad)
if bad>0 then error('the fit failed on '..bad..' cases')end
