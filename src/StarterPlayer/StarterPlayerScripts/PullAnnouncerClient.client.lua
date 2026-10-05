-- R151 (owner: "serverwide messages saying who pulled what and so on and a in server announcement"; then: "pull announcement should only be said in chat"): pull announcements, the CLIENT half.
-- The server (PullAnnouncer) decides and sends {Kind='Pull'|'Global'|'Record', ...} through ChestChaseRemotes.PullAnnounce151; this script only writes the chat line and
-- nothing it does can start an announcement. Every payload is sanitised again (PullAnnounceRules.Event: the rarity comes from the local seed catalog).
--  * Chat only   one system line on RBXGeneral (TextChatService:DisplaySystemMessage, rich text) per announcement: a pull in this server in its rarity colour
--                ("🌟 Ann pulled a MYTHIC Fire Pepper! (1/800)"), a pull in another server in gold ("🌐 Ann pulled a SECRET Obsidian Maw (1/1,000)!"), a record in amber
--                ("🏆 Ann took BEST PULL TODAY!"). Every part of the line is escaped. No Gui, no banner, no sound, no picture, no per-frame work: the script only
--                waits for the remote.
--  * Once        an announcement id is remembered (the last 128), so the same line never shows twice on one client; at most ChatBurst lines per ChatWindow seconds.
--  * Old chat    only when there is no RBXGeneral channel (the legacy chat) or writing to it failed: the same sentence as a plain coloured line (SetCore ChatMakeSystemMessage).
-- Timing is the server's: it sends everyone in the server the line once the puller's reveal has finished.
local RS=game:GetService('ReplicatedStorage');local StarterGui=game:GetService('StarterGui')
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
local function receive(payload)
 if dead or type(payload)~='table'then return end
 local e=Rules.Event(payload.Kind,payload)
 if not e or not e.Id or not remember(e.Id)then return end
 chat(e)
end
connection=remote.OnClientEvent:Connect(receive)
script.Destroying:Connect(function()
 dead=true
 if connection then connection:Disconnect();connection=nil end
end)
