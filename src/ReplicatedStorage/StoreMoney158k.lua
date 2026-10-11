-- R158k (owner: "players can't purchase things in the store when their money is sufficient enough", then "if clicking on something and players don't have
-- enough money, it just tells the player not enough cash"): ONE rule for "can this balance pay this price" and ONE pair of words for "it can't", shared by
-- the server (the source of truth: PlayerDataService.SpendCash, the gem checks in PremiumProgress / PassGiftService) and every store screen (the market's
-- trails / boots, the shop's gem buttons and Cash to Gems, the treadmill / fence pads).
-- Amounts are whole: a number is floored (the server charges math.floor of a price; a balance is an IntValue or a whole Gems count), a plain digit string is
-- exact at any size (compared digit by digit, never through a float), other text goes through tonumber ("1e+20"), and anything else (nil, NaN, inf, a negative,
-- a word) is NOT KNOWN: CanAfford answers nil and a screen leaves the answer to the server.
local M={Version='158k',Cash='Not enough cash!',Gems='Not enough gems!',
 PriceChanged='The price changed! Check the new price.'} -- (owner: "make sure store prices are always the same": a press whose shown price is not the server's is refused with these words, nothing charged)
-- the whole amount as exact decimal digits ("0", "10350000", ...), or nil when it is not an amount
function M.Whole(v)
 if type(v)=='string'then
  if v:match('^%d+$')then local s=v:gsub('^0+','');return s~=''and s or'0'end
  v=tonumber(v)
 end
 if type(v)~='number'or v~=v or v<0 or v==math.huge then return nil end
 if v<1 then return'0'end -- (also -0, which '%.0f' writes as "-0")
 return string.format('%.0f',math.floor(v))
end
-- -1 / 0 / 1 for two Whole() texts
function M.Compare(a,b)
 if #a~=#b then return #a<#b and -1 or 1 end
 return a==b and 0 or(a<b and -1 or 1)
end
-- true = the balance pays the price (equal money pays), false = it does not, nil = one of them is not an amount
function M.CanAfford(balance,price)
 local b,p=M.Whole(balance),M.Whole(price)
 if not b or not p then return nil end
 return M.Compare(b,p)>=0
end
function M.Words(currency)return currency=='Gems'and M.Gems or currency=='Price'and M.PriceChanged or M.Cash end
-- A server's money refusal (these words, or the ones a server sent before R158k) -> 'Cash' / 'Gems' ('Price': the shown price was not the server's); anything else
-- (Bag full, already owned, max level, wait) -> nil.
local refusals={['Not enough cash!']='Cash',['NOT ENOUGH CASH']='Cash',['NOT ENOUGH CASH!']='Cash',['Not enough gems!']='Gems',['NOT ENOUGH GEMS']='Gems',['Not enough Gems!']='Gems',
 [M.PriceChanged]='Price'}
function M.Refusal(message)return type(message)=='string'and refusals[message]or nil end
-- What a shop request costs and in what (the shop's gem buttons and Cash to Gems), from the shared catalogs every screen and the server read: 'Gems' / 'Cash', price;
-- nil for a request that is not paid with in-game money (Robux, claims, State). One function, so the shown price and the charged price are the same number.
function M.PriceOf(action,value)
 local RS=game:GetService('ReplicatedStorage');local Catalog=require(RS:WaitForChild('MechCatalog'))
 if action=='BuyPack'then local offer=Catalog.Offer(value);return'Gems',offer and offer.GemPrice
 elseif action=='BuyBundle'then local row=require(RS:WaitForChild('PremiumPricing')).Find(type(value)=='table'and value.Key or value);return'Gems',row and row.GemPrice
 elseif action=='BuyPerk'then return'Gems',Catalog.PassGemPrices[value]
 elseif action=='Convert'then return'Cash',type(value)=='number'and value==value and value%1==0 and value>=1 and value<=9000 and value*Catalog.CashPerGem or nil end
 return nil,nil
end
-- Client: the balance this player's screen shows (the HUD's Cash stat, ChestChaseStats.Cash, or its Gems attribute), only once the profile has loaded
-- (DataStatus Loaded); nil = not known yet, and then no screen refuses on its own.
function M.Balance(player,currency)
 if not player or player:GetAttribute('DataStatus')~='Loaded'then return nil end
 if currency=='Gems'then local gems=player:GetAttribute('Gems');return type(gems)=='number'and gems or nil end
 local stats=player:FindFirstChild('ChestChaseStats');local cash=stats and stats:FindFirstChild('Cash')
 return cash and type(cash.Value)=='number'and cash.Value or nil
end
-- Client: true only when the balance is known and does not pay the price (the screen then says the words itself and sends nothing).
function M.Short(player,currency,price)return M.CanAfford(M.Balance(player,currency),price)==false end
-- Client: the one answer to a press the money cannot pay: the Denied click (every press) and the plain red notice (once per .7 s per wording, like the Bag full press).
local lastNotice={}
function M.Notice(currency)
 local RS=game:GetService('ReplicatedStorage');local words=M.Words(currency)
 pcall(function()require(RS:WaitForChild('InteractionAudio')).Play('Denied')end)
 local now=os.clock();if now-(lastNotice[words]or -10)<.7 then return false end;lastNotice[words]=now
 local shown=pcall(function()require(RS:WaitForChild('NoticeFeed83')).Plain(words,require(RS:WaitForChild('SimpleGameText')).Red,2.5)end)
 return shown
end
return M
