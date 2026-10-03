-- R140 (owner: "daily login rewards, it will be per week and at the end players get 1 mech pack ... daily quests like
-- steal 3 packs, simple as that, that quest gives 5 gems ... speed boost for friends in the server"): the numbers and
-- the pure rules, shared by the server (DailyProgress, SocialService) and the client (DailyRewardsClient).
-- Days are UTC days, so everyone's new day starts at the same moment.
local D={}
-- One week of login rewards: one claim per day; after day 7 the week starts again at day 1.
D.Login={{Gems=5},{Gems=5},{Gems=10},{Gems=10},{Gems=15},{Gems=15},{MechPack=1}}
-- false: a missed day only pauses the week (you continue where you left off). true: a missed day restarts it at day 1.
D.ResetIfMissed=false
D.QuestGems=5;D.QuestsPerDay=3
-- Quest 1 is always the steal quest; the other two are picked from the rest, fixed for each player and day.
D.Quests={
 {Key='Steal',Goal=3,Text='Steal 3 packs',Icon='🎒'},
 {Key='Open',Goal=3,Text='Open 3 packs',Icon='🎁'},
 {Key='Plant',Goal=3,Text='Plant 3 seeds',Icon='🌱'},
 {Key='Harvest',Goal=5,Text='Pick 5 fruit',Icon='🍎'},
 {Key='Sell',Goal=5,Text='Sell 5 fruit',Icon='💰'},
}
-- Every friend in the same server adds 10% walk speed, counting up to 3 friends (+30%).
D.FriendBoostPerFriend=.10;D.FriendBoostMaxFriends=3
local function integer(n,lo,hi)return type(n)=='number'and n==n and n%1==0 and n>=lo and n<=hi end
function D.Day(t)return math.floor((t or os.time())/86400)end
function D.SecondsLeft(t)t=t or os.time();return 86400-math.floor(t)%86400 end
function D.QuestKeys(userId,day)
 local rest={};for i=2,#D.Quests do rest[#rest+1]=i end
 local seed=(math.abs(tonumber(userId)or 0)%1000003)*7919+(tonumber(day)or 0)%100003
 local rng=Random.new(seed)
 for i=#rest,2,-1 do local j=rng:NextInteger(1,i);rest[i],rest[j]=rest[j],rest[i]end
 local keys={1};for i=1,D.QuestsPerDay-1 do keys[#keys+1]=rest[i]end
 return keys
end
-- Saved login state: Step = days claimed this week (0-7), Day = the UTC day of the last claim.
function D.ReadLogin(v)
 if type(v)~='table'or not integer(v.Step,0,#D.Login)or not integer(v.Day,-1,1e7)then return {Step=0,Day=-1}end
 return {Step=v.Step,Day=v.Day}
end
-- Ready = a claim is waiting today; Next = the day (1-7) that claim is; Claimed = days already ticked this week.
function D.LoginStatus(state,day)
 state=D.ReadLogin(state)
 if state.Day==day then return {Ready=false,Next=state.Step,Claimed=state.Step,Day=day}end
 local step=state.Step
 if step>=#D.Login or(D.ResetIfMissed and state.Day>=0 and state.Day<day-1)then step=0 end
 return {Ready=true,Next=step+1,Claimed=step,Day=day}
end
-- Saved quest state for one day: which quests, how far, which were claimed. Another day starts fresh.
function D.ReadQuests(v,day,userId)
 local keys=D.QuestKeys(userId,day)
 local fresh={Day=day,Keys=keys,Progress={},Claimed={}}
 for i=1,#keys do fresh.Progress[i]=0;fresh.Claimed[i]=false end
 if type(v)~='table'or v.Day~=day or type(v.Progress)~='table'or type(v.Claimed)~='table'then return fresh end
 for i,q in ipairs(keys)do
  local goal=D.Quests[q].Goal;local p=v.Progress[i]
  fresh.Progress[i]=integer(p,0,goal)and p or 0
  fresh.Claimed[i]=v.Claimed[i]==true and fresh.Progress[i]>=goal
 end
 return fresh
end
function D.QuestsReady(state)
 local n=0;for i,q in ipairs(state.Keys)do if not state.Claimed[i]and state.Progress[i]>=D.Quests[q].Goal then n+=1 end end;return n
end
function D.FriendMultiplier(count)
 return 1+math.clamp(math.floor(tonumber(count)or 0),0,D.FriendBoostMaxFriends)*D.FriendBoostPerFriend
end
function D.MaxMultiplier()return 1+D.FriendBoostMaxFriends*D.FriendBoostPerFriend end
function D.RewardText(reward)
 if reward.MechPack then return reward.MechPack==1 and'MECH PACK'or reward.MechPack..' MECH PACKS'end
 return '+'..reward.Gems
end
function D.Countdown(seconds)
 seconds=math.max(0,math.floor(seconds));local h=math.floor(seconds/3600);local m=math.floor(seconds%3600/60)
 if h>0 then return h..'h '..m..'m'end;if m>0 then return m..'m '..seconds%60 ..'s'end;return seconds..'s'
end
return D
