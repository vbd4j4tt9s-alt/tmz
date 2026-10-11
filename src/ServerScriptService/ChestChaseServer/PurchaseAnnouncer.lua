-- R148 (owner: "remove this line when purchasing and add the vfx and sfx and also the notification for making a successful
-- purchase"): the one place that tells the buyer, and only the buyer, that a purchase just landed.
--  * the "✅ Purchased: <what>!" notice goes through the game's notification service (data.Notifications:Show, the same
--    Notice83 stack every other message uses), and
--  * ChestChaseRemotes.PurchaseDone {Kind, Name} is fired at the buyer so PurchaseCelebration.client.lua plays the reward
--    chime and the sparkle burst.
-- Callers announce only AFTER the purchase is committed (a saved receipt, a finished game-pass prompt, a gem spend that went
-- through), and a failure in here never touches the purchase: every step is pcall'd and Announce just returns false.
-- Kinds: Pack (arg = Mech pack count), Bundle (arg = PremiumPricing key), Pass (arg = GamePassCatalog key),
-- Gift (arg = pass key, a gift credit), Gems (arg = how many Gems the Cash became).
local RS=game:GetService('ReplicatedStorage')
local Mech=require(RS.MechCatalog);local Pricing=require(RS.PremiumPricing);local Passes=require(RS.GamePassCatalog);local Numbers=require(RS.CashNumbers)
local A={};A.__index=A
A.Color=Color3.fromRGB(150,255,110);A.Seconds=4
local function plural(n,one,many)return n==1 and one or many end
local function pass(key)for _,row in ipairs(Passes)do if row.Key==key then return row end end end
-- The bundle amount reads the way its shop card does: 250K / 1M / 30B / 1.4T.
local function amount(n)
 if n>=1000 and n<1000000 then return(string.format('%.1f',n/1000):gsub('%.0$',''))..'K'end
 return Numbers.Compact(n)
end
-- Plain words for the item, from the catalogs. nil for anything unknown (nothing is announced then).
function A.Name(kind,arg)
 if kind=='Pack'then
  local offer=Mech.Offer(arg);if offer then return offer.Count..' Mech '..plural(offer.Count,'Pack','Packs')end
 elseif kind=='Bundle'then
  local row=Pricing.Find(type(arg)=='table'and arg.Key or arg)
  if row then return '+'..amount(row.Amount)..' '..(row.Kind=='Cash'and'Cash'or'Speed')end
 elseif kind=='Pass'then
  local row=pass(arg);if row then return row.Name..' Pass'end
 elseif kind=='Gift'then
  local row=pass(arg);if row then return row.Name..' Gift'end
 elseif kind=='Gems'then
  if type(arg)=='number'and arg==arg and arg>=1 and arg<=1000000 and arg%1==0 then return Numbers.Exact(arg)..' '..plural(arg,'Gem','Gems')end
 end
 return nil
end
function A.new(data)
 local folder=RS:WaitForChild('ChestChaseRemotes')
 local remote=folder:FindFirstChild('PurchaseDone')
 if not remote then remote=Instance.new('RemoteEvent');remote.Name='PurchaseDone';remote.Parent=folder end
 return setmetatable({Data=data,Remote=remote},A)
end
-- R155: how many of the packs just granted came coated (their records, PackMutation): "" when none did, else " ✨ GOLD MECH PACK!" / " 💎 DIAMOND MECH PACK!" for one, and
-- " ✨ 2 GOLD + 💎 1 DIAMOND!" for several (the coats NoticeCopy83 already marks with ✨ and 💎). The same notice as always, one line; plain packs say nothing extra.
function A.CoatText(records)
 if type(records)~='table'then return''end
 local gold,diamond=0,0
 for _,r in ipairs(records)do if type(r)=='table'then if r.PackMutation=='Gold'then gold+=1 elseif r.PackMutation=='Diamond'then diamond+=1 end end end
 if gold+diamond==0 then return''end
 if gold+diamond==1 and #records==1 then return gold==1 and' ✨ GOLD MECH PACK!'or' 💎 DIAMOND MECH PACK!'end
 local words={}
 if gold>0 then words[#words+1]='✨ '..gold..' GOLD'end
 if diamond>0 then words[#words+1]='💎 '..diamond..' DIAMOND'end
 return' '..table.concat(words,' + ')..'!'
end
local function coatSuffix(extra)local ok,text=pcall(A.CoatText,extra);return ok and type(text)=='string'and text or''end
-- True when the buyer was sent the event (the notice is best effort next to it). extra (optional, R155): a Mech grant's records (CoatText).
function A:Announce(player,kind,arg,extra)
 local okay,name=pcall(A.Name,kind,arg)
 if not okay or type(name)~='string'or not player or not player.Parent then return false end
 -- R153: a pass with an Emoji (the 4 Leaf Clover 🍀) shows it in the line, and its Icon key goes to the client (PurchaseCelebration pops that picture); the other passes send exactly what they did.
 local row=(kind=='Pass'or kind=='Gift')and pass(arg)or nil
 local notices=self.Data and self.Data.Notifications
 if notices then pcall(notices.Show,notices,player,'✅ Bought: '..(row and row.Emoji and row.Emoji..' 'or'')..name..'!'..(kind=='Pack'and coatSuffix(extra)or''),A.Color,A.Seconds)end
 return(pcall(self.Remote.FireClient,self.Remote,player,{Kind=kind,Name=name,Icon=row and row.Icon or nil}))
end
return A
