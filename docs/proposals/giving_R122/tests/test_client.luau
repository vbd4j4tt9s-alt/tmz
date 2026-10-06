--!nocheck
-- R122 FruitGiftClient smoke test: holding a fruit, seed or pack and clicking / RT-ing a nearby player sends the
-- right remote action and inventory id; carrying, a far target or no held item sends nothing.
-- R130: the click first opens "Are you sure you want to give <item> to <player>?"; only Give sends it. The player under
-- the mouse lights up while a giftable item is held and they are in reach.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end -- mock gap
local Players=W.service('Players')
local present={}
function Players.GetPlayerFromCharacter(_,m)for _,p in pairs(present)do if p.Character==m then return p end end;return nil end
local function makePlayer(id,name,x)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
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
local sent={};function remote.FireServer(_,...)sent[#sent+1]=table.pack(...);sent[#sent].At=R.clock end
local UIS=W.UIS;UIS.TouchTapInWorld=R.signal();function UIS.GetMouseLocation()return R.Vector2.new(640,360)end
W.workspace.CurrentCamera.ViewportPointToRay=function()return {Origin=R.Vector3.new(0,5,-10),Direction=R.Vector3.new(0,0,1)}end
local aim
function W.workspace.Raycast()return aim and {Instance=aim.Character.HumanoidRootPart}or nil end
W.env.RaycastParams={new=function()return {}end}
W.stub('InteractionAudio',{Transaction=function()end,Play=function()end})
local gifts={};W.stub('NoticeFeed83',{Gift=function(text)gifts[#gifts+1]=text end,Push=function()end,Plain=function()end})
local script=R.new('LocalScript');script.Name='FruitGiftClient'
W.load('FruitGiftClient',script)
local gui=pg:FindFirstChild('FruitGifts');local dialog=gui and gui:FindFirstChild('GiftConfirm')
local giveButton=dialog and dialog:FindFirstChild('Give');local cancelButton=dialog and dialog:FindFirstChild('Cancel')
local question=dialog and dialog:FindFirstChild('Question');local status=gui and gui:FindFirstChild('GiftStatus')
check(dialog and giveButton and cancelButton and question,'confirmation popup built')
check(dialog and dialog.Visible==false,'popup hidden at start')
check(question.RichText==true,'question keeps RichText for the coloured names')
local function shown(label)return label:GetAttribute('FullText')or label.Text end
local function tool(attrs,name)local t=R.new('Tool');t.Name=name or'Item';for k,v in pairs(attrs)do t:SetAttribute(k,v)end;t.Parent=me.Character;return t end
local function click(target,input,processed)
 aim=target;R.advance(1);local n=#sent
 UIS.InputBegan:Fire(input or{UserInputType=R.Enum.UserInputType.MouseButton1},processed or false)
 return dialog.Visible,sent[n+1]
end
-- Click, then press Give; returns what was sent (after any send delay).
local function give(target,input,processed)
 local open,early=click(target,input,processed)
 if early then return 'SENT_WITHOUT_ASKING'end
 if not open then return nil end
 local n=#sent;giveButton.Activated:Fire();R.advance(2.1)
 check(dialog.Visible==false,'popup closes after Give')
 return sent[n+1]
end
local function rt()return {UserInputType=R.Enum.UserInputType.Gamepad1,KeyCode=R.Enum.KeyCode.ButtonR2}end
local function lit(p)local h=p.Character:FindFirstChild('GiftTarget');return h~=nil and h:IsA('Highlight')and h.Adornee==p.Character end
local function anyLit()return lit(near)or lit(far)end
-- R122 routing, now through the popup.
check(give(near)==nil,'nothing held: no gift')
local fruit=tool({HarvestItemTool=true,HarvestInventoryId='crop-1'},'Golden Apple')
local open,early=click(near)
check(open and early==nil,'click opens the popup and sends nothing yet')
check(question.Text:find('Give <font',1,true)and question.Text:find('Golden Apple',1,true)and question.Text:find('Near',1,true),'popup names the item and the player: '..question.Text)
check(lit(near),'the chosen player is highlighted')
local n=#sent;giveButton.Activated:Fire();R.advance(2.1)
local s=sent[n+1];check(s and s[1]=='Give'and s[2]==2 and s[3]=='crop-1','Give sends the fruit (Give)')
check(dialog.Visible==false,'popup closed')
-- Cancel and controller B do nothing.
open=click(near);n=#sent;cancelButton.Activated:Fire();R.advance(2.1)
check(open and #sent==n and dialog.Visible==false,'Cancel closes without giving')
open=click(near);n=#sent;UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.Gamepad1,KeyCode=R.Enum.KeyCode.ButtonB},false);R.advance(2.1)
check(open and #sent==n and dialog.Visible==false,'B closes without giving')
-- Unequipping the item closes the popup.
open=click(near);fruit.Parent=bp;W.frames(10)
check(open and dialog.Visible==false,'putting the item away closes the popup')
fruit.Parent=me.Character
fruit:Destroy()
local pack=tool({SeedPackTool=true,SeedInventoryId='101_7'},'Diamond Desert Seed Pack')
s=give(near);check(s and s[1]=='GiveSeed'and s[2]==2 and s[3]=='101_7','pack uses GiveSeed')
open=click(far);check(not open and shown(status):find('Get closer to Far',1,true),'far player: no popup, "Get closer" ('..shown(status)..')')
me:SetAttribute('ChestChaseSeedCarrying',true);check(give(near)==nil,'carrying a stolen pack: nothing sent');me:SetAttribute('ChestChaseSeedCarrying',nil)
me:SetAttribute('ChestChaseRunActive',true);check(give(near)==nil,'running: nothing sent');me:SetAttribute('ChestChaseRunActive',nil)
pack:Destroy()
local seed=tool({GardenSeed=true,SeedInventoryId='101_8'},'Gold Sunflower')
s=give(near);check(s and s[1]=='GiveSeed'and s[3]=='101_8','seed uses GiveSeed')
-- The garden's RT action sinks input while a seed is held; RT must still reach the gift client.
s=give(near,rt(),true);check(s and s[1]=='GiveSeed'and s[3]=='101_8','seed via RT (sunk by the garden action) still gives')
check(give(near,nil,true)==nil,'processed mouse click ignored')
seed:Destroy()
fruit=tool({HarvestItemTool=true,HarvestInventoryId='crop-2'})
check(give(near,rt(),true)==nil,'fruit keeps the original processed-input rule')
s=give(near,rt(),false);check(s and s[1]=='Give'and s[3]=='crop-2','fruit via RT')
-- A quick second gift waits for the server's 2 s gift gap instead of being dropped.
local first=#sent+1
click(near);giveButton.Activated:Fire();R.advance(.2);click(near);giveButton.Activated:Fire();R.advance(2.5)
check(sent[first]and sent[first+1]and sent[first+1].At-sent[first].At>=2.05-1e-6,('second quick gift sent after the 2 s gap (%.2f s)'):format(sent[first+1]and(sent[first+1].At-sent[first].At)or -1))
-- Hover highlight (R130).
aim=near;W.frames(10);check(lit(near),'hovering a player in reach lights them up')
aim=far;W.frames(10);check(not anyLit(),'a player out of reach is not lit')
aim=near;W.frames(10);aim=nil;W.frames(10);check(not anyLit(),'light goes when the mouse leaves')
aim=near;W.frames(10);fruit.Parent=bp;W.frames(10);check(not anyLit(),'no light without a giftable item in hand')
fruit.Parent=me.Character;local gone=near.Character;aim=near;W.frames(10)
local respawn=R.new('Model');respawn.Name='Near';respawn.Parent=W.workspace
local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=R.Vector3.new(8,3,0);root.Parent=respawn
gone:Destroy();near.Character=respawn;W.frames(10)
check(lit(near),'light comes back on the respawned character')
-- Messages: the receiver's text is in the notice stack; the status line shows only text the server puts there.
remote.OnClientEvent:Fire('Received','🎁 Alice gave you Golden Apple!',{From='Alice',Item='Golden Apple'})
check(status.Visible==false,'a received gift is not on the giver status line')
check(#gifts==1 and gifts[1]:find('Alice',1,true)and gifts[1]:find('Golden Apple',1,true)and gifts[1]:find('gave you',1,true),'received gift goes to the notice stack (with its chime): '..tostring(gifts[1]))
remote.OnClientEvent:Fire('Received','<b>x</b> gave you y!')
check(#gifts==2 and not gifts[2]:find('<b>',1,true),'plain fallback text is escaped')
remote.OnClientEvent:Fire('Status','Gift sent to Near!');check(status.Visible and shown(status)=='Gift sent to Near!','sender status shown')
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
