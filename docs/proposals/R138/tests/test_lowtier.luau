--!nocheck
-- R138 (owner: "add sound effects for getting common and uncommon, rare and very little minor animations"): the real
-- RevealFlourish small pop for Common / Uncommon / Rare, and the 2D sparkle pop in PackOpeningFeedback (source).
-- The sounds are checked in docs/proposals/audio_R123/tests (test_sync).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local F=W.module('RevealFlourish');local Seq=W.module('RarityRevealSequence')
local emitted={}
local rawEmit=R.Inst.Emit;R.Inst.Emit=function(self,n)if self.ClassName=='ParticleEmitter'then emitted[#emitted+1]=n end;if rawEmit then return rawEmit(self,n)end end
local holder=R.new('Model');holder.Parent=W.workspace
local function shownParts(f)local n=0;for _,d in ipairs(f.Folder:GetDescendants())do if d:IsA('BasePart')and d.Transparency<1 then n+=1 end end;return n end
local results={}
for rank=1,3 do
 table.clear(emitted)
 local f=F.Create(holder,rank,1);local at=Seq.SeedAt(rank);local mouth=CF(0,2,0)
 check(f and f.Style.Minor and f.Pillar==nil and #f.Helix==0 and #f.Motes==0,'rank '..rank..': small pop only (no pillar, helix or motes)')
 f:Update(mouth,at-.05,at,true);local before=shownParts(f)
 f:Update(mouth,at+.08,at,true);local during=shownParts(f);local r1=0
 for _,seg in ipairs(f.Rings[1])do r1=math.max(r1,(V3(seg.Position.X,0,seg.Position.Z)).Magnitude)end
 f:Update(mouth,at+.3,at,true);local r2=0
 for _,seg in ipairs(f.Rings[1])do r2=math.max(r2,(V3(seg.Position.X,0,seg.Position.Z)).Magnitude)end
 local light=f.Light.Brightness
 f:Update(mouth,at+F.MinorSeconds+.1,at,true);local after=shownParts(f)
 results[rank]={Sparks=emitted[1]or 0,Radius=r2,Light=light,Sound=f.Sound}
 check(before==0 and during>=10 and after==0,('rank %d: nothing before the seed pops, a ring when it does, gone after %.1f s'):format(rank,F.MinorSeconds))
 check(r2>r1,'rank '..rank..': the ring spreads out')
 check(f.Sound==nil and not f.Folder:FindFirstChildWhichIsA('Sound',true),'rank '..rank..': no sound for people nearby (only the opener hears a cue)')
 f:Destroy()
end
check(results[1].Sparks==0 and results[2].Sparks==8 and results[3].Sparks==14,('sparkles grow with the tier: %d / %d / %d'):format(results[1].Sparks,results[2].Sparks,results[3].Sparks))
check(results[3].Radius>results[2].Radius and results[2].Radius>results[1].Radius,'the ring grows with the tier')
check(results[3].Light>0 and results[2].Light==0,'only Rare flashes a little light')
local big=F.Create(holder,5,1);check(big and not big.Style.Minor and big.Pillar~=nil,'Mythic keeps its full burst');big:Destroy()
local src=W.B.PackOpeningFeedback or''
check(src:find('if rank<=3 then',1,true)~=nil and src:find("rank==3 and 8 or rank==2 and 6 or 4",1,true)~=nil,'2D: 4 / 6 / 8 tiny sparkles pop out in the tier colour')
check(src:find('revealAudio.Burst(rank,t,',1,true)~=nil,'2D: the low-tier sound plays when the seed pops out (late cues dropped; R152: its later notes on the reveal clock)')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
