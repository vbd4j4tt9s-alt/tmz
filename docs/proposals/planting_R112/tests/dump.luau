--!nocheck
local W=require('./world').build()
local P=W.req(W.RS.PlantingEffects)
local pal=P.Palette(W.R.Color3.fromRGB(112,75,45))
local function cf(c)local r=c.R;return string.format('[%g,%g,%g,%g,%g,%g,%g,%g,%g,%g,%g,%g]',c.Position.X,c.Position.Y,c.Position.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3])end
local out={}
for _,case in ipairs({{'small','HoloMelonSeed',1},{'medium','AppleSeed',1},{'big','WinterCrownwoodSeed',2}})do
 local base=P.BaseRadius(case[2],case[3]);local l=P.Layout(base,P.Hash(case[1]..'crop'),96,6);local size=P.Size(base)
 local settled=P.Settled(l);local frames={}
 for _,t in ipairs({.14,.3,settled+.05,settled+2.4+.25})do
  local list={}
  for _,c in ipairs(l.Chunks)do local pose=P.Pose(c,t,settled+2.4,false)or(W.R.CFrame.new(c.Position.X,c.Position.Y,c.Position.Z)*c.Rotation)
   local col=pal[c.Tone];table.insert(list,string.format('{"s":%g,"cf":%s,"c":[%g,%g,%g]}',c.Size,cf(pose),col.R,col.G,col.B))end
  table.insert(frames,string.format('{"t":%g,"chunks":[%s]}',t,table.concat(list,',')))
 end
 local o=pal[1]:Lerp(W.R.Color3.new(0,0,0),.12);local i=pal[1]:Lerp(W.R.Color3.new(0,0,0),.42)
 table.insert(out,string.format('"%s":{"seed":"%s","scale":%g,"base":%g,"radius":%g,"height":%g,"mark":%g,"markOuter":[%g,%g,%g],"markInner":[%g,%g,%g],"count":%d,"frames":[%s]}',
  case[1],case[2],case[3],base,size.Radius,size.Height,size.Mark,o.R,o.G,o.B,i.R,i.G,i.B,#l.Chunks,table.concat(frames,',')))
end
print('{'..table.concat(out,',')..'}')
