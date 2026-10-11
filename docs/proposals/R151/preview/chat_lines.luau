--!nocheck
-- R151 preview (not a test): runs the REAL PullAnnouncerClient (and the real PullAnnounceRules) under the Roblox mock, sends it one announcement of each kind and prints one line per
-- chat line it writes to RBXGeneral: LINE <rich text exactly as DisplaySystemMessage receives it>. run_announce_preview.sh draws those lines in a chat window (render_chat.mjs).
local W=require('./world');local R=W.R
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.DisplayName='Me D';me.UserId=1;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.service('StarterGui')
local Packs=W.module('SeedPackRules')
local TCS=W.service('TextChatService')
local channels=R.new('Folder');channels.Name='TextChannels';channels.Parent=TCS
local general=R.new('Folder');general.Name='RBXGeneral';general.Parent=channels
general.DisplaySystemMessage=function(_,text)print('LINE '..text)end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';remote.OnClientEvent=R.signal();remote.Parent=remotes
local script=R.new('LocalScript');script.Name='PullAnnouncerClient'
W.load('PullAnnouncerClient',script)
local function seed(rarity)for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)==rarity then return spec.id end end end
local serial=0
local function send(kind,seedId,extra)
 serial+=1
 local p={Kind=kind,Id='pv-'..serial,UserId=100+serial,Name='Ava',SeedId=seedId,Odds=800}
 for k,v in pairs(extra or{})do p[k]=v end
 remote.OnClientEvent:Fire(p)
end
send('Pull',seed('Legendary'),{Odds=250,Name='Ava'})
send('Pull',seed('Mythic'),{Odds=800,Name='Max'})
send('Pull',seed('Secret'),{Odds=12500,Name='Zoe'})
send('Pull',seed('Cosmic'),{Odds=240000,Name='Kai'})
send('Pull',seed('King'),{Odds=1e6,Name='Mia'})
send('Global',seed('Secret'),{Odds=12500,Name='Nova'})
send('Record',seed('Mythic'),{Record='BestPull',Name='Rex'})
