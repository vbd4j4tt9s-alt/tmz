-- R150: copy, states and timelines of the treadmill bonus UI (owner: "polish the bonus roll button, the bonus gift timer and
-- the bonus roll screen by adding design and personality"). Pure functions only: no Instances, no gameplay. The rules, odds
-- and the server stay in TreadmillBonusRules / TreadmillBonusService; TreadmillBonusClient draws, BonusGiftArt builds shapes.
--  * Timer(...)    what the gift timer shows (the billboard over the player and the button while charging).
--  * ButtonMode    which of the three button looks applies: 'ready' (cheerful), 'charging' (calm, progress) or 'hidden'.
--  * Reveal(...)   the rarity-scaled reveal on the roll screen (word, pop, rays, confetti, close caption).
--  * SpinLine(a)   the playful status line while the strip spins.
local S={}
S.AlmostSeconds=30 -- the last stretch of a countdown: "Almost there!"
S.AttentionPeriod=4.2 -- READY button: a short wiggle + shine every this many seconds
S.ReadyHold=3 -- how long the "Bonus ready!" line stays on the gift timer

function S.Clock(seconds)
 if type(seconds)~='number'or seconds~=seconds then seconds=0 end
 seconds=math.max(0,math.ceil(seconds))
 return string.format('%d:%02d',seconds//60,seconds%60)
end

-- What the gift timer shows. count = READY rolls, maxReady = the cap, interval / left in seconds.
--  State 'charging' | 'almost' (last AlmostSeconds) | 'full' (at the cap the timer is paused: claim!)
--  Fraction 0..1 (how full the gift is), Clock 'm:ss', Caption (small line), Count.
function S.Timer(count,maxReady,interval,left)
 count=math.max(0,math.floor(tonumber(count)or 0));maxReady=math.max(1,math.floor(tonumber(maxReady)or 2))
 if count>=maxReady then
  return {State='full',Fraction=1,Left=0,Clock='',Count=count,Caption=count..' ROLLS READY!',Hint='TAP BONUS ROLL'}
 end
 interval=math.max(1,tonumber(interval)or 360)
 left=tonumber(left)or interval;if left~=left then left=interval end
 left=math.clamp(left,0,interval)
 local almost=left<=S.AlmostSeconds
 return {State=almost and'almost'or'charging',Fraction=1-left/interval,Left=math.ceil(left),Clock=S.Clock(left),Count=count,
  Caption=almost and'ALMOST THERE!'or'NEXT ROLL',Hint=''}
end

-- 'ready' when a roll waits, 'charging' while standing on the treadmill with none ready (the button then shows the timer),
-- else 'hidden' (as before R150). The title screen and the open roll window hide it too.
function S.ButtonMode(count,training,titleActive,rolling)
 if titleActive or rolling then return'hidden'end
 if (tonumber(count)or 0)>=1 then return'ready'end
 if training then return'charging'end
 return'hidden'
end

-- Title and sub line of the button. busy = a request is in flight.
function S.ButtonLines(mode,timer,busy)
 if busy then return'BONUS ROLL','ROLLING...'end
 if mode=='charging'and timer then
  return'BONUS ROLL',(timer.State=='almost'and'ALMOST! 'or'NEXT ')..timer.Clock
 end
 return'BONUS ROLL','READY!'
end

-- Caption and clock of the billboard pill. popping = the "ready" moment (a few seconds after a roll became ready).
function S.BillboardLines(timer,popping)
 if popping then return'BONUS READY! 🎁','OPEN IT!'end
 if timer.State=='full'then return timer.Caption,timer.Hint end
 return timer.Caption,timer.Clock
end

-- Reveal by rarity: the word that pops, how hard it pops, light rays, confetti and sparkles, the close button's caption.
-- Beams = crossing light bars (each one makes two rays); Alpha = their transparency (lower = brighter); Speed in degrees/s.
S.Rarities={'Common','Uncommon','Rare','Epic','Legendary','Mythic','Secret'}
local REVEAL={
 Common={Word='NICE!',Pop=.10,Beams=4,Alpha=.88,Speed=8,Confetti=0,Sparkles=4,Elastic=false,Close='COLLECT'},
 Uncommon={Word='SWEET!',Pop=.14,Beams=5,Alpha=.85,Speed=9,Confetti=0,Sparkles=6,Elastic=false,Close='COLLECT'},
 Rare={Word='GREAT!',Pop=.18,Beams=6,Alpha=.8,Speed=10,Confetti=8,Sparkles=8,Elastic=false,Close='COLLECT'},
 Epic={Word='WOW!',Pop=.22,Beams=6,Alpha=.74,Speed=12,Confetti=14,Sparkles=10,Elastic=true,Close='COLLECT'},
 Legendary={Word='LEGENDARY!',Pop=.28,Beams=7,Alpha=.6,Speed=14,Confetti=24,Sparkles=12,Elastic=true,Close='AWESOME!'},
 Mythic={Word='MYTHIC!!',Pop=.32,Beams=8,Alpha=.54,Speed=18,Confetti=32,Sparkles=14,Elastic=true,Close='AWESOME!'},
 Secret={Word='SECRET!!!',Pop=.36,Beams=8,Alpha=.48,Speed=20,Confetti=40,Sparkles=16,Elastic=true,Close='AWESOME!'},
}
function S.Reveal(rarity)
 local r=REVEAL[rarity]or REVEAL.Common
 return {Word=r.Word,Pop=r.Pop,Beams=r.Beams,Alpha=r.Alpha,Speed=r.Speed,Confetti=r.Confetti,Sparkles=r.Sparkles,Elastic=r.Elastic,Close=r.Close,Known=REVEAL[rarity]~=nil}
end

-- Status line while the strip spins; a = 0..1 progress of the spin. Returns the line and its index (the label changes only
-- when the index does).
S.SpinLines={'Unwrapping your gift...','Ooh, what could it be?','Slowing down...','Here it comes!'}
S.SpinAt={0,.3,.62,.86}
S.SpinHint='Your pack is already in your bag!' -- the server grants it before the strip moves
function S.SpinLine(a)
 a=tonumber(a)or 0;local index=1
 for i,at in ipairs(S.SpinAt)do if a>=at then index=i end end
 return S.SpinLines[index],index
end

-- Seconds left from the published attributes: DueAt (server time) when the timer runs, else the saved Left, else a full interval.
function S.LeftSeconds(dueAt,leftAttr,interval,now)
 interval=math.max(1,tonumber(interval)or 360)
 local due=tonumber(dueAt);local left=due and(due-now)or tonumber(leftAttr)or interval
 return math.clamp(left,0,interval)
end

-- Short copy for the button's status line when the server refuses or something fails (the full text stays on the accessibility
-- label). Every result fits the narrowest button.
function S.Flash(message)
 local text=string.upper(tostring(message or''))
 if text:find('BAG FULL',1,true)then return'BAG FULL!'end
 if text:find('PLEASE WAIT',1,true)then return'ONE SEC...'end
 if text:find('NO BONUS ROLL',1,true)then return'NOT YET!'end
 if text:find('STILL LOADING',1,true)then return'LOADING...'end
 if text:find('PLEASE TRY AGAIN',1,true)or text:find('TRY AGAIN',1,true)then return'TRY AGAIN!'end
 if text:find('UNAVAILABLE',1,true)then return'TRY LATER'end
 if #text>14 then return text:sub(1,12)..'...'end
 if text==''then return'TRY AGAIN!'end
 return text
end

-- Damped wiggle of the gift (degrees) at time t into the wiggle (0..1.. seconds), 0 once it is over.
function S.Wiggle(t,length,degrees)
 length=length or .7;degrees=degrees or 12
 if t<0 or t>=length then return 0 end
 return degrees*math.sin(t*30)*(1-t/length)
end

return S
