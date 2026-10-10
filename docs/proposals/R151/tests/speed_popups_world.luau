--!nocheck
-- R151 speed popups test world: the R123 mock world (real modules from rs_bundle) plus what the REAL SpeedGainPopup.client.lua needs - Players with a local
-- player, the SpeedGainPopup / StopTreadmillTraining remotes, JumpRequest - and counters for what the popups must NOT do (tweens, scheduled work,
-- Instances created or destroyed after the pool exists).
-- PW.boot(opts) -> ctx: Me (local player), PG (its PlayerGui), Remote (SpeedGainPopup), Stop (StopTreadmillTraining), Script, Style (the real SpeedPopupStyle),
-- ctx.fire(player, amount, ticks, interval, character), PW.newPlayer / spawnCharacter / leave, frame readers and listener counts.
local W=require('./world');local R=W.R
local V3=R.Vector3.new
local PW={W=W,R=R}
PW.tweens=0;PW.scheduled=0;PW.destroyed=0;PW.stops=0;PW.Tier=3
do
 local Tween=W.service('TweenService');local create=Tween.Create
 function Tween.Create(...)PW.tweens+=1;return create(...)end
 local t=R.task;local d,df,sp=t.delay,t.defer,t.spawn
 t.delay=function(...)PW.scheduled+=1;return d(...)end
 t.defer=function(...)PW.scheduled+=1;return df(...)end
 t.spawn=function(...)PW.scheduled+=1;return sp(...)end
 local destroy=R.Inst.Destroy
 R.Inst.Destroy=function(self)if not self._destroyed then PW.destroyed+=1 end;return destroy(self)end
end
local Players=W.service('Players');Players.PlayerRemoving=R.signal();Players.PlayerAdded=R.signal()
W.UIS.JumpRequest=R.signal()
function PW.spawnCharacter(p,pos)
 local old=p.Character
 local char=R.new('Model');char.Name=p.Name;char.Parent=W.workspace
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=pos;root.Parent=char
 local head=R.new('Part');head.Name='Head';head.Position=pos+V3(0,1.5,0);head.Parent=char
 p.Character=char
 if old then old:Destroy()end
 return char,head,root
end
function PW.newPlayer(name,opts)
 opts=opts or{}
 local p=R.new('Player');p.Name=name;p.UserId=opts.Id or(#Players:GetChildren()+1);p.Parent=Players
 if opts.Local then Players.LocalPlayer=p;local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=p end
 PW.spawnCharacter(p,opts.Pos or V3(0,3,0))
 if opts.Training~=false then p:SetAttribute('TreadmillTraining',true)end
 return p
end
function PW.leave(p)Players.PlayerRemoving:Fire(p);p.Parent=nil end
function PW.view(height)W.workspace.CurrentCamera.ViewportSize=R.Vector2.new(height*16/9,height)end
-- R155: the popup field scales with the camera's distance to the head (SpeedPopupStyle.Zoom), so a test says where its camera is. PW.camera(d) puts it d studs from the head of a character
-- spawned at y = 3 (the head is at 4.5, straight behind it); the default is the game's default camera zoom, 12.5 studs, where the popups are exactly their R154 size. PW.boot starts there.
PW.ZoomDistance=12.5
function PW.camera(d)W.workspace.CurrentCamera.CFrame=R.CFrame.new(0,4.5,-(d or PW.ZoomDistance))end
function PW.frames(n,dt)W.frames(n,dt or 1/60)end
function PW.seconds(s,dt)dt=dt or 1/60;W.frames(math.floor(s/dt+.5),dt)end
function PW.live(signal)local n=0;for _,c in ipairs(signal._c)do if c.Connected then n+=1 end end;return n end
function PW.frameListeners()local Run=W.Run;return PW.live(Run.RenderStepped)+PW.live(Run.Heartbeat)+PW.live(Run.Stepped)+PW.live(Run.PreSimulation)+PW.live(Run.PostSimulation)end
-- readers ------------------------------------------------------------------------------------------------------------------------------------------
function PW.fields(pg)local out={};for _,c in ipairs(pg:GetChildren())do if c.Name=='SpeedGainField'then out[#out+1]=c end end;return out end
function PW.host(field)return field:FindFirstChild('Zoom')or field end -- (R155: the popup frames live in the field's 'Zoom' container, whose UIScale is the camera-distance scale)
function PW.frameList(field)local out={};for _,f in ipairs(PW.host(field):GetChildren())do if f.Name=='Popup'then out[#out+1]=f end end;return out end
function PW.visible(field)local out={};for _,f in ipairs(PW.host(field):GetChildren())do if f.Name=='Popup'and f.Visible then out[#out+1]=f end end;return out end
function PW.visibleAll(pg)local n=0;for _,field in ipairs(PW.fields(pg))do n+=#PW.visible(field)end;return n end
function PW.enabledFields(pg)local n=0;for _,field in ipairs(PW.fields(pg))do if field.Enabled then n+=1 end end;return n end
function PW.fieldOf(pg,head)for _,field in ipairs(PW.fields(pg))do if field.Enabled and(field.Adornee==head or head and field.Adornee==head.Parent:FindFirstChild('HumanoidRootPart'))then return field end end;return nil end -- (R153: on the root at the head's height)
function PW.read(frame)
 local sc=frame:FindFirstChildOfClass('UIScale')
 return {X=frame.Position.X.Offset,Y=frame.Position.Y.Offset,Scale=sc.Scale,Text=frame.Amount.Text,Alpha=1-frame.Amount.TextTransparency,IconAlpha=1-frame.Lightning.TextTransparency,
  StrokeAlpha=1-frame.Amount.BoldOutline86.Transparency,ZIndex=frame.ZIndex,IconRot=frame.Lightning.Rotation,TextRot=frame.Amount.Rotation}
end
function PW.count(root)local n=0;for _,d in ipairs(root:GetDescendants())do if not d._destroyed then n+=1 end end;return n end
-- boot -------------------------------------------------------------------------------------------------------------------------------------------------
function PW.boot(opts)
 opts=opts or{}
 PW.Tier=opts.tier or 3
 if opts.view then PW.view(opts.view)else PW.view(1080)end
 PW.camera() -- (R155: at the default zoom)
 local me=PW.newPlayer('Me',{Local=true,Id=1,Pos=V3(0,3,0)})
 local pg=me:FindFirstChild('PlayerGui')
 W.stub('ClientFxBudget',{Get=function()return PW.Tier end})
 local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 local popup=R.new('RemoteEvent');popup.Name='SpeedGainPopup';popup.OnClientEvent=R.signal();popup.Parent=remotes
 local stop=R.new('RemoteEvent');stop.Name='StopTreadmillTraining';function stop.FireServer()PW.stops+=1 end;stop.Parent=remotes
 local ctx={Me=me,PG=pg,Remote=popup,Stop=stop,Style=W.module('SpeedPopupStyle')}
 function ctx.fire(player,amount,ticks,interval,character)popup.OnClientEvent:Fire(player,amount,0,ticks,interval,character)end
 if opts.beforeLoad then opts.beforeLoad(ctx)end
 local script=R.new('LocalScript');script.Name='SpeedGainPopup';ctx.Script=script
 W.load('SpeedGainPopup',script)
 return ctx
end
return PW
