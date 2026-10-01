--!nocheck
-- R122 FruitGiftClient smoke test: holding a fruit, seed or pack and clicking / RT-ing a nearby player sends the
-- right remote action and inventory id; carrying, a far target or no held item sends nothing.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end -- mock gap
local Players=W.service('Players')
local present={}
function Players.GetPlayerFromCharacter(_,m)for _,p in pairs(present)do if p.Character==m then return p end end;return nil end
local function makePlayer(id,name,x)
 local p=R.new('Player');p.Name=name;p.UserId=id;p.Parent=Players;present[id]=p
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=R.Vector3.new(x,3,0);root.Parent=c
 p.Character=c;return p
end
local me=makePlayer(1,'Me',0);local near=makePlayer(2,'Near',8);local far=makePlayer(3,'Far',40)
Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local bp=R.new('Backpack');bp.Parent=me
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local remote=R.new('RemoteEvent');remote.Name='FruitGift';remote.Parent=remotes;remote.OnClientEvent=R.signal()
local sent={};function remote.FireServer(_,...)sent[#sent+1]=table.pack(...)end
local UIS=W.UIS;UIS.TouchTapInWorld=R.signal();function UIS.GetMouseLocation()return R.Vector2.new(640,360)end
W.workspace.CurrentCamera.ViewportPointToRay=function()return {Origin=R.Vector3.new(0,5,-10),Direction=R.Vector3.new(0,0,1)}end
local aim
function W.workspace.Raycast()return aim and {Instance=aim.Character.HumanoidRootPart}or nil end
W.env.RaycastParams={new=function()return {}end}
W.stub('InteractionAudio',{Transaction=function()end,Play=function()end})
local script=R.new('LocalScript');script.Name='FruitGiftClient'
W.load('FruitGiftClient',script)
local function tool(attrs)local t=R.new('Tool');for k,v in pairs(attrs)do t:SetAttribute(k,v)end;t.Parent=me.Character;return t end
local function click(target,input,processed)
 aim=target;R.advance(1);local n=#sent
 UIS.InputBegan:Fire(input or{UserInputType=R.Enum.UserInputType.MouseButton1},processed or false)
 return sent[n+1]
end
local function rt()return {UserInputType=R.Enum.UserInputType.Gamepad1,KeyCode=R.Enum.KeyCode.ButtonR2}end
check(click(near)==nil,'nothing held: no gift')
local fruit=tool({HarvestItemTool=true,HarvestInventoryId='crop-1'})
local s=click(near);check(s and s[1]=='Give'and s[2]==2 and s[3]=='crop-1','fruit uses Give')
fruit:Destroy()
local pack=tool({SeedPackTool=true,SeedInventoryId='101_7'})
s=click(near);check(s and s[1]=='GiveSeed'and s[2]==2 and s[3]=='101_7','pack uses GiveSeed')
check(click(far)==nil,'far player: nothing sent')
me:SetAttribute('ChestChaseSeedCarrying',true);check(click(near)==nil,'carrying a stolen pack: nothing sent');me:SetAttribute('ChestChaseSeedCarrying',nil)
me:SetAttribute('ChestChaseRunActive',true);check(click(near)==nil,'running: nothing sent');me:SetAttribute('ChestChaseRunActive',nil)
pack:Destroy()
local seed=tool({GardenSeed=true,SeedInventoryId='101_8'})
s=click(near);check(s and s[1]=='GiveSeed'and s[3]=='101_8','seed uses GiveSeed')
-- The garden's RT action sinks input while a seed is held; RT must still reach the gift client.
s=click(near,rt(),true);check(s and s[1]=='GiveSeed'and s[3]=='101_8','seed via RT (sunk by the garden action) still gives')
check(click(near,nil,true)==nil,'processed mouse click ignored')
seed:Destroy()
fruit=tool({HarvestItemTool=true,HarvestInventoryId='crop-2'})
check(click(near,rt(),true)==nil,'fruit keeps the original processed-input rule')
s=click(near,rt(),false);check(s and s[1]=='Give'and s[3]=='crop-2','fruit via RT')
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
