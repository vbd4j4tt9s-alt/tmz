-- Screen coverage decides where the existing detail budget is most useful.
local P={PartBudget=1400,ModelBudget=24,NearRange=360,FarRange=3200}
function P.View(camera)
 local half=math.tan(math.rad(camera.FieldOfView or 70)*.5)
 local size=camera.ViewportSize;local height=math.max(1,size and size.Y or 720);local aspect=size and size.X/height or 16/9
 return {Frame=camera.CFrame,Half=half,Height=height,Aspect=aspect}
end
function P.Coverage(camera,center,radius,view)
 view=view or P.View(camera)
 local q=view.Frame:PointToObjectSpace(center);local depth=-q.Z
 local half,height,aspect=view.Half,view.Height,view.Aspect
 local visible=depth+radius>0 and math.abs(q.Y)<math.max(0,depth)*half+radius and math.abs(q.X)<math.max(0,depth)*half*aspect+radius
 local pixels=radius*height/(2*half*math.max(radius,depth,1))
 return visible,pixels
end
function P.Select(entries,low)
 local partBudget=low and 850 or P.PartBudget;local modelBudget=low and 12 or P.ModelBudget
 local function score(e)return e.Score-((e.Record.PlanMode=='full'and e.Record.Visual)and 48 or 0)end
 table.sort(entries,function(a,b)local x,y=score(a),score(b);if x~=y then return x<y end;return tostring(a.SortKey or a.Record.Crop and a.Record.Crop.Id or a.SeedId or a.Item)<tostring(b.SortKey or b.Record.Crop and b.Record.Crop.Id or b.SeedId or b.Item)end)
 local used,count=0,0;local crowded=#entries>6;local bodyBudget=crowded and(low and 650 or 1050)or partBudget
 for _,e in ipairs(entries)do
  e.Selected=nil;e.DetailMode=nil;e.Cost=e.FullCost
  local retained=e.Record.PlanMode=='full'and e.Record.Visual~=nil
  local range=retained and 400 or P.NearRange
  if e.OnScreen and e.Pixels>=(retained and 32 or 40)then range=math.max(range,math.min(P.FarRange,e.Radius*(retained and 20 or 18)))end
  if e.Distance<range and used+e.FullCost<=bodyBudget and count<math.min(modelBudget,crowded and 18 or modelBudget)then
   e.DetailMode='full';used+=e.FullCost;count+=1
  end
 end
 -- Preserve the full fruit silhouette (petals, scales, rind, crystals) independently.
 for _,e in ipairs(entries)do
  if e.DetailMode or not e.Ripe or e.Distance>P.FarRange or count>=modelBudget then continue end
  local chosen={};local cost=1
  for _,f in ipairs(e.Fruits)do
   if f.Visible and f.Pixels>=((e.Record.PlanSelected and e.Record.PlanSelected[f.Index])and 14 or 18) and used+cost+f.Cost<=partBudget then chosen[f.Index]=true;cost+=f.Cost end
  end
  if next(chosen)then e.Selected=chosen;e.DetailMode='fruit';e.Cost=cost;used+=cost;count+=1 end
 end
 for _,e in ipairs(entries)do e.Record.PlanMode=e.DetailMode;e.Record.PlanSelected=e.Selected end
 return used,count
end
return P
