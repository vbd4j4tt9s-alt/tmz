do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R151 (owner: "serverwide messages saying who pulled what and so on and a in server announcement"; then: "pull announcement should only be said in chat"): pull announcements, the CLIENT half.
-- The server (PullAnnouncer) decides and sends {Kind='Pull'|'Global'|'Record', ...} through ChestChaseRemotes.PullAnnounce151; this script only writes the chat line and
-- nothing it does can start an announcement. Every payload is sanitised again (PullAnnounceRules.Event: the rarity comes from the local seed catalog).
--  * Chat only   one system line on RBXGeneral (TextChatService:DisplaySystemMessage, rich text) per announcement: a pull in this server in its rarity colour
--                ("🌟 Ann pulled a MYTHIC Fire Pepper! (1/800)"), a pull in another server in gold ("🌐 Ann pulled a SECRET Obsidian Maw (1/1,000)!"), a record in amber
--                ("🏆 Ann took BEST PULL TODAY!"). Every part of the line is escaped. No Gui, no banner, no sound, no picture, no per-frame work: the script only
--                waits for the remote.
--  * Once        an announcement id is remembered (the last 128), so the same line never shows twice on one client; at most ChatBurst lines per ChatWindow seconds.
--  * Old chat    only when there is no RBXGeneral channel (the legacy chat) or writing to it failed: the same sentence as a plain coloured line (SetCore ChatMakeSystemMessage).
--  * Timing      is the server's: it sends everyone the line once the PULLER's reveal has shown the seed (PullAnnounceRules.RevealDelay, from the tables this client plays its reveal
--                with). The one thing added here is a safety net for the puller's own screen: a line about THIS player that arrives before their cinematic's hit (the attribute
--                RarePullClimaxAt, kept up to date by RarePullCinematic, also on a skip) plus the margin waits for it, so a slow device never shows the result in chat first.
local RS=game:GetService('ReplicatedStorage');local StarterGui=game:GetService('StarterGui');local Players=game:GetService('Players')
local Rules=require(RS:WaitForChild('PullAnnounceRules'))
local folder=RS:WaitForChild('ChestChaseRemotes',120);local remote=folder and folder:WaitForChild(Rules.RemoteName,120)
if not remote then return end
local dead=false;local connection
local chatChannel;local chatLog={}
local seen,seenOrder={},{}
-- true the first time an id is seen (the server always sends one; an event without an id is dropped by the caller)
local function remember(id)
 if seen[id]then return false end
 seen[id]=true;table.insert(seenOrder,id);if#seenOrder>128 then seen[table.remove(seenOrder,1)]=nil end
 return true
end
local function channel()
 if chatChannel and chatChannel.Parent then return chatChannel end
 local ok,found=pcall(function()
  local channels=game:GetService('TextChatService'):FindFirstChild('TextChannels')
  return channels and channels:FindFirstChild('RBXGeneral')
 end)
 chatChannel=ok and found or nil;return chatChannel
end
local function chat(e)
 if not Rules.ChatAllowed(chatLog,os.clock())then return end
 local target=channel()
 if target then
  local ok=pcall(function()target:DisplaySystemMessage(Rules.Chat(e),'PullAnnounce151')end)
  if ok then return end -- (one line: the old chat below is only for when this did not work)
 end
 pcall(function()StarterGui:SetCore('ChatMakeSystemMessage',{Text=Rules.Plain(e),Color=Rules.ChatColor(e),Font=Enum.Font.GothamBold,FontSize=Enum.FontSize.Size18})end)
end
-- Seconds a line about this very player waits for their own reveal (0 = none: someone else's line, a line from another server, no cinematic running, or its hit has passed).
local HOLD_MAX=8
local function holdFor(e)
 local me=Players.LocalPlayer
 if not me or e.Kind=='Global'or e.UserId~=me.UserId then return 0 end
 -- R152: the moment the reveal has SHOWN the seed (title, seed, "1 in N" slammed); the hit alone came up to .85 s before it in the story
 -- scenes, so a line held only for the hit + margin could still show in chat before the seed on a slow device
 local at=me:GetAttribute('RarePullClimaxAt');local shown=me:GetAttribute('RarePullSeedShownAt')
 if type(shown)=='number'and shown==shown and(type(at)~='number'or at~=at or shown>at)then at=shown end
 if type(at)~='number'or at~=at then return 0 end
 return math.clamp(at+Rules.Setting('RevealMargin')-workspace:GetServerTimeNow(),0,HOLD_MAX)
end
-- R153: a held line goes out as soon as the puller's reveal has shown the seed: the wait is checked again whenever the reveal moves that
-- moment (a skip shows the seed sooner: RarePullSeedShownAt / RarePullClimaxAt change), and never runs past the first wait.
local held={}
local function release()
 if dead then return end
 local i=1
 while i<=#held do local h=held[i];if holdFor(h.E)<=0 or os.clock()>=h.Until then table.remove(held,i);chat(h.E)else i+=1 end end
end
local function receive(payload)
 if dead or type(payload)~='table'then return end
 local e=Rules.Event(payload.Kind,payload)
 if not e or not e.Id or not remember(e.Id)then return end
 local wait=holdFor(e)
 if wait>0 then held[#held+1]={E=e,Until=os.clock()+wait};task.delay(wait,release)else chat(e)end
end
connection=remote.OnClientEvent:Connect(receive)
local watching={};local me=Players.LocalPlayer
if me then
 for _,name in ipairs({'RarePullSeedShownAt','RarePullClimaxAt'})do
  watching[#watching+1]=me:GetAttributeChangedSignal(name):Connect(function()
   if #held==0 then return end
   release();for _,h in ipairs(held)do local w=math.min(holdFor(h.E),h.Until-os.clock());if w>0 then task.delay(w,release)end end
  end)
 end
end
script.Destroying:Connect(function()
 dead=true
 if connection then connection:Disconnect();connection=nil end
 for _,c in ipairs(watching)do c:Disconnect()end
end)
