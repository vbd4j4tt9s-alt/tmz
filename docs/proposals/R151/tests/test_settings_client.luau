--!nocheck
-- R151 setting "Announcements from other servers", the SETTINGS MENU half: the real SettingsClient on the Roblox mock (real AudioMixer, SettingsConfig, BrightUI, GardenTheme):
--  * the new row sits after the Quality row and before "Replay tutorial"; the canvas grew to fit; the volume rows are where they were
--  * it shows On (default) / Off, a tap flips it and sends {Key='GlobalAnnouncements', Value=<boolean>} to the server through SetSetting, "Saved" follows
--  * the value the server answers (SettingsState) is shown, unless the player already touched it
--  * a failed save is retried; the volume rows and Quality still work next to it (a number or a word, never a boolean, reaches the mixer)
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Enum=R.Enum
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=1000;me.Parent=Players;Players.LocalPlayer=me;function Players.GetPlayers()return {me}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.service('SoundService')
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(1280,720)end;return o end;W.env.Instance=R.Instance end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local request=R.new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
local server={Settings={Music=100,Chase=100,Ambience=100,Effects=100,Interface=100,Quality='Auto',GlobalAnnouncements=true},Calls={},FailSave=false}
function request.InvokeServer(_,action,value)
 server.Calls[#server.Calls+1]={action,value}
 if action=='SettingsState'then return {Success=true,Settings=table.clone(server.Settings)}end
 if action=='SetSetting'then
  if server.FailSave then return {Success=false}end
  local Config=W.module('SettingsConfig');if not Config.Valid(value.Key,value.Value)then return {Success=false,Message='That setting didn\'t work.'}end
  server.Settings[value.Key]=value.Value;return {Success=true}
 end
 return {Success=true}
end
-- (the navigation wheel and the sounds are other scripts' business here)
W.stub('InteractionAudio',{Asset=function()return nil end,Play=function()return true end,Preload=function()end})
W.stub('RarityRevealAudio',{Preload=function()end,Play=function()return true end,Burst=function()end})
local function seconds(s)UW.seconds(s,1/60)end
local function boot(settings)
 server.Settings=settings or{Music=100,Chase=100,Ambience=100,Effects=100,Interface=100,Quality='Auto',GlobalAnnouncements=true};table.clear(server.Calls)
 local old=pg:FindFirstChild('GardenSettings');if old then old:Destroy()end
 local sc=R.new('LocalScript');sc.Name='SettingsClient'
 local ok,err=pcall(W.load,'SettingsClient',sc);check(ok,'SettingsClient loads: '..tostring(err))
 seconds(.1)
 local gui=pg:FindFirstChild('GardenSettings')
 return sc,gui,gui and gui:FindFirstChild('SettingsPanel'),gui and gui.SettingsPanel.Controls
end

local sc,gui,panel,controls=boot()
check(controls~=nil,'the settings panel exists')
local row=controls:FindFirstChild('GlobalAnnouncements')
check(row~=nil and row:IsA('TextButton'),'there is a GlobalAnnouncements row (a button)')
check(row.Label:GetAttribute('FullText')=='Announcements from other servers','its label: "'..tostring(row.Label:GetAttribute('FullText'))..'"')
check(row.Value.Text=='On','default: On')
local quality,replay=controls.Quality,controls.ReplayTutorial
check(row.Position.Y.Offset>quality.Position.Y.Offset+quality.Size.Y.Offset-1 and row.Position.Y.Offset+row.Size.Y.Offset<=replay.Position.Y.Offset,'it sits below Quality and above "Replay tutorial"')
check(row.Position.Y.Offset==340 and replay.Position.Y.Offset==393 and controls.CanvasSize.Y.Offset==444 and replay.Position.Y.Offset+replay.Size.Y.Offset<=controls.CanvasSize.Y.Offset,'positions: row 340, replay 393, canvas 444 (everything fits the canvas)')
check(row.Size.Y.Offset==quality.Size.Y.Offset and row.Size.X.Scale==quality.Size.X.Scale and row.Size.X.Offset==quality.Size.X.Offset,'it is the same size as the Quality row')
local volumes={};for _,k in ipairs({'Music','Chase','Ambience','Effects','Interface'})do volumes[k]=controls:FindFirstChild(k)end
check(volumes.Music.Position.Y.Offset==0 and volumes.Chase.Position.Y.Offset==56 and volumes.Interface.Position.Y.Offset==224 and quality.Position.Y.Offset==287,'the volume rows and Quality are where they were')
-- the saved value is shown
sc,gui,panel,controls=boot({Music=100,Chase=100,Ambience=100,Effects=100,Interface=100,Quality='Auto',GlobalAnnouncements=false})
check(controls.GlobalAnnouncements.Value.Text=='Off','a saved OFF shows Off after SettingsState')
-- a tap flips it and saves it
sc,gui,panel,controls=boot()
local before=#server.Calls
controls.GlobalAnnouncements.Activated:Fire()
check(controls.GlobalAnnouncements.Value.Text=='Off','a tap: Off at once')
seconds(.6)
local set;for _,c in ipairs(server.Calls)do if c[1]=='SetSetting'then set=c[2]end end
check(set and set.Key=='GlobalAnnouncements'and set.Value==false and type(set.Value)=='boolean','the server was sent {Key=GlobalAnnouncements, Value=false} (a boolean)')
check(server.Settings.GlobalAnnouncements==false,'... and kept it')
check(panel.SaveStatus.Text=='Saved','the status line says Saved')
controls.GlobalAnnouncements.Activated:Fire();seconds(.6)
check(controls.GlobalAnnouncements.Value.Text=='On'and server.Settings.GlobalAnnouncements==true,'a second tap: On again, saved')
-- a SettingsState answer arriving after a tap does not undo it
sc,gui,panel,controls=boot({Music=100,Chase=100,Ambience=100,Effects=100,Interface=100,Quality='Auto',GlobalAnnouncements=true})
-- (boot already answered SettingsState: touch it now and open the panel again, which asks again)
controls.GlobalAnnouncements.Activated:Fire();seconds(.1)
pg:SetAttribute('SeedMenu','Settings');seconds(.3);server.Settings.GlobalAnnouncements=true;pg:SetAttribute('SeedMenu',nil);pg:SetAttribute('SeedMenu','Settings');seconds(.3)
check(controls.GlobalAnnouncements.Value.Text=='Off','a tap is not overwritten by a later SettingsState (the player\'s own change wins)')
-- a failed save is retried
sc,gui,panel,controls=boot()
server.FailSave=true;controls.GlobalAnnouncements.Activated:Fire();seconds(.6)
check(panel.SaveStatus.Text:find('Retrying',1,true)~=nil,'a refused save says it will retry')
server.FailSave=false;seconds(3.5)
check(server.Settings.GlobalAnnouncements==false and panel.SaveStatus.Text=='Saved','... and the retry saves it')
-- the other rows still work: numbers and words only reach the mixer, a boolean never does
local Mixer=W.module('AudioMixer')
sc,gui,panel,controls=boot()
controls.Music.Quieter.Activated:Fire();seconds(.6)
check(Mixer.Get('Music')==90 and server.Settings.Music==90,'Music - still saves a volume (90)')
controls.Quality.Activated:Fire();seconds(.6)
check(server.Settings.Quality=='High','Quality still cycles')
controls.GlobalAnnouncements.Activated:Fire();seconds(.6)
check(server.Settings.GlobalAnnouncements==false and Mixer.Group('GlobalAnnouncements')==nil and Mixer.Get('GlobalAnnouncements')==true,'the mixer is never told about the on / off value (no sound group for it, its own copy stays at the default)')
-- a tap is a button: it clicks like the others (ButtonHighlights adds the sound to every TextButton)
check(controls.GlobalAnnouncements:IsA('TextButton'),'it is a TextButton, so it gets the shared hover / click feedback')
sc:Destroy()

print(('R151 settings (menu): %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
