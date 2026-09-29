-- Shared presentation/timing settings. The server alone resolves hits and drops.
local Knockback=require(script.Parent.KnockbackConfig)
return {
    Stage=7,WarningSeconds=3,Radius=11,IntervalMin=1.5,IntervalMax=3,MaxAttempts=48,
    EdgeMargin=3,SeedClearance=16,BirdClearance=27,HitHeight=16,
    CloudHeight=72,CloudCount=3,CloudSpeed=.75,ViewDistance=420,
    CloudOpacity=.90,WarningFillTransparency=.50,WarningRingTransparency=.05,
    BoltWidth=.55,BoltGlowWidth=1.5,ImpactSeconds=.65,
    LightningHorizontal=Knockback.Lightning.Horizontal,LightningVertical=Knockback.Lightning.Vertical,
    ThunderId='rbxassetid://9120016037',RumbleId='rbxassetid://9120018695',
    ImpactId='rbxassetid://9113512609',
    ThunderVolume=.36,RumbleVolume=.10,ImpactVolume=.40,
    SuccessZoom=4,SuccessBrightness=.13,SuccessSeconds=.95,SuccessOpacity=.30,
}
