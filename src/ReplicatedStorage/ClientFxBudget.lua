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
local state,player,connection
function B.Get()
 if not state then
  local Players=game:GetService('Players');local input=game:GetService('UserInputService')
  player=Players.LocalPlayer;state=B.New(input.TouchEnabled and not input.KeyboardEnabled)
  local run=game:GetService('RunService')
  if run:IsClient()then
   connection=run.RenderStepped:Connect(function(dt)B.Step(state,dt)end)
   script.Destroying:Connect(function()if connection then connection:Disconnect();connection=nil end end)
  end
 end
 if player and player:GetAttribute('FastMode')==true then return 1 end
 return state.Tier
end
function B.Low()return B.Get()==1 end
return B
