-- R149 (owner: "for the melons and pumpkins bake the meshes in"): the Watermelon, Snow Melon and Ember Pumpkin each get ONE baked,
-- vertex-coloured mesh body (like the cocoa pod / Fire Pepper) in place of their 8 - 21 part-built body pieces; stem, tendril / curl,
-- leaf stay parts (R151: the white gloss patch on them is gone). The meshes are generated here (parametric lathes: no vertex data is shipped), baked once per
-- server with the same EditableMesh -> MeshPart route as ApprovedPlantMeshes (which is not touched), and kept in
-- ReplicatedStorage.FruitMeshTemplates149 with a white-vertex `_Neutral` twin for Gold / Diamond coats. Clients only clone.
-- PlantVisuals asks Art / Suffix which build a seed uses and routes these keys' Get / Status here (DetailReady keeps the server
-- silhouette while a template is still loading). If a bake fails, or the server never started baking (no folder), the seed keeps
-- its R149 part-built fruit; a failure is logged once.
-- R158d (owner: the Holo Melon uses the updated melon and pumpkin meshes): two more keys, HoloMelon158 and HoloPumpkin158, are the Watermelon's and the Ember Pumpkin's
-- mesh again (the same vertices, normals and triangles: a test pins it) with their vertex colours turned into brightness for the Mech hologram (HologramForms tints the part
-- cyan / violet and draws it in Neon, so the stripes and the pumpkin's grooves show as brighter and dimmer bands). They are baked, kept and failed exactly like the other keys
-- (a `_Neutral` twin for the Gold / Diamond coats). UsesMesh / Suffix also answer for the Holo Melon seed (both keys must be Ready; if one fails it keeps its wire form).
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local M={Folder='FruitMeshTemplates149'}
-- seed -> its mesh key, the fruit specs the mesh replaces, the spec whose frame (and, unless Fit='all', size) it takes, the body's name,
-- its main colour (a plain ellipsoid in that colour stands in on the server if a bake fails mid-build).
-- UnripeNeutral (R149 review part 2, finding 7): the vertex colours are far from green (orange), and a tint can only darken them, so the growing fruit
-- would stay a dark orange. PlantGrowth.Capture gives every such fruit a temporary twin cloned from the white `_Neutral` template: while the fruit is unripe
-- the twin is drawn in the same pale-green-to-ripe colour path as every other fruit (Tone is its ripe colour) and the baked body is hidden; at the ripe
-- moment (the real material switches on) the body shows and the twin hides; EndGrowth destroys the twin. The melons (green vertex colours) keep the tint.
M.Seeds={
 SunflowerSeed={Key='Watermelon149',Name='Melon body',Body='Melon rind',Replace={'Melon rind','Melon stripe band'},Tone={108,180,76}},
 SnowdropSeed={Key='SnowMelon149',Name='Snow melon body',Body='Snow melon rind',Replace={'Snow melon rind','Snow melon stripe band','Snow cap'},Tone={190,232,234}},
 EmberBloomSeed={Key='EmberPumpkin149',Name='Pumpkin body',Body='Pumpkin heart',Replace={'Pumpkin heart','Pumpkin rib','Ember groove'},Fit='all',Tone={232,108,28},UnripeNeutral=true},
}
M.Keys={'EmberPumpkin149','HoloMelon158','HoloPumpkin158','SnowMelon149','Watermelon149'}
-- seed -> its hologram keys (not a plant that draws its own fruit body from them: HologramForms builds the Mech fruit)
M.Holo={HoloMelonSeed={'HoloMelon158','HoloPumpkin158'}}
local owned={};for _,k in ipairs(M.Keys)do owned[k]=true end
function M.Owns(key)return owned[key]==true end
local byKey={};for _,cfg in pairs(M.Seeds)do byKey[cfg.Key]=cfg end
-- The config of a mesh key (the coloured template, not its `_Neutral` twin) whose growing fruit is drawn from the neutral twin (PlantGrowth.Capture), or nil.
function M.UnripeNeutral(key)local cfg=byKey[key];if cfg and cfg.UnripeNeutral then return cfg end;return nil end

-- 1. The meshes ------------------------------------------------------------------------------------------------------------------
local pi,sin,cos,abs,exp=math.pi,math.sin,math.cos,math.abs,math.exp
local function smooth(a,b,x)local t=math.clamp((x-a)/(b-a),0,1);return t*t*(3-2*t)end
local function mix(a,b,t)return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}end
-- A lathe: pole, R-1 rings of S vertices, pole. shape(u,th) -> axial, radius (u 0..1 pole to pole); colour(u,th) -> 0-255 RGB.
-- axis 'X': along X, th=0 points down (-Y); axis 'Y': along Y, u=0 on top. Every axis is normalised to -0.5..0.5 (the spec's size
-- scales it), faces wind outward and normals are area-weighted in that unit box, exactly like ApprovedPlantMeshData.
local function lathe(R,S,axis,shape,colour)
 local P,C={},{}
 local function add(u,th)
  local a,r=shape(u,th);local c,s=cos(th),sin(th)
  P[#P+1]=axis=='X'and{a,-r*c,r*s}or{r*c,a,r*s};local k=colour(u,th);C[#C+1]={k[1]/255,k[2]/255,k[3]/255}
 end
 add(0,0);for i=1,R-1 do for j=0,S-1 do add(i/R,2*pi*j/S)end end;add(1,0)
 local F={};local last=#P
 local function at(i,j)return 2+(i-1)*S+j%S end
 for j=0,S-1 do F[#F+1]={1,at(1,j+1),at(1,j)}end
 for i=1,R-2 do for j=0,S-1 do
  local a,b,c,d=at(i,j),at(i,j+1),at(i+1,j),at(i+1,j+1);F[#F+1]={a,b,d};F[#F+1]={a,d,c}
 end end
 for j=0,S-1 do F[#F+1]={last,at(R-1,j),at(R-1,j+1)}end
 for k=1,3 do
  local lo,hi=math.huge,-math.huge;for _,p in ipairs(P)do lo=math.min(lo,p[k]);hi=math.max(hi,p[k])end
  for _,p in ipairs(P)do p[k]=(p[k]-(lo+hi)/2)/(hi-lo)end
 end
 local N={};for i=1,#P do N[i]={0,0,0}end
 local outward=0
 for _,f in ipairs(F)do
  local p,q,r=P[f[1]],P[f[2]],P[f[3]]
  local ux,uy,uz=q[1]-p[1],q[2]-p[2],q[3]-p[3];local wx,wy,wz=r[1]-p[1],r[2]-p[2],r[3]-p[3]
  local nx,ny,nz=uy*wz-uz*wy,uz*wx-ux*wz,ux*wy-uy*wx
  outward+=nx*(p[1]+q[1]+r[1])+ny*(p[2]+q[2]+r[2])+nz*(p[3]+q[3]+r[3])
  for _,v in ipairs(f)do local n=N[v];n[1]+=nx;n[2]+=ny;n[3]+=nz end
 end
 local flip=outward<0 and -1 or 1
 if flip<0 then for _,f in ipairs(F)do f[2],f[3]=f[3],f[2]end end
 for _,n in ipairs(N)do local m=math.sqrt(n[1]^2+n[2]^2+n[3]^2);if m<1e-12 then m=1 end;n[1]*=flip/m;n[2]*=flip/m;n[3]*=flip/m end
 return {Vertices=P,Normals=N,Colors=C,Faces=F}
end
-- Melons: a slightly blunt oblong lying along X (stem end +X), 8 dark stripes standing a hair proud, a pale
-- ground spot underneath, darker ends. 32 x 9: 258 vertices, 512 triangles.
local function stripe(u,th)return smooth(-.3,.3,sin(8*th+pi/4))end -- two dark, two light vertices per stripe: clean edges
local function melonShape(u,th)
 local phi=pi*u;return 1.25*cos(phi),sin(phi)^.9*(1+.02*stripe(u,th))
end
local function ground(u,th)local d=math.atan2(sin(th),cos(th));return exp(-(d*d/.42+(u-.52)^2/.07))end
local PAL={
 Watermelon149={Light={112,184,78},Dark={30,94,44},Spot={226,214,140},Ends={58,112,46}},
 SnowMelon149={Light={196,236,238},Dark={56,124,156},Spot={222,240,246},Ends={120,170,188},Frost={250,254,255}},
}
local function melonColour(key)
 local c=PAL[key]
 return function(u,th)
  local k=mix(c.Light,c.Dark,stripe(u,th))
  k=mix(k,c.Spot,.85*ground(u,th))
  k=mix(k,c.Ends,.55*abs(cos(pi*u))^7)
  if c.Frost then k=mix(k,c.Frost,.62*smooth(.5,.88,-cos(th)*sin(pi*u)^.5+.08*sin(5*th+3*u)))end -- the snow cap, baked in
  return k
 end
end
-- Ember Pumpkin: squat, 10 lobes, sunken top and bottom, ember-lit grooves, a dark heart round the stem, lighter underside.
-- 40 x 7: 242 vertices, 480 triangles.
local function lobe(th)return abs(cos(5*th))^.6 end
local function pumpkinShape(u,th)
 local phi=pi*u;local s=sin(phi)
 return .64*cos(phi)-(cos(phi)>0 and .09 or -.15)*exp(-(s/.34)^2),s^.72*(.82+.18*lobe(th))
end
local function pumpkinColour(u,th)
 local g=1-lobe(th);local phi=pi*u
 local k=mix({240,120,34},{208,82,20},smooth(.15,.6,g))
 k=mix(k,{255,170,54},smooth(.62,.95,g)*smooth(.06,.3,sin(phi))) -- ember light in the grooves
 k=mix(k,{132,46,14},.82*smooth(.45,.92,cos(phi)))                -- the dark heart round the stem
 return mix(k,{246,146,62},.40*smooth(.35,1,-cos(phi)))             -- lighter underside
end
local BUILD={
 Watermelon149=function()return lathe(9,32,'X',melonShape,melonColour('Watermelon149'))end,
 SnowMelon149=function()return lathe(9,32,'X',melonShape,melonColour('SnowMelon149'))end,
 EmberPumpkin149=function()return lathe(7,40,'Y',pumpkinShape,pumpkinColour)end,
}
-- R158d: the Mech hologram's copy of a real fruit mesh: the same geometry, each vertex colour replaced by its brightness (0.3 .. 1, grey), so the part colour
-- (HologramForms: cyan / violet) is what shows and the real stripes / grooves / ground spot are its bright and dim bands.
local HOLO={HoloMelon158='Watermelon149',HoloPumpkin158='EmberPumpkin149'}
local function hologram(key)
 local d=BUILD[HOLO[key]]();local lo,hi,lum=math.huge,-math.huge,{}
 for i,c in ipairs(d.Colors)do local l=.2126*c[1]+.7152*c[2]+.0722*c[3];lum[i]=l;lo=math.min(lo,l);hi=math.max(hi,l)end
 for i in ipairs(d.Colors)do local g=.3+.7*((lum[i]-lo)/(hi-lo))^1.5;d.Colors[i]={g,g,g}end
 return d
end
for key in pairs(HOLO)do BUILD[key]=function()return hologram(key)end end
-- {Vertices, Normals, Colors (0..1), Faces (1-based)}: the ApprovedPlantMeshData format. Pure and deterministic.
function M.Generate(key)return assert(BUILD[key],'Unknown fruit mesh: '..tostring(key))()end

-- 2. Templates (server bakes, clients clone) -------------------------------------------------------------------------------------
local function folder()
 local f=RS:FindFirstChild(M.Folder)
 if not f and Run:IsServer()then f=Instance.new('Folder');f.Name=M.Folder;f:SetAttribute('Ready',false);f.Parent=RS end
 return f
end
if Run:IsServer()then folder()end -- the folder tells clients this server bakes fruit meshes
function M.Status(key,neutral)
 local name=neutral and key..'_Neutral'or key
 local f=RS:FindFirstChild(M.Folder);if not f then return 'Loading'end
 if f:FindFirstChild(name)then return 'Ready'end
 local errors=f:FindFirstChild('Failures');local value=errors and errors:FindFirstChild(name)
 if value then return 'Failed',value.Value end
 return 'Loading'
end
-- One template, not parented yet (Prepare parents a key's two templates together, so a client never sees one that is then dropped).
local function bake(key,neutral,data)
 local name=neutral and key..'_Neutral'or key
 local Assets=game:GetService('AssetService');local editable,part
 local ok,why=xpcall(function()
  editable=assert(Assets:CreateEditableMesh(),'Mesh memory unavailable while preparing '..name)
  local v,n,c={},{},{};local white=Color3.new(1,1,1)
  for i,p in ipairs(data.Vertices)do
   local q,k=data.Normals[i],data.Colors[i]
   v[i]=editable:AddVertex(Vector3.new(p[1],p[2],p[3]));n[i]=editable:AddNormal(Vector3.new(q[1],q[2],q[3]))
   c[i]=editable:AddColor(neutral and white or Color3.new(k[1],k[2],k[3]),1)
   if i%192==0 then task.wait()end
  end
  for i,t in ipairs(data.Faces)do
   local a,b,d=t[1],t[2],t[3];local face=editable:AddTriangle(v[a],v[b],v[d])
   editable:SetFaceNormals(face,{n[a],n[b],n[d]});editable:SetFaceColors(face,{c[a],c[b],c[d]})
   if i%256==0 then task.wait()end
  end
  local result,content=Assets:CreateDataModelContentAsync(Content.fromObject(editable))
  assert(result==Enum.CreateContentResult.Success,'Could not bake fruit mesh '..name..': '..tostring(result))
  part=Assets:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity.Hull,RenderFidelity=Enum.RenderFidelity.Precise})
  part.Name=name;part.Size=Vector3.one;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  part:SetAttribute('ApprovedMesh',name)
 end,debug.traceback)
 if editable then editable:Destroy()end
 if not ok then if part then part:Destroy()end;error(tostring(why),0)end
 return part
end
local preparing=false
-- Server: bakes every key (normal, then neutral; both parented together). A key that fails is marked Failed for both, so its seed goes
-- back to the part-built fruit everywhere. Safe to call more than once (later calls wait for the first).
function M.Prepare()
 assert(Run:IsServer(),'Fruit mesh preparation is server-only.')
 local f=folder()
 while preparing do task.wait()end
 if f:GetAttribute('PreparationFinished')then return f:GetAttribute('Ready')==true end
 preparing=true;local errors={};local started=os.clock()
 for _,key in ipairs(M.Keys)do
  local normal,neutral
  local ok,why=pcall(function()
   if f:FindFirstChild(key)and f:FindFirstChild(key..'_Neutral')then return end
   local data=M.Generate(key);normal=bake(key,false,data);neutral=bake(key,true,data)
  end)
  if ok and normal then normal.Parent=f;neutral.Parent=f
  elseif not ok then
   if normal then normal:Destroy()end
   table.insert(errors,key..': '..tostring(why))
   local list=f:FindFirstChild('Failures')or Instance.new('Folder');list.Name='Failures';list.Parent=f
   for _,name in ipairs({key,key..'_Neutral'})do
    local value=list:FindFirstChild(name)or Instance.new('StringValue');value.Name=name;value.Value='Could not prepare fruit mesh '..name..': '..tostring(why);value.Parent=list
   end
  end
  task.wait()
 end
 f:SetAttribute('BakeSeconds',os.clock()-started);f:SetAttribute('FailureCount',#errors);f:SetAttribute('PreparationFinished',true);f:SetAttribute('Ready',#errors==0)
 preparing=false
 if #errors>0 then warn('[R149 fruit meshes] '..#errors..' of '..#M.Keys..' fruit keep their part-built look. First failure: '..errors[1])end
 return #errors==0,errors
end
-- The template to clone. Server: bakes (or waits for the bake) first, and returns nil if it failed (PlantVisuals then draws a plain
-- ellipsoid for that one build; later builds use the part-built fruit). Client: errors while the template is still loading.
function M.Get(key,neutral)
 local name=neutral and key..'_Neutral'or key
 local f=RS:FindFirstChild(M.Folder);local part=f and f:FindFirstChild(name)
 if part then return part end
 if Run:IsServer()then M.Prepare();return folder():FindFirstChild(name)end
 error('Fruit mesh is still loading: '..name)
end

-- 3. Which build a seed uses ----------------------------------------------------------------------------------------------------
local final={}
-- true: the baked mesh body (Ready, or Loading: PlantVisuals.DetailReady keeps the silhouette meanwhile); false: the part-built fruit
-- (the bake failed, or this server never made the folder).
local function keysOf(id)local cfg=M.Seeds[id];if cfg then return {cfg.Key}end;return M.Holo[id]end
function M.UsesMesh(id)
 local keys=keysOf(id);if not keys then return false end
 local known=final[id];if known~=nil then return known end
 if not RS:FindFirstChild(M.Folder)then return false end
 local ready=true
 for _,key in ipairs(keys)do
  local a,b=M.Status(key),M.Status(key,true)
  if a=='Failed'or b=='Failed'then final[id]=false;return false end
  if not(a=='Ready'and b=='Ready')then ready=false end
 end
 if ready then final[id]=true end
 return true
end
-- Part of PlantVisuals' spec cache key, so a seed that falls back never reuses mesh-build specs (and the other way round).
function M.Suffix(id)if keysOf(id)==nil or M.UsesMesh(id)then return ''end;return '|parts' end
local derived=setmetatable({},{__mode='k'})
local function body(cfg,source,g,replace)
 local b;for _,s in ipairs(source)do if s.g==g and s.f==cfg.Body then b=s;break end end
 if not b then return nil end
 local at=CFrame.new(table.unpack(b.c));local size,centre=Vector3.new(b.z[1],b.z[2],b.z[3]),at.Position
 if cfg.Fit=='all'then
  local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
  for _,s in ipairs(source)do if s.g==g and replace[s.f]then
   -- each replaced piece is an ellipsoid: its exact extent along the body's axes
   local _,_,_,r00,r01,r02,r10,r11,r12,r20,r21,r22=at:ToObjectSpace(CFrame.new(table.unpack(s.c))):GetComponents()
   local p=at:PointToObjectSpace(Vector3.new(s.c[1],s.c[2],s.c[3]));local x,y,z=s.z[1]/2,s.z[2]/2,s.z[3]/2
   local e={math.sqrt((r00*x)^2+(r01*y)^2+(r02*z)^2),math.sqrt((r10*x)^2+(r11*y)^2+(r12*z)^2),math.sqrt((r20*x)^2+(r21*y)^2+(r22*z)^2)}
   for k,v in ipairs({p.X,p.Y,p.Z})do lo[k]=math.min(lo[k],v-e[k]);hi[k]=math.max(hi[k],v+e[k])end
  end end
  size=Vector3.new(hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3]);centre=at:PointToWorldSpace(Vector3.new((lo[1]+hi[1])/2,(lo[2]+hi[2])/2,(lo[3]+hi[3])/2))
 end
 local _,_,_,r00,r01,r02,r10,r11,r12,r20,r21,r22=at:GetComponents()
 -- white (the vertex colours show) with PlantSurfaceStyle's low-part shade, exactly the cocoa pod's part colour
 return {s='ApprovedMesh',mesh=cfg.Key,z={size.X,size.Y,size.Z},c={centre.X,centre.Y,centre.Z,r00,r01,r02,r10,r11,r12,r20,r21,r22},
  k={242.075,242.515,243.065},fk=cfg.Tone,g=g,r='Fruit',f=cfg.Name,t=0,m='SmoothPlastic',p=b.p,shaded=true,_ArtIndex=b._ArtIndex}
end
-- The seed's styled spec list (PlantVisuals.Specs, after PlantSurfaceStyle: its index-based leaf tints and every _ArtIndex stay as in
-- the part-built list): in each fruit group the replaced pieces become one mesh spec where the first of them stood (with its
-- _ArtIndex); every other spec (stems, leaf, the 'Fruit stem' connector, the plant) is the same table, in the same order.
function M.Art(id,source)
 local cfg=M.Seeds[id];if not cfg or not M.UsesMesh(id)then return source end
 local out=derived[source];if out then return out end
 local replace={};for _,name in ipairs(cfg.Replace)do replace[name]=true end
 out={};local done={}
 for _,s in ipairs(source)do
  if s.g>0 and replace[s.f]then
   if not done[s.g]then
    done[s.g]=body(cfg,source,s.g,replace)
    if not done[s.g]then derived[source]=source;return source end -- (an art list without the body piece: keep it part-built)
    table.insert(out,done[s.g])
   end
  else table.insert(out,s)end
 end
 derived[source]=out;return out
end
return M
