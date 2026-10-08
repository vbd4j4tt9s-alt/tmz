-- R78: one shared, client-only quality governor. Never changes gameplay or saved settings.
local B={}
function B.New(mobile)return {Tier=mobile and 2 or 3,Ceiling=mobile and 2 or 3,Average=1/60,Slow=0,Fast=0}end
function B.Step(s,dt)
 if type(dt)~='number'or dt~=dt or dt<=0 or dt>.25 then return s.Tier end
 s.Average+=(dt-s.Average)*(1-math.exp(-dt*2))
 if s.Average>1/42 then s.Slow+=dt;s.Fast=0
 elseif s.Average<1/55 then s.Fast+=dt;s.Slow=0
 else s.Fast=0;s.Slow=0 end
 if s.Slow>=2.5 and s.Tier>1 then s.Tier-=1;s.Slow=0;s.Fast=0
 elseif s.Fast>=12 and s.Tier<s.Ceiling then s.Tier+=1;s.Fast=0;s.Slow=0 end
 return s.Tier
end
-- R153 perf: ONE quality signal. The frame rate is measured here only: the tier above (42 / 55 fps, smoothed) and, for SettingsClient's Auto quality,
-- frames counted over 3 s windows (B.OnWindow(fn): fn(fps) when a window ends; SettingsClient keeps its own 38 / 53 fps rule). SettingsClient used to
-- count those windows on a Heartbeat of its own.
B.Window=3
local win,winFrames,listeners=0,0,{}
local function countWindow(dt)
 if #listeners==0 then return end
 win+=math.min(dt,.25);winFrames+=1
 if win<B.Window then return end
 local fps=winFrames/win;win=0;winFrames=0
 for _,fn in ipairs(table.clone(listeners))do local ok,err=pcall(fn,fps);if not ok then warn('[ClientFxBudget] '..tostring(err))end end
end
B.CountWindow=countWindow -- (tests)
local state,player,connection
function B.OnWindow(fn)
 B.Get();table.insert(listeners,fn)
 return {Disconnect=function()local i=table.find(listeners,fn);if i then table.remove(listeners,i)end end}
end
-- R153 perf (lag audit D7): Roblox draws at most 31 Highlights at once and silently skips the rest. Client code that keeps a Highlight hands it to
-- B.TrackHighlight (the owner's mutation outlines, plant rarity auras, the Void packs' outline); B.HighlightRoom() is what is left for the track packs
-- (SeedPackRender) after those, the server's weather glows (tag MutationGlow) and HighlightReserve for a brief one (a hover, a gift target).
B.MaxHighlights,B.HighlightReserve=31,1
local tracked=setmetatable({},{__mode='k'})
function B.TrackHighlight(h)if typeof(h)=='Instance'then tracked[h]=true end end
function B.HighlightRoom()
 local used=B.HighlightReserve
 for h in pairs(tracked)do if h.Parent and h.Enabled then used+=1 end end
 local ok,list=pcall(function()return game:GetService('CollectionService'):GetTagged('MutationGlow')end)
 if ok and list then for _,h in ipairs(list)do if h.Parent and h.Enabled~=false then used+=1 end end end
 return math.max(0,B.MaxHighlights-used)
end
function B.Get()
 if not state then
  local Players=game:GetService('Players');local input=game:GetService('UserInputService')
  player=Players.LocalPlayer;state=B.New(input.TouchEnabled and not input.KeyboardEnabled)
  local run=game:GetService('RunService')
  if run:IsClient()then
   connection=run.RenderStepped:Connect(function(dt)B.Step(state,dt);countWindow(dt)end)
   script.Destroying:Connect(function()if connection then connection:Disconnect();connection=nil end end)
  end
 end
 if player and player:GetAttribute('FastMode')==true then return 1 end
 return state.Tier
end
function B.Low()return B.Get()==1 end
return B
