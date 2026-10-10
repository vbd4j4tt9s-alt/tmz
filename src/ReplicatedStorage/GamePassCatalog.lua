-- Set these ModuleScript attributes to passes owned by this experience.
-- Target prices must be set in Creator Dashboard; the client uses Roblox's live price.
-- R153: DefaultId = the pass id used when the ModuleScript has no <IdAttribute> attribute at all (0 = not on sale: no Robux button, the Gem price still works).
-- An attribute that IS there wins (also 0 = off). Late = the release that added the pass: its saved ownership / gift data is kept apart (PremiumProgress.Pack).
-- Icon = the art key CloverIcon153 draws; Emoji = what a plain text line (the purchase notice) shows next to the name.
local C={
 {Key='Growth',Name='Double Plant Growth',Attribute='DoubleGrowthOwned',IdAttribute='GrowthPassId',Price=400,Description='Plants and new fruit grow 2x faster!'},
 {Key='Speed',Name='Double Speed',Attribute='DoubleSpeedOwned',IdAttribute='SpeedPassId',Price=300,Description='Get 2x speed when you train!'},
 {Key='Clover',Name='4 Leaf Clover',Attribute='CloverOwned',IdAttribute='CloverPassId',DefaultId=2005041797,Price=999,Description='x2 luck on EVERY pack you open! 🍀',Late=153,Icon='Clover',Emoji='🍀',Luck=2},
}
function C.Id(pass)
 local id=script:GetAttribute(pass.IdAttribute)
 if id==nil then id=pass.DefaultId end
 id=tonumber(id);return id and id>0 and id%1==0 and id<9007199254740991 and id or 0
end
-- R153: true for a pass that can be sold for Gems before it has a Robux id (it has a DefaultId field, and the id is 0): its card has no Robux button and says ROBUX SOON.
function C.RobuxSoon(pass)return pass.DefaultId~=nil and C.Id(pass)==0 end
-- R153: the luck a pass multiplies every pack opening by (1 = none). R154 (owner: "the 2x luck is universal"): every pack, the Void / Verity / Mech packs too, and on top of
-- the best boots (a pass raises the luck cap by as much: BalanceValues81.LuckCeiling).
function C.LuckOf(key)for _,p in ipairs(C)do if p.Key==key then return p.Luck or 1 end end;return 1 end
return C
