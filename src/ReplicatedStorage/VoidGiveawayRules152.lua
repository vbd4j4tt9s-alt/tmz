-- R152 (owner: "add a pedestal in the middle that gives a player 1 void pack. it will be a limited time for 500 players only and its in every server so basically once
-- serverwide 500 claims have been done it will go to 0 and will not be claimable any more. there is a number above that shows how many is left"): the numbers, texts and the
-- one reservation rule shared by VoidGiveaway152 (the server service), VoidGiveawayStore152 (the DataStore), VoidGiveawayArt152 (the pedestal) and VoidGiveawayClient152 (the
-- number, the pack, the prompt). No Instances, no services: pure.
--  * The shared value (one DataStore key, every server): {Count = n, Users = {[tostring(userId)] = unix time}}. About 30 bytes a claim, 15 KB at 500.
--  * Reserve is the transform of that key's UpdateAsync. UpdateAsync runs it again on the fresh value if another server wrote in between, so two servers can never push the
--    count past the cap, and a user already in Users is never counted twice (the retry after an interrupted grant is the same reservation).
local R={Version=152}
R.Cap=500
R.StoreName='VoidGiveaway152';R.StudioStoreName='VoidGiveaway152_Studio' -- (Studio sessions never touch the live key, like the player data's own _Studio store)
R.Key='Claims';R.Topic='VoidGiveaway152'
R.MinAccountAgeDays=0 -- 0 = off (the owner decides): above 0, Claim refuses an account younger than this many days (Player.AccountAge). The pack is also GiftLocked (FruitGiftService).
R.ModelName='VoidGiveaway152';R.Tag='VoidGiveaway152'
R.Flag='VoidGift152' -- Premium.VoidGift152 = true: this profile has had its pack (an optional field of the saved Premium table: no ProfileVersion change)
R.Pack={Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',Weather='None'} -- the Void Pack, exactly as the track / Verity know it (VerityConfig.VoidVariant, stage 7)
-- Attributes. The pedestal model: Cap, Count (claims so far), Left (Cap - Count), State = Loading (the first read has not come back) / Open / Empty (all claimed, for ever).
-- The player: VoidGift152 = Open / Busy (a claim is in flight) / Claimed; VoidGiftAt152 = the server time of a pack just given (the client's claim moment).
R.Attr={Cap='Cap',Count='Count',Left='Left',State='State',Player='VoidGift152',At='VoidGiftAt152'}
-- R157 (owner: "make it so that the void pack is only claimable after playing for 20 minutes"): a player must have played MinPlaySeconds IN TOTAL (every visit counts) before a claim is
-- accepted. The server counts it in the optional saved field Premium.PlaySeconds157 (whole seconds, no ProfileVersion change: an old save has none and reads as 0; an older server keeps
-- the field it does not know) and publishes what is left on the player as VoidPlayLeft157 (seconds, rounded UP to a whole minute, so it changes once a minute; 0 = the claim is open;
-- no attribute = the counter is not loaded yet, which is "not ready yet", never a refusal). A player the giveaway already reserved a pack for (owed) is not held up by this rule.
R.MinPlaySeconds=20*60
R.PlayField='PlaySeconds157'
R.PlayCap=3*3600 -- counted up to here (nothing needs more; a few hours of room if the rule is ever raised)
R.Attr.PlayLeft='VoidPlayLeft157'
R.PlayRefusal='play %d more min to get your free void pack!' -- the refusal notice (%d = whole minutes left, rounded up)
R.PlayHint='play %d more min to claim' -- the small line on the sign under the number, for a player who has not played long enough
R.PlayLoading='your play time is still loading. try again in a sec!' -- (the counter is not ready: not a number of minutes, never an error)
-- Where: the middle of the hub's plaza (HubDecor151 "Fountain plaza": a brick disc, 21 studs across the radius, centre X 0 / Z -392, top .26 over the lobby floor).
R.Center=Vector3.new(0,0,-392);R.FloorTop=4;R.PlazaRise=.26
-- Studs above the plaza for what the client hangs on the pedestal (VoidGiveawayArt152 builds the stone below them). Scale = how big the stone is (1 = the first design; the plaza is
-- 21 studs from its middle to its edge, the old fountain was 22 across).
R.Scale=1.2
R.PackHeight=17.0;R.PackSize=7.7  -- the pack's centre when it floats, and its height (halo included) on screen
R.PackBob=.36;R.PackSpin=.45      -- the hover (studs) and the slow turn (radians a second: one lap in about 14 s)
R.SignGap=1.4;R.Sign={W=20,H=8}   -- the sign's bottom edge is SignGap over the pack's highest point; its size in studs
R.SignNear=30                     -- closer than this the sign stops growing (BillboardGui.DistanceLowerLimit), so it is never huge up close
R.SignFar=320                     -- and it shows up to here (it reads from across the plaza and well past it)
-- Texts. The number is "<n> / <cap> LEFT" ("487 / 500 LEFT").
R.Title='FREE VOID PACK';R.TitleDone='ALL CLAIMED';R.Loading='…';R.Hint='LIMITED! 1 PER PLAYER';R.Mine='CLAIMED ✓';R.Busy='CLAIMING…'
R.PromptAction='Grab ur FREE Void Pack';R.PromptObject='Void Pack giveaway'
local function whole(n)
 if type(n)~='number'or n~=n or n<0 then return 0 end
 return math.floor(math.min(n,1e9))
end
R.Whole=whole
function R.Left(count,cap)cap=cap or R.Cap;return math.clamp(cap-whole(count),0,cap)end
function R.LeftText(left,cap)
 if left==nil then return R.Loading..' / '..tostring(cap or R.Cap)..' LEFT'end
 return string.format('%d / %d LEFT',left,cap or R.Cap)
end
-- R157: the play time. A saved value made clean: whole seconds from 0 to PlayCap (nothing, a string, NaN or a negative number reads as 0).
function R.CleanPlayed(v)
 if type(v)~='number'or v~=v then return 0 end
 return math.floor(math.clamp(v,0,R.PlayCap))
end
-- Seconds still to play before a claim is accepted (0 = long enough), and the same as whole minutes rounded up (a player with 1 s to go is told "1 more min").
function R.PlayWait(played)return math.max(0,R.MinPlaySeconds-R.CleanPlayed(played))end
function R.PlayMinutes(seconds)return math.ceil(math.max(0,seconds)/60)end
-- What the server publishes (VoidPlayLeft157): the wait rounded up to a whole minute, so the attribute (and the client's line) change once a minute, not every second.
function R.PlayShown(played)return R.PlayMinutes(R.PlayWait(played))*60 end
function R.PlayRefusalText(played)return string.format(R.PlayRefusal,R.PlayMinutes(R.PlayWait(played)))end
function R.PlayHintText(minutes)return string.format(R.PlayHint,minutes)end
-- Any value read from the store, made clean: Count a whole number at least as big as the number of users, Users a table of canonical user-id strings to numbers. Returns a NEW table.
function R.Clean(value)
 local users,n={},0
 if type(value)=='table'and type(value.Users)=='table'then
  for key,at in pairs(value.Users)do
   local id=type(key)=='string'and tonumber(key)
   if id and id>=1 and id<1e14 and id%1==0 and tostring(id)==key and type(at)=='number'and at==at then users[key]=at;n+=1 end
  end
 end
 local count=type(value)=='table'and whole(value.Count)or 0
 return{Count=math.max(count,n),Users=users}
end
-- The transform of UpdateAsync. Returns value, outcome, current:
--   outcome 'already' - the user is in Users (an earlier claim, maybe one whose pack never arrived): value nil (nothing to write: the stored value stays exactly as it is),
--   outcome 'full'    - Count is at the cap: value nil (nothing is written; refused),
--   outcome 'new'     - the user is added and Count + 1: value is the new table.
-- `current` is the state after the call (the new table, or what was seen): the caller keeps it as its picture of the store. It runs again on a retry, so it keeps no state.
function R.Reserve(old,userId,now,cap)
 local v=R.Clean(old);local key=tostring(userId)
 if v.Users[key]~=nil then return nil,'already',v end
 if v.Count>=(cap or R.Cap)then return nil,'full',v end
 v.Users[key]=math.floor(tonumber(now)or 0);v.Count+=1
 return v,'new',v
end
return R
