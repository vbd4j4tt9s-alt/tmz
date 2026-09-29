-- Camera-local weather only. Stage IDs stay stable when biomes move.
local C=Color3.fromRGB
local sparkle='rbxasset://textures/particles/sparkles_main.dds'
local mist='rbxasset://textures/particles/smoke_main.dds'
return {
    [1]={Name='Forest pollen',Texture=sparkle,Color=C(221,246,154),Rate=12,Size=.13,Life=4,Speed=1.2,Height=2,Fade=.55,Glow=.3},
    [6]={Name='Jungle fireflies',Texture=sparkle,Color=C(151,255,116),Rate=9,Size=.16,Life=4,Speed=.8,Height=2,Fade=.3,Glow=.7,Mist=true},
    [2]={Name='Swirling sand',Texture=mist,Color=C(230,195,125),Rate=9,Size=2.8,Life=2.5,Speed=5,Height=1,Fade=.84,Glow=0,Swirl=true},
    [3]={Name='Falling snow',Texture=sparkle,Color=C(238,247,255),Rate=115,Size=.27,Life=2.8,Speed=18,Height=20,Fade=.22,Glow=.2,Falling=true},
    [4]={Name='Rising embers',Texture=sparkle,Color=C(255,137,49),Rate=17,Size=.14,Life=3,Speed=4,Height=-3,Fade=.30,Glow=1},
    [5]={Name='Crystal shimmer',Texture=sparkle,Color=C(190,164,255),Rate=14,Size=.18,Life=3.5,Speed=1.2,Height=2,Fade=.40,Glow=.8},
    [7]={Name='Storm rain',Texture=sparkle,Color=C(171,196,221),Rate=155,Size=.46,Life=1.05,Speed=55,Height=24,Fade=.26,Glow=0,Falling=true,Rain=true},
}
