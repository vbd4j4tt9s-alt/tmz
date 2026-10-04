-- Shared bounded grid and actor-set occupancy. No Roblox services or touch events.
local K={Pitch=3.2,Height=1.368114709854126,RestTop=1.15,DownTop=.05,
 NearRadius=76,FarRadius=150,MaxCaps=3800,MaxNear=2200,MaxFar=1600,CreatePerFrame=64,
 Tick=.05,MaxSweep=48,MaxSweepSamples=16,MaxRadius=6}
function K.grid(x,z)
 local nx,nz=math.ceil(x/K.Pitch),math.ceil(z/K.Pitch)
 return {NX=nx,NZ=nz,DX=x/nx,DZ=z/nz,X=x,Z=z}
end
function K.center(g,x,z)return -g.X/2+(x-.5)*g.DX,-g.Z/2+(z-.5)*g.DZ end
function K.bounds(g,x,z,span)
 span=span or 1
 local width=math.min(span,g.NX-x+1)*g.DX;local depth=math.min(span,g.NZ-z+1)*g.DZ
 return -g.X/2+(x-1)*g.DX+width/2,-g.Z/2+(z-1)*g.DZ+depth/2,width-.14,depth-.14
end
function K.cells(g,x,z,rx,rz,visit)
 rx=math.clamp(rx or 2,0,K.MaxRadius);rz=math.clamp(rz or rx,0,K.MaxRadius)
 if x+rx < -g.X/2 or x-rx>g.X/2 or z+rz < -g.Z/2 or z-rz>g.Z/2 then return end
 local a=math.clamp(math.floor((x-rx+g.X/2)/g.DX)+1,1,g.NX)
 local b=math.clamp(math.floor((x+rx+g.X/2)/g.DX)+1,1,g.NX)
 local c=math.clamp(math.floor((z-rz+g.Z/2)/g.DZ)+1,1,g.NZ)
 local d=math.clamp(math.floor((z+rz+g.Z/2)/g.DZ)+1,1,g.NZ)
 for ix=a,b do for iz=c,d do visit(ix,iz)end end
end
function K.id(s,x,z)return s..':'..x..':'..z end
function K.sweep(a,b,visit)
 local dx,dz=b.X-a.X,b.Z-a.Z;local distance=math.sqrt(dx*dx+dz*dz)
 if distance<.01 or distance>K.MaxSweep or math.abs(b.Y-a.Y)>.8 then return end
 local n=math.min(K.MaxSweepSamples,math.ceil(distance/(K.Pitch*.7)))
 for i=1,n-1 do local t=i/n;visit({X=a.X+dx*t,Y=a.Y+(b.Y-a.Y)*t,Z=a.Z+dz*t,RX=b.RX,RZ=b.RZ})end
end
function K.new()return {Actors={},Counts={},Sequence=0}end
-- contacts: {[actor identity] = {[key identity]=true}}. Several body contacts count once.
function K.replace(state,contacts)
 local counts={}
 for _,keys in pairs(contacts)do for id in pairs(keys)do counts[id]=(counts[id]or 0)+1 end end
 local changes={}
 for id in pairs(state.Counts)do if not counts[id]then changes[#changes+1]={id,false}end end
 for id in pairs(counts)do if not state.Counts[id]then changes[#changes+1]={id,true}end end
 state.Actors,state.Counts=contacts,counts
 if #changes>0 then state.Sequence+=1 end
 return changes,state.Sequence
end
function K.snapshot(state)
 local keys={};for id in pairs(state.Counts)do keys[#keys+1]=id end;table.sort(keys);return keys,state.Sequence
end
function K.packet(view,kind,seq,entries)
 if type(seq)~='number'or seq<view.Sequence or(kind=='Delta'and seq<=view.Sequence)then return false end
 if kind=='Snapshot'then view.Held={};for _,id in ipairs(entries)do view.Held[id]=true end
 elseif kind=='Delta'then for _,e in ipairs(entries)do view.Held[e[1]]=e[2]or nil end
 else return false end
 view.Sequence=seq;return true
end
-- Constant target integration; a release immediately changes direction when occupied again.
function K.animate(current,down,dt)
 local target=down and 1 or 0
 if current==target then return target end
 local rate=down and 30 or 18
 local nextValue=current+(target-current)*(1-math.exp(-math.clamp(dt,0,.1)*rate))
 if math.abs(nextValue-target)<.001 then return target end;return nextValue
end
return K
