-- R151 (owner: "pull announcements ... exclude owner test packs"): a pack that an owner / admin command made is a TEST pack. Its record carries TestGrant=true from the moment it
-- is made, and PullAnnouncer never announces the open of such a pack (in the server or to other servers). Real purchases (Robux Mech / Verity packs), packs from the track, the
-- starter pack and every other normal pack are not marked and still announce.
--  * Direct commands   the command builds the pack: /test pack, /test rarepacks (RarePackTests), packset / eclipse (void) / verity (OwnerUpdateCommands82) set TestGrant on the
--                      record itself (PlayerDataService:AddChest option TestGrant, or Mark for a record the command writes by hand).
--  * Indirect commands the command only makes a normal reward claimable: mystery ready / next, daily next / week / reset / done (the login pack and the quest packs), bonus ready /
--                      progress / roll (a treadmill roll). The command ARMS that source for the player (Arm); the service that makes the pack calls Claim right after it was added,
--                      which marks the record and uses one arm up. An arm lives in this server's memory only, ends after Seconds, and covers `count` packs, so the next day's normal
--                      pack is a normal pack.
--                      R153: the daily rewards have TWO sources, 'Daily' (the login pack) and 'DailyQuest' (a quest pack), so a quest pack claimed first can't use up the arm of the
--                      day-7 Void Pack (one shared source did that). A daily test day lasts until UTC midnight (Arm's `seconds`), not the 15 minutes of the other sources: the
--                      owner may play the quests of a test day for a while before claiming them.
-- Saved with the pack (PlayerDataService:SerializeSeedRecord / _decodeSavedSeedRecord) and kept through gifts and the Void -> Verity conversion. An older server that does not know
-- the field ignores it on load and writes the pack back without it (nothing else changes: no ProfileVersion change).
local T={Field='TestGrant',Sources={Mystery=true,Daily=true,DailyQuest=true,Bonus=true},Seconds=900,MaxCount=20}
local armed=setmetatable({},{__mode='k'})
function T.Mark(record)
 if type(record)=='table'and record.Kind=='Pack'then record.TestGrant=true end
 return record
end
function T.Is(record)return type(record)=='table'and record.TestGrant==true end
-- The next `count` (default 1) packs the service `source` ('Mystery' | 'Daily' | 'DailyQuest' | 'Bonus') makes for this player are TEST packs (for `seconds`, default Seconds).
function T.Arm(player,source,count,now,seconds)
 if not player or not T.Sources[source]then return false end
 count=math.clamp(math.floor(tonumber(count)or 1),0,T.MaxCount)
 local row=armed[player]
 if count<=0 then if row then row[source]=nil end;return false end
 seconds=tonumber(seconds)
 if not seconds or seconds~=seconds or seconds<1 then seconds=T.Seconds end
 seconds=math.min(seconds,86400)
 if not row then row={};armed[player]=row end
 row[source]={Left=count,Expires=(now or os.clock())+seconds}
 return true
end
function T.Disarm(player,source)local row=armed[player];if row then row[source]=nil end end
function T.Armed(player,source,now)
 local row=armed[player];local entry=row and row[source]
 return entry~=nil and(now or os.clock())<=entry.Expires
end
-- Uses one arm up: true when this pack is a TEST pack.
function T.Take(player,source,now)
 local row=armed[player];local entry=row and row[source];if not entry then return false end
 if(now or os.clock())>entry.Expires then row[source]=nil;return false end
 entry.Left-=1;if entry.Left<=0 then row[source]=nil end
 return true
end
-- Called by the service that just added `record` to the player's bag: marks it when the source was armed. Returns the record (as given).
function T.Claim(player,source,record)
 if type(record)=='table'and T.Take(player,source)then T.Mark(record)end
 return record
end
return T
