--!nocheck
-- Gift popup preview (not a test): the REAL FruitGiftClient under the mock, holding a fruit and clicking a nearby
-- player, so the "Are you sure you want to give ... to ...?" popup is open. Prints one JSON dump for render_gui.py.
-- Set W_,H_ (viewport) before this file.
local W=require('./world');local R=W.R;local dump=require('./dump_gui')
local vw,vh=W_ or 1280,H_ or 720
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end
local Players=W.service('Players');local present={}
function Players.GetPlayerFromCharacter(_,m)for _,p in pairs(present)do if p.Character==m then return p end end end
local function makePlayer(id,name,display,x)
 local p=R.new('Player');p.Name=name;p.DisplayName=display;p.UserId=id;p.Parent=Players;present[id]=p
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=R.Vector3.new(x,3,0);root.Parent=c;p.Character=c;return p
end
local me=makePlayer(1,'Me','Me',0);local friend=makePlayer(2,'gardenfan22','Sunny',8);Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='FruitGift';remote.Parent=remotes;remote.OnClientEvent=R.signal();function remote.FireServer()end
W.UIS.TouchTapInWorld=R.signal();function W.UIS.GetMouseLocation()return R.Vector2.new(vw/2,vh/2)end
local camera=W.workspace.CurrentCamera;camera.ViewportSize=R.Vector2.new(vw,vh)
camera.ViewportPointToRay=function()return {Origin=R.Vector3.new(0,5,-10),Direction=R.Vector3.new(0,0,1)}end
function W.workspace.Raycast()return {Instance=friend.Character.HumanoidRootPart}end
W.env.RaycastParams={new=function()return {}end}
W.stub('InteractionAudio',{Transaction=function()end})
local realInstance=R.Instance.new
R.Instance.new=function(class,parent)local o=realInstance(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(vw,vh)end;return o end
local t=R.new('Tool');t.Name='Frosted Golden Apple';t:SetAttribute('HarvestItemTool',true);t:SetAttribute('HarvestInventoryId','c1');t.Parent=me.Character
W.load('FruitGiftClient',R.new('LocalScript'))
R.advance(1);W.UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1},false)
local gui=pg:FindFirstChild('FruitGifts');assert(gui:FindFirstChild('GiftConfirm').Visible,'popup open')
-- The mock gives every label a 100 px size, so the theme's fitter wraps short titles; show the full text instead.
for _,d in ipairs(gui:GetDescendants())do local full=d:GetAttribute('FullText');if full then d._props.Text=full end end
-- render_gui.py ignores UISizeConstraint: apply the popup's 420 px cap here as Roblox does.
local box=gui.GiftConfirm;if vw*.9>420 then box.Size=R.UDim2.new(0,420,0,196)end
print('JSON '..dump(gui,vw,vh))
