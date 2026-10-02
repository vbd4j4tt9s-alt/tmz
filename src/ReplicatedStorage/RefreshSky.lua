-- R68: a black sky, without switching off the world's lights. Scoped and reversible.
local Lighting=game:GetService('Lighting');local A={NightDensity=.32};local image;local attempted=false
local faces={'SkyboxBackContent','SkyboxDownContent','SkyboxFrontContent','SkyboxLeftContent','SkyboxRightContent','SkyboxUpContent'}
local function blackImage()
 if not attempted then
  attempted=true
  local ok,result=pcall(function()
   local e=game:GetService('AssetService'):CreateEditableImage({Size=Vector2.new(1,1)})
   assert(e,'No image budget');local pixels=buffer.create(4);buffer.writeu8(pixels,3,255)
   e:WritePixelsBuffer(Vector2.zero,Vector2.new(1,1),pixels);return e
  end)
  if ok then image=result end
 end
 return image
end
function A.Begin()
 local priorRefresh=Lighting:GetAttribute('TrackRefreshActive');Lighting:SetAttribute('TrackRefreshActive',true)
 local sky=Instance.new('Sky');sky.Name='TrackRefreshBlackSky';sky.CelestialBodiesShown=false;sky.StarCount=0
 local skies,air,clouds={},{},{};local fallback
 for _,child in ipairs(Lighting:GetChildren())do
  if child:IsA('Sky')then skies[#skies+1]=child;child.Parent=nil
  elseif child:IsA('Atmosphere')then
   air[#air+1]={Object=child,Density=child.Density,Haze=child.Haze,Glare=child.Glare,Color=child.Color,Decay=child.Decay,Offset=child.Offset}
  end
 end
 local terrain=workspace:FindFirstChildOfClass('Terrain')
 if terrain then for _,child in ipairs(terrain:GetChildren())do if child:IsA('Clouds')then clouds[#clouds+1]={Object=child,Enabled=child.Enabled};child.Enabled=false end end end
 local ok=pcall(function()
  local e=blackImage();assert(e,'Image API unavailable');local content=Content.fromObject(e)
  for _,property in ipairs(faces)do sky[property]=content end
 end)
 if not ok then
  -- Older/image-restricted clients retain a readable night instead of a black world.
  fallback={ClockTime=Lighting.ClockTime,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient}
  local function readable(c)return Color3.new(math.max(c.R,.55),math.max(c.G,.55),math.max(c.B,.55))end
  Lighting.ClockTime=0;Lighting.Ambient=readable(Lighting.Ambient);Lighting.OutdoorAmbient=readable(Lighting.OutdoorAmbient)
 end
 -- R130 (owner: "when the track refreshes the sky turns dark too"). With the black sky image the air is cleared so the
 -- black shows. Without it (no image API on that client) the sky used to stay light: now there is no texture-less Sky
 -- (Roblox's own sky follows the midnight clock) and the air turns black like The Darkened's lights-out, at about the
 -- usual view distance, so the sky and the far distance go dark while the base stays readable.
 if ok then
  sky.Parent=Lighting
  for _,v in ipairs(air)do v.Object.Density=0;v.Object.Haze=0;v.Object.Glare=0 end
 else
  sky:Destroy();sky=nil
  if #air==0 then
   local night=Instance.new('Atmosphere');night.Name='TrackRefreshNightAir';night.Density=0;night.Parent=Lighting
   air[1]={Object=night,Made=true}
  end
  for _,v in ipairs(air)do
   local a=v.Object;a.Color=Color3.new();a.Decay=Color3.new();a.Offset=0;a.Haze=0;a.Glare=0;a.Density=math.max(a.Density,A.NightDensity)
  end
 end
 local restored=false
 return function()
  if restored then return end;restored=true;if sky then sky:Destroy()end
  for _,old in ipairs(skies)do if old.Parent==nil then old.Parent=Lighting end end
  for _,v in ipairs(air)do
   local a=v.Object
   if v.Made then a:Destroy()
   elseif a.Parent==Lighting then a.Density=v.Density;a.Haze=v.Haze;a.Glare=v.Glare;a.Color=v.Color;a.Decay=v.Decay;a.Offset=v.Offset end
  end
  for _,v in ipairs(clouds)do if v.Object.Parent then v.Object.Enabled=v.Enabled end end
  if fallback then for k,v in pairs(fallback)do Lighting[k]=v end end
  Lighting:SetAttribute('TrackRefreshActive',priorRefresh)
 end
end
function A.Destroy()if image then image:Destroy();image=nil end;attempted=false end
return A
