--!nocheck
-- R155 performance with 200 items (owner: "it should feel responsive"; the cap is 200). The REAL Hotbar (the R155 one, or the R154 one: LABEL) on the engine model
-- (engine153.luau), 200 items in 190 different stacks (fruit of different sizes never stack: the worst case). Real CPU time of this machine's Luau (the mock's
-- Instances are Lua tables, so every number is many times what Roblox spends; only the comparison and the shape matter):
--  load     200 items arrive (the server hands them over) and the hotbar settles
--  refresh  one item changes (a weather), the whole inventory is looked at again
--  click    a click on a slot until the slot shows as held (the press, the equip, the redraw)
--  new      one new item arrives (a harvest)
--  open     the Bag opens (190 cards: only the rows on screen are built)
--  scroll   one scroll step of the Bag grid (cards recycled)
--  drag     a whole drag from one slot to another (12 frames)
--  idle     one frame with nothing happening; Instances made over 120 idle frames (must be 0: no per-frame allocation)
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
E.recorder();E.player('Tester')
local player,pg=E.Player,E.pg
local X=require('./engine153')(W,E,F,{Variant='began',Order='activated first',Handoff='empty'})
local bag=function()return player:FindFirstChildOfClass('Backpack')end
local clock=os.clock -- (the real clock: this file runs outside the mock's environment)
local label=LABEL or'R155'
F.shovel(W,bag())
local sc=R.new('LocalScript');sc.Name='Hotbar';assert(pcall(W.load,'Hotbar',sc))
X.frames(10)
local gui=pg.ChestToolHotbar;local dock=gui.Dock;local panel=gui.Inventory;local open=dock.OpenInventory
local seeds={'AppleSeed','BluebellSeed','CloverSeed','MangoSeed','PlumSeed','OrangeSeed','PeachSeed','LimeSeed','FigSeed','KiwiSeed'}
local made={}
local t0=clock()
for i=1,199 do
 local t
 if i%20==0 then t=F.pack(W,nil,(i%7)+1,'Pack0'..((i%6)+1),1,'None')
 elseif i%10==0 then t=F.seed(W,nil,seeds[(i%10)+1],1,'None')
 else t=F.fruit(W,nil,seeds[(i%10)+1],1+i/1000,'None',700+i,1);t:SetAttribute('SourceCropId','plant-'..i)end
 t.Parent=bag();made[#made+1]=t
end
X.frames(3)
local load=clock()-t0
local function slot(i)return dock['Slot'..i]end
-- refresh: one item's weather changes
local function avg(n,fn)local total=0;for k=1,n do local a=clock();local own=fn(k);total+=own or(clock()-a)end;return total/n end -- (fn may return its own measured part)
local refresh=avg(10,function(k)made[k*3]:SetAttribute('Weather',k%2==0 and'Rain'or'None')end)
-- click to highlight
local function settle()E.hum:UnequipTools();X.frames(2)end
local shownAt={}
local click=avg(10,function(k)
 local s=slot(2+(k%8));settle()
 local p=X.center(s);local a=clock();X.down('mouse',p);X.up(p);local own=clock()-a;shownAt[k]=s:GetAttribute('Selected')==true;return own
end)
local instant=true;for _,v in pairs(shownAt)do if not v then instant=false end end
-- a number key (the Hotbar's own work only: no hit test) until the slot shows as held, then the deferred refresh of the frame after
local NUM={'Two','Three','Four','Five','Six','Seven','Eight','Nine'};local keyFrames=0
local keyT=avg(16,function(k)
 settle();local a=clock();W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[NUM[(k%8)+1]],UserInputType=R.Enum.UserInputType.Keyboard,Position=R.Vector3.new(0,0,0)},false)
 local own=clock()-a;local b=clock();W.frames(1);keyFrames+=clock()-b;return own
end)
-- a new item
local new=avg(10,function(k)local t=F.fruit(W,nil,'MangoSeed',2+k/100,'None',900+k,1);t.Parent=bag();X.frames(1)end)
-- the Bag
settle()
local a=clock();X.tap('mouse',open);local openT=clock()-a
local cards=0;for _,c in ipairs(panel.Items:GetChildren())do if c.Visible and c.Name=='Item'then cards+=1 end end
local scroll=panel.Items
local steps=0;local scrollT=avg(20,function(k)scroll.CanvasPosition=R.Vector2.new(0,k*60);steps+=1 end)
X.tap('mouse',panel.Close);X.frames(2)
-- a drag
local dragT=avg(5,function(k)X.drag('mouse',slot(3),slot(4))end)
-- idle frames
settle();X.frames(30)
local before=#R.created;local b=clock();W.frames(120);local idle=(clock()-b)/120;local made120=#R.created-before -- (W.frames: the game's frame only, not the test engine's layout pass)
print(('PERF %s: load %.1f ms | refresh %.2f ms | click %.2f ms (a number key %.2f ms + the next frame %.2f ms) | new item %.2f ms | Bag open %.1f ms (%d cards built) | scroll step %.2f ms | drag %.1f ms | idle frame %.3f ms, %d Instances in 120 idle frames'):format(
 label,load*1000,refresh*1000,click*1000,keyT*1000,keyFrames/16*1000,new*1000,openT*1000,cards,scrollT*1000,dragT*1000,idle*1000,made120))
if label=='R155'then
 check(instant,'every click shows the slot as held on the frame it ends')
 check(made120==0,'no Instance is made while nothing happens ('..made120..' in 120 frames)')
 check(cards<=60,'opening the Bag builds only the cards on screen and two rows around them ('..cards..')')
 check(click<0.25 and refresh<0.25 and scrollT<0.05,'each step stays far under a frame on this machine')
 check(keyT<0.002,('a press shows the held item at once: the Hotbar\'s own work before the highlight is %.2f ms (R154: a full refresh, ~5 ms here)'):format(keyT*1000))
end
print(('R155 perf checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
