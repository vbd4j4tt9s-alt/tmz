-- R95: original pixels stay available through delayed, failed and revoked image loads.
local A={};local entries={};local jobs={};local running=false
local Fallback=require(script.Parent.ArtworkFallback87)
local Prepared=require(script.Parent.ArtworkFallbackData89)
local function queue(fn)
 table.insert(jobs,fn);if running then return end;running=true
 task.defer(function()
  while #jobs>0 do local job=table.remove(jobs,1);local ok,err=pcall(job);if not ok then warn('[Artwork] '..tostring(err))end;task.wait()end
  running=false
 end)
end
local function refresh(root)
 local fallback=root:FindFirstChild('SmoothFallback')
 local generated=root:FindFirstChild('Artwork');local uploaded=root:FindFirstChild('UploadedArtwork')
 local useUpload=uploaded and uploaded.IsLoaded
 local useGenerated=not useUpload and generated and generated.IsLoaded
 if uploaded then uploaded.Visible=useUpload==true end
 if generated then generated.Visible=useGenerated==true end
 if fallback then fallback.Visible=not(useUpload or useGenerated)end
end
local function watchImage(root,image)
 local loaded,destroyed
 loaded=image:GetPropertyChangedSignal('IsLoaded'):Connect(function()refresh(root)end)
 destroyed=image.Destroying:Connect(function()
  if loaded then loaded:Disconnect();loaded=nil end
  if destroyed then destroyed:Disconnect();destroyed=nil end
 end)
 refresh(root)
end
local function bind(root,entry)
 if not root.Parent or root:FindFirstChild('Artwork')then return true end
 local image=Instance.new('ImageLabel');image.Name='Artwork';image.Size=UDim2.fromScale(1,1);image.BackgroundTransparency=1;image.ScaleType=entry.Kind=='City'and Enum.ScaleType.Crop or Enum.ScaleType.Fit;image.Visible=false;image.ZIndex=2
 local ok=pcall(function()image.ImageContent=Content.fromObject(entry.Image)end)
 if not ok then image:Destroy();return false end
 image.Parent=root;watchImage(root,image)
 return true
end
local function draw(entry,kind,data)
 local spec=Prepared[kind]or(entry.Bytes and Fallback.Build(entry.Bytes,data.Width or data.Size,data.Height or data.Size,kind))
 if not spec then return end
 local f=Instance.new('Frame');f.Name='SmoothFallback';f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale(.5,.5);f.Size=UDim2.fromScale(1,1);f.BackgroundTransparency=1;f.Active=false
 if kind~='City'then local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=spec.Width/spec.Height;aspect.AspectType=Enum.AspectType.FitWithinMaxSize;aspect.Parent=f end
 for _,s in ipairs(spec.Strips)do
  local p=Instance.new('Frame');p.BorderSizePixel=0;p.BackgroundColor3=Color3.new(1,1,1);p.Active=false
  p.Position=UDim2.fromScale(s[1]/spec.Width,s[2]/spec.Height);p.Size=UDim2.fromScale(s[3]/spec.Width,1/spec.Height)
  local c,t={},{};for _,k in ipairs(s[4])do c[#c+1]=ColorSequenceKeypoint.new(k[1],Color3.fromRGB(k[2],k[3],k[4]));t[#t+1]=NumberSequenceKeypoint.new(k[1],1-k[5]/255)end
  local g=Instance.new('UIGradient');g.Color=ColorSequence.new(c);g.Transparency=NumberSequence.new(t);g.Parent=p;p.Parent=f
 end
 entry.Template=f
 for root in pairs(entry.Roots)do if root.Parent and not root:FindFirstChild('SmoothFallback')then f:Clone().Parent=root;refresh(root)end end
end
local function load(entry,kind,data)
 if entry.Image then return end
 entry.Attempts+=1
 local created
 local ok,result=pcall(function()
  local encoding=game:GetService('EncodingService')
  local bytes=encoding:DecompressBuffer(encoding:Base64Decode(buffer.fromstring(data.RGBA)),Enum.CompressionAlgorithm.Zstd)
  local w,h=data.Width or data.Size,data.Height or data.Size
  assert(buffer.len(bytes)==w*h*4,'Invalid artwork buffer')
  entry.Bytes=bytes
  if not entry.Template then draw(entry,kind,data)end
  created=game:GetService('AssetService'):CreateEditableImage({Size=Vector2.new(w,h)});assert(created,'Image unavailable')
  created:WritePixelsBuffer(Vector2.zero,Vector2.new(w,h),bytes);return created
 end)
 entry.Bytes=nil
 if ok then
  entry.Image=result
  for root in pairs(entry.Roots)do if root.Parent then bind(root,entry)end end
 else
  if created then created:Destroy()end
  if entry.Attempts<3 then task.delay(entry.Attempts*3,function()queue(function()load(entry,kind,data)end)end)end
 end
end
function A.Attach(parent,kind,data,id)
 local root=Instance.new('Frame');root.Name='Generated'..kind;root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Active=false;root.ClipsDescendants=true;root.Parent=parent
 local e=entries[kind]
 if not e then e={Kind=kind,Roots=setmetatable({},{__mode='k'}),Attempts=0};entries[kind]=e end
 e.Roots[root]=true
 -- Every prepared icon is visible immediately, even if image APIs never become available.
 if not e.Template then draw(e,kind,data)end
 if e.Template and not root:FindFirstChild('SmoothFallback')then e.Template:Clone().Parent=root end
 if e.Image then bind(root,e)elseif not e.Queued then e.Queued=true;queue(function()load(e,kind,data)end)end
 id=tonumber(id)
 if id and id>0 then
  local image=Instance.new('ImageLabel');image.Name='UploadedArtwork';image.Size=UDim2.fromScale(1,1);image.BackgroundTransparency=1;image.ScaleType=kind=='City'and Enum.ScaleType.Crop or Enum.ScaleType.Fit;image.Image='rbxassetid://'..math.floor(id);image.Visible=false;image.ZIndex=3;image.Parent=root
  watchImage(root,image)
  task.spawn(function()pcall(function()game:GetService('ContentProvider'):PreloadAsync({image})end);if root.Parent then refresh(root)end end)
 end
 root.Destroying:Connect(function()e.Roots[root]=nil end)
 refresh(root)
 return root
end
return A
