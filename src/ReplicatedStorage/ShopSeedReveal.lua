-- Seeds first. Hover/focus/tap reveals a silhouette until seed AND adult are owned.
local RS=game:GetService('ReplicatedStorage');local Tween=game:GetService('TweenService');local Gui=game:GetService('GuiService')
local Preview=require(RS.CollectionViewport);local M={}
function M.Attach(card,view,id,player)
 local adult=false;local generation=0;local dead=false;local connections={};local stop=function()end;local fade,zoomTween
 local zoom=Instance.new('UIScale');zoom.Scale=1;zoom.Parent=view
 local function owned(folder)local f=player:FindFirstChild(folder);local b=f and f:FindFirstChild(id);return b and b.Value==true end
 local function render(animate)
  generation+=1;local token=generation;stop()
  if fade then fade:Cancel()end;if zoomTween then zoomTween:Cancel()end
  view.ImageTransparency=animate and .7 or 0
  task.defer(function()
   if dead or not card.Parent or generation~=token then return end
   local known=not adult or(owned('DiscoveredSeeds')and owned('DiscoveredPlants'))
   stop=Preview.Attach(view,id,adult,known);view:SetAttribute('ShowingAdult',adult);view:SetAttribute('Silhouette',not known)
   if animate and not Gui.ReducedMotionEnabled then
    zoom.Scale=.88;zoomTween=Tween:Create(zoom,TweenInfo.new(.2,Enum.EasingStyle.Back),{Scale=1});zoomTween:Play()
    fade=Tween:Create(view,TweenInfo.new(.16),{ImageTransparency=0});fade:Play()
   else zoom.Scale=1;view.ImageTransparency=0 end
  end)
 end
 local function show(value)if value==adult then return end;adult=value;render(true)end
 local function watch(signal,fn)table.insert(connections,signal:Connect(fn))end
 watch(card.MouseEnter,function()show(true)end);watch(card.MouseLeave,function()show(false)end)
 watch(card.SelectionGained,function()show(true)end);watch(card.SelectionLost,function()show(false)end)
 watch(card.Activated,function()show(not adult)end)
 local function destroy()
  if dead then return end;dead=true;generation+=1;stop();if fade then fade:Cancel()end;if zoomTween then zoomTween:Cancel()end
  for _,c in ipairs(connections)do c:Disconnect()end
 end
 watch(card.Destroying,destroy);render(false)
 return {Refresh=function()if not dead then render(false)end end,Destroy=destroy}
end
return M
