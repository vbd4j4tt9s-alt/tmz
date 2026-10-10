-- V140 display copy only. Validation messages, remote payloads and saved IDs stay intact.
-- R152 (owner: "for any text in the game just type it like how I talk"): the short texts below are in the owner's voice; old -> new in docs/proposals/R152/game_text.md.
local Text = {}
Text.Red = Color3.fromRGB(255, 55, 65)
Text.Green = Color3.fromRGB(65, 235, 125)
Text.Yellow = Color3.fromRGB(255, 215, 70)
Text.Blue = Color3.fromRGB(145, 220, 255)
local copy = {}
local function add(short, tone, originals)
    for _, original in ipairs(originals) do copy[original] = {short, tone} end
end
add("TOO CLOSE! MOVE A BIT", "Red", {"LEAVE MORE ROOM BETWEEN PLANTS"})
add("TOO NEAR THE EDGE!", "Red", {"PLANT A LITTLE FARTHER FROM THE EDGE"})
add("GET CLOSER!", "Red", {"MOVE CLOSER TO THIS PLANTING SPOT"})
add("ONLY IN YOUR GARDEN!", "Red", {"PLANT ON SOIL IN YOUR OWN GARDEN", "RETURN TO YOUR OWN GARDEN", "RETURN TO YOUR GARDEN FIRST"})
add("AIM AT THE SOIL!", "Red", {"AIM AT SOIL IN YOUR GARDEN", "AIM AT THE TOP OF THE SOIL", "KEEP A CLEAR VIEW OF THE SOIL"})
add("HOLD A SEED FIRST!", "Red", {"EQUIP A SEED AND AIM AT YOUR SOIL", "EQUIP THAT SEED BEFORE PLANTING"})
add("STEP BACK A BIT!", "Red", {"STEP BACK AND AIM AT THE SOIL"})
add("WAIT A SEC!", "Yellow", {"PLEASE WAIT A MOMENT", "GARDEN IS NOT READY", "Please wait."})
add("FINISH THAT FIRST!", "Red", {"FINISH YOUR CURRENT ACTION FIRST"})
add("STILL GROWING... 🌱", "Yellow", {"YOUR PLANT IS STILL GROWING"})
add("MAKE ROOM IN YOUR BAG FIRST!", "Red", {"SEED INVENTORY FULL", "BAG FULL - MAKE ROOM IN YOUR BAG FIRST"})
add("BAG FULL! MAKE ROOM FIRST", "Red", {"BAG FULL! MAKE ROOM FIRST"}) -- R157: the Mech shop's full-Bag text (MechCatalog.BagFull.Notice): red like the other bag refusals
add("BAG FULL! SELL SOME CROPS!", "Red", {"HARVEST BAG FULL — SELL SOME HARVESTS FIRST"})
add("THAT SEED IS GONE!", "Red", {"THAT SEED IS NO LONGER IN YOUR INVENTORY"})
add("NOT READY YET!", "Red", {"THIS SEED CANNOT BE PLANTED YET", "THIS SEED NEEDS A TUNING FIX"})
add("REJOIN TO UPDATE!", "Red", {"THIS PLANT NEEDS A NEWER UPDATE", "THIS HARVEST NEEDS A NEWER UPDATE"})
add("THAT CROP IS GONE!", "Red", {"THAT HARVEST WAS ALREADY SOLD OR IS NOT YOURS"})
add("CASH IS MAXED OUT!", "Red", {"CASH LIMIT REACHED"})
add("LOADING... ⏳", "Blue", {"PLAYER DATA IS STILL LOADING", "YOUR DATA IS STILL LOADING", "YOUR SEED IS STILL LOADING — TRY AGAIN", "THAT ITEM TOOL IS STILL LOADING - TRY AGAIN"})
add("TRY AGAIN!", "Red", {"INVALID GARDEN REQUEST", "YOUR CHARACTER CHANGED — TRY AGAIN", "THIS REQUEST WAS ALREADY HANDLED", "INVALID PLANT POSITION", "INVALID PLANT", "THIS PLANT HAS CHANGED — TRY AGAIN", "INVALID PLANT REQUEST", "INVALID HARVEST REQUEST", "INVALID HARVEST", "GARDEN DID NOT RESPOND — TRY AGAIN", "THE SERVER DID NOT RESPOND - TRY AGAIN", "REQUEST FAILED", "UNKNOWN SHOP ITEM", "PURCHASE COULD NOT BE APPLIED", "INVALID ITEM", "ITEM NOT FOUND"})
add("GET TO YOUR BASE FIRST!", "Red", {"FINISH YOUR CHASE FIRST", "FINISH YOUR RUN FIRST", "FAST TRAVEL IS DISABLED WHILE CARRYING A SEED", "STATION TRAVEL IS DISABLED DURING A CHASE"})
add("NO FREE BASE YET!", "Red", {"NO EMPTY BASE IS AVAILABLE", "YOU DO NOT HAVE AN ASSIGNED BASE"})
add("COULDN'T SAVE THE SEED!", "Red", {"SEED COULD NOT BE STORED"})
add("COULDN'T SAVE THE PACK!", "Red", {"PACK COULD NOT BE STORED"})
add("GO TO THE SHOP FIRST! 🛒", "Red", {"VISIT THE BUY STATION FIRST"})
add("GO TO SELL FIRST! 💰", "Red", {"VISIT THE SELL STATION FIRST"})
add("COMING SOON!", "Yellow", {"THIS GEAR IS COMING SOON", "CASH PEDESTALS HAVE BEEN REMOVED"})
add("YOU ALREADY HAVE THIS! ✅", "Yellow", {"YOU ALREADY OWN THIS"})
add("NOT ENOUGH CASH!", "Red", {"NOT ENOUGH CASH"})
add("SAVE ISN'T READY YET!", "Red", {"Your save is not ready."})
add("PICK AN ITEM FIRST!", "Red", {"Choose an item."})
add("GO TO THE SHOP OR SELL SPOT!", "Red", {"VISIT THE SHOP OR SELL STATION"})
add("BUY IT FIRST!", "Red", {"Buy this item first."})
add("TRAINING IS PAUSED!", "Yellow", {"TRAINING PAUSED"})
add("🎁 BONUS ROLL READY! TAP IT", "Yellow", {"🎁 Treadmill bonus roll ready!"})
-- Keep the consequence clear; publishing/API instructions belong in Studio Output.
add("SAVING IS OFF!", "Red", {"SAVING IS OFF - PUBLISH THE GAME AND ENABLE STUDIO API SERVICES"})
add("DATA ERROR! NOT SAVING", "Red", {"PLAYER DATA COULD NOT LOAD - SAVING IS DISABLED THIS SESSION"})
-- V106: exact presentation policy; never hides validation/data errors or alters server results.
local quiet = {
    ["PACK TAKEN - REACH SAFETY! KEEPER IS BUSY"]=true,
    ["PACK RECLAIMED - RUN!"]=true,
    ["CAUGHT! PACK DROPPED"]=true,
    ["ZAP! PACK DROPPED"]=true,
    ["PACK ADDED TO YOUR GARDEN INVENTORY"]=true,
    ["PACK LOST - RETURNED TO START"]=true,
    ["BIOMES REFRESHING"]=true, -- The entrance wall already displays this state.
    ["SEED TAKEN - REACH SAFETY! KEEPER IS BUSY"]=true,
    ["SEED RECLAIMED - RUN!"]=true,
    ["CAUGHT! SEED DROPPED"]=true,
    ["ZAP! SEED DROPPED"]=true,
    ["SEED ADDED TO YOUR GARDEN INVENTORY"]=true,
    ["SEED LOST - RETURNED TO START"]=true,
    ["RETURNED TO EXPEDITION START"]=true,
    ["ESCAPE FAILED - TRY AGAIN"]=true,
}
function Text.Format(message)
    if type(message) ~= "string" then return "", nil end
    if quiet[message] or message:match("^CAUGHT! SEED DROPPED FOR %d+ SECONDS$")
        or message:match("^CAUGHT! PACK DROPPED FOR %d+ SECONDS$")
        or message:match("^RETURNED TO BASE %d+$") then return "", nil end
    local entry = copy[message]
    if entry then return entry[1], Text[entry[2]] end
    if message:match(" planted!$") then return "PLANTED! 🌱", Text.Green end
    if message:match(" harvested! Visit Sell to earn cash%.$") then return "PICKED! 🌾", Text.Green end
    if message:match("^PURCHASED ") then return "BOUGHT! ✅", Text.Green end
    local cash = message:match("^HARVEST SOLD  %+%$(%d+)$") or message:match("^SOLD FOR %$(%d+) CASH$")
    if cash then return "SOLD! +$"..cash.." 💰", Text.Green end
    return message, nil -- Preserve unknown custom text and player/item names.
end
return Text
