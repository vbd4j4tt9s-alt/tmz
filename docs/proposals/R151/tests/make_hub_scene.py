"""Builds hub_scene.luau from the R149 whole-map scene (docs/proposals/R149/tests/zfight_scene.luau): the same place file, the same real start-up builders, and then
the two hub displays through the REAL HubDisplayService (real HubDisplayArt, real HubDisplayAvatar on the Players mock of hub_rig.luau), dumped in the same scene format
for zfight.py and check_hub_scene.py. HUB_STATE (a global the runner puts in front) = 'empty' (nobody holds either spot) or 'champions' (a Mythic Fire Pepper pull and a Gold
fruit, each with an avatar). R152: the displays are the Fruit of the Hour-style pedestal, the showcase item and the giant avatar; the "HUBTEXT" lines carry the plaque's and the
label's words for the preview. The mock plays the dance on a Humanoid it cannot animate: a frame of it (arms up, one hip out) is put into the joints by hand.
Usage: python3 make_hub_scene.py <zfight_scene.luau> <out hub_scene.luau>"""
import sys

src, out = sys.argv[1], sys.argv[2]
s = open(src, encoding='utf-8').read()

marker = "-- Where a camera can be:"
assert s.count(marker) == 1, 'marker not found'
block = r"""-- R151: the two hub displays, built by the REAL HubDisplayService (real art, real avatar code) in the finished map.
step('HubDisplays',function()
 local Meshes=W.module('ApprovedPlantMeshes') -- (the baked fruit meshes live in ServerStorage: one stand-in part each, as the other previews do)
 Meshes.Get=function(key)return {Clone=function()local p=R.new('MeshPart');p.Name=key;p.Size=V3(1,1,1);return p end}end
 Meshes.Status=function()return 'Ready'end
 local rawWarn=W.env.warn;W.env.warn=function(msg,...)if tostring(msg):find('fruit meshes',1,true)then return end;rawWarn(msg,...)end
 local Rig=require('./hub_rig')(W,R)
 Rig.install(Players,{Describe=0,Create=0,Mode='ok',Accessories=6,Scale=1})
 local Service=server('HubDisplayService');local Store=server('HubDisplayStore')
 local svc=Service.new(Config,{},{Show=function()end},{MapRoot=map},{Clock=function()return R.clock end,Time=function()return 20727*86400+3600*5 end,
  Store=Store.new({Disabled=true}),NoLoop=true})
 svc:Start()
 if HUB_STATE=='champions' then
  local function player(id,name)local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;return p end
  svc:NotePull(player(5001,'Champion Of Pulls'),{SeedId='FirePepperSeed',SeedName='Fire Pepper Seed',Rarity='Mythic',SeedScale=1,PackMutation='None'},{Stage=4,Variant='Pack03',Version=149,Luck=1})
  svc:NoteHarvest(player(5002,'Fruit Fan'),{SeedId=svc.Board.FruitId,FruitScale=6,Mutation='Gold',Weather='None'})
  -- The mock does not run Motor6D joints or animations (the dance is a track on the avatar's Animator): one frame of a dance (both arms up, the right higher, the chest turned, the head back)
  -- is put into the joints by hand, parent before child, about each joint's pivot (the top of an arm part, the bottom of the head and of the torso): the dump (preview + extents check)
  -- sees an avatar mid-dance with its arms in the air, the widest it gets.
  local FRAME={RightShoulder={-.15,0,2.7},RightElbow={-.5,0,0},LeftShoulder={.2,0,-2.3},LeftElbow={-.8,0,0},Waist={0,.25,.12},Neck={-.1,-.2,.1}}
  local JOINTS={
   {'Waist','UpperTorso',-1,{'UpperTorso','Head','LeftUpperArm','LeftLowerArm','LeftHand','RightUpperArm','RightLowerArm','RightHand'},true},
   {'Neck','Head',-1,{'Head'},true},
   {'RightShoulder','RightUpperArm',1,{'RightUpperArm','RightLowerArm','RightHand'}},{'RightElbow','RightLowerArm',1,{'RightLowerArm','RightHand'}},
   {'LeftShoulder','LeftUpperArm',1,{'LeftUpperArm','LeftLowerArm','LeftHand'}},{'LeftElbow','LeftLowerArm',1,{'LeftLowerArm','LeftHand'}},
  }
  for _,kind in ipairs({'Pull','Fruit'})do
   local rig=svc.Displays[kind].AvatarFolder:FindFirstChildWhichIsA('Model')
   if rig and rig:FindFirstChild('Humanoid')then
    local handles={}
    for _,a in ipairs(rig:GetChildren())do if a:IsA('Accessory')and a:FindFirstChild('Handle')then handles[#handles+1]=a.Handle end end
    for _,j in ipairs(JOINTS)do
     local t=FRAME[j[1]];local pv=rig:FindFirstChild(j[2])
     if t and pv then
      local pivot=pv.CFrame*CF(0,j[3]*pv.Size.Y/2,0)
      local delta=pivot*R.CFrame.Angles(t[1],t[2],t[3])*pivot:Inverse()
      local moved={};for _,n in ipairs(j[4])do moved[#moved+1]=rig:FindFirstChild(n)end
      if j[5]then for _,h in ipairs(handles)do moved[#moved+1]=h end end
      for _,p in ipairs(moved)do p.CFrame=delta*p.CFrame end
     end
    end
   end
  end
 end
 print('HUBINFO state='..tostring(HUB_STATE or'empty')..' fruit='..tostring(svc.Board.FruitId))
 for _,kind in ipairs({'Pull','Fruit'})do
  local d=svc.Displays[kind];local n=svc.Art.Counts(d)
  print(string.format('HUBINFO %s frame=%d item=%d avatar=%d source=%s mode=%s',kind,n.Frame,n.Item,n.Avatar,tostring(svc.AvatarSource and svc.AvatarSource[kind]),tostring(svc.AvatarMode and svc.AvatarMode[kind])))
 end
 -- the words and where they are, for the preview renderer (docs/proposals/R151/preview): one "HUBTEXT {json}" line per display: the plaque (its plate's frame, the rows as the SurfaceGui lays them out)
 -- and the label (where the BillboardGui floats, its size in studs, the rows)
 local Rules=W.module('HubDisplayRules')
 local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
 local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
 for _,kind in ipairs({'Pull','Fruit'})do
  local d=svc.Displays[kind];local cf=d.Plaque.CFrame;local r=cf.R;local p=cf.Position;local s=d.Plaque.Size
  local prows={}
  for _,key in ipairs({'Title','Name','Line','Footer'})do
   local row=Rules.Plaque.Rows[key];local label=d.Plate[key]
   prows[#prows+1]=string.format('{"key":%s,"text":%s,"color":%s,"x":%d,"y":%d,"w":%d,"h":%d,"max":%d,"strokeT":%s}',q(key),q(label.Text),c3(label.TextColor3),row.X,row.Y,row.W,row.H,row.Max,tostring(label.TextStrokeTransparency))
  end
  local lrows={}
  for _,key in ipairs({'Title','Name','Info'})do
   local row=Rules.Label.Rows[key];local label=d.Tag[key]
   lrows[#lrows+1]=string.format('{"key":%s,"text":%s,"color":%s,"y":%.3f,"h":%.3f}',q(key),q(label.Text),c3(label.TextColor3),row.Y,row.H)
  end
  local lp=d.LabelGui.Adornee.CFrame.Position+d.LabelGui.StudsOffsetWorldSpace
  local ic=d.Model:GetAttribute('ItemCenter');local ac=d.Model:GetAttribute('Accent');local lk=d.F.LookVector;local o=d.F.Position
  print(string.format('HUBTEXT {"kind":%s,"state":%s,"origin":[%.3f,%.3f,%.3f],"look":[%.5f,%.5f,%.5f],"item":[%.3f,%.3f,%.3f],"accent":%s,"calm":%s,"plaque":{"p":[%.4f,%.4f,%.4f],"r":[%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f],"s":[%.3f,%.3f,%.3f],"canvas":[%d,%d],"rows":[%s]},"label":{"p":[%.3f,%.3f,%.3f],"w":%.2f,"h":%.2f,"rows":[%s]}}',
   q(kind),q(d.Model:GetAttribute('State')),o.X,o.Y,o.Z,lk.X,lk.Y,lk.Z,ic.X,ic.Y,ic.Z,ac and c3(ac)or'null',tostring(d.Model:GetAttribute('Calm')==true),p.X,p.Y,p.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3],s.X,s.Y,s.Z,
   Rules.Plaque.Canvas.W,Rules.Plaque.Canvas.H,table.concat(prows,','),lp.X,lp.Y,lp.Z,Rules.Label.W,Rules.Label.H,table.concat(lrows,',')))
 end
end)
"""
s = s.replace(marker, block + marker)

old = "local function areaOf(p)\n local path=Z.path(p)\n"
assert s.count(old) == 1, 'areaOf not found'
s = s.replace(old, old + " if path:find('HubDisplays151',1,true)then return'hubdisplay'end\n")
open(out, 'w', encoding='utf-8').write(s)
print('wrote', out)
