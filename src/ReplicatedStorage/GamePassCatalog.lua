-- Set these ModuleScript attributes to passes owned by this experience.
-- Target prices must be set in Creator Dashboard; the client uses Roblox's live price.
local C={
 {Key='Growth',Name='Double Plant Growth',Attribute='DoubleGrowthOwned',IdAttribute='GrowthPassId',Price=400,Description='Plants and new fruit grow 2x faster!'},
 {Key='Speed',Name='Double Speed',Attribute='DoubleSpeedOwned',IdAttribute='SpeedPassId',Price=300,Description='Get 2x speed when u train!'},
}
function C.Id(pass)
 local id=tonumber(script:GetAttribute(pass.IdAttribute));return id and id>0 and id%1==0 and id or 0
end
return C
