--!nocheck
-- R158i (owner: "increase the base speed of new players to 20k in-game speed but ... still displayed as 1 speed on their screen"), the shared rule and the HUD, on the Roblox mock with the REAL scripts:
--  1  SpeedPoints.Sub (exact whole-number subtraction on decimal text of any size);
--  2  SpeedDisplay.Shown / Compact / Exact / PlayerList: points - 19,999, never below 1 (20,000 reads 1, 20,060 reads 61, 50,000 reads 30,001), exact for 10^1011 too;
--  3  SpeedDisplay.NeedText / NeedForWalkSpeed: what a keeper's sign and a gate key ask for, in the SHOWN speed (a keeper that needs 50,000 points reads 30,001 -> 31K; up to 20,000 points reads 1);
--  4  the HUD readout (the real GardenWallet bound to a ChestChaseStats.Speed): 20,000 reads 1; a +60 gain reads 61; the saved points are untouched; the exact label for screen readers is the shown number;
--  5  gains are deltas: SpeedPopupStyle.FormatGain is as it was (+60 stays +60).
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local P=W.module('SpeedPoints');local D=W.module('SpeedDisplay');local Progress=W.module('Progression81')

-- 1. Sub ---------------------------------------------------------------------------------------------------------------------------------------------------------------
check(P.Sub('20060','19999')=='61' and P.Sub('20000','19999')=='1' and P.Sub('19999','19999')=='0' and P.Sub('5','19999')=='0' and P.Sub('1000','1')=='999' and P.Sub('100000','1')=='99999','1: Sub: borrow, equal, smaller')
check(P.Sub('1'..string.rep('0',30),'1')==string.rep('9',30) and P.Sub('1'..string.rep('0',1011),'19999')==string.rep('9',1006)..'80001' and P.Sub(50000,19999)=='30001' and P.Sub(nil,'5')=='0','1: Sub: 10^30 - 1, 10^1011 - 19,999 (exact), numbers, nonsense')

-- 2. The shown speed ---------------------------------------------------------------------------------------------------------------------------------------------------
local cases={{'0','1'},{0,'1'},{'1','1'},{'19999','1'},{'20000','1'},{20000,'1'},{'20001','2'},{'20060','61'},{'50000','30001'},{'123456789','123436790'},{'1000000','980001'},{nil,'1'},{'x','1'},{-5,'1'},{'1'..string.rep('0',15),'999999999980001'}}
for _,c in ipairs(cases)do check(D.Shown(c[1])==c[2],'2: Shown('..tostring(c[1])..') reads '..c[2]..' (got '..tostring(D.Shown(c[1]))..')')end
check(D.Shown('1'..string.rep('0',1011))==string.rep('9',1006)..'80001','2: Shown(10^1011) is exact')
check(D.Compact('20000')=='1' and D.Compact('20060')=='61' and D.Compact('50000')=='30001' and D.Compact('1020000')=='1M' and D.Compact('13019999')=='13M','2: Compact (the HUD): 1, 61, 30001, 1M, 13M ('..D.Compact('1020000')..' / '..D.Compact('13019999')..')')
check(D.Exact('20000')=='1' and D.Exact('50000')=='30,001' and D.Exact('1020000')=='1,000,001','2: Exact (the label for screen readers): 1, 30,001, 1,000,001')
check(D.PlayerList('20000')=='1' and D.PlayerList('20060')=='61' and D.PlayerList('50000')=='30K','2: PlayerList (the narrow cell): 1, 61, 30K')
check(D.Both('20060')=='61 (20,060 points)' and D.Both('20000')=='1 (20,000 points)','2: Both (owner / test commands): "61 (20,060 points)"')

-- 3. What a sign asks for ----------------------------------------------------------------------------------------------------------------------------------------------
check(D.NeedText('0')=='1' and D.NeedText('3751')=='1' and D.NeedText('20000')=='1' and D.NeedText('20001')=='5' and D.NeedText('20004')=='5' and D.NeedText('20005')=='10','3: up to 20,000 points asked: "1" (everyone has it); 2 shown rounds up to 5 (the multiples of 5 rule), 6 to 10')
check(D.NeedText('50001')=='31K' and D.NeedText('91501')=='72K' and D.NeedText('1165456')=='1.2M','3: a keeper that needs 50,001 points reads 31K (30,002 shown), 91,501 reads 72K, 1,165,456 reads 1.2M')
local want={[20]='1',[23]='1',[26]='1',[32]='1',[37]='1',[42]='26K',[50]='72K',[57]='190K',[65]='520K',[80]='1.2M',[92]='2.9M',[104]='7.1M',[128]='16M',[147]='25M',[166]='45M',[205]='160M',[236]='370M',[266]='690M',[330]='2.6B',[379]='7.1B',[429]='22B'}
local ok=true;local bad={}
for e,t in pairs(want)do local got=D.NeedForWalkSpeed(e);if got~=t then ok=false;bad[#bad+1]=e..' '..got..' (want '..t..')'end end
check(ok,'3: NeedForWalkSpeed for the 21 keepers: 1 / 1 / 1, 1 / 1 / 26K, 72K / 190K / 520K, 1.2M ... 22B'..(#bad>0 and(': '..table.concat(bad,'; '))or''))
check(D.NeedForWalkSpeed(600)=='∞' and D.NeedForWalkSpeed(10)=='1','3: The Darkened (600) is still infinity; a speed under the new runner\'s needs 1')
-- the shown number is the one that really beats the keeper: shown + 19,999 points walk faster than the keeper
do local fine=true
 for e in pairs(want)do if e<500 then local shown=tonumber(D.Shown(P.Add(Progress.PointsText(e),'1')));if not(Progress.Speed(shown+19999)>e-1e-9)then fine=false end end end
 check(fine,'3: shown + 19,999 real points always walk faster than the keeper (the sign never lies about the real need)')
end

-- 4. The HUD readout ---------------------------------------------------------------------------------------------------------------------------------------------------
local Players=W.service('Players');local player=R.new('Player');player.Name='P';player.UserId=3;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local stats=R.new('Folder');stats.Name='ChestChaseStats';stats.Parent=player
local speed=R.new('StringValue');speed.Name='Speed';speed.Value='20000';speed.Parent=stats
local econ=R.Instance.new('ScreenGui');econ.Name='GardenEconomy';econ.Parent=pg
local wallet=W.module('GardenWallet').new(econ)
local row=econ:FindFirstChild('SpeedHud');local amount=row and row:FindFirstChild('Amount')
check(amount and amount.Text=='1','4: a new player (20,000 points) reads speed 1 on the HUD ('..tostring(amount and amount.Text)..')')
check(row:GetAttribute('ExactCash')=='1','4: ... and the exact label is the shown number too')
speed.Value='20060';check(amount.Text=='61','4: +60 points: the HUD reads 61 ('..amount.Text..')')
speed.Value='50000';check(amount.Text=='30001' and row:GetAttribute('ExactCash')=='30,001','4: 50,000 points read 30001 (exact 30,001)')
speed.Value='1000019999';check(amount.Text=='1B','4: 1,000,019,999 points read 1B ('..amount.Text..')')
speed.Value='5';check(amount.Text=='1','4: (an impossible value below the floor still never reads under 1)')
check(speed.Value=='5','4: the stat itself (the real points) is never rewritten by the HUD')

-- 5. Gains stay deltas -------------------------------------------------------------------------------------------------------------------------------------------------
local Style=W.module('SpeedPopupStyle')
check(Style.FormatGain(60)=='60' or Style.FormatGain(60)=='+60' or tostring(Style.FormatGain(60)):find('60',1,true)~=nil,'5: a +60 gain is written 60 (no shift)')
check(tostring(Style.FormatGain(2000)):find('2K',1,true)~=nil,'5: a +2000 gain is written 2K (no shift)')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
