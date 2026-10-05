-- R151 treadmill polish (owner: "works we can implement the treadmill polishes"; the approved proposal is docs/proposals/R151/treadmills.md).
-- The config of the treadmill dressing, shared by the server build (BiomeVisuals.BuildTreadmillV131, GardenUpgradeService's sign) and the client
-- (TreadmillFx: belt texture scroll, label hide; TreadmillBeltArt151: the belt images). Pure data and pure functions: no Instances, no gameplay.
-- The machine keeps its shape: the dressing only ADDS a moving textured belt, neon trims, studs, two small corner accents, a capped light or two,
-- a "+N/step" label and (GardenUpgradeService) a sign beside the floor button. The old per-part "flow" belt pieces are retired (the chevrons stay).
--  * Biome by the treadmill's skin (1 Forest ... 7 Storm, Config.TreadmillTiers order); Grade by the machine level: low 1-2, mid 3-5, top 6-7.
--  * Grades: Layers = belt texture layers; EdgeBeams / BumperLines / Underglow / Pulse = the extras of the grade; StudPitch = studs apart on the
--    bumpers; Cap = the most real lights the WHOLE machine may have (old + new); Budget = the most new parts; Emitters / Beams = the most new ones.
--  * Biomes: belt layers {image, colour, transparency, studs per tile U, V, scroll rate x the chevrons'}: Slats (every level), Glow (mid +),
--    Stream (top); Beam = the edge light flow {colour, built-in particle texture}; Neon = the trim colour; Accent = the corner accent kind
--    ('Plinth' where the machine already has pylons at the entry end); Mote = the accent's particle {colour, texture}; Lamp = its glow colour.
--  * Images: uploaded asset ids that override the generated belt images (empty = generate them on each client with EditableImage; if that is not
--    possible, the place's own grid texture Grid). The PNGs to upload are docs/proposals/R151/treadmills/textures/*.png.
--  * Scroll: the belt texture travel in studs per second (the chevrons' speed: SpeedGainPopup moves them 3.0 / 1.3 studs a second); Sign flips
--    the direction if Studio shows the texture running against the arrows.
local L={Version=151}
local RGB=Color3.fromRGB
local Style=require(script.Parent:WaitForChild('SpeedPopupStyle'))
L.Grid='rbxassetid://6372755229'
L.Images={slats='',circuit='',crust='',veins='',stream=''}
L.Scroll={Training=3.0,Idle=1.3,Sign=1}
L.Biome={'Forest','Jungle','Desert','Snow','Lava','Crystal','Storm'}
L.Grade={'low','low','mid','mid','mid','top','top'}
L.Grades={
 low={Layers=1,EdgeBeams=false,BumperLines=false,StudPitch=2.0,Underglow=false,Pulse=false,Cap=3,Budget=44,Emitters=2,Beams=0},
 mid={Layers=2,EdgeBeams=true,BumperLines=true,StudPitch=1.6,Underglow=true,Pulse=false,Cap=5,Budget=50,Emitters=2,Beams=2},
 top={Layers=3,EdgeBeams=true,BumperLines=true,StudPitch=1.6,Underglow=true,Pulse=true,Cap=6,Budget=50,Emitters=2,Beams=2},
}
L.Biomes={
 Forest={Slats={'slats',RGB(178,225,140),.4,9.2,1.6,1},Neon=RGB(150,230,110),Accent='Lantern',Mote={RGB(214,255,120),'sparkles'},Lamp=RGB(255,214,120)},
 Jungle={Slats={'slats',RGB(140,230,170),.4,9.2,1.4,1},Neon=RGB(90,225,150),Accent='Torch',Mote={RGB(255,190,90),'sparkles'},Lamp=RGB(255,160,60)},
 Desert={Slats={'slats',RGB(150,92,48),.3,9.2,1.6,1},Glow={'veins',RGB(255,240,170),.35,4.6,4.6,1.6},Beam={RGB(255,226,140),'sparkles'},
  Neon=RGB(255,196,90),Accent='Brazier',Mote={RGB(255,200,90),'sparkles'},Lamp=RGB(255,170,70)},
 Snow={Slats={'slats',RGB(70,150,215),.35,9.2,1.6,1},Glow={'circuit',RGB(130,245,255),.12,4.6,4.6,1.6},Beam={RGB(150,240,255),'sparkles'},
  Neon=RGB(110,230,255),Accent='Frost',Mote={RGB(235,250,255),'sparkles'},Lamp=RGB(150,235,255)},
 Lava={Slats={'crust',RGB(56,26,24),.04,4.6,4.6,1},Glow={'veins',RGB(255,226,110),.3,4.6,5.12,1.6},Beam={RGB(255,150,50),'fire'},
  Neon=RGB(255,120,40),Accent='Plinth'},
 Crystal={Slats={'slats',RGB(255,205,250),.35,9.2,1.6,1},Glow={'circuit',RGB(140,255,240),.15,4.6,4.6,1.6},Stream={'veins',RGB(255,255,255),.45,3.07,5.12,2.4},
  Beam={RGB(255,200,250),'sparkles'},Neon=RGB(150,250,240),Accent='Prism',Mote={RGB(255,190,250),'sparkles'},Lamp=RGB(150,250,240)},
 Storm={Slats={'slats',RGB(110,170,255),.3,9.2,1.4,1},Glow={'circuit',RGB(255,236,120),.15,4.6,4.6,1.6},Stream={'stream',RGB(170,225,255),.1,2.3,4.6,2.4},
  Beam={RGB(150,205,255),'sparkles'},Neon=RGB(120,190,255),Accent='Plinth'},
}
-- The label floats this far above the top of the machine's front, and is drawn within MaxDistance studs (BillboardGui.MaxDistance).
L.LabelLift=1.5;L.LabelMaxDistance=90

local function clampLevel(n)n=tonumber(n)or 1;if n~=n then n=1 end;return math.clamp(math.floor(n),1,#L.Biome)end
function L.BiomeOf(skin)return L.Biome[clampLevel(skin)]end
function L.GradeOf(level)return L.Grade[clampLevel(level)]end
-- The belt layers of a biome at a grade, in draw order: {{Name, Image, Color, Transparency, U, V, Rate}, ...}
function L.Layers(biome,grade)
 local b=L.Biomes[biome];local g=L.Grades[grade];if not(b and g)then return{}end
 local out={}
 for i,key in ipairs({'Slats','Glow','Stream'})do
  local s=b[key]
  if s and i<=g.Layers then out[#out+1]={Name='Belt'..key,Image=s[1],Color=s[2],Transparency=s[3],U=s[4],V=s[5],Rate=s[6]}end
 end
 return out
end
-- Whole points exactly as the speed popups write them (SpeedPopupStyle.FormatGain: 20, 335, 2K, 65K, 500K, never "1000K"), so the label, the
-- upgrade sign and the popups always match.
function L.Format(n)return Style.FormatGain(n)end
-- One training step = one server tick (Config.TrainingInterval) of this machine on its own: points per second x interval x the machine multiplier
-- (the same for everyone: no trail, pass or friends). R151: with the 1/5 s step it is 20 x the multiplier, a round multiple of 5 at every level,
-- and the server awards exactly that (Config.GetTrainingAward pays whole fives). nil when a number is missing.
function L.StepGain(pointsPerSecond,interval,multiplier)
 local a,b,c=tonumber(pointsPerSecond),tonumber(interval),tonumber(multiplier)
 if not(a and b and c)or a~=a or b~=b or c~=c then return nil end
 return a*b*c
end
function L.LabelText(gain)if not gain then return nil end;return'+'..L.Format(gain)..'/step'end
return L
