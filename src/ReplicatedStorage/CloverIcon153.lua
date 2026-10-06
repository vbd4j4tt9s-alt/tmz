-- R153 (owner: the 4 Leaf Clover pass picture, "a chunky low-poly green four-leaf clover with a curved stem"): ONE place that draws it, for the shop card, the HUD's luck row
-- and the purchase pop (A.Attach(parent) -> a Frame filling the parent). Nothing is uploaded. Every Attach shows the best picture there is and switches by itself when a better one arrives:
--  1. the pass's own Roblox icon: GetProductInfo(passId, GamePass).IconImageAssetId -> rbxassetid://<id> (the owner sets the clover as the pass icon on the Creator Dashboard).
--     A.SetInfo(info) takes the info table GamePassClient already fetched for the Robux price (cached there, pcall'd, retried with a growing wait when Roblox throttles); it is used
--     once the ImageLabel says IsLoaded.
--  2. the same picture drawn on the client: CloverIconData153 (palette + alpha, deflate, base64) -> Inflate153 (pure Luau) -> RGBA -> ONE EditableImage per client
--     (AssetService:CreateEditableImage + WritePixelsBuffer, shown with Content.fromObject on every Attach). Made lazily, in time slices, by A.Ensure() (the shop opens, the luck
--     row appears), never when every Attach already shows the pass icon; A.Release() destroys it (it also does when the pass icon has loaded everywhere). It is made at most once at a
--     time, a failure destroys what was made, and a failed draw is tried again twice (5 s, 10 s) before giving up.
--  3. the plain clover that is always there (no Image API, nothing loaded yet): drawn with UI shapes (PremiumEmblems 'Clover', a few dozen static frames, no image), or a 🍀 if even that is missing.
-- The Frame's attribute IconSource says which one is showing (pass / embedded / fallback). Tests / the preview replace the engine calls through A.Hooks.
local A={Version=153,Key='Clover'}
A.SliceSeconds=.004 -- of decoding a frame
A.MaxAttempts=3
A.Hooks={} -- Create(w,h,rgba) -> image object; Content(image) -> content; Spawn(fn); Wait(); Delay(seconds,fn); Preload(imageLabel)
local S={Status='idle',Attempts=0,Created=0,Destroyed=0,Token=0} -- Status: idle | working | ready | failed (Image, Content when ready; PassId once SetInfo had an icon)
local roots=setmetatable({},{__mode='k'}) -- every Attach's Frame
local function noop()end
-- Decode -------------------------------------------------------------------------------------------------------------------------------------
-- data (CloverIconData153) -> width, height, RGBA buffer (row 0 first, straight alpha). tick (optional) is called every ~1 KB of work (see Inflate153).
function A.Decode(data,tick)
 tick=tick or noop
 local Z=require(script.Parent.Inflate153)
 local w,h,colors=data.Width,data.Height,data.Colors
 assert(type(w)=='number'and type(h)=='number'and type(colors)=='number'and w>=1 and h>=1 and w*h<=1048576 and colors>=1 and colors<=256,'clover icon: bad header')
 assert(data.Bytes==colors*3+2*w*h,'clover icon: the stream length does not fit the header')
 local raw=Z.Inflate(Z.Base64(table.concat(data.Data),tick),data.Bytes,tick)
 assert(Z.Adler(raw,tick)==data.Adler,'clover icon: checksum mismatch')
 local words={}
 for i=0,colors-1 do words[i]=buffer.readu8(raw,i*3)+buffer.readu8(raw,i*3+1)*256+buffer.readu8(raw,i*3+2)*65536 end
 local count=w*h;local out=buffer.create(count*4);local ix,ax=colors*3,colors*3+count
 for i=0,count-1 do
  local c=words[buffer.readu8(raw,ix+i)];assert(c,'clover icon: colour index out of range')
  buffer.writeu32(out,i*4,c+buffer.readu8(raw,ax+i)*16777216)
  if i%4096==4095 then tick()end
 end
 return w,h,out
end
-- Engine calls (hookable) -------------------------------------------------------------------------------------------------------------------
local function wait()if A.Hooks.Wait then A.Hooks.Wait()else task.wait()end end
local function createImage(w,h,rgba)
 local image
 if A.Hooks.Create then image=A.Hooks.Create(w,h,rgba)
 else
  image=game:GetService('AssetService'):CreateEditableImage({Size=Vector2.new(w,h)})
  assert(image,'no EditableImage (memory budget or API unavailable)')
  local written,why=pcall(image.WritePixelsBuffer,image,Vector2.zero,Vector2.new(w,h),rgba)
  if not written then pcall(image.Destroy,image);error(why,0)end
 end
 assert(image,'no EditableImage')
 S.Created+=1;return image
end
local function destroyImage(image)if image then pcall(image.Destroy,image);S.Destroyed+=1 end end
local function contentOf(image)if A.Hooks.Content then return A.Hooks.Content(image)end;return Content.fromObject(image)end
local function noContent()if A.Hooks.Content then return nil end;return Content.none end
-- One Attach ------------------------------------------------------------------------------------------------------------------------------------
local function refresh(root)
 if not root.Parent then return end
 local fallback,embedded,pass=root:FindFirstChild('Fallback'),root:FindFirstChild('Embedded'),root:FindFirstChild('PassIcon')
 local usePass=pass~=nil and pass.IsLoaded==true
 local useEmbedded=not usePass and embedded~=nil and S.Content~=nil
 if pass then pass.Visible=usePass end
 if embedded then embedded.Visible=useEmbedded end
 if fallback then fallback.Visible=not(usePass or useEmbedded)end
 root:SetAttribute('IconSource',usePass and'pass'or useEmbedded and'embedded'or'fallback')
end
local function refreshAll()for root in pairs(roots)do refresh(root)end end
-- Does any Attach still need the drawn picture (its pass icon is not loaded)? With no Attach at all the answer is yes (one is coming).
local function needed()
 local any=false
 for root in pairs(roots)do
  any=true;local pass=root:FindFirstChild('PassIcon')
  if not(pass and pass.IsLoaded==true)then return true end
 end
 return not any
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
  refresh(root)
  if label.IsLoaded==true and not needed()then A.Release()end -- the pass icon is everywhere: the drawn one is not needed any more
 end)
 task.spawn(function()
  pcall(function()if A.Hooks.Preload then A.Hooks.Preload(label)else game:GetService('ContentProvider'):PreloadAsync({label})end end)
  if root.Parent then refresh(root)end
 end)
 refresh(root)
end
function A.Attach(parent)
 local root=Instance.new('Frame');root.Name='CloverIcon153';root.BackgroundTransparency=1;root.BorderSizePixel=0;root.Size=UDim2.fromScale(1,1);root.Active=false;root.Parent=parent
 local fallback=Instance.new('Frame');fallback.Name='Fallback';fallback.BackgroundTransparency=1;fallback.BorderSizePixel=0;fallback.Size=UDim2.fromScale(1,1);fallback.Active=false;fallback.Parent=root
 local made=pcall(function()require(script.Parent.PremiumEmblems).Draw(fallback,'Clover')end)
 if not made then
  for _,child in ipairs(fallback:GetChildren())do child:Destroy()end
  local text=Instance.new('TextLabel');text.Name='Emoji';text.Text='🍀';text.BackgroundTransparency=1;text.Size=UDim2.fromScale(1,1);text.TextScaled=true;text.Active=false;text.Parent=fallback
 end
 local embedded=image(root,'Embedded',2)
 if S.Content~=nil then pcall(function()embedded.ImageContent=S.Content end)end
 roots[root]=true
 attachPass(root);refresh(root)
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
local function failed(why)
 S.Status='failed';S.Attempts+=1;S.Why=tostring(why)
 if not S.Warned then S.Warned=true;warn('[CloverIcon153] the clover could not be drawn, the plain one stays: '..S.Why)end
 if S.Attempts<A.MaxAttempts then
  local delay=A.Hooks.Delay or task.delay
  delay(5*S.Attempts,function()if S.Status=='failed'then S.Status='idle';A.Ensure()end end)
 end
end
local function work(token)
 local t0=os.clock()
 local function tick()
  if os.clock()-t0>A.SliceSeconds then wait();t0=os.clock();if token~=S.Token then error('cancelled',0)end end
 end
 local ok,w,h,rgba=pcall(function()return A.Decode(require(script.Parent.CloverIconData153),tick)end)
 if token~=S.Token then return end
 if not ok then failed(w);return end
 local made,object=pcall(createImage,w,h,rgba)
 if token~=S.Token then if made then destroyImage(object)end;return end
 if not made then failed(object);return end
 local got,content=pcall(contentOf,object)
 if not got or content==nil then destroyImage(object);failed(got and'no content'or content);return end
 S.Image=object;S.Content=content;S.Status='ready'
 for root in pairs(roots)do local embedded=root:FindFirstChild('Embedded');if embedded then pcall(function()embedded.ImageContent=content end)end end
 refreshAll()
end
-- Starts drawing (once per client; returns the status at once). Cheap to call again.
function A.Ensure()
 if S.Status=='working'or S.Status=='ready'then return S.Status end
 if S.Status=='failed'and S.Attempts>=A.MaxAttempts then return S.Status end
 if not needed()then return S.Status end
 S.Status='working';S.Token+=1;local token=S.Token
 local spawn=A.Hooks.Spawn or task.spawn;spawn(function()work(token)end)
 return S.Status
end
-- Destroys the drawn picture (and stops one in the making). The Attach frames fall back to the plain clover until Ensure draws it again.
function A.Release()
 S.Token+=1
 local object=S.Image;S.Image=nil;S.Content=nil
 for root in pairs(roots)do local embedded=root:FindFirstChild('Embedded');if embedded then pcall(function()embedded.ImageContent=noContent()end);pcall(function()embedded.Image=''end)end end
 if object then destroyImage(object)end
 if S.Status=='working'or S.Status=='ready'then S.Status='idle' end
 refreshAll()
end
function A.Stats()return {Status=S.Status,Attempts=S.Attempts,Created=S.Created,Destroyed=S.Destroyed,Live=S.Created-S.Destroyed,PassId=S.PassId,Why=S.Why}end
function A.Source(root)return root and root:GetAttribute('IconSource')end
-- Tests: back to a fresh client.
function A.Reset()A.Release();S.Status='idle';S.Attempts=0;S.Created=0;S.Destroyed=0;S.PassId=nil;S.Why=nil;S.Warned=nil;roots=setmetatable({},{__mode='k'})end
return A
