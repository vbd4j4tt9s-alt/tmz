local R=require('./roblox');local B=require('./b')
local game=R.new('DataModel');local svc={}
function game.GetService(_,n)if not svc[n]then svc[n]=R.new(n);svc[n].Name=n end;return svc[n]end
local RS=game:GetService('ReplicatedStorage');function RS.WaitForChild(_,n)return n end
local stubs={GardenTextFit={},GardenCardMotion={Apply=function()end},CosmicLettering={}}
game:GetService('RunService').Heartbeat=R.signal()
local env=setmetatable({game=game,Instance=R.Instance,UDim2=R.UDim2,UDim=R.UDim,Vector2=R.Vector2,Color3=R.Color3,ColorSequence=R.ColorSequence,ColorSequenceKeypoint=R.ColorSequenceKeypoint,Enum=R.Enum,
 require=function(n)return stubs[n]end},{__index=_G})
local src=B.GardenTheme:gsub("game:GetService%('ReplicatedStorage'%):WaitForChild%('(%w+)'%)","'%1'");local fn=assert(loadstring(src));setfenv(fn,env);local T=fn()
for _,rar in ipairs({'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'})do
 local root=T.Icon(R.new('Frame'),rar)
 for _,f in ipairs(root:GetChildren())do if f.ClassName=='Frame'then
  local g=f:FindFirstChildOfClass('UIGradient');local st=f:FindFirstChildOfClass('UIStroke');local cr=f:FindFirstChildOfClass('UICorner')
  local function c3(c)return string.format('%d,%d,%d',c.R*255,c.G*255,c.B*255)end
  local gc=''
  if g and g.Color.B then gc=c3(g.Color.A)..'|'..c3(g.Color.B)end
  print(table.concat({rar,f.Name,f.Position.X.Scale,f.Position.Y.Scale,f.Size.X.Scale,f.Size.Y.Scale,f.Rotation,c3(f.BackgroundColor3),f.BackgroundTransparency or 0,cr and 1 or 0,st and c3(st.Color)or'',gc},';'))
 end end
end
