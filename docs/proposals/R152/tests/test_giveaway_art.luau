--!nocheck
-- R152 Void Pack giveaway: the pedestal as the server builds it (VoidGiveawayArt152 through the real VoidGiveaway152 service) on the Roblox mock:
--  * where: the plaza centre (X 0, Z -392), on the plaza (lobby floor top 4 + the plaza's .26), well inside the plaza's 21-stud radius and clear of the benches round it;
--  * what: about 32 parts (a phone-friendly count), all anchored, the stone solid and the glow / beam / anchors not, nothing that touches, four plaques on four faces with the
--    lettering outward, an invisible anchor each for the pack, the sign and the prompt, one violet light, one prompt ("Claim FREE Void Pack");
--  * how it looks: Void colours (obsidian / dark purple stone, violet neon), the Fruit of the Hour's format (plinth, column, capital, cradle with four prongs, projector beam, lettering,
--    no discs or rings), the beam stops under the pack (nothing behind it), the sign hangs clear above the pack at its highest;
--  * state: Loading / Open / Empty (the lettering, the light and the prompt), nothing changes the part count, streaming Persistent, tagged, no scripts.
local G=require('./giveaway_harness');local H,W,R=G.H,G.W,G.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=G.Rules;local Art=H.server('VoidGiveawayArt152')
local b=G.backend();local s=G.server(b,nil,{FreshMap=true,Name='A'});s.Svc:Start()
local ped=s.Svc.Pedestal;local m=ped.Model
local function parts(prefix)local out={};for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')and(prefix==nil or d.Name:sub(1,#prefix)==prefix)then out[#out+1]=d end end;return out end
local all=parts()
local TOP=4.26

-- where
local footing=parts('Void footing')[1]
check(m.Parent==s.Root and m.Name=='VoidGiveaway152','the model "VoidGiveaway152" is in the map root (not under EconomyHub, whose parts are made walk-through)')
check(math.abs(footing.Position.X-0)<1e-6 and math.abs(footing.Position.Z+392)<1e-6,'centred on X 0 / Z -392: the middle of the plaza')
check(math.abs((footing.Position.Y-footing.Size.Y/2)-4.0)<1e-6,'the footing\'s foot is on the lobby floor (top y 4), sunk into the plaza\'s .26')
check(math.abs(ped.PackAnchor.Position.Y-(TOP+Rules.PackHeight))<1e-6,'the pack hovers '..Rules.PackHeight..' studs over the plaza top (4.26)')
local far=0;for _,p in ipairs(all)do local d=math.sqrt(p.Position.X^2+(p.Position.Z+392)^2)+math.max(p.Size.X,p.Size.Z)/2;far=math.max(far,d)end
check(far<13,'everything is inside 13 studs of the centre (the plaza is 21): the corner of the footing reaches '..string.format('%.1f',far))
check(12.4*math.sqrt(2)-far>4,'clear of the benches that stood round the old fountain (17.5 studs out) by '..string.format('%.1f',12.4*math.sqrt(2)-far))

-- what
check(#all>=24 and #all<=40,'a phone-friendly part count: '..#all)
local solid,glow,bad={}, {},0
for _,p in ipairs(all)do
 if not p.Anchored then bad+=1 end
 if p.CanTouch then bad+=1 end
 if p.CanCollide then solid[#solid+1]=p.Name else glow[#glow+1]=p.Name end
 if p.CanCollide~=p.CanQuery then bad+=1 end
end
check(bad==0,'every part is anchored, CanTouch off, and CanQuery follows CanCollide')
local names={};for _,n in ipairs(solid)do names[n]=(names[n]or 0)+1 end
check(names['Void footing']==1 and names['Void plinth']==1 and names['Void column']==1 and names['Void capital']==1 and names['Capital top']==1 and names['Corner pylon']==4,'the stone is solid: footing, plinth, column, capital, capital top, four pylons')
check(#solid==9,'and nothing else is ('..#solid..' solid parts)')
for _,n in ipairs({'Footing trim','Plinth stud','Column band','Cradle glow','Cradle prong','Projector beam','Pylon cap','Column plaque','PackAnchor','SignAnchor','PromptAnchor'})do
 local ps=parts(n);local ok=#ps>0;for _,p in ipairs(ps)do if p.CanCollide then ok=false end end
 check(ok,n..' exists and is not solid')
end
for _,n in ipairs({'PackAnchor','SignAnchor','PromptAnchor'})do local p=parts(n)[1];check(p.Transparency==1 and p.Size.X<=.5,n..' is an invisible .5 stud anchor')end
check(#parts('Cradle prong')==4 and #parts('Plinth stud')==4 and #parts('Column plaque')==4 and #parts('Pylon cap')==4,'four prongs, studs, plaques, pylon caps')
check(not parts('Projector beam')[1].CanCollide and parts('Projector beam')[1].Transparency>.8 and parts('Projector beam')[1].Material==R.Enum.Material.Neon,'the projector beam is a faint neon column')
-- no discs or rings (the owner: "remove the discs"): the only cylinder is the beam; no part behind the pack
local cyl=0;for _,p in ipairs(all)do if p.Shape==R.Enum.PartType.Cylinder then cyl+=1 end end
check(cyl==1,'no discs or rings: the beam is the only cylinder')
local beam=parts('Projector beam')[1];local beamTop=beam.Position.Y+beam.Size.X/2
check(beamTop<ped.PackAnchor.Position.Y-Rules.PackSize/2+.01,'the beam stops under the pack ('..string.format('%.1f',beamTop)..' < '..string.format('%.1f',ped.PackAnchor.Position.Y-Rules.PackSize/2)..'): nothing sits behind the pack')
local behind=0;for _,p in ipairs(all)do
 local lo,hi=p.Position.Y-p.Size.Y/2,p.Position.Y+p.Size.Y/2
 if p.Transparency<1 and hi>ped.PackAnchor.Position.Y-Rules.PackSize/2-.3 and lo<ped.PackAnchor.Position.Y+Rules.PackSize/2+Rules.PackBob and p.Name~='PackAnchor'then behind+=1 end
end
check(behind==0,'no visible part of the pedestal lies at the height of the pack (its glow and particles are the pack\'s own)')
check(parts('SignAnchor')[1].Position.Y-Rules.Sign.H/2>=ped.PackAnchor.Position.Y+Rules.PackSize/2+Rules.PackBob+Rules.SignGap-1e-6,'the sign\'s bottom edge hangs '..Rules.SignGap..' studs over the pack at its highest bob')
check(math.abs(parts('SignAnchor')[1].Position.X)<1e-6 and math.abs(parts('PackAnchor')[1].Position.X)<1e-6 and math.abs(parts('PackAnchor')[1].Position.Z+392)<1e-6,'anchors on the pedestal\'s axis')
-- plaques
local plaques=parts('Column plaque');local seen={}
for _,p in ipairs(plaques)do
 local out=V3(p.Position.X,0,p.Position.Z+392).Unit;local look=p.CFrame.LookVector
 check(look:Dot(out)>.99,'a plaque faces outward ('..string.format('%.0f,%.0f',look.X,look.Z)..')')
 seen[string.format('%d,%d',math.floor(out.X+.5),math.floor(out.Z+.5))]=true
 local gui=p:FindFirstChildWhichIsA('SurfaceGui');check(gui and gui.Face==R.Enum.NormalId.Front and gui:FindFirstChild('Line1').Text=='FREE VOID PACK','the plaque says FREE VOID PACK on its front')
end
local faces=0;for _ in pairs(seen)do faces+=1 end;check(faces==4,'the four faces of the column each carry one')
-- the prompt and the light
local prompt=ped.Prompt
check(prompt.ActionText=='Claim FREE Void Pack','the prompt: "Claim FREE Void Pack"')
check(prompt.HoldDuration>0 and prompt.HoldDuration<=1 and prompt.RequiresLineOfSight==false and prompt.MaxActivationDistance>=12 and prompt.MaxActivationDistance<=24,'a short hold, no line of sight needed, reachable from the footing\'s edge')
check(prompt.Parent==parts('PromptAnchor')[1],'the prompt hangs on its own anchor, in the column')
local lights={};for _,d in ipairs(m:GetDescendants())do if d:IsA('Light')then lights[#lights+1]=d end end
check(#lights==1 and lights[1].Parent==ped.PackAnchor and lights[1].Color.B>.9 and lights[1].Color.G<.5 and lights[1].Shadows==false,'one violet light on the pack anchor, no shadows')
local scripts=0;for _,d in ipairs(m:GetDescendants())do if d:IsA('BaseScript')or d:IsA('Sound')then scripts+=1 end end
check(scripts==0,'no scripts, no sounds')
-- how it looks
local function lum(c)return .2126*c.R+.7152*c.G+.0722*c.B end
local stoneOk=true;for _,n in ipairs({'Void footing','Void plinth','Void column','Void capital','Corner pylon','Column plaque'})do for _,p in ipairs(parts(n))do if lum(p.Color)>.14 then stoneOk=false end end end
check(stoneOk,'obsidian / dark purple stone (every stone part is dark)')
local violet=true;for _,n in ipairs({'Cradle glow','Pylon cap','Plinth stud'})do for _,p in ipairs(parts(n))do local c=p.Color;if not(p.Material==R.Enum.Material.Neon and c.B>c.R and c.R>c.G and c.B>.9)then violet=false end end end
check(violet,'the glow parts are violet neon')
local purple=true;for _,n in ipairs({'Void column','Footing trim','Capital top','Column band','Cradle prong'})do for _,p in ipairs(parts(n))do local c=p.Color;if not(c.B>c.G and c.R>=c.G*.99)then purple=false end end end
check(purple,'the trims and the column are purple (blue over green)')
-- the Fruit of the Hour's format: plinth, column, capital, cradle glow, four prongs, beam, lettering
local fruit=H.server('MarketLayout');check(fruit.Pedestal~=nil,'(the market\'s Fruit of the Hour pedestal exists to be styled after)')
-- heights are one stack: each stone layer rests on the one under it
local function top(n)local p=parts(n)[1];return p.Position.Y+p.Size.Y/2 end
local function bottom(n)local p=parts(n)[1];return p.Position.Y-p.Size.Y/2 end
check(math.abs(bottom('Footing trim')-top('Void footing'))<1e-6 and math.abs(bottom('Void plinth')-top('Footing trim'))<1e-6 and math.abs(bottom('Void column')-top('Void plinth'))<1e-6
 and math.abs(bottom('Void capital')-top('Void column'))<1e-6 and math.abs(bottom('Capital top')-top('Void capital'))<1e-6 and math.abs(bottom('Cradle glow')-top('Capital top'))<1e-6,'footing, trim, plinth, column, capital, capital top, glow: each rests exactly on the one below')
check(top('Cradle glow')<ped.PackAnchor.Position.Y-Rules.PackSize/2,'the pack floats above the cradle')

-- state
local function snapshot()local t={};for i,p in ipairs(all)do t[i]=string.format('%s %.3f %.3f %.3f %.3f',p.Name,p.Position.X,p.Position.Y,p.Position.Z,p.Transparency)end;return table.concat(t,'|')end
local before=snapshot()
check(m:GetAttribute('State')=='Loading'or m:GetAttribute('State')=='Open','the model starts Loading and is Open once the first read is in ('..tostring(m:GetAttribute('State'))..')')
check(m:GetAttribute('Cap')==500 and m:GetAttribute('VoidGiveaway152')==152,'Cap 500 and the version attribute')
check(m.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent,'Persistent streaming (the place uses StreamingEnabled: the prompt and the number must always be there)')
check(W.CS:HasTag(m,'VoidGiveaway152')and W.CS:HasTag(m,'SnowAvoid'),'tagged VoidGiveaway152 (the client finds it) and SnowAvoid (the blizzard drifts keep off it)')
local light=ped.Light.Brightness
s.Svc:_force(500);check(ped.Plaques[1].Text=='ALL CLAIMED'and ped.Plaques[4].Text=='ALL CLAIMED'and ped.Prompt.Enabled==false and ped.Light.Brightness<light,'at 0: ALL CLAIMED on every plaque, the prompt off, the light dimmer')
check(snapshot()==before,'and no part moved, appeared or changed transparency')
s.Svc:_force(13);check(ped.Plaques[1].Text=='FREE VOID PACK'and ped.Prompt.Enabled==true and ped.Light.Brightness==light,'487 left: the title and the light are back (a Studio reset)')
-- built again (a second Start / a rebuild) it replaces the old one
local again=Art.Build(s.Root,TOP);local n=0;for _,c in ipairs(s.Root:GetChildren())do if c.Name=='VoidGiveaway152'then n+=1 end end;check(n==1 and again.Model~=m,'building again replaces the old pedestal (one model)')

print(string.format('giveaway art: %d checks, %d failed (%d parts)',checks,fails,#all))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
