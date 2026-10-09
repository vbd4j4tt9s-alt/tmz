-- R153 (owner: the 4 Leaf Clover pass picture, "a chunky low-poly green four-leaf clover with a curved stem"): ONE place that shows it, for the shop card, the HUD's luck row
-- and the purchase pop (A.Attach(parent) -> a Frame filling the parent). Nothing is uploaded. Every Attach shows the best picture there is and switches by itself when a better one arrives:
--  1. the pass's own Roblox icon: GetProductInfo(passId, GamePass).IconImageAssetId -> rbxassetid://<id> (the owner sets the clover as the pass icon on the Creator Dashboard).
--     A.SetInfo(info) takes the info table GamePassClient already fetched for the Robux price (cached there, pcall'd, retried with a growing wait when Roblox throttles); it is used
--     once the ImageLabel says IsLoaded.
--  2. the same picture drawn on the client: CloverPassImage153 (palette + alpha, deflate, base64) shown by EmbeddedImage153 (the game's one embedded-image decoder: decoded once per client in
--     time slices, ONE EditableImage shared by every label, destroyed when the last label lets go, a "fallback" route when the Image API is off or the data is bad). It starts when A.Ensure()
--     is called (the shop opens, the luck row appears, a clover is bought), never for an Attach whose pass icon has already loaded, and an Attach lets go of it (A.Release / its own pass icon
--     loading) so the EditableImage is not kept for nothing.
--  3. the plain clover that is always there (no Image API, nothing loaded yet): drawn with UI shapes (PremiumEmblems 'Clover', a few dozen static frames, no image), or a 🍀 if even that is missing.
-- R155 (owner uploaded the same picture: image 121815230112848): 0. that uploaded image comes first (A.AssetId; 0 / nil = off), loaded like the pass icon; once it
--  shows, the Attach lets go of the drawn picture. The pass icon, the drawn picture and the plain clover stay as the next choices.
-- The Frame's attribute IconSource says which one is showing (asset / pass / embedded / fallback). Tests replace the engine calls through A.Hooks.Preload and EmbeddedImage153.Hooks.
local A={Version=153,Key='Clover',AssetId=121815230112848}
A.Hooks={} -- Preload(imageLabel)
local S={Wanted=false} -- Wanted: somebody asked for the drawn picture (Ensure); PassId once SetInfo had an icon
local roots=setmetatable({},{__mode='k'}) -- every Attach's Frame
local function embedded()return require(script.Parent.EmbeddedImage153)end
local function refresh(root)
 if not root.Parent then return end
 local fallback,emb,pass,asset=root:FindFirstChild('Fallback'),root:FindFirstChild('Embedded'),root:FindFirstChild('PassIcon'),root:FindFirstChild('AssetIcon')
 local useAsset=asset~=nil and asset.IsLoaded==true
 local usePass=not useAsset and pass~=nil and pass.IsLoaded==true
 local useEmbedded=not(useAsset or usePass)and emb~=nil and root:GetAttribute('EmbeddedRoute')=='image'
 if asset then asset.Visible=useAsset end
 if pass then pass.Visible=usePass end
 if emb then emb.Visible=useEmbedded end
 if fallback then fallback.Visible=not(useAsset or usePass or useEmbedded)end
 root:SetAttribute('IconSource',useAsset and'asset'or usePass and'pass'or useEmbedded and'embedded'or'fallback')
end
-- the drawn picture for one Attach (EmbeddedImage153 shares the image between them)
local function startRoot(root)
 local emb=root:FindFirstChild('Embedded');if not emb or root:GetAttribute('Showing')==true then return end
 root:SetAttribute('Showing',true);root:SetAttribute('EmbeddedRoute','pending')
 local ok=pcall(function()
  embedded().Show(emb,require(script.Parent.CloverPassImage153),function(route)root:SetAttribute('EmbeddedRoute',route);refresh(root)end)
 end)
 if not ok then root:SetAttribute('EmbeddedRoute','fallback');refresh(root)end
end
local function stopRoot(root)
 if root:GetAttribute('Showing')~=true then return end
 root:SetAttribute('Showing',false);root:SetAttribute('EmbeddedRoute',nil)
 local emb=root:FindFirstChild('Embedded');if emb then pcall(function()embedded().Release(emb)end)end
 refresh(root)
end
local function image(parent,name,z)
 local label=Instance.new('ImageLabel');label.Name=name;label.BackgroundTransparency=1;label.BorderSizePixel=0;label.Size=UDim2.fromScale(1,1);label.ScaleType=Enum.ScaleType.Fit
 label.ZIndex=z;label.Visible=false;label.Active=false;label.Parent=parent;return label
end
local function attachPass(root)
 if not S.PassId then return end
 local label=root:FindFirstChild('PassIcon')
 if label then label.Image='rbxassetid://'..math.floor(S.PassId);return end
 label=image(root,'PassIcon',3);label.Image='rbxassetid://'..math.floor(S.PassId)
 label:GetPropertyChangedSignal('IsLoaded'):Connect(function()
  if label.IsLoaded==true then stopRoot(root)end -- this Attach has its pass icon: it lets go of the drawn picture
  refresh(root)
 end)
 task.spawn(function()
  pcall(function()if A.Hooks.Preload then A.Hooks.Preload(label)else game:GetService('ContentProvider'):PreloadAsync({label})end end)
  if root.Parent then refresh(root)end
 end)
 refresh(root)
end
-- R155: the owner's uploaded clover (0)
local function attachAsset(root)
 local id=tonumber(A.AssetId);if not(id and id>0)then return end
 local label=image(root,'AssetIcon',4);label.Image='rbxassetid://'..math.floor(id)
 label:GetPropertyChangedSignal('IsLoaded'):Connect(function()
  if label.IsLoaded==true then stopRoot(root)end
  refresh(root)
 end)
 task.spawn(function()
  pcall(function()if A.Hooks.Preload then A.Hooks.Preload(label)else game:GetService('ContentProvider'):PreloadAsync({label})end end)
  if root.Parent then refresh(root)end
 end)
end
function A.Attach(parent)
 local root=Instance.new('Frame');root.Name='CloverIcon153';root.BackgroundTransparency=1;root.BorderSizePixel=0;root.Size=UDim2.fromScale(1,1);root.Active=false;root.Parent=parent
 local fallback=Instance.new('Frame');fallback.Name='Fallback';fallback.BackgroundTransparency=1;fallback.BorderSizePixel=0;fallback.Size=UDim2.fromScale(1,1);fallback.Active=false;fallback.Parent=root
 local made=pcall(function()require(script.Parent.PremiumEmblems).Draw(fallback,'Clover')end)
 if not made then
  for _,child in ipairs(fallback:GetChildren())do child:Destroy()end
  local text=Instance.new('TextLabel');text.Name='Emoji';text.Text='🍀';text.BackgroundTransparency=1;text.Size=UDim2.fromScale(1,1);text.TextScaled=true;text.Active=false;text.Parent=fallback
 end
 image(root,'Embedded',2)
 roots[root]=true
 attachAsset(root);attachPass(root);refresh(root)
 if S.Wanted then startRoot(root)end
 return root
end
-- The pass icon (1) -----------------------------------------------------------------------------------------------------------------------------
-- info: what MarketplaceService:GetProductInfoAsync(passId, GamePass) returned. true when it has an icon id (a table without one, nil or junk changes nothing).
function A.SetInfo(info)
 local id=type(info)=='table'and tonumber(info.IconImageAssetId)or nil
 if not(id and id>0 and id%1==0 and id<9007199254740991)then return false end
 if S.PassId==id then return true end
 S.PassId=id
 for root in pairs(roots)do attachPass(root)end
 return true
end
-- The drawn picture (2) -------------------------------------------------------------------------------------------------------------------------
-- Starts drawing for every Attach that does not have its pass icon yet (and for the ones made later). Cheap to call again: EmbeddedImage153 decodes once.
function A.Ensure()
 S.Wanted=true
 for root in pairs(roots)do
  local pass,asset=root:FindFirstChild('PassIcon'),root:FindFirstChild('AssetIcon')
  if not(pass and pass.IsLoaded==true)and not(asset and asset.IsLoaded==true)then startRoot(root)end
 end
end
-- Lets go of the drawn picture everywhere (the last one to let go destroys the EditableImage). The Attach frames show the pass icon or the plain clover until Ensure draws it again.
function A.Release()
 S.Wanted=false
 for root in pairs(roots)do stopRoot(root)end
end
function A.Stats()local s=embedded().Status();s.PassId=S.PassId;s.Wanted=S.Wanted;return s end
function A.Source(root)return root and root:GetAttribute('IconSource')end
-- Tests: back to a fresh client.
function A.Reset()A.Release();S.PassId=nil;roots=setmetatable({},{__mode='k'})end
return A
