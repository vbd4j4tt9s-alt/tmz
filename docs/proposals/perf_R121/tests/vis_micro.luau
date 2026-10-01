--!nocheck
-- R121 micro-check: ShopViewport.CachedVisible gives the same answer as ShopViewport.Visible over random
-- show/hide/reparent sequences, and counts instance accesses for a view in a closed menu.
local R=require('./roblox');local new=R.new
local B=require('./vb_new')
local accesses=0
local mt=R.instMeta;local idx=mt.__index
mt.__index=function(o,k)accesses+=1;return idx(o,k)end
local game=new('DataModel');local services={}
function game.GetService(_,n)local s=services[n];if not s then s=new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
local RS=game:GetService('ReplicatedStorage');for _,n in ipairs({'ShopProductArt','HarvestGeometry'})do local m=new('ModuleScript');m.Name=n;m.Parent=RS end
local env=setmetatable({game=game,require=function(m)return {}end,Instance=R.Instance,task=R.task},{__index=_G})
local fn=assert(loadstring(B.ShopViewport,'=ShopViewport'));setfenv(fn,env);local V=fn()
-- PlayerGui > ScreenGui > panel > list(clips) > card > view
local pg=new('Folder')
local sg=new('ScreenGui');sg.Parent=pg
local panel=new('Frame');panel.Parent=sg
local list=new('ScrollingFrame');list.ClipsDescendants=true;list.AbsoluteSize=R.Vector2.new(400,400);list.Parent=panel
local other=new('Frame');other.Parent=sg
local views={}
for i=1,12 do local card=new('Frame');card.Parent=list;local v=new('Frame');v.AbsolutePosition=R.Vector2.new(10,(i-1)*30);v.AbsoluteSize=R.Vector2.new(20,20);v.Parent=card;views[i]={View=v,Card=card} end
local seed=12345;local function rand(n)seed=(seed*1103515245+12345)%2147483648;return seed%n+1 end
local mismatches=0
for step=1,20000 do
 local r=rand(9)
 if r==1 then panel.Visible=not panel.Visible
 elseif r==2 then sg.Enabled=not sg.Enabled
 elseif r==3 then local e=views[rand(12)];e.Card.Visible=not e.Card.Visible
 elseif r==4 then local e=views[rand(12)];e.View.Visible=not e.View.Visible
 elseif r==5 then local e=views[rand(12)];e.Card.Parent=(e.Card.Parent==list)and other or list
 elseif r==6 then list.Visible=not list.Visible
 elseif r==7 then local e=views[rand(12)];e.View.AbsolutePosition=R.Vector2.new(10,rand(30)*30)
 end
 for _,e in ipairs(views)do
  local a=V.Visible(e.View)and true or false;local b=V.CachedVisible(e)and true or false
  if a~=b then mismatches+=1 end
 end
end
print('random toggles: 20000 steps x 12 views, mismatches',mismatches)
-- Cost for the common case: menu closed (panel hidden), 12 views checked once per frame.
panel.Visible=false;sg.Enabled=true;list.Visible=true
for _,e in ipairs(views)do e.Card.Parent=list;e.Card.Visible=true;e.View.Visible=true;e.HiddenBy=nil end
accesses=0;for i=1,100 do for _,e in ipairs(views)do V.Visible(e.View)end end;local full=accesses/1200
for _,e in ipairs(views)do V.CachedVisible(e)end
accesses=0;for i=1,100 do for _,e in ipairs(views)do V.CachedVisible(e)end end;local cached=accesses/1200
print(string.format('closed menu: instance accesses per check  full walk %.1f  cached %.1f',full,cached))
