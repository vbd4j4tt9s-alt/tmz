-- R153 (owner: "fix all jittery type effects"): a client anchor that follows a keeper's SMOOTHED body frame (KeeperMotion), for signs over keepers
-- (KeeperSpeedLabels). The server moves a keeper's anchored root in packet steps (irregular, no engine interpolation) and the body is drawn from
-- KeeperMotion's prediction, so a BillboardGui on the raw root stepped with the packets while the body glided. The keeper's animator (BeastAnimation;
-- VeiledEventClient81 for The Darkened) moves the anchor in its own RenderStepped batch with the body: the sign and the body move together.
-- One small invisible part per animated keeper (no collision / query / touch / shadow), written only when the body frame changed.
local F={}
local anchors=setmetatable({},{__mode='k'}) -- [keeper model] = {Part=, Placed=}
local listeners={}
local folder
local function home()
 if folder and folder.Parent then return folder end
 folder=Instance.new('Folder');folder.Name='_KeeperFollow153';folder.Parent=workspace;return folder
end
local function tell(model,part)for _,fn in ipairs(table.clone(listeners))do pcall(fn,model,part)end end
-- The animator: this keeper's body is drawn from its smoothed frame from now on (frame: where it is now). Returns the anchor.
function F.Drive(model,frame)
 local a=anchors[model]
 if a and a.Part.Parent then return a.Part end
 local p=Instance.new('Part');p.Name='KeeperFollow';p.Size=Vector3.new(.2,.2,.2);p.Transparency=1;p.Anchored=true
 p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.CFrame=frame;p.Parent=home()
 anchors[model]={Part=p,Placed=frame}
 tell(model,p);return p
end
-- The animator lets go (the keeper left, or is no longer animated here): a sign goes back to the root.
function F.Release(model)
 local a=anchors[model];if not a then return end
 anchors[model]=nil;a.Part:Destroy();tell(model,nil)
end
-- The anchor of an animated keeper, or nil (then the root is the right thing to follow).
function F.Get(model)local a=anchors[model];return a and a.Part.Parent and a.Part or nil end
-- Joins the animator's BulkMoveTo batch: the anchor goes to this frame's body frame.
function F.Push(model,frame,parts,frames)
 local a=anchors[model];if not a or a.Placed==frame then return end
 a.Placed=frame;parts[#parts+1]=a.Part;frames[#frames+1]=frame
end
-- fn(model, anchor or nil) when a keeper starts / stops being animated. Returns a function that stops listening.
function F.Listen(fn)
 listeners[#listeners+1]=fn
 return function()local i=table.find(listeners,fn);if i then table.remove(listeners,i)end end
end
return F
