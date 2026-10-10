-- R158b (owner: "make it so that dropped packs have a highlight and can be seen"): how a DROPPED pack (a stolen pack that fell when its carrier was caught,
-- hit or zapped; the server's model DroppedSeed_Stage<N>, attribute DroppedChest) is drawn for every player, and how much of it a client may spend.
-- Shared by DroppedPackHighlight158b (the client script) and its tests. No Instances are made here.
--  * Highlight  an outline (opaque) and a soft fill on the pack itself, ALWAYS ON TOP (like the weather / mutation outlines): a drop lasts 5 seconds, so it must be found
--               through a wall and a crowd. One colour for every biome: the outline pulses between WHITE and GOLD (1.1 times a second) and the fill is pale gold. The
--               rarity colours were NOT used: white (Common), green (Uncommon), blue (Rare) and purple (Epic) would vanish on the matching track floors (the white
--               snow keys, the green forest and jungle keys, the purple crystal keys); white and gold do not both fade into one floor (gold stands out on snow, crystal
--               and storm, white on lava, forest and jungle; both read on the sand): the picture docs/proposals/R158/dropped_pack158.png shows all seven floors.
--  * Marker     a gold diamond with "DROPPED PACK" and the distance, over the pack, always on top and the same size on screen from any distance (what a player down the
--               track sees), and a Beam: a slim column of light (gold at the foot, white above) that rises over the track walls.
--  * Budget     Roblox draws 31 Highlights at once and silently skips the rest. Only the nearest MaxHighlights drops (4; 3 in Fast Mode) get the Highlight, and only as many as
--               ClientFxBudget.HighlightRoom() leaves after every other Highlight (the weather glows, the mutation outlines, the plant auras, the Void pack, ...): each one is
--               handed to ClientFxBudget.TrackHighlight, so the track packs (SeedPackRender) give way to it and nothing else is ever pushed out. Every drop keeps its Marker
--               (up to MaxMarkers nearest); the Beam is for the nearest MaxBeams (none in Fast Mode).
--  * Fast Mode / low graphics (ClientFxBudget tier 1) and Reduced Motion: the Highlight STAYS (3), the Marker stays; the Beam and every animation (the pulse, the bob) go.
local L={Version='158b',Name='DroppedPackLook',Attribute='DroppedChest',PackTag='BiomeSeedPackVisual',Folder='_DroppedPackFx158b'}
L.Gold=Color3.fromRGB(255,200,50)
L.White=Color3.fromRGB(255,255,255)
L.FillColor=Color3.fromRGB(255,226,130)
L.Ink=Color3.fromRGB(58,32,0)            -- the dark edge of the diamond and the text
L.OutlineTransparency=0
L.StaticOutline=L.White                  -- the outline when nothing moves (Fast Mode / Reduced Motion)
L.FillTransparency=.7                    -- a soft fill: the pack's own art still shows through
L.PulseSeconds=.9                        -- white -> gold -> white
L.BobStuds=.45;L.BobSeconds=2.1          -- the marker rises and falls a little
-- budget, by ClientFxBudget tier (1 = Fast Mode / low graphics, 2 = phones, 3 = full)
L.MaxHighlights={3,4,4}
L.MaxBeams={0,3,6}
L.MaxMarkers=16
L.MaxAnimated=6                          -- only the nearest 6 pulse / bob; the others are drawn still
L.Stick=6                                -- studs: a drop that already has the Highlight keeps it against one just that much nearer (no flicker between two)
L.MarkerRange=3000                       -- studs (BillboardGui.MaxDistance)
L.MarkerAbove=4.5                        -- studs over the MIDDLE of the pack, plus half its height; the marker stands on that point (clear of the server's own timer, 3.2 studs over the middle)
L.BeamHeight=90;L.BeamFoot=.8;L.BeamTop=.3;L.BeamEmission=.6
L.BeamFade={{0,.35},{.5,.55},{1,1}}          -- (time along the beam, transparency): a clear gold foot, fading out at the top
L.MaxAge=120                             -- seconds: a drop never lasts this long (DroppedChestDuration is 5); a leak guard, not a rule
L.SelectSeconds=.25
-- How many of each kind a client may hold right now. held = this script's Highlights that exist now, room = what is left of Roblox's 31 after ALL Highlights (ours
-- included; negative when they already add up to more). Returns highlights, beams, markers.
function L.Limits(tier,held,room)
 local t=math.clamp(math.floor(tonumber(tier)or 3),1,3)
 local h=math.min(L.MaxHighlights[t],math.max(0,(tonumber(held)or 0)+(tonumber(room)or 0)))
 return h,L.MaxBeams[t],L.MaxMarkers
end
-- items: array of {Distance=studs, Held=true when the drop has its Highlight now}; sorts it nearest first (a held Highlight counts as Stick studs nearer) and writes
-- .Rank (1 = first); returns the same array. Nothing is allocated.
function L.Rank(items)
 for _,item in ipairs(items)do item.Score=(tonumber(item.Distance)or math.huge)-(item.Held and L.Stick or 0)end
 table.sort(items,function(a,b)return a.Score<b.Score end)
 for i,item in ipairs(items)do item.Rank=i end
 return items
end
-- The outline colour t seconds into the pulse (white <-> gold).
function L.Pulse(t)
 local k=.5+.5*math.cos(t*2*math.pi/L.PulseSeconds)
 return L.White:Lerp(L.Gold,1-k)
end
-- The marker's second line.
function L.Distance(studs)
 if type(studs)~='number'or studs~=studs or studs==math.huge then return''end
 return string.format('%d studs',math.max(0,math.floor(studs+.5)))
end
return L
