--!nocheck
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local Wallet=W.module('GardenWallet')
local function fake(kind,born)
 local root=R.new('Frame');local amount=R.new('TextLabel')
 local t=setmetatable({Kind=kind,Amount=amount,Root=root,Born=born,Jumps=0},{__index=Wallet})
 t.Jump=function(self)self.Jumps+=1 end
 return t
end
local now=R.clock
for _,kind in ipairs({'Cash','Gems'})do
 local w=fake(kind,now-10)
 w:SetValue(0);w:SetValue(500);check(w.Jumps==1,kind..' jumps when it goes up')
 w:SetValue(200);check(w.Jumps==1,kind..' no jump when it goes down')
 w:SetValue(200);check(w.Jumps==1,kind..' no jump when unchanged')
 w:SetValue(1e12);check(w.Jumps==2,kind..' jumps again')
 local fresh=fake(kind,R.clock);fresh:SetValue(0);fresh:SetValue(5e9);check(fresh.Jumps==0,kind..' no jump while the save loads in')
end
local sp=fake('Speed',now-10);sp:SetValue('100');sp:SetValue('200');check(sp.Jumps==0,'speed keeps its own jump path')
print(('%d checks, %d failures'):format(checks,fails))
