"""Builds giveaway_scene.luau from the R149 whole-map scene (docs/proposals/R149/tests/zfight_scene.luau): the owner's place file, the real start-up builders (MapService.new: the market,
the festival streets and plazas, Verity's dais ...), and then the REAL VoidGiveaway152 (the pedestal, in an in-memory store like Studio without API access) with the REAL
VoidGiveawayClient152 as a player standing in the plaza (the sign, the Void Pack built by SeedPackVisuals / EclipsePackArt on stand-in meshes, VoidPackFx's glow and particles).
GIVE_STATE (a global the runner puts in front) = 'open' (13 claimed: "487 / 500 LEFT") or 'empty' (all 500 claimed: "0 / 500 LEFT", ALL CLAIMED).
It prints, besides zfight_scene's own "SCENE {...}" (every part of the map in the zfight.py format), "GSCENE <json>" lines (docs/proposals/R150/preview/preview_dump.luau): the emitters, lights
and the sign's layout of what the client made.
Usage: python3 make_giveaway_scene.py <zfight_scene.luau> <out giveaway_scene.luau>"""
import sys

src, out = sys.argv[1], sys.argv[2]
s = open(src, encoding='utf-8').read()
marker = "-- Where a camera can be:"
assert s.count(marker) == 1, 'marker not found'
block = r"""-- R152: the free Void Pack pedestal on the finished map, and the client as a player in the plaza.
step('VoidGiveaway',function()
 local D=require('./preview_dump')
 local Svc=server('VoidGiveaway152');local Store=server('VoidGiveawayStore152')
 local svc=Svc.new(Config,{},{},{},{MapRoot=map},{Store=Store.new({Memory=true,Studio=true}),Studio=true,NoLoop=true,Clock=function()return R.clock end,Time=function()return 1760000000 end})
 local w0=W.warns;W.env.warn=function()end
 svc:Start()
 svc:_force(GIVE_STATE=='empty'and 500 or 13)
 -- the client: the local player stands in the plaza, a little south of the pedestal's front
 Run.IsClient=function()return true end;Run.IsServer=function()return false end
 local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
 function Players.GetPlayers()return{player}end
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
 function R.Inst.Play()end;function R.Inst.Stop()end;function R.Inst.Emit(self,n)self._emitted=(self._emitted or 0)+(n or 1)end
 W.service('ContentProvider').PreloadAsync=function()end
 W.stub('ClientFxBudget',{Get=function()return 3 end,Low=function()return false end})
 W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end})
 local F=require('./fixtures');F.packAssets(W) -- the place's SeedPackMeshAssets: stand-in meshes so SeedPackVisuals.Bag builds the Void Pack
 local model=R.new('Model');model.Name='Tester'
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Transparency=1;root.Parent=model
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=model;model.PrimaryPart=root;model.Parent=W.workspace;player.Character=model
 root.CFrame=CF(0,7,-366)
 W.workspace.CurrentCamera.CFrame=R.CFrame.lookAt(V3(0,10,-360),V3(0,18,-392))
 local sc=R.new('LocalScript');sc.Name='VoidGiveawayClient152';W.load('VoidGiveawayClient152',sc)
 player:SetAttribute('VoidGift152','Open')
 -- 7 s of frames (209: the pack has turned half a lap at 0.45 rad/s), so its face points at the market side where the cameras are
 for _=1,209 do W.frames(1,1/30)end
 local pack=W.workspace:FindFirstChild('VoidGiveawayPacks152')
 local roots={map:FindFirstChild('VoidGiveaway152')}
 for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='_VoidPackFx122'or c.Name=='VoidGiveawayPacks152'then roots[#roots+1]=c end end
 print('GSCENE '..D.scene(W,roots,'{}'))
 -- the lettering on the column's plaques (SurfaceGui text: the renderer draws it on the plaque's front face)
 local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
 for _,d in ipairs(roots[1]:GetDescendants())do
  if d.Name=='Column plaque'then
   local cf=d.CFrame;local r=cf.R;local p=cf.Position;local sz=d.Size;local label=d:FindFirstChildWhichIsA('SurfaceGui',true)and d:FindFirstChildWhichIsA('SurfaceGui',true):FindFirstChild('Line1')
   print(string.format('GPLAQUE {"p":[%.4f,%.4f,%.4f],"r":[%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f],"s":[%.3f,%.3f,%.3f],"text":"%s","color":%s,"stroke":%s}',
    p.X,p.Y,p.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3],sz.X,sz.Y,sz.Z,label.Text,c3(label.TextColor3),c3(label.TextStrokeColor3)))
  end
 end
 print(string.format('GINFO state=%s parts=%d',tostring(GIVE_STATE),#roots))
end)
"""
s = s.replace(marker, block + marker)
old = "local function areaOf(p)\n local path=Z.path(p)\n"
assert s.count(old) == 1, 'areaOf not found'
s = s.replace(old, old + " if path:find('VoidGiveaway',1,true)then return'giveaway'end\n if path:find('_VoidPackFx122',1,true)then return'giveaway'end\n")
open(out, 'w', encoding='utf-8').write(s)
print('wrote', out)
