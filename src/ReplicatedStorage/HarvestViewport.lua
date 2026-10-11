-- Visible previews share one bounded build queue. Rotation moves cameras, not mesh parts.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local H=require(RS:WaitForChild('HarvestPresentation'));local Geometry=require(RS:WaitForChild('HarvestGeometry'))
local V={};local entries={};local connection;local job;local clock=0
local function cancel()
 if not job then return end
 if coroutine.status(job.Thread)~='dead'then coroutine.close(job.Thread)end
 for _,m in ipairs(job.Models)do if not m.Parent then m:Destroy()end end;job=nil
end
local function step(dt)
 clock+=dt
 if job and(job.Entry.Dead or not H.Visible(job.Entry.View))then cancel()end
 if not job then for _,e in ipairs(entries)do if not e.Model and not e.Dead and os.clock()>=(e.Retry or 0)and H.Visible(e.View)then
  local j={Entry=e,Models={}};local work={Model=function(m)table.insert(j.Models,m)end}
  work.BeforePart=function(cost)if j.Parts<cost or os.clock()>j.Deadline then coroutine.yield()end;j.Parts-=cost end
  j.Thread=coroutine.create(function()
   local model,crop,index=H.Build(e.Item,{Work=work});if e.Dead then model:Destroy();return end
   local world=Instance.new('WorldModel');world.Parent=e.View;model.Parent=world
   local center,size=Geometry.Bounds(model);local camera=Instance.new('Camera');camera.FieldOfView=36;camera.Parent=e.View;e.View.CurrentCamera=camera
   e.Center=center;e.Radius=math.max(size.Magnitude/2,.3);e.Camera=camera;e.Model=model;e.Cleanup=H.Register(e.View,model,crop,index)
  end);job=j;break
 end end end
 if job then
  job.Parts=16;job.Deadline=os.clock()+.001;local okay,why=coroutine.resume(job.Thread)
  if not okay then job.Entry.Retry=os.clock()+5;warn('[V149] Sell preview: '..tostring(why));cancel()
  elseif coroutine.status(job.Thread)=='dead'then job=nil end
 end
 if clock<.05 then return end;clock=0
 local angle=os.clock()*.35;local sine,cosine=math.sin(angle),math.cos(angle)
 for _,e in ipairs(entries)do if e.Camera and H.Visible(e.View)then
  local size=e.View.AbsoluteSize
  if e.Width~=size.X or e.Height~=size.Y then
   e.Width=size.X;e.Height=size.Y;local aspect=math.max(.3,size.X/math.max(1,size.Y))
   e.Distance=e.Radius/math.sin(math.atan(math.tan(math.rad(18))*math.min(1,aspect)))*1.1
  end
  local distance=e.Distance;e.Camera.CFrame=CFrame.lookAt(e.Center+Vector3.new(sine*distance,distance*.22,cosine*distance),e.Center)
 end end
end
function V.Attach(view,item)
 local e={View=view,Item=item};table.insert(entries,e);local destroy
 local function cleanup()
  if e.Dead then return end;e.Dead=true;if destroy then destroy:Disconnect()end
  if job and job.Entry==e then cancel()end
  if e.Cleanup then e.Cleanup()end
  local at=table.find(entries,e);if at then table.remove(entries,at)end
  if #entries==0 and connection then connection:Disconnect();connection=nil end
 end
 destroy=view.Destroying:Connect(cleanup)
 if not connection then connection=Run.RenderStepped:Connect(step)end -- (R153: the camera's orbit with the drawn frame; was Heartbeat)
 return cleanup
end
return V
