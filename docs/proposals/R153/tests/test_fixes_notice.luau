--!nocheck
-- R153 start-up notice (architecture_review.md item 4; owner: "if a server fails just kick them out"): the client half. Live servers kick, so this script only ever draws something in Studio, where
-- the server sets ReplicatedStorage.ChestChaseStartupNotice instead of kicking. On the Roblox mock with the REAL StartupNotice153 client script of the tree under test.
--  [A4] nothing on screen without the attribute; the text of the attribute on screen while it is a non-empty string; hidden when cleared; one gui however often it changes; junk ignored;
--       a very long text is cut; it needs no other script, module or server object
local E=require('./clover_env');local W,R,check=E.W,E.R,E.check
local function T(tag)return function(c,msg)return check(c,'['..tag..'] '..msg)end end
local t=T('A4')
local RS=E.RS
local srcText=W.B.StartupNotice153
t(srcText~=nil,'the tree has the client script StartupNotice153')
if srcText then
 local playerGui=R.new('PlayerGui');local me=R.new('Player');me.Name='Me';playerGui.Parent=me
 E.Players.LocalPlayer=me
 local scriptInst=R.new('LocalScript');scriptInst.Name='StartupNotice153'
 local firstLine=srcText:match('^[^\n]*')
 t(firstLine:find('R152: start once the whole game has arrived',1,true)~=nil and firstLine:sub(1,2)=='do','line 1 is the R152 load guard')
 t(not srcText:find('require%(')and not srcText:find('WaitForChild%(\'ChestChaseRemotes')and not srcText:find('RemoteEvent')and not srcText:find('OnClientEvent'),'it needs no module and no remote (a failed server may have none): attribute and PlayerGui only')
 -- the guard line on the mock game (not loaded yet: it waits once)
 W.load('StartupNotice153',scriptInst)
 local function gui()return playerGui:FindFirstChild('StartupNotice153')end
 local function text()local g=gui();local l=g and g:FindFirstChild('Text',true);return l and l.Text end
 t(gui()==nil,'no attribute: nothing is drawn')
 RS:SetAttribute('ChestChaseStartupNotice','this server broke while loading 😭 pls rejoin\n(Studio: not kicking. boom)')
 t(gui()~=nil and gui().Enabled==true and text()=='this server broke while loading 😭 pls rejoin\n(Studio: not kicking. boom)','the server\'s message is on screen')
 t(gui().ResetOnSpawn==false and gui().DisplayOrder>=100,'the gui survives respawns and sits above the others')
 RS:SetAttribute('ChestChaseStartupNotice',nil)
 t(gui().Enabled==false,'cleared: hidden')
 RS:SetAttribute('ChestChaseStartupNotice','second text')
 local count=0;for _,c in ipairs(playerGui:GetChildren())do if c.Name=='StartupNotice153'then count+=1 end end
 t(count==1 and gui().Enabled==true and text()=='second text','changed again: still ONE gui, showing the new text')
 RS:SetAttribute('ChestChaseStartupNotice',42);t(gui().Enabled==false,'a value that is not a string is ignored (hidden)')
 RS:SetAttribute('ChestChaseStartupNotice','');t(gui().Enabled==false,'an empty string is hidden')
 RS:SetAttribute('ChestChaseStartupNotice',string.rep('x',2000));t(#text()<=400,'a very long text is cut to 400 characters ('..#text()..')')
 RS:SetAttribute('ChestChaseStartupNotice',nil)
 scriptInst:Destroy();t(gui()==nil,'the gui goes with the script')
end
E.finish('R153 start-up notice')
